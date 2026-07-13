BEGIN;
SELECT plan(11);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Inventory', 'org-inventory')).id AS org1 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');

INSERT INTO public.products (organization_id, sku, name, price_cents, stock_on_hand)
  VALUES (:'org1'::uuid, 'SKU-1', 'Shampoo', 2500, 10)
  RETURNING id AS product1 \gset

-- Grant lockdown
SELECT ok(
  NOT has_function_privilege('authenticated', 'public.inventory_adjust(uuid, uuid, text, uuid, integer, text)', 'EXECUTE'),
  'authenticated cannot execute inventory_adjust'
);

-- Reception role is not allowed to adjust inventory (owner/admin/manager only).
SELECT throws_ok(
  format(
    'select public.inventory_adjust(%L, %L, ''ia-role-0001'', %L, 5, ''purchase'')',
    :'org1', :'reception1', :'product1'
  ),
  '42501',
  NULL,
  'reception1 cannot call inventory_adjust (insufficient organization permission)'
);

-- Purchase increases stock and records a movement.
SELECT public.inventory_adjust(:'org1'::uuid, :'owner1'::uuid, 'ia-purchase-0001', :'product1'::uuid, 20, 'purchase');
SELECT is(
  (SELECT stock_on_hand FROM public.products WHERE id = :'product1'::uuid),
  30,
  'a purchase of +20 raises stock from 10 to 30'
);
SELECT is(
  (SELECT count(*)::int FROM public.inventory_movements WHERE product_id = :'product1'::uuid AND reason = 'purchase'),
  1,
  'inventory_adjust records one movement of reason purchase'
);

-- Adjustment can be negative, but not below zero.
SELECT public.inventory_adjust(:'org1'::uuid, :'owner1'::uuid, 'ia-adjust-0001', :'product1'::uuid, -5, 'adjustment');
SELECT is(
  (SELECT stock_on_hand FROM public.products WHERE id = :'product1'::uuid),
  25,
  'a negative adjustment of -5 lowers stock from 30 to 25'
);
SELECT throws_ok(
  format(
    'select public.inventory_adjust(%L, %L, ''ia-negative-0001'', %L, -1000, ''adjustment'')',
    :'org1', :'owner1', :'product1'
  ),
  'P0001',
  NULL,
  'an adjustment that would drive stock below zero is rejected'
);
SELECT is(
  (SELECT stock_on_hand FROM public.products WHERE id = :'product1'::uuid),
  25,
  'a rejected adjustment leaves stock untouched'
);

-- purchase/return require a positive delta.
SELECT throws_ok(
  format(
    'select public.inventory_adjust(%L, %L, ''ia-bad-purchase-0001'', %L, -3, ''purchase'')',
    :'org1', :'owner1', :'product1'
  ),
  '22023',
  NULL,
  'a purchase with a negative delta is rejected'
);

-- Idempotent replay: same key + same args returns cached response, no double effect.
SELECT public.inventory_adjust(:'org1'::uuid, :'owner1'::uuid, 'ia-purchase-0001', :'product1'::uuid, 20, 'purchase');
SELECT is(
  (SELECT stock_on_hand FROM public.products WHERE id = :'product1'::uuid),
  25,
  'replaying ia-purchase-0001 does not add another +20'
);

-- Same key, different args: rejected.
SELECT throws_ok(
  format(
    'select public.inventory_adjust(%L, %L, ''ia-purchase-0001'', %L, 7, ''purchase'')',
    :'org1', :'owner1', :'product1'
  ),
  '22023',
  NULL,
  'reusing an idempotency key with different adjustment arguments is rejected'
);

-- Nonexistent / inactive product rejected.
SELECT throws_ok(
  format(
    'select public.inventory_adjust(%L, %L, ''ia-missing-0001'', %L, 1, ''purchase'')',
    :'org1', :'owner1', gen_random_uuid()
  ),
  'P0002',
  NULL,
  'inventory_adjust rejects a product id that does not exist'
);

SELECT * FROM finish();
ROLLBACK;
