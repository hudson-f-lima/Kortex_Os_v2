BEGIN;
SELECT plan(32);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('professional1@test.local') AS professional1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Checkout', 'org-checkout')).id AS org1 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'professional1'::uuid, 'professional');

INSERT INTO public.products (organization_id, sku, name, price_cents, stock_on_hand)
  VALUES (:'org1'::uuid, 'SKU-1', 'Shampoo', 2500, 5)
  RETURNING id AS product1 \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid)
  RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Prof Um')
  RETURNING id AS prof1 \gset

-- Grant lockdown
SELECT ok(
  NOT has_function_privilege('authenticated', 'public.checkout_close(uuid, uuid, text, jsonb)', 'EXECUTE'),
  'authenticated cannot execute checkout_close'
);

-- Actor without sufficient role (professional is not in owner/admin/manager/reception)
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-role-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind','product','id',%L,'quantity',1)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',2500))
    ))$sql$,
    :'org1', :'professional1', :'product1'
  ),
  '42501',
  NULL,
  'professional1 cannot close a checkout (insufficient organization permission)'
);

-- A service item without professional_id is rejected.
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-no-professional-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind','service','id',%L,'quantity',1)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',5000))
    ))$sql$,
    :'org1', :'owner1', :'service1'
  ),
  '22023',
  NULL,
  'checkout_close rejects a service item without professional_id'
);

-- Happy path: one product + one service, exact payment match.
SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'ck-happy-0001',
  jsonb_build_object(
    'items', jsonb_build_array(
      jsonb_build_object('kind','product','id',:'product1'::uuid,'quantity',2),
      jsonb_build_object('kind','service','id',:'service1'::uuid,'quantity',1,'professional_id',:'prof1'::uuid)
    ),
    'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',10000))
  )
) AS checkout_response \gset
SELECT ok(:'checkout_response' IS NOT NULL, 'checkout_close returns a response for a valid payload');
SELECT is(
  (SELECT stock_on_hand FROM public.products WHERE id = :'product1'::uuid),
  3,
  'checkout_close decrements stock by the purchased quantity (5 - 2 = 3)'
);
SELECT is(
  (SELECT count(*)::int FROM public.inventory_movements WHERE product_id = :'product1'::uuid AND reason = 'sale'),
  1,
  'checkout_close records one inventory_movement of reason sale'
);
SELECT is(
  (SELECT count(*)::int FROM public.cash_entries WHERE organization_id = :'org1'::uuid AND kind = 'sale'),
  1,
  'checkout_close records one cash_entries row of kind sale'
);
SELECT is(
  (SELECT total_cents FROM public.orders WHERE organization_id = :'org1'::uuid ORDER BY created_at DESC LIMIT 1),
  10000::bigint,
  'order total reconciles with 2x product (5000) + 1x service (5000)'
);
SELECT is(
  (SELECT commission_cents FROM public.order_items WHERE order_id = (:'checkout_response'::jsonb ->> 'order_id')::uuid AND kind = 'service'),
  2250::bigint,
  'service order_item commission resolves via group default (45% of 5000 = 2250)'
);

-- Idempotent replay with the identical payload returns the cached response, no side effects duplicated.
SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'ck-happy-0001',
  jsonb_build_object(
    'items', jsonb_build_array(
      jsonb_build_object('kind','product','id',:'product1'::uuid,'quantity',2),
      jsonb_build_object('kind','service','id',:'service1'::uuid,'quantity',1,'professional_id',:'prof1'::uuid)
    ),
    'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',10000))
  )
);
SELECT is(
  (SELECT stock_on_hand FROM public.products WHERE id = :'product1'::uuid),
  3,
  'replaying the same idempotency key does not decrement stock again'
);
SELECT is(
  (SELECT count(*)::int FROM public.orders WHERE organization_id = :'org1'::uuid),
  1,
  'replaying the same idempotency key does not create a second order'
);

