-- Onda 1, fatia 005 (issues/005-no-show-settlement-rpc.md):
-- no_show_settlement_create — commission from the deposit_hold snapshot,
-- CAS parity with fatia 004, authorization parity with appointment status
-- changes, and visibility through the same order_items query the
-- professional already uses.
BEGIN;
SELECT plan(15);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org No Show', 'org-no-show')).id AS org1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4000) RETURNING id AS group1 \gset
INSERT INTO public.services (
  organization_id, name, price_cents, duration_minutes, service_group_id,
  deposit_mechanic, deposit_type, deposit_value, no_show_commission_type, no_show_commission_value
) VALUES (
  :'org1'::uuid, 'Corte Com Depósito', 20000, 30, :'group1'::uuid, 'hold', 'fixed', 5000, 'percentage', 3000
) RETURNING id AS service1 \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof Um') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid)
  RETURNING id AS client1 \gset

INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-20 10:00+00', '2026-08-20 10:30+00', 'no_show', :'owner1'::uuid)
  RETURNING id AS appt1 \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt1'::uuid) AS hold_result \gset

SELECT public.no_show_settlement_create(:'org1'::uuid, :'owner1'::uuid, :'appt1'::uuid) AS result \gset
SELECT is(
  (:'result'::jsonb ->> 'status'),
  'settled',
  'no_show_settlement_create settles a no_show appointment with an active hold'
);
-- 5000 cents (deposit_hold.amount_cents, fixed) * 3000 basis points / 10000 = 1500 (percentage no_show_commission).
SELECT is(
  ((:'result'::jsonb ->> 'commission_cents')::bigint),
  1500::bigint,
  'commission is computed from the deposit_hold no_show_commission snapshot, not resolve_commission()'
);
SELECT is(
  ((:'result'::jsonb ->> 'amount_cents')::bigint),
  5000::bigint,
  'the synthetic order charges exactly the deposit amount, not the full service price'
);

SELECT (SELECT id FROM public.deposit_holds WHERE appointment_id = :'appt1'::uuid) AS hold_id \gset
SELECT is(
  (SELECT status FROM public.deposit_holds WHERE id = :'hold_id'::uuid),
  'captured_no_show',
  'the deposit_hold transitions to captured_no_show'
);

SELECT (SELECT (:'result'::jsonb ->> 'order_id')::uuid) AS order_id \gset
SELECT is(
  (SELECT status FROM public.orders WHERE id = :'order_id'::uuid),
  'closed',
  'the synthetic order is created closed, same as a real checkout'
);
SELECT is(
  (SELECT total_cents FROM public.orders WHERE id = :'order_id'::uuid),
  5000::bigint,
  'the order total is exactly the deposit amount forfeited'
);
SELECT is(
  (SELECT amount_cents FROM public.payments WHERE order_id = :'order_id'::uuid AND method = 'deposit'),
  5000::bigint,
  'a deposit-method payment records the forfeited amount'
);

-- === visibility: the no-show commission shows up in the exact same query the
-- professional already uses to see their commission (no parallel trail) ===
SELECT is(
  (
    SELECT commission_cents FROM public.order_items
    WHERE organization_id = :'org1'::uuid AND professional_id = :'prof1'::uuid AND order_id = :'order_id'::uuid
  ),
  1500::bigint,
  'the no-show commission is visible via the same order_items.commission_cents query as any other sale'
);
SELECT is(
  (SELECT service_id FROM public.order_items WHERE order_id = :'order_id'::uuid),
  (:'service1'::uuid),
  'the order_item references the original appointment service'
);

-- === CAS: a hold already captured by checkout (fatia 004) is not settled twice ===
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-20 11:00+00', '2026-08-20 11:30+00', 'no_show', :'owner1'::uuid)
  RETURNING id AS appt_race \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_race'::uuid) AS hold_result_race \gset
SELECT (SELECT id FROM public.deposit_holds WHERE appointment_id = :'appt_race'::uuid) AS hold_race_id \gset
-- Simulates checkout_close (fatia 004) winning the race.
UPDATE public.deposit_holds SET status = 'captured_checkout' WHERE id = :'hold_race_id'::uuid;

SELECT public.no_show_settlement_create(:'org1'::uuid, :'owner1'::uuid, :'appt_race'::uuid) AS result_race \gset
SELECT is(
  (:'result_race'::jsonb ->> 'status'),
  'skipped',
  'no_show_settlement_create no-ops when the CAS finds the hold already captured by checkout (0 rows affected)'
);
SELECT is(
  (SELECT status FROM public.deposit_holds WHERE id = :'hold_race_id'::uuid),
  'captured_checkout',
  'the hold status from the winning path (checkout) is preserved, not overwritten'
);

-- === authorization: same rule as appointment status changes (owner/admin/manager/reception) ===
SELECT pg_temp.mk_user('professional1@test.local') AS professional_user1 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'professional_user1'::uuid, 'professional');
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-20 12:00+00', '2026-08-20 12:30+00', 'no_show', :'owner1'::uuid)
  RETURNING id AS appt_auth \gset
SELECT throws_ok(
  format('select public.no_show_settlement_create(%L, %L, %L)', :'org1', :'professional_user1', :'appt_auth'),
  '42501',
  NULL,
  'professional_user1 cannot settle a no-show (same write role as appointment status changes, not a new surface)'
);

-- === no active hold at all (service never had a deposit policy): no-op ===
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte Sem Depósito', 4000, 20, :'group1'::uuid) RETURNING id AS service_no_deposit \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service_no_deposit'::uuid, '2026-08-20 13:00+00', '2026-08-20 13:30+00', 'no_show', :'owner1'::uuid)
  RETURNING id AS appt_no_hold \gset
SELECT public.no_show_settlement_create(:'org1'::uuid, :'owner1'::uuid, :'appt_no_hold'::uuid) AS result_no_hold \gset
SELECT is(
  (:'result_no_hold'::jsonb ->> 'status'),
  'skipped',
  'an appointment whose service never had a deposit policy settles as a no-op, no order created'
);

-- === precondition: appointment must already be marked no_show ===
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-20 14:00+00', '2026-08-20 14:30+00', 'scheduled', :'owner1'::uuid)
  RETURNING id AS appt_not_no_show \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_not_no_show'::uuid) AS hold_result_not_no_show \gset
SELECT throws_ok(
  format('select public.no_show_settlement_create(%L, %L, %L)', :'org1', :'owner1', :'appt_not_no_show'),
  'P0001',
  NULL,
  'settlement is rejected when the appointment is not (yet) marked no_show'
);

-- === commission comes from the deposit_hold snapshot, never from a
-- professional_service_commissions override (nunca resolve_commission()) ===
INSERT INTO public.professional_service_commissions (organization_id, professional_id, service_id, commission_type, commission_value)
  VALUES (:'org1'::uuid, :'prof1'::uuid, :'service1'::uuid, 'percentage', 9999);
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid, '2026-08-20 15:00+00', '2026-08-20 15:30+00', 'no_show', :'owner1'::uuid)
  RETURNING id AS appt_override \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_override'::uuid) AS hold_result_override \gset
SELECT public.no_show_settlement_create(:'org1'::uuid, :'owner1'::uuid, :'appt_override'::uuid) AS result_override \gset
SELECT is(
  ((:'result_override'::jsonb ->> 'commission_cents')::bigint),
  1500::bigint,
  'a professional_service_commissions override (9999bp) is ignored — commission still comes from the no_show snapshot (3000bp), never resolve_commission()'
);

SELECT * FROM finish();
ROLLBACK;
