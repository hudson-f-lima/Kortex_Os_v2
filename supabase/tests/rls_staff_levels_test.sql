-- Onda 3, fatia 018 (issues/018-staff-levels-professional-assignment.md,
-- Blueprint §2/§3.1/§3.8/§4, DEC-46): staff_levels + professionals.staff_level_id.
BEGIN;
SELECT plan(19);

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
SELECT pg_temp.mk_user('admin1@test.local') AS admin1 \gset
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('professional1_user@test.local') AS professional1_user \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org StaffLevels', 'org-stafflevels')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org StaffLevels Two', 'org-stafflevels-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'admin1'::uuid, 'admin');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'professional1_user'::uuid, 'professional');

INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Ana')
  RETURNING id AS professional1 \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org2'::uuid, 'Bia')
  RETURNING id AS professional2 \gset

-- === schema-level invariants ===
SELECT lives_ok(
  format(
    $sql$insert into public.staff_levels (organization_id, name, rank) values (%L, 'Aprendiz', 0)$sql$,
    :'org1'
  ),
  'a valid staff_level row can be inserted'
);
INSERT INTO public.staff_levels (organization_id, name, rank)
  VALUES (:'org1'::uuid, 'Senior', 1)
  RETURNING id AS level1_senior \gset
INSERT INTO public.staff_levels (organization_id, name, rank)
  VALUES (:'org2'::uuid, 'Aprendiz', 0)
  RETURNING id AS level2_aprendiz \gset

SELECT throws_ok(
  format($sql$insert into public.staff_levels (organization_id, name, rank) values (%L, 'Senior', 5)$sql$, :'org1'),
  '23505',
  NULL,
  'duplicate (organization_id, name) is rejected'
);
SELECT throws_ok(
  format($sql$insert into public.staff_levels (organization_id, name, rank) values (%L, 'Pleno', 1)$sql$, :'org1'),
  '23505',
  NULL,
  'duplicate (organization_id, rank) is rejected'
);
SELECT throws_ok(
  format($sql$insert into public.staff_levels (organization_id, name, rank) values (%L, '', 9)$sql$, :'org1'),
  '23514',
  NULL,
  'empty name is rejected'
);
SELECT throws_ok(
  format($sql$insert into public.staff_levels (organization_id, name, rank) values (%L, 'Negativo', -1)$sql$, :'org1'),
  '23514',
  NULL,
  'negative rank is rejected'
);

-- === RLS layer (temporary grants within this transaction only) ===
GRANT SELECT, INSERT, UPDATE, DELETE ON public.staff_levels TO authenticated;
GRANT SELECT, UPDATE ON public.professionals TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.staff_levels WHERE organization_id = :'org1'::uuid),
  'owner1 can select staff_levels'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.staff_levels WHERE organization_id = :'org1'::uuid),
  'reception1 can select staff_levels (read is open to any active member)'
);

SELECT pg_temp.login_as(:'professional1_user'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.staff_levels WHERE organization_id = :'org1'::uuid),
  'professional1 can select staff_levels (read is open to any active member)'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.staff_levels WHERE organization_id = :'org2'::uuid),
  'professional1 (org1) cannot see staff_levels from org2 (cross-tenant)'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT throws_ok(
  format($sql$insert into public.staff_levels (organization_id, name, rank) values (%L, 'Reception Level', 8)$sql$, :'org1'),
  '42501',
  NULL,
  'reception1 cannot insert a staff_level (owner/admin/manager required)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT lives_ok(
  format($sql$insert into public.staff_levels (organization_id, name, rank) values (%L, 'Manager Level', 7)$sql$, :'org1'),
  'manager1 can insert a staff_level'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
WITH u AS (
  UPDATE public.staff_levels SET rank = 70 WHERE organization_id = :'org1'::uuid AND name = 'Manager Level' RETURNING id
)
SELECT is((SELECT count(*) FROM u), 0::bigint, 'reception1 cannot update a staff_level');

SELECT pg_temp.login_as(:'manager1'::uuid);
WITH u AS (
  UPDATE public.staff_levels SET rank = 70 WHERE organization_id = :'org1'::uuid AND name = 'Manager Level' RETURNING id
)
SELECT is((SELECT count(*) FROM u), 1::bigint, 'manager1 can update a staff_level');

SELECT pg_temp.login_as(:'manager1'::uuid);
WITH d AS (
  DELETE FROM public.staff_levels WHERE organization_id = :'org1'::uuid AND name = 'Manager Level' RETURNING id
)
SELECT is((SELECT count(*) FROM d), 0::bigint, 'manager1 cannot delete a staff_level (owner/admin required)');

SELECT pg_temp.login_as(:'admin1'::uuid);
WITH d AS (
  DELETE FROM public.staff_levels WHERE organization_id = :'org1'::uuid AND name = 'Manager Level' RETURNING id
)
SELECT is((SELECT count(*) FROM d), 1::bigint, 'admin1 can delete a staff_level');

-- === professionals.staff_level_id ===
SELECT lives_ok(
  format($sql$update public.professionals set staff_level_id = null where id = %L$sql$, :'professional1'),
  'professionals.staff_level_id accepts null'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT lives_ok(
  format($sql$update public.professionals set staff_level_id = %L where id = %L$sql$, :'level1_senior', :'professional1'),
  'professionals.staff_level_id accepts a valid level from the same organization'
);

SELECT pg_temp.logout();

SELECT throws_ok(
  format($sql$update public.professionals set staff_level_id = %L where id = %L$sql$, :'level2_aprendiz', :'professional1'),
  '23503',
  NULL,
  'professionals.staff_level_id rejects a level from another organization (cross-tenant FK violation)'
);

SELECT throws_ok(
  format($sql$delete from public.staff_levels where id = %L$sql$, :'level1_senior'),
  '23503',
  NULL,
  'deleting a staff_level referenced by a professional is blocked (on delete restrict)'
);

SELECT * FROM finish();
ROLLBACK;
