BEGIN;
SELECT plan(12);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Packages', 'org-packages')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Packages Two', 'org-packages-two')).id AS org2 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 8000, 30, :'group1'::uuid)
  RETURNING id AS service1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Escova', 6000, 20, :'group1'::uuid)
  RETURNING id AS service2 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, active)
  VALUES (:'org1'::uuid, 'Descontinuado', 3000, 15, :'group1'::uuid, false)
  RETURNING id AS inactive_service \gset

-- Grant lockdown
SELECT ok(
  NOT has_function_privilege('authenticated', 'public.create_package(uuid, uuid, jsonb)', 'EXECUTE'),
  'authenticated cannot execute create_package'
);
SELECT ok(
  NOT has_function_privilege('authenticated', 'public.update_package(uuid, uuid, uuid, jsonb)', 'EXECUTE'),
  'authenticated cannot execute update_package'
);

-- Role gating: reception cannot create a package (owner/admin/manager only).
SELECT throws_ok(
  format(
    $sql$select public.create_package(%L, %L, jsonb_build_object('name','Bloqueado','price_cents',1000,'items',jsonb_build_array(jsonb_build_object('service_id',%L::uuid,'quantity',1))))$sql$,
    :'org1', :'reception1', :'service1'
  ),
  '42501',
  NULL,
  'reception1 cannot call create_package (insufficient organization permission)'
);

-- Happy path: package with two components at a discounted bundle price
-- (price_cents is the sale price, not the sum of the components).
SELECT (public.create_package(
  :'org1'::uuid, :'owner1'::uuid,
  jsonb_build_object(
    'name', 'Dia da Noiva',
    'price_cents', 12000,
    'items', jsonb_build_array(
      jsonb_build_object('service_id', :'service1'::uuid, 'quantity', 1),
      jsonb_build_object('service_id', :'service2'::uuid, 'quantity', 1)
    )
  )
) ->> 'id')::uuid AS package1 \gset

SELECT is(
  (SELECT price_cents FROM public.packages WHERE id = :'package1'::uuid),
  12000::bigint,
  'create_package stores the bundle price, not the sum of components'
);
SELECT is(
  (SELECT count(*)::int FROM public.package_items WHERE package_id = :'package1'::uuid),
  2,
  'create_package inserts one package_items row per component'
);

-- Duplicate service_id in the same payload is rejected.
SELECT throws_ok(
  format(
    $sql$select public.create_package(%L, %L, jsonb_build_object('name','Dup','price_cents',1000,'items',jsonb_build_array(jsonb_build_object('service_id',%L::uuid,'quantity',1),jsonb_build_object('service_id',%L::uuid,'quantity',1))))$sql$,
    :'org1', :'owner1', :'service1', :'service1'
  ),
  '22023',
  NULL,
  'create_package rejects a payload with the same service_id twice'
);

-- Inactive service cannot be added to a package.
SELECT throws_ok(
  format(
    $sql$select public.create_package(%L, %L, jsonb_build_object('name','Com Inativo','price_cents',1000,'items',jsonb_build_array(jsonb_build_object('service_id',%L::uuid,'quantity',1))))$sql$,
    :'org1', :'owner1', :'inactive_service'
  ),
  'P0002',
  NULL,
  'create_package rejects an inactive service'
);

-- Cross-tenant service cannot be added to a package.
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org2'::uuid, 'Grupo Org2', 'percentage', 3000)
  RETURNING id AS group2 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org2'::uuid, 'Servico Org2', 4000, 20, :'group2'::uuid)
  RETURNING id AS service_org2 \gset
SELECT throws_ok(
  format(
    $sql$select public.create_package(%L, %L, jsonb_build_object('name','Cross Tenant','price_cents',1000,'items',jsonb_build_array(jsonb_build_object('service_id',%L::uuid,'quantity',1))))$sql$,
    :'org1', :'owner1', :'service_org2'
  ),
  'P0002',
  NULL,
  'create_package rejects a service_id belonging to another organization'
);

-- update_package: partial patch renames without touching the composition.
SELECT public.update_package(:'org1'::uuid, :'owner1'::uuid, :'package1'::uuid, '{"name":"Dia da Noiva Premium"}'::jsonb);
SELECT is(
  (SELECT name FROM public.packages WHERE id = :'package1'::uuid),
  'Dia da Noiva Premium',
  'update_package renames the package'
);
SELECT is(
  (SELECT count(*)::int FROM public.package_items WHERE package_id = :'package1'::uuid),
  2,
  'update_package without an items key leaves the composition untouched'
);

-- update_package replaces the full item set when items is present.
SELECT public.update_package(
  :'org1'::uuid, :'owner1'::uuid, :'package1'::uuid,
  jsonb_build_object('items', jsonb_build_array(jsonb_build_object('service_id', :'service1'::uuid, 'quantity', 1)))
);
SELECT is(
  (SELECT count(*)::int FROM public.package_items WHERE package_id = :'package1'::uuid),
  1,
  'update_package with an items key fully replaces the composition'
);

-- update_package on a package from another organization is rejected.
SELECT throws_ok(
  format(
    $sql$select public.update_package(%L, %L, %L, '{"name":"Hijack"}'::jsonb)$sql$,
    :'org2', :'owner2', :'package1'
  ),
  'P0002',
  NULL,
  'update_package cannot target a package from another organization'
);

SELECT * FROM finish();
ROLLBACK;
