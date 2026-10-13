BEGIN;
SELECT plan(18);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$ INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id; $$;

SELECT pg_temp.mk_user('onda6-reclose-owner@test.local') AS owner \gset
SELECT (public.create_organization(:'owner'::uuid, 'Org Onda6 Reclose', 'org-onda6-reclose')).id AS org \gset
SELECT id AS unit FROM public.units WHERE organization_id = :'org'::uuid AND is_default \gset
INSERT INTO public.products (organization_id, sku, name, price_cents, cost_cents, stock_on_hand)
VALUES (:'org'::uuid, 'O6-RECLOSE-001', 'Produto Refechamento', 1000, 100, 10)
RETURNING id AS product \gset
UPDATE public.organizations SET settings = jsonb_build_object('checkout_reopen_enabled', true) WHERE id = :'org'::uuid;

SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-reclose-close-v1', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1000))
)) AS close_response \gset
SELECT (:'close_response'::jsonb ->> 'order_id')::uuid AS order_id \gset
SELECT public.order_reopen_request(:'org'::uuid, :'owner'::uuid, 'o6-reclose-request-v1', :'order_id'::uuid, 'item_correction', 'adicionar produto') AS request_response \gset
SELECT (:'request_response'::jsonb ->> 'reopen_attempt_id')::uuid AS attempt_id \gset
SELECT public.order_reopen(:'org'::uuid, :'owner'::uuid, 'o6-reclose-open-v1', :'order_id'::uuid, :'attempt_id'::uuid);

SELECT public.order_reclose(:'org'::uuid, :'owner'::uuid, 'o6-reclose-v2', :'order_id'::uuid, :'attempt_id'::uuid, jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 2)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 2000)),
  'discount_cents', 0,
  'tip_cents', 0
)) AS reclose_response \gset

SELECT is(:'reclose_response'::jsonb ->> 'status', 'closed', 'reclose closes the edited order as revision v2');
SELECT is((select amount_cents from public.cash_entries where organization_id = :'org'::uuid and order_id = :'order_id'::uuid and kind = 'sale' order by created_at desc limit 1), 1000::bigint, 'reclose posts only the positive cash delta');
SELECT is((select current_revision from public.orders where id = :'order_id'::uuid), 2, 'reclose advances the live revision only after v2 is complete');
SELECT is((select count(*)::int from public.order_revisions where order_id = :'order_id'::uuid), 2, 'both immutable v1 and v2 snapshots are retained');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'order_id'::uuid and revision_number = 2 and kind = 'closure'), 1, 'v2 receives its own balanced closure link');
SELECT is((select count(*)::int from public.payments where order_id = :'order_id'::uuid and revision_number = 1), 1, 'v1 payment remains append-only');
SELECT is((select count(*)::int from public.payments where order_id = :'order_id'::uuid and revision_number = 2), 1, 'v2 payment is appended at the new revision');
SELECT is((select stock_on_hand from public.products where id = :'product'::uuid), 8, 'v2 applies exactly its edited stock consumption after reopening restored v1');
SELECT is((select status from public.order_reopen_attempts where id = :'attempt_id'::uuid), 'reclosed', 'reclose resolves the active attempt');
SELECT is(
  (public.order_reclose(:'org'::uuid, :'owner'::uuid, 'o6-reclose-v2', :'order_id'::uuid, :'attempt_id'::uuid, jsonb_build_object(
    'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 2)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 2000)),
    'discount_cents', 0,
    'tip_cents', 0
  )) ->> 'revision_number')::integer,
  2,
  'same idempotency key replays the v2 response without another closing'
);
SELECT ok(
  not has_function_privilege('authenticated', 'public.order_reclose(uuid,uuid,text,uuid,uuid,jsonb)', 'EXECUTE'),
  'authenticated has no direct execute grant on the server-owned reclose command'
);

-- A smaller v2 creates an exact refund and allocates it to the v1 payment.
SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-reclose-close-refund-v1', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 2)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 2000))
)) AS refund_close_response \gset
SELECT (:'refund_close_response'::jsonb ->> 'order_id')::uuid AS refund_order_id \gset
SELECT public.order_reopen_request(:'org'::uuid, :'owner'::uuid, 'o6-reclose-request-refund', :'refund_order_id'::uuid, 'item_correction', 'remover um produto') AS refund_request \gset
SELECT (:'refund_request'::jsonb ->> 'reopen_attempt_id')::uuid AS refund_attempt_id \gset
SELECT public.order_reopen(:'org'::uuid, :'owner'::uuid, 'o6-reclose-open-refund', :'refund_order_id'::uuid, :'refund_attempt_id'::uuid);
SELECT public.order_reclose(:'org'::uuid, :'owner'::uuid, 'o6-reclose-refund-v2', :'refund_order_id'::uuid, :'refund_attempt_id'::uuid, jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1000)),
  'discount_cents', 0,
  'tip_cents', 0
)) AS refund_reclose_response \gset
SELECT is((:'refund_reclose_response'::jsonb ->> 'cash_delta_cents')::bigint, -1000::bigint, 'smaller v2 reports the negative cash delta');
SELECT is((select amount_cents from public.cash_entries where order_id = :'refund_order_id'::uuid and kind = 'refund'), 1000::bigint, 'smaller v2 writes one exact refund cash entry');
SELECT is((select sum(amount_cents)::bigint from public.order_payment_adjustments where order_id = :'refund_order_id'::uuid), 1000::bigint, 'refund allocation sums exactly to the negative delta');

-- Equal total creates neither a new sale nor a refund delta.
SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-reclose-close-zero-v1', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1000))
)) AS zero_close_response \gset
SELECT (:'zero_close_response'::jsonb ->> 'order_id')::uuid AS zero_order_id \gset
SELECT public.order_reopen_request(:'org'::uuid, :'owner'::uuid, 'o6-reclose-request-zero', :'zero_order_id'::uuid, 'item_correction', 'confirmar mesma comanda') AS zero_request \gset
SELECT (:'zero_request'::jsonb ->> 'reopen_attempt_id')::uuid AS zero_attempt_id \gset
SELECT public.order_reopen(:'org'::uuid, :'owner'::uuid, 'o6-reclose-open-zero', :'zero_order_id'::uuid, :'zero_attempt_id'::uuid);
SELECT public.order_reclose(:'org'::uuid, :'owner'::uuid, 'o6-reclose-zero-v2', :'zero_order_id'::uuid, :'zero_attempt_id'::uuid, jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1000)),
  'discount_cents', 0,
  'tip_cents', 0
)) AS zero_reclose_response \gset
SELECT is((:'zero_reclose_response'::jsonb ->> 'cash_delta_cents')::bigint, 0::bigint, 'equal v2 reports a zero cash delta');
SELECT is((select count(*)::int from public.cash_entries where order_id = :'zero_order_id'::uuid), 1, 'equal v2 preserves only the original cash entry');
SELECT is((select count(*)::int from public.order_payment_adjustments where order_id = :'zero_order_id'::uuid), 0, 'equal v2 creates no refund allocation');

SELECT throws_ok(
  format('select public.order_reclose(%L,%L,%L,%L,%L,%L::jsonb)', :'org', :'owner', 'o6-reclose-replay-divergent', :'order_id', :'attempt_id', jsonb_build_object('items',jsonb_build_array(), 'payments',jsonb_build_array())::text),
  'P0001', 'only reopened orders can be reclosed', 'a closed order cannot be reclosed a second time'
);

SELECT * FROM finish();
ROLLBACK;
