-- Onda 3, fatia 019 (issues/019-staff-level-service-overrides-pricing-resolution.md,
-- Blueprint §0/§2/§3.2/§3.3/§3.8/§4, DEC-46):
-- staff_level_service_overrides + private.resolve_service_pricing().
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
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org ResolvePricing', 'org-resolve-pricing')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org ResolvePricing Two', 'org-resolve-pricing-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'admin1'::uuid, 'admin');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid)
  RETURNING id AS service1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Escova', 4000, 20, :'group1'::uuid)
  RETURNING id AS service2 \gset

INSERT INTO public.staff_levels (organization_id, name, rank) VALUES (:'org1'::uuid, 'Senior', 1) RETURNING id AS level1_senior \gset
INSERT INTO public.staff_levels (organization_id, name, rank) VALUES (:'org2'::uuid, 'Junior', 0) RETURNING id AS level2_junior \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Ana') RETURNING id AS professional_base \gset
INSERT INTO public.professionals (organization_id, name, staff_level_id) VALUES (:'org1'::uuid, 'Bia', :'level1_senior'::uuid) RETURNING id AS professional_leveled \gset
INSERT INTO public.professionals (organization_id, name, staff_level_id) VALUES (:'org1'::uuid, 'Cau', :'level1_senior'::uuid) RETURNING id AS professional_leveled_override \gset

-- === schema-level invariants ===
SELECT lives_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, price_override_cents, duration_override_minutes)
    values (%L, %L, %L, 7000, 25)$sql$,
    :'org1', :'level1_senior', :'service1'
  ),
  'a valid override row can be inserted'
);
SELECT throws_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, price_override_cents)
    values (%L, %L, %L, 8000)$sql$,
    :'org1', :'level1_senior', :'service1'
  ),
  '23505',
  NULL,
  'duplicate (organization_id, staff_level_id, service_id) is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, duration_override_minutes)
    values (%L, %L, %L, 3)$sql$,
    :'org1', :'level1_senior', :'service2'
  ),
  '23514',
  NULL,
  'duration_override_minutes below 5 is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, duration_override_minutes)
    values (%L, %L, %L, 1441)$sql$,
    :'org1', :'level1_senior', :'service2'
  ),
  '23514',
  NULL,
  'duration_override_minutes above 1440 is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, price_override_cents)
    values (%L, %L, %L, -100)$sql$,
    :'org1', :'level1_senior', :'service2'
  ),
  '23514',
  NULL,
  'negative price_override_cents is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, commission_type)
    values (%L, %L, %L, 'percentage')$sql$,
    :'org1', :'level1_senior', :'service2'
  ),
  '23514',
  NULL,
  'commission_type without commission_value is rejected (pair check)'
);
SELECT throws_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, commission_type, commission_value)
    values (%L, %L, %L, 'percentage', 10001)$sql$,
    :'org1', :'level1_senior', :'service2'
  ),
  '23514',
  NULL,
  'commission_value above 10000 basis points for percentage is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, price_override_cents)
    values (%L, %L, %L, 1000)$sql$,
    :'org1', :'level2_junior', :'service1'
  ),
  '23503',
  NULL,
  'staff_level_id from another organization is rejected (cross-tenant FK)'
);

-- === RLS layer (temporary grants within this transaction only) ===
GRANT SELECT, INSERT, UPDATE, DELETE ON public.staff_level_service_overrides TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.staff_level_service_overrides WHERE organization_id = :'org1'::uuid),
  'owner1 can select overrides'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.staff_level_service_overrides WHERE organization_id = :'org1'::uuid),
  'manager1 can select overrides'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.staff_level_service_overrides WHERE organization_id = :'org1'::uuid),
  'reception1 cannot select overrides (financial data, stricter than professional_service_capabilities)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.staff_level_service_overrides WHERE organization_id = :'org2'::uuid),
  'manager1 (org1) cannot see overrides from org2 (cross-tenant)'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT throws_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, price_override_cents)
    values (%L, %L, %L, 1500)$sql$,
    :'org1', :'level1_senior', :'service2'
  ),
  '42501',
  NULL,
  'reception1 cannot insert an override (owner/admin/manager required)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT lives_ok(
  format(
    $sql$insert into public.staff_level_service_overrides (organization_id, staff_level_id, service_id, price_override_cents)
    values (%L, %L, %L, 1500)$sql$,
    :'org1', :'level1_senior', :'service2'
  ),
  'manager1 can insert an override'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
WITH u AS (
  UPDATE public.staff_level_service_overrides SET price_override_cents = 1600
  WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid RETURNING id
)
SELECT is((SELECT count(*) FROM u), 0::bigint, 'reception1 cannot update an override');

SELECT pg_temp.login_as(:'manager1'::uuid);
WITH u AS (
  UPDATE public.staff_level_service_overrides SET price_override_cents = 1600
  WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid RETURNING id
)
SELECT is((SELECT count(*) FROM u), 1::bigint, 'manager1 can update an override');

WITH d AS (
  DELETE FROM public.staff_level_service_overrides WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid RETURNING id
)
SELECT is((SELECT count(*) FROM d), 0::bigint, 'manager1 cannot delete an override (owner/admin required)');

SELECT pg_temp.login_as(:'admin1'::uuid);
WITH d AS (
  DELETE FROM public.staff_level_service_overrides WHERE organization_id = :'org1'::uuid AND service_id = :'service2'::uuid RETURNING id
)
SELECT is((SELECT count(*) FROM d), 1::bigint, 'admin1 can delete an override');

SELECT pg_temp.logout();

-- === private.resolve_service_pricing() cascade ===
SELECT is(
  (SELECT (price_cents, duration_minutes) FROM private.resolve_service_pricing(:'org1'::uuid, :'professional_base'::uuid, :'service1'::uuid)),
  (5000::bigint, 30),
  'no override at all: falls back to the service base price/duration'
);

SELECT is(
  (SELECT (price_cents, duration_minutes) FROM private.resolve_service_pricing(:'org1'::uuid, :'professional_leveled'::uuid, :'service1'::uuid)),
  (7000::bigint, 25),
  'level-only override (professional has staff_level_id, no professional x service override): level wins'
);

INSERT INTO public.professional_service_capabilities (organization_id, professional_id, service_id, price_override_cents, duration_override_minutes)
  VALUES (:'org1'::uuid, :'professional_leveled_override'::uuid, :'service1'::uuid, 9000, 40);
SELECT is(
  (SELECT (price_cents, duration_minutes) FROM private.resolve_service_pricing(:'org1'::uuid, :'professional_leveled_override'::uuid, :'service1'::uuid)),
  (9000::bigint, 40),
  'professional x service override wins over level override (most specific)'
);

SELECT is(
  (SELECT (price_cents, duration_minutes) FROM private.resolve_service_pricing(:'org1'::uuid, :'professional_base'::uuid, :'service1'::uuid)),
  (5000::bigint, 30),
  'professional without staff_level_id falls back to base, even though a level override exists for this service'
);

SELECT * FROM finish();
ROLLBACK;
