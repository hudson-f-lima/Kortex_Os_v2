-- Fase 9: Fundação Financeira — Desconto, Gorjeta, Lançamentos Manuais e Estorno
-- Tests: checkout_close com desconto/gorjeta; cash_entry_manual; order_refund

begin;
select plan(28);

-- Setup: create test org, user, professional, service, product
do $$
declare
  v_org_id uuid;
  v_user_id uuid;
  v_prof_id uuid;
  v_svc_id uuid;
  v_prod_id uuid;
  v_grp_id uuid;
begin
  -- Organization
  v_org_id := 'f47ac10b-58cc-4372-a567-0e02b2c3d479'::uuid;
  insert into public.organizations(id, name, slug, active)
  values (v_org_id, 'Test Org F9', 'test-org-f9', true);

  -- User
  v_user_id := 'a0000000-0000-0000-0000-000000000001'::uuid;
  insert into auth.users(id, email, encrypted_password, email_confirmed_at)
  values (v_user_id, 'test-f9@example.com', crypt('password', gen_salt('bf')), now());

  -- Membership (owner)
  insert into public.memberships(organization_id, user_id, role, active)
  values (v_org_id, v_user_id, 'owner', true);

  -- Service group
  v_grp_id := gen_random_uuid();
  insert into public.service_groups(id, organization_id, name, default_commission_type, default_commission_value, active)
  values (v_grp_id, v_org_id, 'Test Group', 'percentage', 2000, true);

  -- Service (R$ 100 = 10000 centavos)
  v_svc_id := gen_random_uuid();
  insert into public.services(id, organization_id, name, price_cents, duration_minutes, service_group_id, active)
  values (v_svc_id, v_org_id, 'Service A', 10000, 30, v_grp_id, true);

  -- Product (R$ 50 = 5000 centavos)
  v_prod_id := gen_random_uuid();
  insert into public.products(id, organization_id, sku, name, price_cents, stock_on_hand, active)
  values (v_prod_id, v_org_id, 'PROD-001', 'Product A', 5000, 100, true);

  -- Professional
  v_prof_id := gen_random_uuid();
  insert into public.professionals(id, organization_id, name, active)
  values (v_prof_id, v_org_id, 'Prof A', true);

  -- Store in temp table for access in tests
  create temp table test_data as
  select v_org_id as org_id, v_user_id as user_id, v_svc_id as service_id,
         v_prod_id as product_id, v_prof_id as professional_id;
end $$;

-- Helper: get test data
create temp view test_context as
select org_id, user_id, service_id, product_id, professional_id from test_data;

-- ============ CHECKOUT_CLOSE: DESCONTO E GORJETA ============

-- T1: Basic checkout com serviço, sem desconto/gorjeta
select results_eq(
  $$ select (res ->> 'status')::text from public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-001',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 10000)
      )
    )
  ) as res $$,
  $$ select 'closed'::text $$,
  'T1: checkout básico sem desconto/gorjeta fecha com status closed'
);

-- T2: Verifica que a ordem sem desconto/gorjeta do T1 fechou com os dois zerados
select results_eq(
  $$ select discount_cents, tip_cents, total_cents
     from public.orders where total_cents = 10000 and discount_cents = 0 and tip_cents = 0 limit 1 $$,
  $$ select 0::bigint, 0::bigint, 10000::bigint $$,
  'T2: ordem sem desconto tem discount_cents=0, tip_cents=0, total=subtotal'
);

-- T3: Checkout com desconto simples (R$ 20 = 2000 centavos em serviço de R$ 100)
select results_eq(
  $$ select (res ->> 'status')::text from public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-002',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'discount_cents', 2000,
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 8000)
      )
    )
  ) as res $$,
  $$ select 'closed'::text $$,
  'T3: checkout com desconto de R$ 20 em serviço de R$ 100 fecha com sucesso'
);

-- T4: Verifica desconto rateado em order_items
select results_eq(
  $$ select sum(discount_cents)::bigint from public.order_items
     where order_id in (select id from public.orders where discount_cents = 2000 limit 1) $$,
  $$ select 2000::bigint $$,
  'T4: desconto foi rateado e somado nos items'
);

-- T5: Checkout com gorjeta em serviço (R$ 10 = 1000 centavos)
select results_eq(
  $$ select (res ->> 'status')::text from public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-003',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'tip_cents', 1000,
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 11000)
      )
    )
  ) as res $$,
  $$ select 'closed'::text $$,
  'T5: checkout com gorjeta de R$ 10 em serviço de R$ 100 fecha com sucesso'
);

-- T6: Verifica gorjeta rateada em order_items
select results_eq(
  $$ select sum(tip_cents)::bigint from public.order_items
     where order_id in (select id from public.orders where tip_cents = 1000 limit 1) $$,
  $$ select 1000::bigint $$,
  'T6: gorjeta foi rateada e somada nos items'
);

