-- Onda 1 remediation, fatia 3: status de appointment e dinheiro transitam
-- juntos. Cancelar libera hold; no_show liquida uma única ocorrência.
BEGIN;
SELECT plan(7);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner-lifecycle@test.local') AS owner_id \gset
SELECT (public.create_organization(:'owner_id'::uuid, 'Org Lifecycle', 'org-lifecycle')).id AS org_id \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org_id'::uuid AND is_default) AS unit_id \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
VALUES (:'org_id'::uuid, 'Grupo', 'percentage', 1000) RETURNING id AS group_id \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_mechanic, deposit_type, deposit_value)
VALUES (:'org_id'::uuid, 'Serviço hold', 10000, 30, :'group_id'::uuid, 'hold', 'fixed', 3000) RETURNING id AS hold_service \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_mechanic, deposit_type, deposit_value)
VALUES (:'org_id'::uuid, 'Serviço charge', 10000, 30, :'group_id'::uuid, 'immediate_charge', 'fixed', 3000) RETURNING id AS immediate_service \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org_id'::uuid, 'Profissional') RETURNING id AS professional_id \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org_id'::uuid, 'Cliente', :'owner_id'::uuid) RETURNING id AS client_id \gset

-- Cancellation releases a hold authorization and cancels its local intent.
INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
VALUES (:'org_id'::uuid, :'unit_id'::uuid, :'client_id'::uuid, :'professional_id'::uuid, :'hold_service'::uuid, '2026-08-10 10:00+00', '2026-08-10 10:30+00', :'owner_id'::uuid)
RETURNING id AS cancel_appointment \gset
SELECT public.deposit_hold_create(:'org_id'::uuid, :'owner_id'::uuid, :'cancel_appointment'::uuid);
UPDATE public.appointments SET status = 'cancelled' WHERE id = :'cancel_appointment'::uuid;
SELECT is((SELECT status FROM public.deposit_holds WHERE appointment_id = :'cancel_appointment'::uuid), 'released', 'cancelling an appointment releases an active hold');
SELECT is((SELECT pi.status FROM public.payment_intents pi JOIN public.deposit_holds dh ON dh.payment_intent_id = pi.id WHERE dh.appointment_id = :'cancel_appointment'::uuid), 'canceled', 'cancelling a hold also cancels its intent');

-- An immediate charge cannot masquerade as a released authorization.
INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
VALUES (:'org_id'::uuid, :'unit_id'::uuid, :'client_id'::uuid, :'professional_id'::uuid, :'immediate_service'::uuid, '2026-08-10 11:00+00', '2026-08-10 11:30+00', :'owner_id'::uuid)
RETURNING id AS immediate_appointment \gset
SELECT public.deposit_hold_create(:'org_id'::uuid, :'owner_id'::uuid, :'immediate_appointment'::uuid);
SELECT throws_ok(
  format($sql$update public.appointments set status = 'cancelled' where id = %L$sql$, :'immediate_appointment'),
  'P0008',
  NULL,
  'cancelling immediate_charge is blocked until a real refund command exists'
);
SELECT is((SELECT status FROM public.appointments WHERE id = :'immediate_appointment'::uuid), 'scheduled', 'the blocked immediate-charge cancellation leaves the appointment unchanged');

-- No-show creates exactly one financial order attached to the same occurrence.
INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
VALUES (:'org_id'::uuid, :'unit_id'::uuid, :'client_id'::uuid, :'professional_id'::uuid, :'hold_service'::uuid, '2026-08-10 12:00+00', '2026-08-10 12:30+00', :'owner_id'::uuid)
RETURNING id AS no_show_appointment \gset
SELECT public.deposit_hold_create(:'org_id'::uuid, :'owner_id'::uuid, :'no_show_appointment'::uuid);
UPDATE public.appointments SET status = 'no_show' WHERE id = :'no_show_appointment'::uuid;
SELECT is((SELECT status FROM public.deposit_holds WHERE appointment_id = :'no_show_appointment'::uuid), 'captured_no_show', 'no_show captures its own active hold');
SELECT is((SELECT count(*) FROM public.orders WHERE appointment_id = :'no_show_appointment'::uuid), 1::bigint, 'no_show creates exactly one linked financial order');
SELECT is((SELECT deposit_hold_id FROM public.orders WHERE appointment_id = :'no_show_appointment'::uuid), (SELECT id FROM public.deposit_holds WHERE appointment_id = :'no_show_appointment'::uuid), 'no_show order records the hold that funded it');

SELECT * FROM finish();
ROLLBACK;
