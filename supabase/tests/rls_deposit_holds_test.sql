-- Onda 1, fatia 003 (issues/003-deposit-holds-creation.md): grant lockdown,
-- authorization of deposit_hold_create (same rule as appointment creation —
-- owner/admin/manager/reception, not professional), and RLS isolation
-- (org-wide vs unit-scoped, cross-tenant, cross-unit) for deposit_holds.
BEGIN;
SELECT plan(11);

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
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('professional1@test.local') AS professional_user1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org Hold', 'org-hold')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Hold Two', 'org-hold-two')).id AS org2 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
INSERT INTO public.units (organization_id, name, timezone) VALUES (:'org1'::uuid, 'Filial Dois', 'America/Sao_Paulo')
  RETURNING id AS unit2 \gset

INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid),
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null),
  (:'org1'::uuid, :'professional_user1'::uuid, 'professional', :'unit1'::uuid);

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4000) RETURNING id AS group1 \gset
INSERT INTO public.services (
  organization_id, name, price_cents, duration_minutes, service_group_id,
  deposit_mechanic, deposit_type, deposit_value
) VALUES (
  :'org1'::uuid, 'Corte Com Depósito', 20000, 30, :'group1'::uuid, 'hold', 'fixed', 2000
) RETURNING id AS service1 \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof Unit1') RETURNING id AS prof1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof Unit2') RETURNING id AS prof2 \gset
-- professionals_link_default_unit already auto-links both to unit1 (the
-- default) on insert; prof2 additionally needs an explicit link to unit2.
INSERT INTO public.professional_units (organization_id, professional_id, unit_id) VALUES (:'org1'::uuid, :'prof2'::uuid, :'unit2'::uuid);
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset

INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-11 10:00+00', '2026-08-11 10:30+00', :'owner1'::uuid)
  RETURNING id AS appt_unit1 \gset
INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'unit2'::uuid, :'client1'::uuid, :'prof2'::uuid, :'service1'::uuid, '2026-08-11 10:00+00', '2026-08-11 10:30+00', :'owner1'::uuid)
  RETURNING id AS appt_unit2 \gset

INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-11 14:00+00', '2026-08-11 14:30+00', :'owner1'::uuid)
  RETURNING id AS appt_for_reception \gset

SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_unit1'::uuid) AS r1 \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_unit2'::uuid) AS r2 \gset
SELECT (SELECT id FROM public.deposit_holds WHERE appointment_id = :'appt_unit1'::uuid) AS hold_unit1 \gset
SELECT (SELECT id FROM public.deposit_holds WHERE appointment_id = :'appt_unit2'::uuid) AS hold_unit2 \gset

-- === authorization: same rule as appointment creation (owner/admin/manager/reception) ===
SELECT lives_ok(
  format('select public.deposit_hold_create(%L, %L, %L)', :'org1', :'reception1', :'appt_for_reception'),
  'reception1 can call deposit_hold_create (same write role as appointment creation)'
);
SELECT throws_ok(
  format('select public.deposit_hold_create(%L, %L, %L)', :'org1', :'professional_user1', :'appt_unit1'),
  '42501',
  NULL,
  'professional_user1 cannot call deposit_hold_create (not a write role for appointments either)'
);

-- === grant lockdown ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.deposit_holds', 'INSERT'),
  'authenticated has no direct INSERT grant on deposit_holds'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.deposit_holds', 'UPDATE'),
  'authenticated has no direct UPDATE grant on deposit_holds'
);

-- === RLS: org-wide vs unit-scoped SELECT, cross-tenant, cross-unit ===
GRANT SELECT ON public.deposit_holds TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.deposit_holds WHERE id = :'hold_unit1'::uuid),
  'owner1 (org-wide role) can select a deposit_hold in unit1'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.deposit_holds WHERE id = :'hold_unit2'::uuid),
  'owner1 (org-wide role) can also select a deposit_hold in unit2'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.deposit_holds WHERE id = :'hold_unit2'::uuid),
  'manager1 (org-wide role, no unit_id on membership) can select a deposit_hold in unit2'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.deposit_holds WHERE id = :'hold_unit1'::uuid),
  'reception1 (scoped to unit1) can select a deposit_hold in unit1'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.deposit_holds WHERE id = :'hold_unit2'::uuid),
  'reception1 (scoped to unit1) cannot select a deposit_hold in unit2 (cross-unit)'
);

SELECT pg_temp.login_as(:'professional_user1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.deposit_holds WHERE id = :'hold_unit1'::uuid),
  'professional_user1 (scoped to unit1) can select a deposit_hold in unit1'
);

SELECT pg_temp.login_as(:'owner2'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.deposit_holds WHERE organization_id = :'org1'::uuid),
  'owner2 (org2) cannot see any deposit_hold from org1 (cross-tenant)'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
