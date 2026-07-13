BEGIN;
SELECT plan(13);

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

SELECT (public.create_organization(:'owner1'::uuid, 'Org Groups', 'org-groups')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Groups Two', 'org-groups-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org2'::uuid, 'Cabelo Org2', 'percentage', 4000)
  RETURNING id AS group2 \gset

INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid)
  RETURNING id AS service1 \gset

INSERT INTO public.packages (organization_id, name, price_cents)
  VALUES (:'org1'::uuid, 'Pacote Teste', 9000)
  RETURNING id AS package1 \gset
INSERT INTO public.package_items (organization_id, package_id, service_id, quantity)
  VALUES (:'org1'::uuid, :'package1'::uuid, :'service1'::uuid, 1);

-- === schema-level invariants: the commission cascade only terminates if
-- every service has a group with a bounded default (docs/PLANEJAMENTO_COMISSOES.md §4.1) ===
SELECT throws_ok(
  format(
    $sql$insert into public.service_groups (organization_id, name, default_commission_type, default_commission_value)
    values (%L, 'Percent Over 100', 'percentage', 10001)$sql$,
    :'org1'
  ),
  '23514',
  NULL,
  'a percentage default_commission_value above 10000 basis points (100%) is rejected'
);
SELECT lives_ok(
  format(
    $sql$insert into public.service_groups (organization_id, name, default_commission_type, default_commission_value)
    values (%L, 'Fixed Sem Teto', 'fixed', 999999)$sql$,
    :'org1'
  ),
  'a fixed default_commission_value is not bounded by the percentage range check'
);
SELECT throws_ok(
  format(
    $sql$insert into public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
    values (%L, 'Sem Grupo', 1000, 10, null)$sql$,
    :'org1'
  ),
  '23502',
  NULL,
  'a service without service_group_id is rejected (not null)'
);
SELECT throws_ok(
  format(
    $sql$insert into public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
    values (%L, 'Grupo de Outro Tenant', 1000, 10, %L)$sql$,
    :'org1', :'group2'
  ),
  '23503',
  NULL,
  'a service cannot reference a service_group from another organization (composite FK)'
);

-- === grant lockdown: only service_role has direct table access, same as every other business table ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.service_groups', 'INSERT'),
  'authenticated has no direct INSERT grant on service_groups'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.packages', 'INSERT'),
  'authenticated has no direct INSERT grant on packages'
);

-- === RLS layer (temporary grants within this transaction only) ===
GRANT SELECT, INSERT, UPDATE, DELETE ON public.service_groups, public.packages, public.package_items TO authenticated;

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.service_groups WHERE organization_id = :'org1'::uuid),
  'reception1 (any active member) can select service_groups in org1'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.service_groups WHERE organization_id = :'org2'::uuid),
  'reception1 cannot see service_groups from org2 (cross-tenant)'
);
SELECT throws_ok(
  format(
    'insert into public.service_groups (organization_id, name, default_commission_type, default_commission_value) values (%L, %L, ''percentage'', 1000)',
    :'org1', 'Bloqueado'
  ),
  '42501',
  NULL,
  'reception1 cannot insert a service_group (owner/admin/manager required)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT lives_ok(
  format(
    'insert into public.service_groups (organization_id, name, default_commission_type, default_commission_value) values (%L, %L, ''fixed'', 500)',
    :'org1', 'Unhas'
  ),
  'manager1 can insert a service_group'
);
-- RLS-filtered DELETE does not raise (USING just hides the row from the
-- statement), it silently affects zero rows — same pattern as the
-- clients_delete gating check in rls_business_tables_test.sql.
WITH d AS (
  DELETE FROM public.service_groups WHERE organization_id = :'org1'::uuid AND name = 'Unhas' RETURNING id
)
SELECT is(
  (SELECT count(*) FROM d),
  0::bigint,
  'manager1 cannot delete a service_group (owner/admin required)'
);

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.packages WHERE organization_id = :'org1'::uuid),
  'owner1 can select packages in org1'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.package_items WHERE organization_id = :'org1'::uuid),
  'owner1 can select package_items in org1'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