-- T7: Checkout com desconto + gorjeta combinados
select results_eq(
  $$ select (res ->> 'total_cents')::bigint from public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-004',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'discount_cents', 2000,
      'tip_cents', 1000,
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 9000)
      )
    )
  ) as res $$,
  $$ select 9000::bigint $$,
  'T7: total da ordem com desconto 2000 + gorjeta 1000 é 10000 - 2000 + 1000 = 9000'
);

-- ============ DESCONTO/GORJETA: CASOS NEGATIVOS ============

-- T8: Desconto maior que subtotal rejeita
select throws_ok(
  $$ select public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-005',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'discount_cents', 15000,
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 0)
      )
    )
  ) $$,
  '22023',
  NULL,
  'T8: desconto maior que subtotal lança 22023'
);

-- T9: Gorjeta sem itens de serviço rejeita
select throws_ok(
  $$ select public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-006',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'product', 'id', (select product_id from test_context)::text, 'quantity', 1)
      ),
      'tip_cents', 1000,
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 6000)
      )
    )
  ) $$,
  '22023',
  NULL,
  'T9: gorjeta sem itens de serviço lança 22023'
);

-- T10: Desconto negativo rejeita
select throws_ok(
  $$ select public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-007',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'discount_cents', -1000,
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 10000)
      )
    )
  ) $$,
  '22023',
  NULL,
  'T10: desconto negativo lança 22023'
);

-- T11: Gorjeta negativa rejeita
select throws_ok(
  $$ select public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-008',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'tip_cents', -1000,
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 10000)
      )
    )
  ) $$,
  '22023',
  NULL,
  'T11: gorjeta negativa lança 22023'
);

-- T12: Pagamento não reconcilia (subtotal - desconto + gorjeta)
select throws_ok(
  $$ select public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-009',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'discount_cents', 2000,
      'tip_cents', 1000,
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 8000)
      )
    )
  ) $$,
  '22023',
  NULL,
  'T12: pagamento desatualizado (esperado 9000, recebido 8000) rejeita 22023'
);

-- ============ COMISSÃO CALCULADA SOBRE NET_CENTS (TOTAL - DESCONTO) ============

-- T13: Comissão de serviço é calculada sobre o valor com desconto já aplicado
-- Service: R$ 100, desconto R$ 20, net = R$ 80
-- Comissão 20% (2000 bps) = R$ 16 (1600 centavos)
select results_eq(
  $$ select commission_cents from public.order_items
     where order_id in (select id from public.orders where discount_cents = 2000 limit 1)
       and kind = 'service' $$,
  $$ select 1600::bigint $$,
  'T13: comissão calculada sobre net_cents (100 - 20 = 80; 80 * 20% = 16)'
);

-- ============ IDEMPOTÊNCIA ============

-- T14: Mesma idempotency_key retorna mesmo resultado
select results_eq(
  $$ select (res1 ->> 'order_id')::text = (res2 ->> 'order_id')::text
     from (
       select public.checkout_close(
         (select org_id from test_context),
         (select user_id from test_context),
         'idempotency-reuse',
         jsonb_build_object(
           'items', jsonb_build_array(
             jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                               'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
           ),
           'payments', jsonb_build_array(
             jsonb_build_object('method', 'cash', 'amount_cents', 10000)
           )
         )
       ) as res1
     ) as t1,
     (
       select public.checkout_close(
         (select org_id from test_context),
         (select user_id from test_context),
         'idempotency-reuse',
         jsonb_build_object(
           'items', jsonb_build_array(
             jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                               'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
           ),
           'payments', jsonb_build_array(
             jsonb_build_object('method', 'cash', 'amount_cents', 10000)
           )
         )
       ) as res2
     ) as t2 $$,
  $$ select true $$,
  'T14: reuso da mesma idempotency_key retorna mesmo order_id'
);

-- T15: Idempotency_key reusado com payload diferente rejeita
select throws_ok(
  $$ select public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-010',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 1)
      ),
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 10000)
      )
    )
  );
  select public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'idempotency-010',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'service', 'id', (select service_id from test_context)::text,
                          'professional_id', (select professional_id from test_context)::text, 'quantity', 2)
      ),
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 20000)
      )
    )
  ) $$,
  '22023',
  NULL,
  'T15: reuso da idempotency_key com payload diferente lança 22023'
);

-- ============ CASH_ENTRY_MANUAL ============

-- T16: Lançamento manual de income (owner)
select results_eq(
  $$ select (res ->> 'status')::text from public.cash_entry_manual(
    (select org_id from test_context),
    (select user_id from test_context),
    'cash-manual-001',
    'income',
    10000,
    'Depósito inicial'
  ) as res $$,
  $$ select 'success'::text $$,
  'T16: lançamento manual de income é aceito'
);

-- T17: Lançamento manual de expense (owner)
select results_eq(
  $$ select (res ->> 'status')::text from public.cash_entry_manual(
    (select org_id from test_context),
    (select user_id from test_context),
    'cash-manual-002',
    'expense',
    5000,
    'Despesa operacional'
  ) as res $$,
  $$ select 'success'::text $$,
  'T17: lançamento manual de expense é aceito'
);