-- Same key, different payload: rejected.
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-happy-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind','product','id',%L,'quantity',1)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',2500))
    ))$sql$,
    :'org1', :'owner1', :'product1'
  ),
  '22023',
  NULL,
  'reusing an idempotency key with a different payload is rejected'
);

-- Insufficient stock: only 3 left, requesting 100 must fail and change nothing.
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-insufficient-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind','product','id',%L,'quantity',100)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',250000))
    ))$sql$,
    :'org1', :'owner1', :'product1'
  ),
  'P0001',
  NULL,
  'checkout_close rejects a purchase that exceeds stock on hand'
);
SELECT is(
  (SELECT stock_on_hand FROM public.products WHERE id = :'product1'::uuid),
  3,
  'a failed checkout leaves stock untouched (atomic rollback)'
);

-- Payments do not reconcile with the order total.
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-mismatch-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind','service','id',%L,'quantity',1,'professional_id',%L)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',1))
    ))$sql$,
    :'org1', :'owner1', :'service1', :'prof1'
  ),
  '22023',
  NULL,
  'checkout_close rejects payments that do not reconcile with the order total'
);

-- Cross-tenant: a product id from another organization is invisible to checkout_close.
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Checkout Two', 'org-checkout-two')).id AS org2 \gset
INSERT INTO public.products (organization_id, sku, name, price_cents, stock_on_hand)
  VALUES (:'org2'::uuid, 'SKU-X', 'Produto Org2', 1000, 50)
  RETURNING id AS product_org2 \gset
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-cross-tenant-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind','product','id',%L,'quantity',1)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',1000))
    ))$sql$,
    :'org1', :'owner1', :'product_org2'
  ),
  'P0002',
  NULL,
  'checkout_close cannot resolve a product id that belongs to a different organization'
);

-- Cross-tenant professional_id on a service item is rejected the same way.
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org2'::uuid, 'Prof Org2')
  RETURNING id AS prof_org2 \gset
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-prof-cross-tenant-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind','service','id',%L,'quantity',1,'professional_id',%L)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',5000))
    ))$sql$,
    :'org1', :'owner1', :'service1', :'prof_org2'
  ),
  'P0002',
  NULL,
  'checkout_close cannot resolve a professional_id that belongs to a different organization'
);

-- Inactive professional is rejected.
INSERT INTO public.professionals (organization_id, name, active)
  VALUES (:'org1'::uuid, 'Prof Inativo', false)
  RETURNING id AS prof_inactive \gset
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-prof-inactive-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object('kind','service','id',%L,'quantity',1,'professional_id',%L)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',5000))
    ))$sql$,
    :'org1', :'owner1', :'service1', :'prof_inactive'
  ),
  'P0002',
  NULL,
  'checkout_close rejects an inactive professional_id'
);

-- === Commission cascade (docs/PLANEJAMENTO_COMISSOES.md §4.1): profissional
-- x servico override > servico proprio > grupo. Three services, each
-- resolving at a different level of the cascade. ===
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Estetica', 'fixed', 1000)
  RETURNING id AS group2 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte Pacote', 8000, 30, :'group1'::uuid)
  RETURNING id AS service_a \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Escova Pacote', 6000, 20, :'group1'::uuid)
  RETURNING id AS service_b \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, commission_type, commission_value)
  VALUES (:'org1'::uuid, 'Maquiagem Pacote', 11000, 40, :'group2'::uuid, 'fixed', 4000)
  RETURNING id AS service_c \gset

INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Ana')
  RETURNING id AS prof_ana \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Beatriz')
  RETURNING id AS prof_beatriz \gset

-- Level 1 override: Ana x Corte Pacote = 60% (beats the 45% group default).
INSERT INTO public.professional_service_commissions (organization_id, professional_id, service_id, commission_type, commission_value)
  VALUES (:'org1'::uuid, :'prof_ana'::uuid, :'service_a'::uuid, 'percentage', 6000);

SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'ck-cascade-0001',
  jsonb_build_object(
    'items', jsonb_build_array(
      jsonb_build_object('kind','service','id',:'service_a'::uuid,'quantity',1,'professional_id',:'prof_ana'::uuid),
      jsonb_build_object('kind','service','id',:'service_b'::uuid,'quantity',1,'professional_id',:'prof_ana'::uuid),
      jsonb_build_object('kind','service','id',:'service_c'::uuid,'quantity',1,'professional_id',:'prof_beatriz'::uuid)
    ),
    'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',25000))
  )
) AS cascade_response \gset
SELECT is(
  (SELECT commission_cents FROM public.order_items WHERE order_id = (:'cascade_response'::jsonb ->> 'order_id')::uuid AND service_id = :'service_a'::uuid),
  4800::bigint,
  'level 1 (professional override) wins: Ana x Corte Pacote = 60% of 8000 = 4800'
);
SELECT is(
  (SELECT commission_cents FROM public.order_items WHERE order_id = (:'cascade_response'::jsonb ->> 'order_id')::uuid AND service_id = :'service_b'::uuid),
  2700::bigint,
  'level 3 (group default) applies when no override exists: 45% of 6000 = 2700'
);
SELECT is(
  (SELECT commission_cents FROM public.order_items WHERE order_id = (:'cascade_response'::jsonb ->> 'order_id')::uuid AND service_id = :'service_c'::uuid),
  4000::bigint,
  'level 2 (service default) wins over the group default: fixed 4000, ignoring price/quantity'
);

-- === Packages: proportional allocation (docs/PLANEJAMENTO_COMISSOES.md
-- §4.4/§6) expands into one order_item per component, each with its own
-- professional and commission, summing exactly to the package price. ===
INSERT INTO public.packages (organization_id, name, price_cents)
  VALUES (:'org1'::uuid, 'Dia da Noiva', 22000)
  RETURNING id AS package1 \gset
INSERT INTO public.package_items (organization_id, package_id, service_id, quantity) VALUES
  (:'org1'::uuid, :'package1'::uuid, :'service_a'::uuid, 1),
  (:'org1'::uuid, :'package1'::uuid, :'service_b'::uuid, 1),
  (:'org1'::uuid, :'package1'::uuid, :'service_c'::uuid, 1);

SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'ck-package-0001',
  jsonb_build_object(
    'items', jsonb_build_array(jsonb_build_object(
      'kind','package','id',:'package1'::uuid,'quantity',1,
      'professionals', jsonb_build_object(
        :'service_a', :'prof_ana',
        :'service_b', :'prof_ana',
        :'service_c', :'prof_beatriz'
      )
    )),
    'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',22000))
  )
) AS package_response \gset
SELECT is(
  (SELECT count(*)::int FROM public.order_items WHERE order_id = (:'package_response'::jsonb ->> 'order_id')::uuid),
  3,
  'a package expands into one order_item per component'
);
SELECT is(
  (SELECT sum(total_cents)::bigint FROM public.order_items WHERE order_id = (:'package_response'::jsonb ->> 'order_id')::uuid),
  22000::bigint,
  'the allocated component values sum exactly to the package price (no lost/extra cent)'
);
SELECT is(
  (SELECT total_cents FROM public.order_items WHERE order_id = (:'package_response'::jsonb ->> 'order_id')::uuid AND service_id = :'service_a'::uuid),
  7040::bigint,
  'Corte Pacote is allocated R$70,40 (8000/25000 share of the R$220,00 package)'
);
SELECT is(
  (SELECT commission_cents FROM public.order_items WHERE order_id = (:'package_response'::jsonb ->> 'order_id')::uuid AND service_id = :'service_a'::uuid),
  4224::bigint,
  'Corte Pacote commission uses the allocated value, not the list price: 60% of 7040 = 4224'
);
SELECT is(
  (SELECT commission_cents FROM public.order_items WHERE order_id = (:'package_response'::jsonb ->> 'order_id')::uuid AND service_id = :'service_c'::uuid),
  4000::bigint,
  'Maquiagem Pacote commission is fixed 4000 regardless of its allocated value'
);

