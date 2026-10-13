BEGIN;
SELECT plan(12);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$ INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id; $$;

SELECT pg_temp.mk_user('onda6-refund-ledger-owner@test.local') AS owner \gset
SELECT pg_temp.mk_user('onda6-refund-ledger-outsider@test.local') AS outsider \gset
SELECT (public.create_organization(:'owner'::uuid, 'Org Onda6 Refund Ledger', 'org-onda6-refund-ledger')).id AS org \gset
INSERT INTO public.products (organization_id, sku, name, price_cents, cost_cents, stock_on_hand)
VALUES (:'org'::uuid, 'O6-REFUND-LEDGER-001', 'Produto Refund Ledger', 1000, 100, 10)
RETURNING id AS product \gset

-- The order becomes versioned while the dark launch is on, then reaches v2.
UPDATE public.organizations SET settings = jsonb_build_object('checkout_reopen_enabled', true) WHERE id = :'org'::uuid;
SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-refund-ledger-close-v1', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1000))
)) AS close_v1 \gset
SELECT (:'close_v1'::jsonb ->> 'order_id')::uuid AS versioned_order_id \gset
SELECT public.order_reopen_request(:'org'::uuid, :'owner'::uuid, 'o6-refund-ledger-request', :'versioned_order_id'::uuid, 'item_correction', 'adicionar produto') AS reopen_request \gset
SELECT (:'reopen_request'::jsonb ->> 'reopen_attempt_id')::uuid AS reopen_attempt_id \gset
SELECT public.order_reopen(:'org'::uuid, :'owner'::uuid, 'o6-refund-ledger-open', :'versioned_order_id'::uuid, :'reopen_attempt_id'::uuid);
SELECT public.order_reclose(:'org'::uuid, :'owner'::uuid, 'o6-refund-ledger-reclose-v2', :'versioned_order_id'::uuid, :'reopen_attempt_id'::uuid, jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 2)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 2000)),
  'discount_cents', 0,
  'tip_cents', 0
));

-- The current flag may turn off new versioned closes, never the refund path.
UPDATE public.organizations SET settings = '{}'::jsonb WHERE id = :'org'::uuid;
SELECT public.order_refund(:'org'::uuid, :'owner'::uuid, 'o6-refund-ledger-refund-v2', :'versioned_order_id'::uuid, 'customer_cancellation') AS versioned_refund \gset

SELECT is(:'versioned_refund'::jsonb ->> 'status', 'refunded', 'versioned order still refunds after the flag is disabled');
SELECT is((select current_revision from public.orders where id = :'versioned_order_id'::uuid), 2, 'refund keeps the current version immutable');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'versioned_order_id'::uuid and revision_number = 2 and kind = 'reversal'), 1, 'current version receives one reversal link');
SELECT is((select amount_cents from public.cash_entries where order_id = :'versioned_order_id'::uuid and kind = 'refund'), 2000::bigint, 'refund cash entry keeps the existing full-current-total contract');
SELECT is((select stock_on_hand from public.products where id = :'product'::uuid), 10, 'refund restores v2 product stock exactly once');

SELECT l.ledger_transaction_id AS closure_transaction_id
FROM public.order_ledger_links l
WHERE l.order_id = :'versioned_order_id'::uuid AND l.revision_number = 2 AND l.kind = 'closure' \gset
SELECT l.ledger_transaction_id AS reversal_transaction_id
FROM public.order_ledger_links l
WHERE l.order_id = :'versioned_order_id'::uuid AND l.revision_number = 2 AND l.kind = 'reversal' \gset
SELECT set_eq(
  format('select account_id, case when direction = ''debit'' then ''credit'' else ''debit'' end as direction, amount_cents from public.kortex_ledger_entries where transaction_id = %L::uuid', :'closure_transaction_id'),
  format('select account_id, direction, amount_cents from public.kortex_ledger_entries where transaction_id = %L::uuid', :'reversal_transaction_id'),
  'reversal ledger entries are the exact inverse of the current closure'
);

SELECT public.order_refund(:'org'::uuid, :'owner'::uuid, 'o6-refund-ledger-refund-v2', :'versioned_order_id'::uuid, 'customer_cancellation') AS replay_refund \gset
SELECT is(:'replay_refund'::jsonb ->> 'status', 'refunded', 'same refund idempotency key replays the response');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'versioned_order_id'::uuid and revision_number = 2 and kind = 'reversal'), 1, 'refund replay never posts a second reversal');

-- A legacy order has no closure link and retains the old refund path exactly.
SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-refund-ledger-legacy-close', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 1000))
)) AS legacy_close \gset
SELECT (:'legacy_close'::jsonb ->> 'order_id')::uuid AS legacy_order_id \gset
SELECT public.order_refund(:'org'::uuid, :'owner'::uuid, 'o6-refund-ledger-legacy-refund', :'legacy_order_id'::uuid, 'customer_default') AS legacy_refund \gset
SELECT is(:'legacy_refund'::jsonb ->> 'status', 'refunded', 'legacy order keeps the established refund response');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'legacy_order_id'::uuid), 0, 'legacy refund creates no ledger link');
SELECT ok(
  not has_function_privilege('authenticated', 'public.order_refund(uuid,uuid,text,uuid,text)', 'EXECUTE'),
  'authenticated has no direct execute grant on the server-owned refund command'
);
SELECT throws_ok(
  format('select public.order_refund(%L,%L,%L,%L,%L)', :'org', :'outsider', 'o6-refund-ledger-cross-tenant', :'legacy_order_id', 'customer_cancellation'),
  '42501', 'insufficient organization permission',
  'an actor without membership in the order tenant cannot refund it'
);

SELECT * FROM finish();
ROLLBACK;
