BEGIN;
SELECT plan(14);

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
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('outsider@test.local') AS outsider \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one')).id AS org1 \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null),
  (:'org1'::uuid, :'reception1'::uuid, 'reception', (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default));
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset

-- === Constraints ===
SELECT lives_ok(
  format(
    'insert into public.benefit_obligations (organization_id, client_id, source_type, source_reference, total_cents, status) values (%L, %L, %L, %L, %s, %L)',
    :'org1', :'client1', 'package', 'pkg-001', 10000, 'active'
  ),
  'a valid benefit_obligation can be created'
);
SELECT throws_ok(
  format(
    'insert into public.benefit_obligations (organization_id, client_id, source_type, total_cents, consumed_cents, status) values (%L, %L, %L, %s, %s, %L)',
    :'org1', :'client1', 'package', 10000, 10001, 'active'
  ),
  '23514',
  NULL,
  'consumed_cents cannot exceed total_cents'
);
SELECT throws_ok(
  format(
    'insert into public.benefit_obligations (organization_id, client_id, source_type, total_cents, status) values (%L, %L, %L, %s, %L)',
    :'org1', :'client1', 'subscription', 10000, 'active'
  ),
  '23514',
  NULL,
  'source_type outside the allowlist is rejected'
);
SELECT throws_ok(
  format(
    'insert into public.benefit_obligations (organization_id, client_id, source_type, total_cents, status) values (%L, %L, %L, %s, %L)',
    :'org1', :'client1', 'package', 10000, 'pending'
  ),
  '23514',
  NULL,
  'status outside the allowlist is rejected'
);
SELECT throws_ok(
  format(
    'insert into public.benefit_obligations (organization_id, client_id, source_type, total_cents, status) values (%L, %L, %L, %s, %L)',
    :'org1', :'client1', 'plan', -100, 'active'
  ),
  '23514',
  NULL,
  'total_cents cannot be negative'
);
SELECT throws_ok(
  format(
    'insert into public.benefit_obligations (organization_id, client_id, source_type, total_cents, consumed_cents, status) values (%L, %L, %L, %s, %s, %L)',
    :'org1', :'client1', 'corporate', 10000, -1, 'active'
  ),
  '23514',
  NULL,
  'consumed_cents cannot be negative'
);
SELECT throws_ok(
  format(
    'insert into public.benefit_obligations (organization_id, client_id, source_type, total_cents, status) values (%L, %L, %L, %s, %L)',
    :'org1', gen_random_uuid(), 'partner', 5000, 'active'
  ),
  '23503',
  NULL,
  'client_id must belong to a real client in the organization'
);

-- === Layer 1: grants — no direct table privilege for anon/authenticated ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.benefit_obligations', 'INSERT'),
  'authenticated has no direct INSERT grant on benefit_obligations'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.benefit_obligations', 'UPDATE'),
  'authenticated has no direct UPDATE grant on benefit_obligations'
);
SELECT ok(
  NOT has_table_privilege('anon', 'public.benefit_obligations', 'SELECT'),
  'anon has no direct SELECT grant on benefit_obligations'
);

-- === Layer 2: RLS policies ===
GRANT SELECT ON public.benefit_obligations TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.benefit_obligations WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'owner can read a benefit_obligation'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.benefit_obligations WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'manager can read a benefit_obligation'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.benefit_obligations WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'reception cannot read benefit_obligations (raw financial data)'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'outsider'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.benefit_obligations WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'a user with no membership cannot read any benefit_obligations row'
);
SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
