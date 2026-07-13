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

-- Fixtures
SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('professional1@test.local') AS professional1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one-biz')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Two', 'org-two-biz')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'professional1'::uuid, 'professional');

INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Org1', :'owner1'::uuid);
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org2'::uuid, 'Cliente Org2', :'owner2'::uuid);
INSERT INTO public.products (organization_id, sku, name, price_cents, stock_on_hand)
  VALUES (:'org1'::uuid, 'SKU-1', 'Shampoo', 2500, 10);
INSERT INTO public.professionals (organization_id, user_id, name)
  VALUES (:'org1'::uuid, :'professional1'::uuid, 'Professional One');

-- === Grant lockdown: business tables are never directly reachable by authenticated/anon ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.orders', 'INSERT'),
  'authenticated has no direct INSERT grant on orders'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.inventory_movements', 'INSERT'),
  'authenticated has no direct INSERT grant on inventory_movements'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.cash_entries', 'INSERT'),
  'authenticated has no direct INSERT grant on cash_entries'
);

-- === RLS layer (temporary grants within this transaction only) ===
GRANT SELECT, INSERT, UPDATE, DELETE ON public.clients TO authenticated;
GRANT SELECT ON public.professionals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.orders, public.order_items, public.payments, public.inventory_movements, public.cash_entries TO authenticated;

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.clients WHERE organization_id = :'org1'::uuid),
  'reception1 (allowlisted role) can select clients in org1'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.clients WHERE organization_id = :'org2'::uuid),
  'reception1 cannot see clients from org2 (cross-tenant)'
);
SELECT lives_ok(
  format('insert into public.clients (organization_id, name) values (%L, %L)', :'org1', 'Novo Cliente'),
  'reception1 can insert a client in org1'
);

SELECT pg_temp.login_as(:'professional1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.clients WHERE organization_id = :'org1'::uuid),
  'professional1 (role not in select allowlist) cannot see clients'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.professionals WHERE organization_id = :'org1'::uuid),
  'professional1 can still see professionals (is_member-only policy)'
);
SELECT throws_ok(
  format('insert into public.clients (organization_id, name) values (%L, %L)', :'org1', 'Bloqueado'),
  '42501',
  NULL,
  'professional1 cannot insert a client (insufficient role)'
);

-- Orders/order_items/payments/inventory_movements/cash_entries: even with a
-- direct grant, RLS defines no INSERT/UPDATE/DELETE policy for these tables,
-- so authenticated writes are always denied; only the SECURITY DEFINER RPCs
-- (checkout_close, inventory_adjust) may mutate them.
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT throws_ok(
  format(
    'insert into public.orders (organization_id, status, subtotal_cents, total_cents) values (%L, %L, 0, 0)',
    :'org1', 'closed'
  ),
  '42501',
  NULL,
  'owner1 cannot insert directly into orders even with table grant (no RLS policy for insert)'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.clients WHERE organization_id = :'org1'::uuid),
  'owner1 (allowlisted role) can select clients in org1'
);

-- DELETE gating: clients_delete requires manager+, reception cannot delete.
SELECT pg_temp.login_as(:'reception1'::uuid);
WITH d AS (
  DELETE FROM public.clients WHERE organization_id = :'org1'::uuid RETURNING id
)
SELECT is(
  (SELECT count(*) FROM d),
  0::bigint,
  'reception1 cannot delete clients (manager+ required)'
);

SELECT pg_temp.logout();

-- === Agenda: no double-booking for the same professional (exclusion constraint) ===
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid);
SELECT (id) AS service1 FROM public.services WHERE organization_id = :'org1'::uuid LIMIT 1 \gset
SELECT (id) AS client1 FROM public.clients WHERE organization_id = :'org1'::uuid AND name = 'Cliente Org1' \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof Solo') RETURNING id AS prof1 \gset

INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-01 10:00+00', '2026-08-01 10:30+00', :'owner1'::uuid);

SELECT throws_ok(
  format(
    $sql$insert into public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
    values (%L, %L, %L, %L, '2026-08-01 10:15+00', '2026-08-01 10:45+00', %L)$sql$,
    :'org1', :'client1', :'prof1', :'service1', :'owner1'
  ),
  '23P01',
  NULL,
  'overlapping appointment for the same professional is rejected by the exclusion constraint'
);
SELECT lives_ok(
  format(
    $sql$insert into public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
    values (%L, %L, %L, %L, '2026-08-01 10:30+00', '2026-08-01 11:00+00', %L)$sql$,
    :'org1', :'client1', :'prof1', :'service1', :'owner1'
  ),
  'a back-to-back (non-overlapping) appointment is accepted'
);

-- === Tenant-safe FKs: an appointment cannot reference a client from another org ===
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org2'::uuid, 'Cliente Org2 b', :'owner2'::uuid);
SELECT throws_ok(
  format(
    $sql$insert into public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
    values (%L, (select id from public.clients where organization_id = %L and name = 'Cliente Org2 b'), %L, %L, '2026-08-02 09:00+00', '2026-08-02 09:30+00', %L)$sql$,
    :'org1', :'org2', :'prof1', :'service1', :'owner1'
  ),
  '23503',
  NULL,
  'appointment cannot reference a client from a different organization (composite FK)'
);

SELECT * FROM finish();
ROLLBACK;
