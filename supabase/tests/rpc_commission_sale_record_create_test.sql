-- Onda 3, fatia 020 (issues/020-package-sale-commission-records.md,
-- Blueprint §2/§3.4/§3.5/§3.6/§3.8/§4, DEC-46):
-- packages.sale_commission_*, private.resolve_sale_commission(),
-- commission_sale_records, commission_sale_record_create().
-- Estendido pela fatia 021 (issues/021-order-items-package-linkage.md,
-- DEC-48): commission_sale_record_create() agora exige que o pacote
-- esteja de fato entre os order_items do pedido e calcula a comissão
-- sobre o valor cobrado (sum(order_items.total_cents)), não o preço de
-- tabela do pacote.
BEGIN;
SELECT plan(29);

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
SELECT pg_temp.mk_user('seller1_user@test.local') AS seller1_user \gset
SELECT pg_temp.mk_user('other_pro1_user@test.local') AS other_pro1_user \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org SaleCommission', 'org-sale-commission')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org SaleCommission Two', 'org-sale-commission-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'seller1_user'::uuid, 'professional');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'other_pro1_user'::uuid, 'professional');

INSERT INTO public.professionals (organization_id, name, user_id) VALUES (:'org1'::uuid, 'Seller', :'seller1_user'::uuid) RETURNING id AS seller1 \gset
INSERT INTO public.professionals (organization_id, name, user_id) VALUES (:'org1'::uuid, 'Other', :'other_pro1_user'::uuid) RETURNING id AS other_pro1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org2'::uuid, 'Seller Two') RETURNING id AS seller2 \gset

INSERT INTO public.packages (organization_id, name, price_cents) VALUES (:'org1'::uuid, 'Pacote Sem Comissao', 8000) RETURNING id AS package_no_commission \gset
INSERT INTO public.packages (organization_id, name, price_cents) VALUES (:'org1'::uuid, 'Pacote Com Comissao', 10000) RETURNING id AS package_with_commission \gset
INSERT INTO public.packages (organization_id, name, price_cents) VALUES (:'org2'::uuid, 'Pacote Org2', 6000) RETURNING id AS package_org2 \gset

INSERT INTO public.orders (organization_id, subtotal_cents, total_cents, created_by)
  VALUES (:'org1'::uuid, 10000, 10000, :'owner1'::uuid) RETURNING id AS order1, unit_id AS order1_unit \gset
INSERT INTO public.orders (organization_id, subtotal_cents, total_cents, created_by)
  VALUES (:'org2'::uuid, 6000, 6000, :'owner2'::uuid) RETURNING id AS order2 \gset

-- === schema-level invariants: packages.sale_commission_* ===
SELECT lives_ok(
  format($sql$update public.packages set sale_commission_type = 'percentage', sale_commission_value = 1500 where id = %L$sql$, :'package_with_commission'),
  'a valid sale_commission pair can be set on a package'
);
SELECT throws_ok(
  format($sql$update public.packages set sale_commission_type = 'percentage' where id = %L$sql$, :'package_no_commission'),
  '23514',
  NULL,
  'sale_commission_type without sale_commission_value is rejected (pair check)'
);
SELECT throws_ok(
  format($sql$update public.packages set sale_commission_type = 'percentage', sale_commission_value = 10001 where id = %L$sql$, :'package_no_commission'),
  '23514',
  NULL,
  'sale_commission_value above 10000 basis points for percentage is rejected'
);

