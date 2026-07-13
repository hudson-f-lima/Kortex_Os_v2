BEGIN;
SELECT plan(14);

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
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30)
  RETURNING id AS service1 \gset

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

-- Happy path: one product + one service, exact payment match.
SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'ck-happy-0001',
  jsonb_build_object(
    'items', jsonb_build_array(
      jsonb_build_object('kind','product','id',:'product1'::uuid,'quantity',2),
      jsonb_build_object('kind','service','id',:'service1'::uuid,'quantity',1)
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

-- Idempotent replay with the identical payload returns the cached response, no side effects duplicated.
SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'ck-happy-0001',
  jsonb_build_object(
    'items', jsonb_build_array(
      jsonb_build_object('kind','product','id',:'product1'::uuid,'quantity',2),
      jsonb_build_object('kind','service','id',:'service1'::uuid,'quantity',1)
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
      'items', jsonb_build_array(jsonb_build_object('kind','service','id',%L,'quantity',1)),
      'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',1))
    ))$sql$,
    :'org1', :'owner1', :'service1'
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

SELECT * FROM finish();
ROLLBACK;
