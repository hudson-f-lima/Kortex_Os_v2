-- Onda 1 remediation, fatia 2: checkout de agendamento é uma relação
-- persistida e fail-closed, não uma alegação opcional no payload.
BEGIN;
SELECT plan(7);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner-checkout-binding@test.local') AS owner_id \gset
SELECT (public.create_organization(:'owner_id'::uuid, 'Org Checkout Binding', 'org-checkout-binding')).id AS org_id \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org_id'::uuid AND is_default) AS unit_id \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
VALUES (:'org_id'::uuid, 'Grupo', 'percentage', 1000) RETURNING id AS group_id \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_mechanic, deposit_type, deposit_value)
VALUES (:'org_id'::uuid, 'Serviço', 10000, 30, :'group_id'::uuid, 'hold', 'fixed', 3000) RETURNING id AS service_id \gset
INSERT INTO public.professionals (organization_id, name)
VALUES (:'org_id'::uuid, 'Profissional A') RETURNING id AS professional_a \gset
INSERT INTO public.professionals (organization_id, name)
VALUES (:'org_id'::uuid, 'Profissional B') RETURNING id AS professional_b \gset
INSERT INTO public.clients (organization_id, name, created_by)
VALUES (:'org_id'::uuid, 'Cliente', :'owner_id'::uuid) RETURNING id AS client_id \gset
INSERT INTO public.appointments (
  organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by
) VALUES (
  :'org_id'::uuid, :'unit_id'::uuid, :'client_id'::uuid, :'professional_a'::uuid, :'service_id'::uuid,
  '2026-08-10 10:00+00', '2026-08-10 10:30+00', 'in_service', :'owner_id'::uuid
) RETURNING id AS appointment_id \gset
SELECT public.deposit_hold_create(:'org_id'::uuid, :'owner_id'::uuid, :'appointment_id'::uuid);

SELECT public.checkout_close_appointment(
  :'org_id'::uuid,
  :'owner_id'::uuid,
  'appointment-binding-legitimate-001',
  :'appointment_id'::uuid,
  jsonb_build_object(
    'items', jsonb_build_array(jsonb_build_object('kind', 'service', 'id', :'service_id', 'quantity', 1, 'professional_id', :'professional_a')),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 7000))
  )
) AS checkout_result \gset
SELECT (:'checkout_result'::jsonb ->> 'order_id') AS order_id \gset

SELECT is(
  (SELECT appointment_id FROM public.orders WHERE id = :'order_id'::uuid),
  :'appointment_id'::uuid,
  'the order persists the server-owned appointment occurrence'
);
SELECT ok(
  (SELECT deposit_hold_id FROM public.orders WHERE id = :'order_id'::uuid) IS NOT NULL,
  'the order persists the captured deposit hold'
);
SELECT is(
  (SELECT unit_id FROM public.orders WHERE id = :'order_id'::uuid),
  :'unit_id'::uuid,
  'the order unit is the appointment unit, not client input'
);
SELECT is(
  (SELECT status FROM public.deposit_holds WHERE appointment_id = :'appointment_id'::uuid),
  'captured_checkout',
  'the legitimate occurrence captures its own hold exactly once'
);

INSERT INTO public.appointments (
  organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by
) VALUES (
  :'org_id'::uuid, :'unit_id'::uuid, :'client_id'::uuid, :'professional_a'::uuid, :'service_id'::uuid,
  '2026-08-11 10:00+00', '2026-08-11 10:30+00', 'in_service', :'owner_id'::uuid
) RETURNING id AS mismatch_appointment_id \gset
SELECT public.deposit_hold_create(:'org_id'::uuid, :'owner_id'::uuid, :'mismatch_appointment_id'::uuid);

SELECT throws_ok(
  format(
    $sql$select public.checkout_close_appointment(%L, %L, 'appointment-binding-professional-mismatch-001', %L, jsonb_build_object('items', jsonb_build_array(jsonb_build_object('kind', 'service', 'id', %L, 'quantity', 1, 'professional_id', %L)), 'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 10000))))$sql$,
    :'org_id', :'owner_id', :'mismatch_appointment_id', :'service_id', :'professional_b'
  ),
  'P0010',
  NULL,
  'a professional mismatch fails even when client payment covers the full total'
);
SELECT is(
  (SELECT status FROM public.deposit_holds WHERE appointment_id = :'mismatch_appointment_id'::uuid),
  'active',
  'a failed mismatch rolls back without capturing the hold'
);
SELECT is(
  (SELECT count(*) FROM public.orders WHERE appointment_id = :'mismatch_appointment_id'::uuid),
  0::bigint,
  'a failed mismatch leaves no financial order behind'
);

SELECT * FROM finish();
ROLLBACK;