-- Remainder distribution: three components with equal weight and a package
-- price that does not divide evenly must still sum exactly (largest
-- remainder gets the leftover cent).
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Empate Um', 100, 10, :'group1'::uuid)
  RETURNING id AS service_tie1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Empate Dois', 100, 10, :'group1'::uuid)
  RETURNING id AS service_tie2 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Empate Tres', 100, 10, :'group1'::uuid)
  RETURNING id AS service_tie3 \gset
INSERT INTO public.packages (organization_id, name, price_cents)
  VALUES (:'org1'::uuid, 'Pacote Empate', 100)
  RETURNING id AS package_tie \gset
INSERT INTO public.package_items (organization_id, package_id, service_id, quantity) VALUES
  (:'org1'::uuid, :'package_tie'::uuid, :'service_tie1'::uuid, 1),
  (:'org1'::uuid, :'package_tie'::uuid, :'service_tie2'::uuid, 1),
  (:'org1'::uuid, :'package_tie'::uuid, :'service_tie3'::uuid, 1);

SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'ck-package-tie-0001',
  jsonb_build_object(
    'items', jsonb_build_array(jsonb_build_object(
      'kind','package','id',:'package_tie'::uuid,'quantity',1,
      'professionals', jsonb_build_object(
        :'service_tie1', :'prof_ana',
        :'service_tie2', :'prof_ana',
        :'service_tie3', :'prof_ana'
      )
    )),
    'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',100))
  )
) AS package_tie_response \gset
SELECT is(
  (SELECT sum(total_cents)::bigint FROM public.order_items WHERE order_id = (:'package_tie_response'::jsonb ->> 'order_id')::uuid),
  100::bigint,
  'a package price that does not divide evenly across equal-weight components still sums exactly'
);
SELECT is(
  (SELECT count(*)::int FROM public.order_items WHERE order_id = (:'package_tie_response'::jsonb ->> 'order_id')::uuid AND total_cents = 34),
  1,
  'exactly one equal-weight component receives the leftover cent'
);
SELECT is(
  (SELECT count(*)::int FROM public.order_items WHERE order_id = (:'package_tie_response'::jsonb ->> 'order_id')::uuid AND total_cents = 33),
  2,
  'the other two equal-weight components are floored'
);

-- Package payload validation: quantity must be 1, and professionals must map
-- exactly the package components (no missing, no extra keys).
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-package-qty-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object(
        'kind','package','id',%L,'quantity',2,
        'professionals', jsonb_build_object(%L,%L,%L,%L,%L,%L)
      )),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',44000))
    ))$sql$,
    :'org1', :'owner1', :'package1',
    :'service_a', :'prof_ana', :'service_b', :'prof_ana', :'service_c', :'prof_beatriz'
  ),
  '22023',
  NULL,
  'a package item with quantity <> 1 is rejected'
);
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-package-missing-map-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object(
        'kind','package','id',%L,'quantity',1,
        'professionals', jsonb_build_object(%L,%L)
      )),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',22000))
    ))$sql$,
    :'org1', :'owner1', :'package1', :'service_a', :'prof_ana'
  ),
  '22023',
  NULL,
  'a professionals map missing a package component is rejected'
);
-- Same cardinality (3 keys) as the package's components, but one key
-- (service_tie1) does not belong to it — exercises the "exists" half of the
-- bijection check, not just the cheaper count mismatch.
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'ck-package-wrong-map-0001', jsonb_build_object(
      'items', jsonb_build_array(jsonb_build_object(
        'kind','package','id',%L,'quantity',1,
        'professionals', jsonb_build_object(%L,%L,%L,%L,%L,%L)
      )),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',22000))
    ))$sql$,
    :'org1', :'owner1', :'package1',
    :'service_a', :'prof_ana', :'service_b', :'prof_ana', :'service_tie1', :'prof_ana'
  ),
  '22023',
  NULL,
  'a professionals map with an unrelated key in place of a real component is rejected'
);

SELECT * FROM finish();
ROLLBACK;
