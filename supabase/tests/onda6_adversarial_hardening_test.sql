-- Onda 6, fatia 061: Gates 10/11/12/14/18 e serializacao de fatos
-- financeiros contra a linha viva de orders. Nao simula concorrencia: prova
-- o protocolo que a torna serializavel e reexecuta os caminhos apos reopen.
BEGIN;
SELECT plan(12);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$ INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id; $$;

SELECT pg_temp.mk_user('onda6-hardening-owner@test.local') AS owner \gset
SELECT (public.create_organization(:'owner'::uuid, 'Org Onda6 Hardening', 'org-onda6-hardening')).id AS org \gset
SELECT id AS unit FROM public.units WHERE organization_id = :'org'::uuid AND is_default \gset
INSERT INTO public.products (organization_id, sku, name, price_cents, cost_cents, stock_on_hand)
VALUES (:'org'::uuid, 'O6-HARDENING-001', 'Produto Hardening', 1000, 100, 10)
RETURNING id AS product \gset

-- Gate 10/11/12/18: fechamento novo com pagamentos fracionados continua
-- atomico, balanceado, alocado e com caixa exato.
UPDATE public.organizations SET settings = jsonb_build_object('checkout_reopen_enabled', true) WHERE id = :'org'::uuid;
SELECT public.checkout_close(:'org'::uuid, :'owner'::uuid, 'o6-hardening-close-v1', jsonb_build_object(
  'items', jsonb_build_array(jsonb_build_object('kind', 'product', 'id', :'product'::uuid, 'quantity', 1)),
  'payments', jsonb_build_array(
    jsonb_build_object('method', 'cash', 'amount_cents', 700),
    jsonb_build_object('method', 'credit_card', 'amount_cents', 300)
  )
)) AS close_v1 \gset
SELECT (:'close_v1'::jsonb ->> 'order_id')::uuid AS order_id \gset

SELECT is((select status from public.orders where id = :'order_id'::uuid), 'closed', 'Gate 10: dark-launched checkout closes the live order');
SELECT is((select sum(case when direction = 'debit' then amount_cents else -amount_cents end)::bigint from public.kortex_ledger_entries e join public.order_ledger_links l on l.ledger_transaction_id = e.transaction_id where l.order_id = :'order_id'::uuid and l.kind = 'closure'), 0::bigint, 'Gate 11: closure ledger is balanced');
SELECT is((select sum(amount_cents)::bigint from public.payments where order_id = :'order_id'::uuid and revision_number = 1), 1000::bigint, 'Gate 12: version payment allocations sum to the order total');
SELECT is((select sum(amount_cents)::bigint from public.cash_entries where order_id = :'order_id'::uuid and kind = 'sale'), 1000::bigint, 'Gate 18: cash sale remains the exact order total');

-- order_reopen wins the shared row lock: any later financial-lock producer
-- is rejected because the row is now reopened, never appended to v1.
SELECT public.order_reopen_request(:'org'::uuid, :'owner'::uuid, 'o6-hardening-request', :'order_id'::uuid, 'item_correction', 'teste de serializacao') AS reopen_request \gset
SELECT (:'reopen_request'::jsonb ->> 'reopen_attempt_id')::uuid AS attempt_id \gset
SELECT public.order_reopen(:'org'::uuid, :'owner'::uuid, 'o6-hardening-open', :'order_id'::uuid, :'attempt_id'::uuid);
SELECT throws_ok(
  format($sql$insert into public.order_financial_locks(organization_id, unit_id, order_id, revision_number, source_type, source_id, enforcement, created_by) values (%L, %L, %L, 1, 'fiscal_emission', gen_random_uuid(), 'terminal', %L)$sql$, :'org', :'unit', :'order_id', :'owner'),
  'P0001', 'financial lock requires a closed order',
  'Gate 10: producer cannot append a financial lock after order_reopen wins'
);
SELECT is((select count(*)::int from public.order_financial_locks where order_id = :'order_id'::uuid), 0, 'no financial lock was appended after the reopening');

-- Gate 14: commission RPC now shares the same orders FOR UPDATE discipline
-- and refuses an order that became reopened before its turn.
SELECT throws_ok(
  format($sql$select public.commission_sale_record_create(%L, %L, 'o6-hardening-commission-after-open', %L, gen_random_uuid(), gen_random_uuid())$sql$, :'org', :'owner', :'order_id'),
  'P0001', 'order is not closed',
  'Gate 14: commission producer cannot accrue after order_reopen wins'
);
SELECT ok(
  position('for update' in substring(
    pg_get_functiondef('public.commission_sale_record_create(uuid,uuid,text,uuid,uuid,uuid)'::regprocedure)
    from position('from public.orders' in pg_get_functiondef('public.commission_sale_record_create(uuid,uuid,text,uuid,uuid,uuid)'::regprocedure))
  )) > 0,
  'commission producer locks orders before validating closed/current state'
);
SELECT ok(
  position('for update' in pg_get_functiondef('private.onda6_guard_financial_lock_producer()'::regprocedure)) > 0,
  'financial lock producer locks the same order row'
);

-- The revision check closes the second half of the stale-producer race even
-- for a closed order: a v1 lock cannot be created after the order is v2.
UPDATE public.orders SET status = 'closed', current_revision = 2 WHERE id = :'order_id'::uuid;
SELECT throws_ok(
  format($sql$insert into public.order_financial_locks(organization_id, unit_id, order_id, revision_number, source_type, source_id, enforcement, created_by) values (%L, %L, %L, 1, 'staff_payout', gen_random_uuid(), 'terminal', %L)$sql$, :'org', :'unit', :'order_id', :'owner'),
  'P0021', 'financial lock revision is no longer current',
  'stale financial lock revision is rejected after the shared order lock'
);

-- Private primitives remain unavailable even to service_role; only Commands
-- may compose them. This preserves the Red Team surface from slices 056/058.
SELECT ok(not has_function_privilege('authenticated', 'private.onda6_guard_financial_lock_producer()', 'EXECUTE') and not has_function_privilege('service_role', 'private.onda6_guard_financial_lock_producer()', 'EXECUTE'), 'authenticated and service_role cannot call the lock primitive directly');
SELECT ok(not has_function_privilege('authenticated', 'private.checkout_ledger_post(uuid,uuid,text,uuid,integer,text)', 'EXECUTE') and not has_function_privilege('service_role', 'private.checkout_ledger_post(uuid,uuid,text,uuid,integer,text)', 'EXECUTE'), 'authenticated and service_role cannot call the ledger primitive directly');

SELECT * FROM finish();
ROLLBACK;