-- === schema-level invariants: commission_sale_records (direct insert as superuser) ===
SELECT lives_ok(
  format(
    $sql$insert into public.commission_sale_records (organization_id, unit_id, order_id, package_id, professional_id, commission_type, commission_value, commission_cents)
    values (%L, %L, %L, %L, %L, 'percentage', 1500, 1500)$sql$,
    :'org1', :'order1_unit', :'order1', :'package_with_commission', :'seller1'
  ),
  'a valid commission_sale_records row can be inserted directly'
);
SELECT throws_ok(
  format(
    $sql$insert into public.commission_sale_records (organization_id, unit_id, order_id, package_id, professional_id, commission_type, commission_value, commission_cents)
    values (%L, %L, null, %L, %L, 'percentage', 1500, 1500)$sql$,
    :'org1', :'order1_unit', :'package_with_commission', :'seller1'
  ),
  '23502',
  NULL,
  'order_id is not null (hardening beyond the Blueprint draft: the FK composite guarantee is only real when order_id/unit_id cannot be null)'
);
SELECT throws_ok(
  format(
    $sql$insert into public.commission_sale_records (organization_id, unit_id, order_id, package_id, professional_id, commission_type, commission_value, commission_cents)
    values (%L, gen_random_uuid(), %L, %L, %L, 'percentage', 1500, 1500)$sql$,
    :'org1', :'order1', :'package_with_commission', :'seller1'
  ),
  '23503',
  NULL,
  'a unit_id not matching the order''s real unit_id is rejected (3-column FK composite)'
);
SELECT lives_ok(
  format(
    $sql$insert into public.commission_sale_records (organization_id, unit_id, order_id, package_id, professional_id, commission_type, commission_value, commission_cents)
    values (%L, %L, %L, %L, %L, 'percentage', 1500, 1500)$sql$,
    :'org1', :'order1_unit', :'order1', :'package_with_commission', :'seller1'
  ),
  'the same (order_id, package_id, professional_id) can be inserted a second time (no business-key uniqueness — checkout_close does not deduplicate repeated package sales)'
);

-- === RLS layer (temporary grants within this transaction only) ===
GRANT SELECT, INSERT ON public.commission_sale_records TO authenticated;
GRANT SELECT ON public.professionals TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.commission_sale_records WHERE organization_id = :'org1'::uuid AND professional_id = :'seller1'::uuid),
  'owner1 can select commission_sale_records org-wide'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.commission_sale_records WHERE organization_id = :'org1'::uuid AND professional_id = :'seller1'::uuid),
  'manager1 can select commission_sale_records org-wide'
);

SELECT pg_temp.login_as(:'seller1_user'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.commission_sale_records WHERE organization_id = :'org1'::uuid AND professional_id = :'seller1'::uuid),
  'seller1 (the professional on the record) can self-view their own commission_sale_records'
);

SELECT pg_temp.login_as(:'other_pro1_user'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.commission_sale_records WHERE organization_id = :'org1'::uuid AND professional_id = :'seller1'::uuid),
  'other_pro1 (a different professional, not the seller) cannot see seller1''s commission_sale_records'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.commission_sale_records WHERE organization_id = :'org1'::uuid AND professional_id = :'seller1'::uuid),
  'reception1 (not owner/admin/manager and not the seller) cannot see commission_sale_records'
);
SELECT throws_ok(
  format(
    $sql$insert into public.commission_sale_records (organization_id, unit_id, order_id, package_id, professional_id, commission_type, commission_value, commission_cents)
    values (%L, %L, %L, %L, %L, 'percentage', 1500, 1500)$sql$,
    :'org1', :'order1_unit', :'order1', :'package_with_commission', :'seller1'
  ),
  '42501',
  NULL,
  'authenticated (any role) cannot insert commission_sale_records directly — only commission_sale_record_create (security definer) can'
);

SELECT pg_temp.logout();

-- === private.resolve_sale_commission() ===
SELECT is(
  (SELECT commission_type FROM private.resolve_sale_commission(:'org1'::uuid, :'package_no_commission'::uuid)),
  NULL::text,
  'a package without sale_commission configured resolves to null (RPC becomes a no-op)'
);
SELECT is(
  (SELECT (commission_type, commission_value) FROM private.resolve_sale_commission(:'org1'::uuid, :'package_with_commission'::uuid)),
  ('percentage'::text, 1500::bigint),
  'a package with sale_commission configured resolves to the exact stored value (flat field, no cascade)'
);

