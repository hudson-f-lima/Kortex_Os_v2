-- Red Team pós-merge (DEC-36): checkout_close reconciliava um deposit_hold
-- validando só organization_id + appointment_id — nada ligava o
-- appointment_id do payload ao cliente/serviço do checkout que estava de
-- fato sendo fechado. Um checkout com itens de QUALQUER natureza, desde
-- que acompanhado do appointment_id de OUTRO agendamento com hold ativo
-- (outro cliente, outro serviço), capturava esse hold e aplicava seu valor
-- ao pedido não relacionado.
BEGIN;
SELECT plan(4);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Guard', 'org-guard')).id AS org1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4000) RETURNING id AS group1 \gset

-- service_a: has a deposit policy, booked by client_a.
INSERT INTO public.services (
  organization_id, name, price_cents, duration_minutes, service_group_id,
  deposit_mechanic, deposit_type, deposit_value
) VALUES (
  :'org1'::uuid, 'Corte Com Depósito', 20000, 30, :'group1'::uuid, 'hold', 'fixed', 5000
) RETURNING id AS service_a \gset

-- service_b: unrelated service, booked/checked out by client_b — no deposit policy at all.
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Manicure', 3000, 20, :'group1'::uuid) RETURNING id AS service_b \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof Um') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente A', :'owner1'::uuid)
  RETURNING id AS client_a \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente B', :'owner1'::uuid)
  RETURNING id AS client_b \gset

-- appointment_a: client_a books service_a, gets an active deposit hold.
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client_a'::uuid, :'prof1'::uuid, :'service_a'::uuid, '2026-09-01 10:00+00', '2026-09-01 10:30+00', :'owner1'::uuid)
  RETURNING id AS appointment_a \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appointment_a'::uuid) AS hold_result \gset
SELECT (SELECT id FROM public.deposit_holds WHERE appointment_id = :'appointment_a'::uuid) AS hold_a_id \gset

-- The exploit: checkout for client_b buying service_b (totally unrelated to
-- appointment_a, price 3000 <= the mismatched hold's 5000), paying NOTHING
-- out of pocket — relying entirely on the mismatched deposit_hold to
-- silently cover the order via the bug. With the guard in place, the
-- reconciliation simply doesn't apply (mismatch), so v_paid stays 0 while
-- v_total is 3000 — the checkout fails loudly on the pre-existing
-- reconciliation check, exactly as it would for anyone forgetting to pay.
SELECT throws_ok(
  format(
    $sql$select public.checkout_close(%L, %L, 'guard-test-mismatch-001', jsonb_build_object(
      'client_id', %L,
      'appointment_id', %L,
      'items', jsonb_build_array(jsonb_build_object('kind', 'service', 'id', %L, 'quantity', 1, 'professional_id', %L)),
      'payments', jsonb_build_array()
    ))$sql$,
    :'org1', :'owner1', :'client_b', :'appointment_a', :'service_b', :'prof1'
  ),
  '22023',
  'payments do not reconcile with order total',
  'a checkout for an unrelated client/service does not silently borrow another appointment''s deposit — it just fails to reconcile, same as forgetting to pay'
);
SELECT is(
  (SELECT status FROM public.deposit_holds WHERE id = :'hold_a_id'::uuid),
  'active',
  'the unrelated appointment''s hold is untouched after the failed mismatched attempt'
);

-- Sanity check: the SAME appointment_id, with a checkout that DOES belong
-- to that client and includes that service, still reconciles correctly.
SELECT public.checkout_close(
  :'org1'::uuid,
  :'owner1'::uuid,
  'guard-test-legit-001',
  jsonb_build_object(
    'client_id', :'client_a',
    'appointment_id', :'appointment_a',
    'items', jsonb_build_array(
      jsonb_build_object('kind', 'service', 'id', :'service_a', 'quantity', 1, 'professional_id', :'prof1')
    ),
    'payments', jsonb_build_array(
      jsonb_build_object('method', 'cash', 'amount_cents', 15000)
    )
  )
) AS legit_result \gset

SELECT is(
  (SELECT status FROM public.deposit_holds WHERE id = :'hold_a_id'::uuid),
  'captured_checkout',
  'a legitimate checkout (matching client and service) still captures its own appointment''s hold'
);
SELECT is(
  ((:'legit_result'::jsonb ->> 'total_cents')::bigint),
  20000::bigint,
  'the legitimate order total is unaffected by the guard (20000 = 15000 cash + 5000 deposit)'
);

SELECT * FROM finish();
ROLLBACK;
