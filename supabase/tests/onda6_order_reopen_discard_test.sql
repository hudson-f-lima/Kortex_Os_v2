BEGIN;
SELECT plan(36);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$ INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id; $$;

SELECT ok(NOT has_function_privilege('authenticated', 'public.order_reopen_request(uuid,uuid,text,uuid,text,text)', 'EXECUTE'), 'authenticated cannot call the reopen request command directly');
SELECT ok(NOT has_function_privilege('authenticated', 'public.order_reopen_approve(uuid,uuid,text,uuid,uuid)', 'EXECUTE'), 'authenticated cannot call the owner approval command directly');
SELECT ok(NOT has_function_privilege('authenticated', 'public.order_reopen(uuid,uuid,text,uuid,uuid)', 'EXECUTE'), 'authenticated cannot call the reopen command directly');
SELECT ok(NOT has_function_privilege('authenticated', 'public.order_reopen_discard(uuid,uuid,text,uuid,uuid)', 'EXECUTE'), 'authenticated cannot call the discard command directly');

SELECT pg_temp.mk_user('onda6-reopen-owner@test.local') AS owner \gset
SELECT pg_temp.mk_user('onda6-reopen-manager@test.local') AS manager \gset
SELECT pg_temp.mk_user('onda6-reopen-reception@test.local') AS reception \gset
SELECT (public.create_organization(:'owner'::uuid, 'Org Onda6 Reopen', 'org-onda6-reopen')).id AS org \gset
SELECT id AS unit FROM public.units WHERE organization_id = :'org'::uuid AND is_default \gset
INSERT INTO public.memberships (organization_id, user_id, role) VALUES (:'org'::uuid, :'manager'::uuid, 'manager');
INSERT INTO public.memberships (organization_id, user_id, role, unit_id) VALUES (:'org'::uuid, :'reception'::uuid, 'reception', :'unit'::uuid);
INSERT INTO public.products (organization_id, sku, name, price_cents, cost_cents, stock_on_hand)
VALUES (:'org'::uuid, 'O6-REOPEN-001', 'Produto de reabertura', 1000, 100, 10)
RETURNING id AS product \gset
UPDATE public.organizations SET settings = jsonb_build_object('checkout_reopen_enabled', true) WHERE id = :'org'::uuid;

SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-reopen-close-001', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind','product','id',:'product'::uuid,'quantity',1)),
  'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',1000))
)) AS close_response \gset
SELECT (:'close_response'::jsonb ->> 'order_id')::uuid AS order_id \gset
SELECT is((select stock_on_hand from public.products where id = :'product'::uuid), 9, 'versioned checkout consumes stock before reopening');
SELECT (public.order_reopen_request(:'org'::uuid, :'manager'::uuid, 'o6-reopen-request-001', :'order_id'::uuid, 'item_correction', 'corrigir produto')) AS request_response \gset
SELECT (:'request_response'::jsonb ->> 'reopen_attempt_id')::uuid AS attempt_id \gset
SELECT is((:'request_response'::jsonb ->> 'status'), 'requested', 'management request creates the single active reopen attempt');

SELECT public.order_reopen(:'org'::uuid, :'manager'::uuid, 'o6-reopen-open-001', :'order_id'::uuid, :'attempt_id'::uuid) AS open_response \gset
SELECT is((:'open_response'::jsonb ->> 'status'), 'reopened', 'manager opens a versioned closed order');
SELECT is((select stock_on_hand from public.products where id = :'product'::uuid), 10, 'opening restores v1 stock from the immutable snapshot');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'order_id'::uuid and kind = 'reversal'), 1, 'opening writes exactly one linked ledger reversal');
SELECT is((select count(*)::int from public.cash_entries where order_id = :'order_id'::uuid), 1, 'opening creates no cash refund or sale');
SELECT is((select status from public.order_reopen_attempts where id = :'attempt_id'::uuid), 'opened', 'opening transitions the attempt atomically');
SELECT is((select count(*)::int from public.order_reopen_attempt_events where reopen_attempt_id = :'attempt_id'::uuid and event_type = 'opened'), 1, 'opening appends an audit event');