-- === fatia 021 (DEC-48): fixtures do vínculo pacote↔pedido ===
-- commission_sale_record_create agora exige que o package_id apareça em
-- order_items daquele order_id — sem isso, checkout_close nunca teria
-- gravado essa venda. As chamadas de RPC abaixo que esperam sucesso
-- (package_with_commission/package_no_commission em order1) precisam desse
-- vínculo; package_not_sold fica deliberadamente sem order_items para
-- provar a rejeição.
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Grupo Venda Pacote', 'percentage', 1000)
  RETURNING id AS group_sale \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Servico do Pacote', 10000, 60, :'group_sale'::uuid)
  RETURNING id AS service_pkg \gset
INSERT INTO public.order_items (organization_id, order_id, kind, service_id, description, quantity, unit_price_cents, total_cents, professional_id, package_id)
  VALUES
    (:'org1'::uuid, :'order1'::uuid, 'service', :'service_pkg'::uuid, 'Servico do Pacote Com Comissao', 1, 10000, 10000, :'seller1'::uuid, :'package_with_commission'::uuid),
    (:'org1'::uuid, :'order1'::uuid, 'service', :'service_pkg'::uuid, 'Servico do Pacote Sem Comissao', 1, 8000, 8000, :'seller1'::uuid, :'package_no_commission'::uuid);

INSERT INTO public.packages (organization_id, name, price_cents, sale_commission_type, sale_commission_value)
  VALUES (:'org1'::uuid, 'Pacote Nao Vendido', 5000, 'percentage', 1000)
  RETURNING id AS package_not_sold \gset

INSERT INTO public.packages (organization_id, name, price_cents, sale_commission_type, sale_commission_value)
  VALUES (:'org1'::uuid, 'Pacote Com Desconto', 10000, 'percentage', 1000)
  RETURNING id AS package_discounted \gset
INSERT INTO public.orders (organization_id, subtotal_cents, total_cents, created_by)
  VALUES (:'org1'::uuid, 8000, 8000, :'owner1'::uuid) RETURNING id AS order_discounted \gset
INSERT INTO public.order_items (organization_id, order_id, kind, service_id, description, quantity, unit_price_cents, total_cents, professional_id, package_id)
  VALUES (:'org1'::uuid, :'order_discounted'::uuid, 'service', :'service_pkg'::uuid, 'Servico do Pacote Com Desconto', 1, 8000, 8000, :'seller1'::uuid, :'package_discounted'::uuid);

-- === commission_sale_record_create() ===
SELECT throws_ok(
  format(
    $sql$select public.commission_sale_record_create(%L, %L, 'k-insufficient-role-001', %L, %L, %L)$sql$,
    :'org1', :'other_pro1_user', :'order1', :'package_with_commission', :'seller1'
  ),
  '42501',
  NULL,
  'an actor without owner/admin/manager/reception role is rejected'
);
SELECT throws_ok(
  format(
    $sql$select public.commission_sale_record_create(%L, %L, 'k-not-sold-001', %L, %L, %L)$sql$,
    :'org1', :'owner1', :'order1', :'package_not_sold', :'seller1'
  ),
  'P0002',
  NULL,
  'a package not present among order_items of that order is rejected (fatia 021, DEC-48 — fixes P1)'
);

