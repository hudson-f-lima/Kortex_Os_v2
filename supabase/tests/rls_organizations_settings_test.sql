BEGIN;
SELECT plan(4);

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

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org Settings', 'org-settings')).id AS org1 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');

-- Behavior 1 (issue 017): new organization is born with settings = '{}'.
SELECT is(
  (SELECT settings FROM public.organizations WHERE id = :'org1'::uuid),
  '{}'::jsonb,
  'new organization is born with settings = {}'
);

-- Layer 2: RLS policies (temporarily grant table privileges within this
-- transaction only, same pattern as rls_baseline_test.sql).
GRANT SELECT, UPDATE ON public.organizations TO authenticated;

-- Behavior 2 (issue 017): owner/admin can update settings — reuses the
-- existing organizations_update policy (owner/admin allowlist), no new
-- policy needed since settings is just another column on the same row.
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT lives_ok(
  format('update public.organizations set settings = %L where id = %L', '{"staff_levels_enabled": true}'::jsonb, :'org1'),
  'owner1 (role owner) can update settings'
);
SELECT is(
  (SELECT settings FROM public.organizations WHERE id = :'org1'::uuid),
  '{"staff_levels_enabled": true}'::jsonb,
  'settings update is persisted correctly'
);

-- Behavior 3 (issue 017): role outside the owner/admin allowlist is rejected
-- (same organizations_update policy already covers this — RLS silently
-- filters the row out of the UPDATE, same assertion style as
-- rls_baseline_test.sql's "insufficient role" case).
SELECT pg_temp.login_as(:'reception1'::uuid);
WITH u AS (
  UPDATE public.organizations SET settings = '{"hacked": true}'::jsonb WHERE id = :'org1'::uuid RETURNING id
)
SELECT is(
  (SELECT count(*) FROM u),
  0::bigint,
  'reception1 (insufficient role) cannot update settings'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
