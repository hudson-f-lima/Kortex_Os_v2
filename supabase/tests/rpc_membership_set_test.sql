BEGIN;
SELECT plan(7);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('target@test.local') AS target \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Membership', 'org-membership')).id AS org1 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');

SELECT ok(
  NOT has_function_privilege('authenticated', 'public.membership_set(uuid, uuid, uuid, text, boolean)', 'EXECUTE'),
  'authenticated cannot execute membership_set'
);

-- Happy path: owner sets a new role for a target user.
SELECT (public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'target'::uuid, 'reception')).role AS target_role \gset
SELECT is(:'target_role'::text, 'reception'::text, 'owner1 sets target user role to reception');

-- Upsert: calling again with a different role updates in place, not a duplicate row.
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'target'::uuid, 'manager');
SELECT is(
  (SELECT count(*)::int FROM public.memberships WHERE organization_id = :'org1'::uuid AND user_id = :'target'::uuid),
  1,
  'membership_set upserts instead of creating duplicate membership rows'
);

-- Non-owner actor rejected.
SELECT throws_ok(
  format('select public.membership_set(%L, %L, %L, %L)', :'org1', :'manager1', :'target', 'admin'),
  '42501',
  NULL,
  'manager1 (non-owner) cannot call membership_set'
);

-- Invalid role rejected.
SELECT throws_ok(
  format('select public.membership_set(%L, %L, %L, %L)', :'org1', :'owner1', :'target', 'ceo'),
  '22023',
  NULL,
  'membership_set rejects an invalid role value'
);

-- Nonexistent target user rejected.
SELECT throws_ok(
  format('select public.membership_set(%L, %L, %L, %L)', :'org1', :'owner1', gen_random_uuid(), 'reception'),
  'P0002',
  NULL,
  'membership_set rejects a target user that does not exist'
);

-- Nonexistent organization rejected.
SELECT throws_ok(
  format('select public.membership_set(%L, %L, %L, %L)', gen_random_uuid(), :'owner1', :'target', 'reception'),
  'P0002',
  NULL,
  'membership_set rejects a nonexistent organization'
);

SELECT * FROM finish();
ROLLBACK;
