BEGIN;
SELECT plan(22);

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

SELECT (public.create_organization(:'owner1'::uuid, 'Org PSCap', 'org-pscap')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org PSCap Two', 'org-pscap-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'admin1'::uuid, 'admin');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'professional1_user'::uuid, 'professional');

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid)
  RETURNING id AS service1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Escova', 4000, 20, :'group1'::uuid)
  RETURNING id AS service2 \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Ana')
  RETURNING id AS professional1 \gset

-- === schema-level invariants ===
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_capabilities (organization_id, professional_id, service_id, duration_override_minutes)
    values (%L, %L, %L, 3)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  '23514',
  NULL,
  'duration_override_minutes below 5 is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_capabilities (organization_id, professional_id, service_id, buffer_before_min)
    values (%L, %L, %L, -1)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  '23514',
  NULL,
  'negative buffer_before_min is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_capabilities (organization_id, professional_id, service_id, buffer_after_min)
    values (%L, %L, %L, 481)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  '23514',
  NULL,
  'buffer_after_min above 480 is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_capabilities (organization_id, professional_id, service_id, price_override_cents)
    values (%L, %L, %L, -100)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  '23514',
  NULL,
  'negative price_override_cents is rejected'
);
SELECT lives_ok(
  format(
    $sql$insert into public.professional_service_capabilities (organization_id, professional_id, service_id, duration_override_minutes, buffer_before_min, buffer_after_min, price_override_cents)
    values (%L, %L, %L, 45, 10, 5, 6000)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  'a valid capability row can be inserted'
);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_capabilities (organization_id, professional_id, service_id, duration_override_minutes)
    values (%L, %L, %L, 40)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  '23505',
  NULL,
  'a duplicate (organization_id, professional_id, service_id) capability is rejected'
);

-- === grant lockdown ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.professional_service_capabilities', 'INSERT'),
  'authenticated has no direct INSERT grant on professional_service_capabilities'
);

-- === RLS layer (temporary grants within this transaction only) ===
GRANT SELECT, INSERT, UPDATE, DELETE ON public.professional_service_capabilities TO authenticated;

-- SELECT: any active member can read (owner/admin/manager/reception/professional)
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.professional_service_capabilities WHERE organization_id = :'org1'::uuid),
  'owner1 can select capabilities'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.professional_service_capabilities WHERE organization_id = :'org1'::uuid),
  'reception1 can select capabilities (read is open to any active member)'
);

SELECT pg_temp.login_as(:'professional1_user'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.professional_service_capabilities WHERE organization_id = :'org1'::uuid),
  'professional1 can select capabilities (read is open to any active member)'
);

-- Cross-tenant isolation
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.professional_service_capabilities WHERE organization_id = :'org2'::uuid),
  'professional1 (org1) cannot see capabilities from org2 (cross-tenant)'
);

-- INSERT: owner/admin/manager only
SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_capabilities (organization_id, professional_id, service_id, duration_override_minutes)
    values (%L, %L, %L, 50)$sql$,
    :'org1', :'professional1', :'service2'
  ),
  '42501',
  NULL,
  'reception1 cannot insert a capability (owner/admin/manager required)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT lives_ok(
  format(
    $sql$insert into public.professional_service_capabilities (organization_id, professional_id, service_id, duration_override_minutes)
    values (%L, %L, %L, 55)$sql$,
    :'org1', :'professional1', :'service2'
  ),
  'manager1 can insert a capability'
);

-- UPDATE: owner/admin/manager only
SELECT pg_temp.login_as(:'reception1'::uuid);
WITH u AS (
  UPDATE public.professional_service_capabilities
  SET duration_override_minutes = 70
  WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM u),
  0::bigint,
  'reception1 cannot update a capability (RLS-filtered, affects zero rows)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
WITH u AS (
  UPDATE public.professional_service_capabilities
  SET duration_override_minutes = 70
  WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM u),
  1::bigint,
  'manager1 can update a capability'
);

-- DELETE: owner/admin only (manager cannot)
SELECT pg_temp.login_as(:'manager1'::uuid);
WITH d AS (
  DELETE FROM public.professional_service_capabilities
  WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM d),
  0::bigint,
  'manager1 cannot delete a capability (owner/admin required)'
);

SELECT pg_temp.login_as(:'admin1'::uuid);
WITH d AS (
  DELETE FROM public.professional_service_capabilities
  WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM d),
  1::bigint,
  'admin1 can delete a capability'
);

SELECT pg_temp.logout();

-- === appointments hardening (Fase 10 extended scope) ===
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente Teste', :'owner1'::uuid)
  RETURNING id AS client1 \gset

INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'professional1'::uuid, :'service1'::uuid, now() + interval '1 day', now() + interval '1 day 30 minutes', :'owner1'::uuid)
  RETURNING id AS appointment1, version AS appt1_version_initial \gset

SELECT is(
  :'appt1_version_initial'::bigint,
  1::bigint,
  'a freshly created appointment starts at version 1'
);

UPDATE public.appointments SET status = 'confirmed' WHERE id = :'appointment1'::uuid;
SELECT is(
  (SELECT version FROM public.appointments WHERE id = :'appointment1'::uuid),
  2::bigint,
  'updating an appointment increments its version'
);

UPDATE public.appointments SET status = 'completed' WHERE id = :'appointment1'::uuid;
SELECT throws_ok(
  format(
    $sql$update public.appointments set status = 'scheduled' where id = %L$sql$,
    :'appointment1'
  ),
  '23514',
  'completed appointments are immutable',
  'a completed appointment cannot transition to another status'
);
SELECT throws_ok(
  format(
    $sql$update public.appointments set status = 'cancelled' where id = %L$sql$,
    :'appointment1'
  ),
  '23514',
  'completed appointments are immutable',
  'a completed appointment cannot be cancelled either'
);
SELECT lives_ok(
  format(
    $sql$update public.appointments set status = 'completed' where id = %L$sql$,
    :'appointment1'
  ),
  'a completed appointment can be re-saved as completed (no-op transition allowed)'
);

SELECT * FROM finish();
ROLLBACK;