SELECT public.order_reopen_discard(:'org'::uuid, :'manager'::uuid, 'o6-reopen-discard-001', :'order_id'::uuid, :'attempt_id'::uuid) AS discard_response \gset
SELECT is((:'discard_response'::jsonb ->> 'status'), 'closed', 'discard restores the order to closed');
SELECT is((select stock_on_hand from public.products where id = :'product'::uuid), 9, 'discard reapplies v1 stock consumption');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'order_id'::uuid and kind = 'restore'), 1, 'discard writes exactly one linked ledger restoration');
SELECT is((select count(*)::int from public.cash_entries where order_id = :'order_id'::uuid), 1, 'discard creates no cash refund or sale');
SELECT is((select status from public.order_reopen_attempts where id = :'attempt_id'::uuid), 'discarded', 'discard transitions the attempt atomically');
SELECT is((select count(*)::int from public.order_reopen_attempt_events where reopen_attempt_id = :'attempt_id'::uuid and event_type = 'discarded'), 1, 'discard appends an audit event');
SELECT is(public.order_reopen_discard(:'org'::uuid, :'manager'::uuid, 'o6-reopen-discard-001', :'order_id'::uuid, :'attempt_id'::uuid), :'discard_response'::jsonb, 'discard replay returns the cached response without new effects');

-- A discarded attempt frees the order for a new attempt on the same immutable
-- revision. Each reversal/restore must remain attributable to its own attempt.
SELECT public.order_reopen_request(:'org'::uuid, :'manager'::uuid, 'o6-reopen-request-again-001', :'order_id'::uuid, 'pricing_error', 'segunda tentativa') AS second_request_response \gset
SELECT (:'second_request_response'::jsonb ->> 'reopen_attempt_id')::uuid AS second_attempt_id \gset
SELECT is((:'second_request_response'::jsonb ->> 'status'), 'requested', 'a discarded attempt permits a second request on the same revision');
SELECT public.order_reopen(:'org'::uuid, :'manager'::uuid, 'o6-reopen-open-again-001', :'order_id'::uuid, :'second_attempt_id'::uuid) AS second_open_response \gset
SELECT is((:'second_open_response'::jsonb ->> 'status'), 'reopened', 'the second attempt opens the same revision');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'order_id'::uuid and kind = 'reversal'), 2, 'each successful attempt has its own reversal ledger link');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'order_id'::uuid and reopen_attempt_id = :'second_attempt_id'::uuid and kind = 'reversal'), 1, 'the second reversal link is attributed to the second attempt');
SELECT public.order_reopen_discard(:'org'::uuid, :'manager'::uuid, 'o6-reopen-discard-again-001', :'order_id'::uuid, :'second_attempt_id'::uuid) AS second_discard_response \gset
SELECT is((:'second_discard_response'::jsonb ->> 'status'), 'closed', 'the second discard restores the order to closed');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'order_id'::uuid and kind = 'restore'), 2, 'each discarded attempt has its own restore ledger link');
SELECT is((select stock_on_hand from public.products where id = :'product'::uuid), 9, 'two open/discard cycles preserve the original stock consumption');

SELECT throws_ok(
  format('select public.order_reopen_request(%L,%L,%L,%L,%L,%L)', :'org', :'reception', 'o6-reopen-reception-001', :'order_id', 'other', 'forbidden'),
  '42501', NULL, 'reception can never request a financial reopen'
);
SELECT public.order_reopen_request(:'org'::uuid, :'manager'::uuid, 'o6-reopen-divergent-001', :'order_id'::uuid, 'other', 'first') AS divergent_request \gset
SELECT throws_ok(
  format('select public.order_reopen_request(%L,%L,%L,%L,%L,%L)', :'org', :'manager', 'o6-reopen-divergent-001', :'order_id', 'other', 'second'),
  '22023', 'idempotency key reused with different payload', 'reopen request rejects a divergent replay'
);

