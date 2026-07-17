BEGIN;
SELECT plan(15);

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
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org GroupElig', 'org-groupelig')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org GroupElig Two', 'org-groupelig-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Unhas', 'percentage', 4000)
  RETURNING id AS group2 \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Ana')
  RETURNING id AS professional1 \gset

-- === schema-level invariants ===
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_group_eligibility (organization_id, professional_id, service_group_id, eligibility)
    values (%L, %L, %L, 'not_a_real_state')$sql$,
    :'org1', :'professional1', :'group1'
  ),
  '23514',
  NULL,
  'an eligibility value outside INHERIT/ENABLED/DISABLED is rejected'
);
SELECT lives_ok(
  format(
    $sql$insert into public.professional_service_group_eligibility (organization_id, professional_id, service_group_id, eligibility)
    values (%L, %L, %L, 'INHERIT')$sql$,
    :'org1', :'professional1', :'group1'
  ),
  'a valid group eligibility row can be inserted'
);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_group_eligibility (organization_id, professional_id, service_group_id, eligibility)
    values (%L, %L, %L, 'ENABLED')$sql$,
    :'org1', :'professional1', :'group1'
  ),
  '23505',
  NULL,
  'a duplicate (organization_id, professional_id, service_group_id) row is rejected'
);

-- === grant lockdown ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.professional_service_group_eligibility', 'INSERT'),
  'authenticated has no direct INSERT grant on professional_service_group_eligibility'
);

-- === RLS layer (temporary grants within this transaction only) ===
GRANT SELECT, INSERT, UPDATE, DELETE ON public.professional_service_group_eligibility TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.professional_service_group_eligibility WHERE organization_id = :'org1'::uuid),
  'owner1 can select group eligibility rows'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.professional_service_group_eligibility WHERE organization_id = :'org1'::uuid),
  'reception1 can select group eligibility rows (read is open to any active member)'
);

-- Cross-tenant isolation
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.professional_service_group_eligibility WHERE organization_id = :'org2'::uuid),
  'reception1 (org1) cannot see group eligibility rows from org2'
);

-- INSERT: owner/admin/manager only
SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_group_eligibility (organization_id, professional_id, service_group_id, eligibility)
    values (%L, %L, %L, 'DISABLED')$sql$,
    :'org1', :'professional1', :'group1'
  ),
  '42501',
  NULL,
  'reception1 cannot insert a group eligibility row (owner/admin/manager required)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT lives_ok(
  format(
    $sql$insert into public.professional_service_group_eligibility (organization_id, professional_id, service_group_id, eligibility)
    values (%L, %L, %L, 'DISABLED')$sql$,
    :'org1', :'professional1', :'group2'
  ),
  'manager1 can insert a group eligibility row'
);

-- UPDATE: owner/admin/manager only
SELECT pg_temp.login_as(:'reception1'::uuid);
WITH u AS (
  UPDATE public.professional_service_group_eligibility
  SET eligibility = 'ENABLED'
  WHERE organization_id = :'org1'::uuid AND service_group_id = :'group2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM u),
  0::bigint,
  'reception1 cannot update a group eligibility row (RLS-filtered, affects zero rows)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
WITH u AS (
  UPDATE public.professional_service_group_eligibility
  SET eligibility = 'ENABLED'
  WHERE organization_id = :'org1'::uuid AND service_group_id = :'group2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM u),
  1::bigint,
  'manager1 can update a group eligibility row'
);

-- DELETE: owner/admin only (manager cannot)
SELECT pg_temp.login_as(:'manager1'::uuid);
WITH d AS (
  DELETE FROM public.professional_service_group_eligibility
  WHERE organization_id = :'org1'::uuid AND service_group_id = :'group2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM d),
  0::bigint,
  'manager1 cannot delete a group eligibility row (owner/admin required)'
);

SELECT pg_temp.login_as(:'owner1'::uuid);
WITH d AS (
  DELETE FROM public.professional_service_group_eligibility
  WHERE organization_id = :'org1'::uuid AND service_group_id = :'group2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM d),
  1::bigint,
  'owner1 can delete a group eligibility row'
);

SELECT pg_temp.logout();

-- === organizations.default_service_eligibility ===
SELECT is(
  (SELECT default_service_eligibility FROM public.organizations WHERE id = :'org1'::uuid),
  'ENABLED',
  'default_service_eligibility is ENABLED by default for a newly created organization'
);
SELECT throws_ok(
  format(
    $sql$update public.organizations set default_service_eligibility = 'nope' where id = %L$sql$,
    :'org1'
  ),
  '23514',
  NULL,
  'default_service_eligibility only accepts ENABLED or DISABLED'
);

SELECT * FROM finish();
ROLLBACK;
