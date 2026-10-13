-- Onda 3, fatia 022 (issues/022-commission-sale-records-immutability.md,
-- DEC-47, achados P2/P3): commission_sale_records ganha o mesmo padrão de
-- guard de imutabilidade de deposit_holds (20260726200000) + o mesmo
-- lockdown de grant de service_role do ledger (20260727170000) — o
-- projeto nunca havia aplicado os dois numa mesma tabela.
BEGIN;
SELECT plan(10);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Imutabilidade', 'org-imutabilidade')).id AS org1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Grupo', 'percentage', 1000)
  RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Servico', 10000, 60, :'group1'::uuid)
  RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Vendedor') RETURNING id AS professional1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Outro Vendedor') RETURNING id AS professional_other \gset
INSERT INTO public.packages (organization_id, name, price_cents, sale_commission_type, sale_commission_value)
  VALUES (:'org1'::uuid, 'Pacote', 10000, 'percentage', 1000)
  RETURNING id AS package1 \gset
INSERT INTO public.orders (organization_id, subtotal_cents, total_cents, created_by)
  VALUES (:'org1'::uuid, 10000, 10000, :'owner1'::uuid) RETURNING id AS order1, unit_id AS order1_unit \gset
INSERT INTO public.order_items (organization_id, order_id, kind, service_id, description, quantity, unit_price_cents, total_cents, professional_id, package_id)
  VALUES (:'org1'::uuid, :'order1'::uuid, 'service', :'service1'::uuid, 'Servico do Pacote', 1, 10000, 10000, :'professional1'::uuid, :'package1'::uuid);

-- === grant lockdown (padrão do ledger, 20260727170000) ===
SELECT ok(
  NOT has_table_privilege('service_role', 'public.commission_sale_records', 'INSERT'),
  'service_role has no direct INSERT grant on commission_sale_records (write-lockdown)'
);
SELECT ok(
  NOT has_table_privilege('service_role', 'public.commission_sale_records', 'UPDATE'),
  'service_role has no direct UPDATE grant on commission_sale_records (write-lockdown)'
);
SELECT ok(
  NOT has_table_privilege('service_role', 'public.commission_sale_records', 'DELETE'),
  'service_role has no direct DELETE grant on commission_sale_records (write-lockdown)'
);

SET LOCAL role service_role;
SELECT throws_ok(
  format(
    $sql$insert into public.commission_sale_records (organization_id, unit_id, order_id, package_id, professional_id, commission_type, commission_value, commission_cents)
    values (%L, %L, %L, %L, %L, 'percentage', 1000, 1000)$sql$,
    :'org1', :'order1_unit', :'order1', :'package1', :'professional1'
  ),
  '42501',
  NULL,
  'service_role cannot insert directly into commission_sale_records, even authenticated as itself'
);

RESET role;
-- Uma linha real, gravada como superuser (contorna o lockdown de grant só
-- para preparar o fixture — o teste é sobre o guard de coluna, não sobre o
-- lockdown, que já foi provado acima).
INSERT INTO public.commission_sale_records (organization_id, unit_id, order_id, package_id, professional_id, commission_type, commission_value, commission_cents)
  VALUES (:'org1'::uuid, :'order1_unit'::uuid, :'order1'::uuid, :'package1'::uuid, :'professional1'::uuid, 'percentage', 1000, 1000)
  RETURNING id AS record1 \gset

SET LOCAL role service_role;
SELECT throws_ok(
  format($sql$update public.commission_sale_records set status = 'clawed_back' where id = %L$sql$, :'record1'),
  '42501',
  NULL,
  'service_role cannot update directly into commission_sale_records, even authenticated as itself'
);
SELECT throws_ok(
  format($sql$delete from public.commission_sale_records where id = %L$sql$, :'record1'),
  '42501',
  NULL,
  'service_role cannot delete directly from commission_sale_records, even authenticated as itself'
);
RESET role;

-- === trigger guard (padrão de deposit_holds, 20260726200000) ===
SELECT lives_ok(
  format($sql$update public.commission_sale_records set status = 'clawed_back' where id = %L$sql$, :'record1'),
  'status alone (the clawback transition, DEC-18) can be updated — the only column the guard leaves open besides updated_at'
);
SELECT throws_ok(
  format($sql$update public.commission_sale_records set status = 'accrued', commission_cents = 0 where id = %L$sql$, :'record1'),
  '55000',
  NULL,
  'changing commission_cents cannot hide behind a legitimate status transition in the same statement (guard blocks the whole UPDATE)'
);
SELECT throws_ok(
  format($sql$update public.commission_sale_records set professional_id = %L where id = %L$sql$, :'professional_other', :'record1'),
  '55000',
  NULL,
  'financial identity (professional_id) is immutable — reassigning the seller after the fact is blocked'
);

-- === SECURITY DEFINER still writes (function owner privilege, not caller) ===
SELECT pg_temp.mk_user('actor1@test.local') AS actor1_user \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'actor1_user'::uuid, 'manager');
SET LOCAL role service_role;
SELECT lives_ok(
  format(
    $sql$select public.commission_sale_record_create(%L, %L, 'k-lockdown-001', %L, %L, %L)$sql$,
    :'org1', :'actor1_user', :'order1', :'package1', :'professional1'
  ),
  'commission_sale_record_create still works when called as service_role, even after the write-lockdown (SECURITY DEFINER bypasses via function owner, not caller)'
);
RESET role;

SELECT * FROM finish();
ROLLBACK;
