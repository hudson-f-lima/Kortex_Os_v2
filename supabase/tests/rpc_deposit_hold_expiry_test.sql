-- Onda 1 remediation, fatia 5: uma autorização vencida termina como expired
-- sem gerar pedido, pagamento ou captura fictícia.
BEGIN;
SELECT plan(4);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner-expiry@test.local') AS owner_id \gset
SELECT (public.create_organization(:'owner_id'::uuid, 'Org Expiry', 'org-expiry')).id AS org_id \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org_id'::uuid AND is_default) AS unit_id \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
VALUES (:'org_id'::uuid, 'Grupo', 'percentage', 1000) RETURNING id AS group_id \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_mechanic, deposit_type, deposit_value)
VALUES (:'org_id'::uuid, 'Serviço', 10000, 30, :'group_id'::uuid, 'hold', 'fixed', 3000) RETURNING id AS service_id \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org_id'::uuid, 'Profissional') RETURNING id AS professional_id \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org_id'::uuid, 'Cliente', :'owner_id'::uuid) RETURNING id AS client_id \gset
INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
VALUES (:'org_id'::uuid, :'unit_id'::uuid, :'client_id'::uuid, :'professional_id'::uuid, :'service_id'::uuid, '2026-08-10 10:00+00', '2026-08-10 10:30+00', 'in_service', :'owner_id'::uuid)
RETURNING id AS appointment_id \gset
SELECT public.deposit_hold_create(:'org_id'::uuid, :'owner_id'::uuid, :'appointment_id'::uuid);

-- Test-only clock setup: production code cannot mutate expires_at because the
-- identity trigger guards it. The expiry path reads this provider-derived
-- timestamp under the hold lock.
ALTER TABLE public.deposit_holds DISABLE TRIGGER deposit_holds_financial_identity_guard;
UPDATE public.deposit_holds SET expires_at = now() - interval '1 second' WHERE appointment_id = :'appointment_id'::uuid;
ALTER TABLE public.deposit_holds ENABLE TRIGGER deposit_holds_financial_identity_guard;

SELECT public.checkout_close_appointment(
  :'org_id'::uuid, :'owner_id'::uuid, 'expired-checkout-001', :'appointment_id'::uuid,
  jsonb_build_object(
    'items', jsonb_build_array(jsonb_build_object('kind', 'service', 'id', :'service_id', 'quantity', 1, 'professional_id', :'professional_id')),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount_cents', 7000))
  )
) AS result \gset
SELECT is((:'result'::jsonb ->> 'status'), 'deposit_expired', 'checkout reports a persisted expired hold instead of attempting capture');
SELECT is((SELECT status FROM public.deposit_holds WHERE appointment_id = :'appointment_id'::uuid), 'expired', 'expired hold reaches its terminal state');
SELECT is((SELECT pi.status FROM public.payment_intents pi JOIN public.deposit_holds dh ON dh.payment_intent_id = pi.id WHERE dh.appointment_id = :'appointment_id'::uuid), 'canceled', 'expired authorization cancels its local intent');
SELECT is((SELECT count(*) FROM public.orders WHERE appointment_id = :'appointment_id'::uuid), 0::bigint, 'expired checkout creates no financial order');

SELECT * FROM finish();
ROLLBACK;