SELECT throws_ok(
  format(
    $sql$select public.commission_sale_record_create(%L, %L, 'k-cross-tenant-order-001', %L, %L, %L)$sql$,
    :'org1', :'owner1', :'order2', :'package_with_commission', :'seller1'
  ),
  'P0002',
  NULL,
  'an order_id from another organization is rejected'
);
SELECT throws_ok(
  format(
    $sql$select public.commission_sale_record_create(%L, %L, 'k-cross-tenant-package-001', %L, %L, %L)$sql$,
    :'org1', :'owner1', :'order1', :'package_org2', :'seller1'
  ),
  'P0002',
  NULL,
  'a package_id from another organization is rejected'
);
SELECT throws_ok(
  format(
    $sql$select public.commission_sale_record_create(%L, %L, 'k-cross-tenant-seller-001', %L, %L, %L)$sql$,
    :'org1', :'owner1', :'order1', :'package_with_commission', :'seller2'
  ),
  'P0002',
  NULL,
  'a professional_id (seller) from another organization is rejected'
);

SELECT is(
  (
    SELECT count(*) FROM public.commission_sale_records
    WHERE organization_id = :'org1'::uuid AND package_id = :'package_no_commission'::uuid
  ),
  0::bigint,
  'sanity: no commission_sale_records exist yet for the no-commission package'
);
SELECT is(
  public.commission_sale_record_create(:'org1'::uuid, :'owner1'::uuid, 'k-skip-001', :'order1'::uuid, :'package_no_commission'::uuid, :'seller1'::uuid) ->> 'skipped',
  'true',
  'a package with no sale_commission configured returns {"skipped": true, ...} without inserting a row'
);
SELECT is(
  (
    SELECT count(*) FROM public.commission_sale_records
    WHERE organization_id = :'org1'::uuid AND package_id = :'package_no_commission'::uuid
  ),
  0::bigint,
  'the skipped call really did not insert any row'
);

SELECT is(
  (
    SELECT count(*) FROM public.commission_sale_records
    WHERE organization_id = :'org1'::uuid AND order_id = :'order1'::uuid AND package_id = :'package_with_commission'::uuid
  ),
  2::bigint,
  'sanity: 2 rows already exist for package_with_commission from the schema-level direct-insert block above'
);
SELECT is(
  (public.commission_sale_record_create(:'org1'::uuid, :'owner1'::uuid, 'k-sell-001', :'order1'::uuid, :'package_with_commission'::uuid, :'seller1'::uuid) ->> 'commission_cents')::bigint,
  1500::bigint,
  'commission_cents uses the same percentage formula as checkout_close, over the value charged in this order (here order_items.total_cents = 10000, same as list price, so both bases agree)'
);
SELECT is(
  (public.commission_sale_record_create(:'org1'::uuid, :'owner1'::uuid, 'k-discount-001', :'order_discounted'::uuid, :'package_discounted'::uuid, :'seller1'::uuid) ->> 'commission_cents')::bigint,
  800::bigint,
  'commission_cents is computed on the value actually charged (order_items.total_cents = 8000), not packages.price_cents (10000) — proves the fatia 021 fix, not a coincidence'
);
SELECT is(
  (
    SELECT count(*) FROM public.commission_sale_records
    WHERE organization_id = :'org1'::uuid AND order_id = :'order1'::uuid AND package_id = :'package_with_commission'::uuid
  ),
  3::bigint,
  'selling the same package a second time via the RPC (distinct idempotency key) inserts another row — no business-key uniqueness blocks it'
);

SELECT is(
  public.commission_sale_record_create(:'org1'::uuid, :'owner1'::uuid, 'k-sell-001', :'order1'::uuid, :'package_with_commission'::uuid, :'seller1'::uuid),
  public.commission_sale_record_create(:'org1'::uuid, :'owner1'::uuid, 'k-sell-001', :'order1'::uuid, :'package_with_commission'::uuid, :'seller1'::uuid),
  'replaying the same idempotency_key returns the identical cached response'
);
SELECT is(
  (
    SELECT count(*) FROM public.commission_sale_records
    WHERE organization_id = :'org1'::uuid AND order_id = :'order1'::uuid AND package_id = :'package_with_commission'::uuid
  ),
  3::bigint,
  'replaying the same idempotency_key does not insert a new row'
);

SELECT * FROM finish();
ROLLBACK;