-- T18: Kind inválido rejeita
select throws_ok(
  $$ select public.cash_entry_manual(
    (select org_id from test_context),
    (select user_id from test_context),
    'cash-manual-003',
    'invalid_kind',
    5000,
    'Teste'
  ) $$,
  '22023',
  NULL,
  'T18: kind inválido lança 22023'
);

-- T19: Montante negativo rejeita
select throws_ok(
  $$ select public.cash_entry_manual(
    (select org_id from test_context),
    (select user_id from test_context),
    'cash-manual-004',
    'income',
    -1000,
    'Teste'
  ) $$,
  '22023',
  NULL,
  'T19: montante negativo lança 22023'
);

-- T20: Idempotency_key inválido (muito curto) rejeita
select throws_ok(
  $$ select public.cash_entry_manual(
    (select org_id from test_context),
    (select user_id from test_context),
    'short',
    'income',
    5000,
    'Teste'
  ) $$,
  '22023',
  NULL,
  'T20: idempotency_key muito curta lança 22023'
);

-- ============ ORDER_REFUND ============

-- T21: Estorno de pedido fechado (usa o primeiro pedido 'closed' criado pelos testes acima)
select results_eq(
  $$ select (public.order_refund(
       (select org_id from test_context),
       (select user_id from test_context),
       'refund-001',
       (select id from public.orders where status = 'closed' order by created_at limit 1),
       'customer_cancellation'
     ) ->> 'status')::text $$,
  $$ select 'refunded'::text $$,
  'T21: estorno de pedido fechado muda status para refunded'
);

-- T21b: motivo do estorno gravado no pedido
select results_eq(
  $$ select refund_reason from public.orders where status = 'refunded' limit 1 $$,
  $$ select 'customer_cancellation'::text $$,
  'T21b: refund_reason gravado no pedido'
);

-- T22: Estorno duplicado rejeita
select throws_ok(
  $$ select public.order_refund(
    (select org_id from test_context),
    (select user_id from test_context),
    'refund-002',
    (select id from public.orders where status = 'refunded' limit 1),
    'customer_cancellation'
  ) $$,
  'P0001',
  NULL,
  'T22: estorno duplicado lança P0001'
);

-- T23: Estorno de pedido inexistente rejeita
select throws_ok(
  $$ select public.order_refund(
    (select org_id from test_context),
    (select user_id from test_context),
    'refund-003',
    'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid,
    'customer_cancellation'
  ) $$,
  'P0002',
  NULL,
  'T23: estorno de pedido inexistente lança P0002'
);

-- T24: Estorno reverte estoque de produtos
-- Setup: fecha uma comanda avulsa de produto (5 unidades) e guarda o estoque pós-venda.
do $$
begin
  perform public.checkout_close(
    (select org_id from test_context),
    (select user_id from test_context),
    'stock-test-checkout',
    jsonb_build_object(
      'items', jsonb_build_array(
        jsonb_build_object('kind', 'product', 'id', (select product_id from test_context)::text, 'quantity', 5)
      ),
      'payments', jsonb_build_array(
        jsonb_build_object('method', 'cash', 'amount_cents', 25000)
      )
    )
  );
end $$;

create temp table t24_stock_before as
select stock_on_hand from public.products where id = (select product_id from test_context);

do $$
begin
  perform public.order_refund(
    (select org_id from test_context),
    (select user_id from test_context),
    'stock-test-refund',
    (select id from public.orders where status = 'closed' and exists (
      select 1 from public.order_items oi
      where oi.order_id = public.orders.id and oi.kind = 'product'
    ) order by created_at desc limit 1),
    'customer_default'
  );
end $$;

select results_eq(
  $$ select stock_on_hand from public.products where id = (select product_id from test_context) $$,
  format($s$ select (%L::integer + 5) $s$, (select stock_on_hand from t24_stock_before)),
  'T24: estorno incrementa estoque do produto (5 unidades)'
);

-- T25: Idempotency_key inválido no estorno rejeita
select throws_ok(
  $$ select public.order_refund(
    (select org_id from test_context),
    (select user_id from test_context),
    'bad',
    (select id from public.orders where status = 'closed' limit 1),
    'customer_cancellation'
  ) $$,
  '22023',
  NULL,
  'T25: idempotency_key muito curta em order_refund lança 22023'
);

-- T26: Motivo ausente (null) no estorno rejeita
select throws_ok(
  $$ select public.order_refund(
    (select org_id from test_context),
    (select user_id from test_context),
    'refund-missing-reason',
    (select id from public.orders where status = 'closed' limit 1),
    null
  ) $$,
  '22023',
  NULL,
  'T26: motivo ausente em order_refund lança 22023'
);

-- T27: Motivo inválido no estorno rejeita
select throws_ok(
  $$ select public.order_refund(
    (select org_id from test_context),
    (select user_id from test_context),
    'refund-invalid-reason',
    (select id from public.orders where status = 'closed' limit 1),
    'because_i_said_so'
  ) $$,
  '22023',
  NULL,
  'T27: motivo inválido em order_refund lança 22023'
);

-- Cleanup
select * from finish();
rollback;