-- A cash-close lock turns the request into an owner-approved Action Request.
SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-reopen-close-002', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind','product','id',:'product'::uuid,'quantity',1)),
  'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',1000))
)) AS locked_close_response \gset
SELECT (:'locked_close_response'::jsonb ->> 'order_id')::uuid AS locked_order_id \gset
INSERT INTO public.order_financial_locks(organization_id, unit_id, order_id, revision_number, source_type, source_id, enforcement, created_by)
VALUES (:'org'::uuid, :'unit'::uuid, :'locked_order_id'::uuid, 1, 'cash_close', gen_random_uuid(), 'action_request_required', :'owner'::uuid);
SELECT public.order_reopen_request(:'org'::uuid, :'manager'::uuid, 'o6-reopen-request-002', :'locked_order_id'::uuid, 'pricing_error', 'fechamento de caixa') AS cash_request \gset
SELECT (:'cash_request'::jsonb ->> 'reopen_attempt_id')::uuid AS cash_attempt_id \gset
SELECT throws_ok(
  format('select public.order_reopen(%L,%L,%L,%L,%L)', :'org', :'manager', 'o6-reopen-open-002', :'locked_order_id', :'cash_attempt_id'),
  'P0001', 'owner approval required for cash close', 'cash close blocks opening before owner approval'
);
SELECT is(
  public.order_reopen_approve(:'org'::uuid, :'owner'::uuid, 'o6-reopen-approve-001', :'locked_order_id'::uuid, :'cash_attempt_id'::uuid) ->> 'status',
  'approved',
  'owner approval transitions the cash-close action request'
);
SELECT is((public.order_reopen(:'org'::uuid, :'manager'::uuid, 'o6-reopen-open-002', :'locked_order_id'::uuid, :'cash_attempt_id'::uuid) ->> 'status'), 'reopened', 'owner-approved cash close attempt can open');
SELECT is((select count(*)::int from public.order_ledger_links where order_id = :'locked_order_id'::uuid and kind = 'reversal' and reopen_attempt_id = :'cash_attempt_id'::uuid), 1, 'owner-approved reversal link is attributed to its attempt');

-- A historical closed order without the v1 closure link is intentionally ineligible.
INSERT INTO public.orders(organization_id, unit_id, status, subtotal_cents, total_cents, created_by, closed_at)
VALUES (:'org'::uuid, :'unit'::uuid, 'closed', 0, 0, :'owner'::uuid, now())
RETURNING id AS legacy_order_id \gset
SELECT throws_ok(
  format('select public.order_reopen_request(%L,%L,%L,%L,%L,%L)', :'org', :'manager', 'o6-reopen-legacy-001', :'legacy_order_id', 'other', 'pedido legado'),
  'P0001', 'legacy order cannot be reopened', 'a legacy closed order without a closure link is rejected'
);

SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-reopen-close-terminal', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind','product','id',:'product'::uuid,'quantity',1)),
  'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',1000))
)) AS terminal_close_response \gset
SELECT (:'terminal_close_response'::jsonb ->> 'order_id')::uuid AS terminal_order_id \gset
INSERT INTO public.order_financial_locks(organization_id, unit_id, order_id, revision_number, source_type, source_id, enforcement, created_by)
VALUES (:'org'::uuid, :'unit'::uuid, :'terminal_order_id'::uuid, 1, 'fiscal_emission', gen_random_uuid(), 'terminal', :'owner'::uuid);
SELECT throws_ok(
  format('select public.order_reopen_request(%L,%L,%L,%L,%L,%L)', :'org', :'manager', 'o6-reopen-terminal-001', :'terminal_order_id', 'other', 'fiscal fechado'),
  'P0001', 'order has a terminal financial lock', 'a terminal financial lock rejects a reopen request'
);

SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-reopen-close-captured', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind','product','id',:'product'::uuid,'quantity',1)),
  'payments', jsonb_build_array(jsonb_build_object('method','cash','amount_cents',1000))
)) AS captured_close_response \gset
SELECT (:'captured_close_response'::jsonb ->> 'order_id')::uuid AS captured_order_id \gset
INSERT INTO public.payment_intents(organization_id, unit_id, order_id, purpose, provider, provider_reference, amount_cents, status, created_by)
VALUES (:'org'::uuid, :'unit'::uuid, :'captured_order_id'::uuid, 'checkout', 'test', 'o6-reopen-captured-001', 1000, 'captured', :'owner'::uuid);
SELECT throws_ok(
  format('select public.order_reopen_request(%L,%L,%L,%L,%L,%L)', :'org', :'manager', 'o6-reopen-captured-001', :'captured_order_id', 'other', 'captura PSP'),
  'P0001', 'order has a terminal financial lock', 'a captured payment intent rejects a reopen request'
);

SELECT pg_temp.mk_user('onda6-reopen-other-owner@test.local') AS other_owner \gset
SELECT (public.create_organization(:'other_owner'::uuid, 'Org Onda6 Reopen Outra', 'org-onda6-reopen-outra')).id AS other_org \gset
UPDATE public.organizations SET settings = jsonb_build_object('checkout_reopen_enabled', true) WHERE id = :'other_org'::uuid;
SELECT throws_ok(
  format('select public.order_reopen_request(%L,%L,%L,%L,%L,%L)', :'other_org', :'other_owner', 'o6-reopen-cross-tenant-001', :'order_id', 'other', 'tenant errado'),
  'P0002', 'order not found', 'a tenant member cannot request reopening an order from another tenant'
);

SELECT * FROM finish();
ROLLBACK;
