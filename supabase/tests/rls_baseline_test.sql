BEGIN;
SELECT plan(20);

-- Helpers: simulate Supabase Auth JWT context inside this transaction only.
CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

CREATE FUNCTION pg_temp.login_as(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  SET LOCAL role authenticated;
END;
$$;

CREATE FUNCTION pg_temp.logout() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  RESET role;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$$;

-- Fixtures (created as postgres/service-role-equivalent, bypassing RLS).
SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('owner1b@test.local') AS owner1b \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset
SELECT pg_temp.mk_user('outsider@test.local') AS outsider \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Two', 'org-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'owner1b'::uuid, 'owner');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');

-- === Layer 1: grants ===
-- anon/authenticated must have zero direct table privileges; all business access
-- goes through the backend's service_role after JWT validation (defense in depth).
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.organizations', 'SELECT'),
  'authenticated has no direct SELECT grant on organizations'
);
SELECT ok(
  NOT has_table_privilege('anon', 'public.organizations', 'SELECT'),
  'anon has no direct SELECT grant on organizations'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.memberships', 'INSERT'),
  'authenticated has no direct INSERT grant on memberships'
);

-- private.idempotency_keys: internal RPC bookkeeping (checkout_close,
-- create_appointment, etc.), never meant to be queryable by a client — RLS
-- enabled with zero policies is the correct terminal state, not a gap
-- (2026-07-17 production advisor finding, closed by this migration).
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE relnamespace = 'private'::regnamespace AND relname = 'idempotency_keys'),
  'private.idempotency_keys has RLS enabled'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'private.idempotency_keys', 'SELECT'),
  'authenticated has no direct SELECT grant on private.idempotency_keys'
);
SELECT ok(
  NOT has_table_privilege('anon', 'private.idempotency_keys', 'SELECT'),
  'anon has no direct SELECT grant on private.idempotency_keys'
);
SELECT is(
  (SELECT count(*)::integer FROM pg_policies WHERE schemaname = 'private' AND tablename = 'idempotency_keys'),
  0,
  'private.idempotency_keys has zero RLS policies (deny-all by design)'
);

-- === Layer 2: RLS policies (temporarily grant table privileges within this
-- transaction only, to prove policies isolate tenants even if grants ever change) ===
GRANT SELECT, UPDATE ON public.organizations TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.memberships TO authenticated;
GRANT SELECT, UPDATE ON public.profiles TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.organizations WHERE id = :'org1'::uuid),
  'owner1 sees org1'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.organizations WHERE id = :'org2'::uuid),
  'owner1 cannot see org2 (cross-tenant select denied)'
);
SELECT lives_ok(
  format('update public.organizations set name = %L where id = %L', 'Org One Renamed', :'org1'),
  'owner1 (role owner) can update org1'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
WITH u AS (
  UPDATE public.organizations SET name = 'Hacked' WHERE id = :'org1'::uuid RETURNING id
)
SELECT is(
  (SELECT count(*) FROM u),
  0::bigint,
  'reception1 (insufficient role) cannot update org1'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.organizations WHERE id = :'org1'::uuid),
  'reception1 still sees org1 (is_member true)'
);

SELECT pg_temp.login_as(:'outsider'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.organizations WHERE id = :'org1'::uuid),
  'outsider (no membership) cannot see org1'
);

-- memberships: only owner role can insert new memberships directly.
SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT throws_ok(
  format(
    'insert into public.memberships (organization_id, user_id, role) values (%L, %L, %L)',
    :'org1', :'outsider', 'manager'
  ),
  '42501',
  NULL,
  'reception1 cannot insert a membership (owner-only policy)'
);

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT lives_ok(
  format(
    'insert into public.memberships (organization_id, user_id, role) values (%L, %L, %L)',
    :'org1', :'outsider', 'manager'
  ),
  'owner1 can insert a membership directly'
);

-- profiles: strictly self-only.
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.profiles WHERE user_id = :'owner1'::uuid),
  'owner1 sees own profile'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.profiles WHERE user_id = :'owner2'::uuid),
  'owner1 cannot see owner2 profile'
);
WITH u AS (
  UPDATE public.profiles SET display_name = 'Hacked' WHERE user_id = :'owner2'::uuid RETURNING user_id
)
SELECT is(
  (SELECT count(*) FROM u),
  0::bigint,
  'owner1 cannot update owner2 profile'
);

SELECT pg_temp.logout();

-- === Invariant: organization must retain an active owner ===
-- org1 currently has two active owners (owner1, owner1b): demoting one is fine.
SELECT lives_ok(
  format('update public.memberships set active = false where organization_id = %L and user_id = %L', :'org1', :'owner1b'),
  'demoting owner1b succeeds while owner1 remains an active owner'
);
-- now org1 has a single active owner (owner1): demoting it must fail.
SELECT throws_ok(
  format('update public.memberships set active = false where organization_id = %L and user_id = %L', :'org1', :'owner1'),
  '23514',
  NULL,
  'demoting the sole remaining owner is impossible'
);

SELECT * FROM finish();
ROLLBACK;
