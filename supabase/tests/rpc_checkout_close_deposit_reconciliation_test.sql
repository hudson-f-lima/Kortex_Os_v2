-- Onda 1, fatia 004 (issues/004-checkout-close-deposit-reconciliation.md):
-- checkout_close's deposit reconciliation — applied amount per mechanic,
-- CAS against a concurrent capture (simulated race with fatia 005), and
-- overflow refund vs void. HITL: maior risco da Onda 1.
BEGIN;
SELECT plan(16);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Checkout Deposit', 'org-checkout-deposit')).id AS org1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4000) RETURNING id AS group1 \gset
INSERT INTO public.services (
  organization_id, name, price_cents, duration_minutes, service_group_id,
  deposit_mechanic, deposit_type, deposit_value
) VALUES (
  :'org1'::uuid, 'Corte Com Depósito', 20000, 30, :'group1'::uuid, 'hold', 'fixed', 5000
) RETURNING id AS service1 \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof Um') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid)
  RETURNING id AS client1 \gset

INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-15 10:00+00', '2026-08-15 10:30+00', :'owner1'::uuid)
  RETURNING id AS appt1 \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt1'::uuid) AS hold_result \gset

SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'checkout-deposit-hold-001',
  jsonb_build_object(
    'appointment_id', :'appt1',
    'items', jsonb_build_array(jsonb_build_object('kind', 'service', 'id', :'service1', 'quantity', 1, 'professional_id', :'prof1')),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 15000))
  )
) AS checkout_result \gset

SELECT is(
  (:'checkout_result'::jsonb ->> 'status'),
  'closed',
  'checkout_close still closes normally when reconciling a hold-mechanic deposit'
);
SELECT is(
  ((:'checkout_result'::jsonb ->> 'deposit_applied_cents')::bigint),
  5000::bigint,
  'deposit_applied_cents in the response reflects the full deposit (no overflow, 5000 < 20000 total)'
);
SELECT is(
  ((:'checkout_result'::jsonb ->> 'total_cents')::bigint),
  20000::bigint,
  'the order total_cents is the full service price, unaffected by the deposit reconciliation'
);

SELECT (SELECT id FROM public.deposit_holds WHERE appointment_id = :'appt1'::uuid) AS hold_id \gset
SELECT is(
  (SELECT status FROM public.deposit_holds WHERE id = :'hold_id'::uuid),
  'captured_checkout',
  'the deposit_hold transitions to captured_checkout'
);
SELECT (SELECT payment_intent_id FROM public.deposit_holds WHERE id = :'hold_id'::uuid) AS intent_id \gset
SELECT is(
  (SELECT status FROM public.payment_intents WHERE id = :'intent_id'::uuid),
  'captured',
  'the linked payment_intent transitions to captured'
);
SELECT is(
  (SELECT order_id FROM public.payment_intents WHERE id = :'intent_id'::uuid),
  ((:'checkout_result'::jsonb ->> 'order_id')::uuid),
  'the payment_intent is now linked to the order it helped pay for'
);
SELECT is(
  (SELECT amount_cents FROM public.payments WHERE order_id = ((:'checkout_result'::jsonb ->> 'order_id')::uuid) AND method = 'deposit'),
  5000::bigint,
  'a deposit-method payment row records the applied amount'
);
SELECT is(
  (SELECT sum(amount_cents)::bigint FROM public.payments WHERE order_id = ((:'checkout_result'::jsonb ->> 'order_id')::uuid)),
  20000::bigint,
  'payments (deposit + cash) sum exactly to the order total, same invariant as before'
);
SELECT ok(
  NOT EXISTS(
    SELECT 1 FROM public.cash_entries
    WHERE order_id = ((:'checkout_result'::jsonb ->> 'order_id')::uuid) AND kind = 'refund'
  ),
  'no refund cash_entry when the deposit does not exceed the order total (no overflow)'
);

