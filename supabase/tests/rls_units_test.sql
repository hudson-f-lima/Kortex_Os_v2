BEGIN;
SELECT plan(17);

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
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset
SELECT pg_temp.mk_user('outsider@test.local') AS outsider \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Two', 'org-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');

SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org2'::uuid AND is_default) AS unit2 \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Um') RETURNING id AS professional1 \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Grupo Um', 'percentage', 1000) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid) RETURNING id AS service1 \gset

-- membership_set has no unit_id parameter (RPC untouched by Onda 0) — the
-- default-fill trigger on memberships must resolve it to org1's default unit.
SELECT is(
  (SELECT unit_id FROM public.memberships WHERE organization_id = :'org1'::uuid AND user_id = :'reception1'::uuid),
  :'unit1'::uuid,
  'membership_set, with no unit_id parameter, still gets unit_id auto-filled to the org default by trigger'
);

-- === Layer 1: grants — no direct table privilege for anon/authenticated ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.units', 'SELECT'),
  'authenticated has no direct SELECT grant on units'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.unit_access_audit_events', 'SELECT'),
  'authenticated has no direct SELECT grant on unit_access_audit_events'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.unit_access_audit_events', 'INSERT'),
  'authenticated has no direct INSERT grant on unit_access_audit_events'
);

-- === Layer 2: RLS policies (temporarily grant table privileges within this
-- transaction only, to prove policies isolate tenants even if grants ever change) ===
GRANT SELECT, INSERT ON public.units TO authenticated;
GRANT SELECT, INSERT ON public.professional_units TO authenticated;
GRANT SELECT, INSERT ON public.unit_access_audit_events TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.units WHERE id = :'unit1'::uuid),
  'owner1 sees org1''s default unit'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.units WHERE id = :'unit2'::uuid),
  'owner1 cannot see org2''s unit (cross-tenant select denied)'
);
SELECT lives_ok(
  format('insert into public.units (organization_id, name, timezone) values (%L, %L, %L)', :'org1', 'Filial Centro', 'America/Sao_Paulo'),
  'owner1 (role owner) can insert a second unit in org1'
);
SELECT throws_ok(
  format('insert into public.unit_access_audit_events (organization_id, event_type, actor_kind, actor_user_id) values (%L, %L, %L, %L)', :'org1', 'unit_created', 'user', :'owner1'),
  '42501',
  NULL,
  'owner1 cannot insert directly into unit_access_audit_events (no RLS insert policy — append-only via security definer functions only)'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.units WHERE id = :'unit1'::uuid),
  'reception1 (any active member) can still see org1''s unit'
);
SELECT throws_ok(
  format('insert into public.units (organization_id, name, timezone) values (%L, %L, %L)', :'org1', 'Filial Indevida', 'America/Sao_Paulo'),
  '42501',
  NULL,
  'reception1 (insufficient role) cannot insert a new unit'
);

SELECT pg_temp.login_as(:'outsider'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.units WHERE id = :'unit1'::uuid),
  'outsider (no membership) cannot see org1''s unit'
);

SELECT pg_temp.logout();

-- === professional_units: backfill linked the existing professional to the default unit ===
SELECT ok(
  EXISTS(
    SELECT 1 FROM public.professional_units
    WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid
  ),
  'onda 0 backfill/professional creation path leaves professional_units consistent for org1'
);

-- === Default-fill trigger: new facts without unit_id resolve to the org default ===
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'professional1'::uuid, :'service1'::uuid, now() + interval '1 day', now() + interval '1 day 30 minutes', :'owner1'::uuid);
SELECT is(
  (SELECT count(*)::integer FROM public.appointments WHERE organization_id = :'org1'::uuid AND unit_id IS NULL),
  0,
  'appointments inserted without an explicit unit_id are default-filled by the trigger (none left null)'
);
SELECT ok(
  (SELECT unit_id FROM public.appointments WHERE organization_id = :'org1'::uuid ORDER BY created_at DESC LIMIT 1) = :'unit1'::uuid,
  'the default-fill trigger resolves the new appointment to org1''s default unit'
);

-- === Default-fill "from order": order_items/payments/inventory/cash inherit
-- the parent order's unit_id instead of resolving the org default directly ===
INSERT INTO public.orders (organization_id, subtotal_cents, total_cents, created_by)
  VALUES (:'org1'::uuid, 1000, 1000, :'owner1'::uuid) RETURNING id AS order1 \gset
SELECT ok(
  (SELECT unit_id FROM public.orders WHERE id = :'order1'::uuid) = :'unit1'::uuid,
  'an order inserted without unit_id resolves to org1''s default unit'
);

-- === Immutability trigger: unit_id cannot change once set ===
SELECT throws_ok(
  format(
    'update public.appointments set unit_id = (select id from public.units where organization_id = %L and not is_default limit 1) where organization_id = %L',
    :'org1', :'org1'
  ),
  '23514',
  NULL,
  'unit_id on an appointment is immutable once set'
);

SELECT * FROM finish();
ROLLBACK;
