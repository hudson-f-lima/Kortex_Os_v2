-- Onda 1 remediation, fatia 3: replan é o único caminho que pode trocar a
-- identidade de uma ocorrência com hold ativo, liberando e reemitindo tudo
-- dentro da mesma transação idempotente.
BEGIN;
SELECT plan(5);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner-replan@test.local') AS owner_id \gset
SELECT (public.create_organization(:'owner_id'::uuid, 'Org Replan', 'org-replan')).id AS org_id \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
VALUES (:'org_id'::uuid, 'Grupo', 'percentage', 1000) RETURNING id AS group_id \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_mechanic, deposit_type, deposit_value)
VALUES (:'org_id'::uuid, 'Serviço', 10000, 30, :'group_id'::uuid, 'hold', 'fixed', 2000) RETURNING id AS service_id \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org_id'::uuid, 'Profissional') RETURNING id AS professional_id \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org_id'::uuid, 'Cliente original', :'owner_id'::uuid) RETURNING id AS client_a \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org_id'::uuid, 'Cliente novo', :'owner_id'::uuid) RETURNING id AS client_b \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
VALUES (:'org_id'::uuid, :'client_a'::uuid, :'professional_id'::uuid, :'service_id'::uuid, '2026-08-10 10:00+00', '2026-08-10 10:30+00', :'owner_id'::uuid)
RETURNING id AS appointment_id \gset
SELECT public.deposit_hold_create(:'org_id'::uuid, :'owner_id'::uuid, :'appointment_id'::uuid);
SELECT (SELECT id FROM public.deposit_holds WHERE appointment_id = :'appointment_id'::uuid) AS old_hold_id \gset

SELECT public.appointment_replan_with_hold(
  :'org_id'::uuid,
  :'owner_id'::uuid,
  'replan-hold-001',
  :'appointment_id'::uuid,
  jsonb_build_object('client_id', :'client_b', 'version', 1)
) AS replan_result \gset

SELECT is((SELECT client_id FROM public.appointments WHERE id = :'appointment_id'::uuid), :'client_b'::uuid, 'replan changes the appointment client');
SELECT is((SELECT status FROM public.deposit_holds WHERE id = :'old_hold_id'::uuid), 'released', 'replan releases the old hold');
SELECT is((SELECT count(*) FROM public.deposit_holds WHERE appointment_id = :'appointment_id'::uuid AND status = 'active'), 1::bigint, 'replan creates exactly one new active hold');
SELECT is((SELECT client_id FROM public.deposit_holds WHERE appointment_id = :'appointment_id'::uuid AND status = 'active'), :'client_b'::uuid, 'the new hold snapshots the new client identity');
SELECT is(
  public.appointment_replan_with_hold(
    :'org_id'::uuid, :'owner_id'::uuid, 'replan-hold-001', :'appointment_id'::uuid,
    jsonb_build_object('client_id', :'client_b', 'version', 1)
  ) ->> 'status',
  'applied',
  'replaying the same replan idempotency key does not create another hold'
);

SELECT * FROM finish();
ROLLBACK;