-- === immediate_charge with overflow: deposit (8000) > final order (5000) ===
-- money already moved for the full 8000 at booking time, so the 3000
-- overflow must actually come back — via a refund cash_entry, never a
-- credit/balance (§3.1 overflow, Onda 2 client_wallets scope).
INSERT INTO public.services (
  organization_id, name, price_cents, duration_minutes, service_group_id,
  deposit_mechanic, deposit_type, deposit_value
) VALUES (
  :'org1'::uuid, 'Corte Reduzido', 5000, 15, :'group1'::uuid, 'immediate_charge', 'fixed', 8000
) RETURNING id AS service_overflow \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service_overflow'::uuid, '2026-08-15 11:00+00', '2026-08-15 11:15+00', :'owner1'::uuid)
  RETURNING id AS appt_overflow \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_overflow'::uuid) AS hold_result_overflow \gset

SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'checkout-deposit-overflow-001',
  jsonb_build_object(
    'appointment_id', :'appt_overflow',
    'items', jsonb_build_array(jsonb_build_object('kind', 'service', 'id', :'service_overflow', 'quantity', 1, 'professional_id', :'prof1')),
    'payments', jsonb_build_array()
  )
) AS checkout_result_overflow \gset

SELECT is(
  ((:'checkout_result_overflow'::jsonb ->> 'deposit_applied_cents')::bigint),
  5000::bigint,
  'deposit_applied_cents is capped at the order total (min(8000, 5000) = 5000), never more'
);
SELECT is(
  ((:'checkout_result_overflow'::jsonb ->> 'total_cents')::bigint),
  5000::bigint,
  'the order total is never negative or reduced by the overflow'
);
SELECT is(
  (
    SELECT amount_cents FROM public.cash_entries
    WHERE order_id = ((:'checkout_result_overflow'::jsonb ->> 'order_id')::uuid) AND kind = 'refund'
  ),
  3000::bigint,
  'the 3000 overflow (8000 charged - 5000 owed) is recorded as a refund cash_entry, not a new credit system'
);

-- === CAS: a hold already captured by another path (simulating a race with
-- the fatia 005 no-show settlement) is not double-captured; checkout closes
-- normally, requiring full payment since no active hold was found ===
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-15 12:00+00', '2026-08-15 12:30+00', :'owner1'::uuid)
  RETURNING id AS appt_race \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_race'::uuid) AS hold_result_race \gset
SELECT (SELECT id FROM public.deposit_holds WHERE appointment_id = :'appt_race'::uuid) AS hold_race_id \gset

-- Simulates the no-show RPC (fatia 005, not built yet) winning the race and
-- capturing the hold first.
UPDATE public.deposit_holds SET status = 'captured_no_show' WHERE id = :'hold_race_id'::uuid;

SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'checkout-deposit-race-001',
  jsonb_build_object(
    'appointment_id', :'appt_race',
    'items', jsonb_build_array(jsonb_build_object('kind', 'service', 'id', :'service1', 'quantity', 1, 'professional_id', :'prof1')),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 20000))
  )
) AS checkout_result_race \gset

SELECT is(
  (:'checkout_result_race'::jsonb ->> 'status'),
  'closed',
  'checkout_close does not error when the CAS finds the hold already captured elsewhere (0 rows affected, no-op)'
);
SELECT is(
  ((:'checkout_result_race'::jsonb ->> 'deposit_applied_cents')::bigint),
  0::bigint,
  'nothing is applied — the hold was already captured by the other path, never captured twice'
);
SELECT is(
  (SELECT status FROM public.deposit_holds WHERE id = :'hold_race_id'::uuid),
  'captured_no_show',
  'the hold status from the winning path (no-show) is preserved, not overwritten by checkout'
);

-- === no appointment_id / no active hold at all: unchanged, exact same behavior as before this fatia ===
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte Sem Depósito', 4000, 20, :'group1'::uuid) RETURNING id AS service_plain \gset
SELECT public.checkout_close(
  :'org1'::uuid, :'owner1'::uuid, 'checkout-no-deposit-001',
  jsonb_build_object(
    'items', jsonb_build_array(jsonb_build_object('kind', 'service', 'id', :'service_plain', 'quantity', 1, 'professional_id', :'prof1')),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 4000))
  )
) AS checkout_result_plain \gset
SELECT is(
  ((:'checkout_result_plain'::jsonb ->> 'deposit_applied_cents')::bigint),
  0::bigint,
  'a checkout with no appointment_id reconciles nothing (identical to pre-fatia-004 behavior)'
);

SELECT * FROM finish();
ROLLBACK;
