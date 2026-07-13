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
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org PSC', 'org-psc')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org PSC Two', 'org-psc-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');

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
    $sql$insert into public.professional_service_commissions (organization_id, professional_id, service_id, commission_type, commission_value)
    values (%L, %L, %L, 'percentage', 10001)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  '23514',
  NULL,
  'a percentage commission_value above 10000 basis points (100%) is rejected'
);
SELECT lives_ok(
  format(
    $sql$insert into public.professional_service_commissions (organization_id, professional_id, service_id, commission_type, commission_value)
    values (%L, %L, %L, 'fixed', 999999)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  'a fixed commission_value is not bounded by the percentage range check'
);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_commissions (organization_id, professional_id, service_id, commission_type, commission_value)
    values (%L, %L, %L, 'percentage', 1000)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  '23505',
  NULL,
  'a duplicate (organization_id, professional_id, service_id) override is rejected'
);

-- === grant lockdown ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.professional_service_commissions', 'INSERT'),
  'authenticated has no direct INSERT grant on professional_service_commissions'
);

-- === RLS layer (temporary grants within this transaction only) ===
GRANT SELECT, INSERT, UPDATE, DELETE ON public.professional_service_commissions TO authenticated;

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.professional_service_commissions WHERE organization_id = :'org1'::uuid),
  'reception1 cannot select professional_service_commissions (financial data, owner/admin/manager only)'
);
SELECT throws_ok(
  format(
    $sql$insert into public.professional_service_commissions (organization_id, professional_id, service_id, commission_type, commission_value)
    values (%L, %L, %L, 'percentage', 2000)$sql$,
    :'org1', :'professional1', :'service1'
  ),
  '42501',
  NULL,
  'reception1 cannot insert a professional_service_commission (owner/admin/manager required)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT lives_ok(
  format(
    $sql$insert into public.professional_service_commissions (organization_id, professional_id, service_id, commission_type, commission_value)
    values (%L, %L, %L, 'percentage', 3000)$sql$,
    :'org1', :'professional1', :'service2'
  ),
  'manager1 can insert a professional_service_commission'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.professional_service_commissions WHERE organization_id = :'org1'::uuid),
  'manager1 (owner/admin/manager) can select professional_service_commissions in org1'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.professional_service_commissions WHERE organization_id = :'org2'::uuid),
  'manager1 cannot see professional_service_commissions from org2 (cross-tenant)'
);
-- RLS-filtered DELETE does not raise (USING just hides the row from the
-- statement), it silently affects zero rows.
WITH d AS (
  DELETE FROM public.professional_service_commissions
  WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM d),
  0::bigint,
  'manager1 cannot delete a professional_service_commission (owner/admin required)'
);

SELECT pg_temp.login_as(:'owner1'::uuid);
WITH d AS (
  DELETE FROM public.professional_service_commissions
  WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM d),
  1::bigint,
  'owner1 can delete a professional_service_commission'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
