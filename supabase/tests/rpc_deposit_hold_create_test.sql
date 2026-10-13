-- Onda 1, fatia 003 (issues/003-deposit-holds-creation.md): deposit_hold_create
-- RPC — snapshot da política de depósito do serviço, mecânica hold vs
-- immediate_charge, no-op quando o serviço não tem política, índice único
-- parcial (um hold ativo por agendamento) e RLS.
BEGIN;
SELECT plan(18);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Deposit Hold', 'org-deposit-hold')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4000) RETURNING id AS group1 \gset
INSERT INTO public.services (
  organization_id, name, price_cents, duration_minutes, service_group_id,
  deposit_mechanic, deposit_type, deposit_value, no_show_commission_type, no_show_commission_value
) VALUES (
  :'org1'::uuid, 'Corte Com Depósito', 20000, 30, :'group1'::uuid,
  'hold', 'percentage', 2000, 'fixed', 1500
) RETURNING id AS service_with_deposit \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof Um') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid)
  RETURNING id AS client1 \gset

INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service_with_deposit'::uuid, '2026-08-10 10:00+00', '2026-08-10 10:30+00', :'owner1'::uuid)
  RETURNING id AS appt_with_deposit \gset

SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_with_deposit'::uuid) AS result \gset
SELECT is(
  (:'result'::jsonb ->> 'status'),
  'created',
  'deposit_hold_create returns status=created for a service with a full deposit policy'
);

-- 20000 cents * 2000 basis points / 10000 = 4000 cents (§2.1: deposit_value
-- em basis points quando deposit_type = percentage).
SELECT is(
  (SELECT amount_cents FROM public.deposit_holds WHERE appointment_id = :'appt_with_deposit'::uuid),
  4000::bigint,
  'amount_cents is computed from price_cents * deposit_value (basis points) for a percentage deposit_type'
);
SELECT is(
  (SELECT mechanic FROM public.deposit_holds WHERE appointment_id = :'appt_with_deposit'::uuid),
  'hold',
  'mechanic is snapshotted from the service deposit_mechanic'
);
SELECT ok(
  (SELECT expires_at FROM public.deposit_holds WHERE appointment_id = :'appt_with_deposit'::uuid) IS NOT NULL,
  'expires_at is set for mechanic = hold (card network authorization window)'
);
SELECT is(
  (SELECT no_show_commission_type FROM public.deposit_holds WHERE appointment_id = :'appt_with_deposit'::uuid),
  'fixed',
  'no_show_commission_type is snapshotted from the service'
);
SELECT is(
  (SELECT no_show_commission_value FROM public.deposit_holds WHERE appointment_id = :'appt_with_deposit'::uuid),
  1500::bigint,
  'no_show_commission_value is snapshotted from the service'
);
SELECT is(
  (SELECT status FROM public.deposit_holds WHERE appointment_id = :'appt_with_deposit'::uuid),
  'active',
  'the new hold starts as active'
);

SELECT (SELECT payment_intent_id FROM public.deposit_holds WHERE appointment_id = :'appt_with_deposit'::uuid) AS intent_id \gset
SELECT is(
  (SELECT purpose FROM public.payment_intents WHERE id = :'intent_id'::uuid),
  'deposit',
  'the linked payment_intent has purpose = deposit'
);
SELECT is(
  (SELECT amount_cents FROM public.payment_intents WHERE id = :'intent_id'::uuid),
  4000::bigint,
  'the linked payment_intent has the same snapshotted amount_cents as the hold'
);

-- === immediate_charge: expires_at stays NULL (money already moved) ===
INSERT INTO public.services (
  organization_id, name, price_cents, duration_minutes, service_group_id,
  deposit_mechanic, deposit_type, deposit_value
) VALUES (
  :'org1'::uuid, 'Corte Cobrança Imediata', 10000, 30, :'group1'::uuid,
  'immediate_charge', 'fixed', 3000
) RETURNING id AS service_immediate \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service_immediate'::uuid, '2026-08-10 11:00+00', '2026-08-10 11:30+00', :'owner1'::uuid)
  RETURNING id AS appt_immediate \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_immediate'::uuid) AS result_immediate \gset
SELECT is(
  (SELECT mechanic FROM public.deposit_holds WHERE appointment_id = :'appt_immediate'::uuid),
  'immediate_charge',
  'mechanic = immediate_charge is snapshotted correctly'
);
SELECT ok(
  (SELECT expires_at FROM public.deposit_holds WHERE appointment_id = :'appt_immediate'::uuid) IS NULL,
  'expires_at stays NULL for mechanic = immediate_charge'
);
SELECT is(
  (SELECT amount_cents FROM public.deposit_holds WHERE appointment_id = :'appt_immediate'::uuid),
  3000::bigint,
  'a fixed deposit_value is copied as-is (already in cents), no percentage math applied'
);

-- === no policy on the service: no hold, no error ===
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte Sem Depósito', 8000, 30, :'group1'::uuid)
  RETURNING id AS service_no_deposit \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service_no_deposit'::uuid, '2026-08-10 12:00+00', '2026-08-10 12:30+00', :'owner1'::uuid)
  RETURNING id AS appt_no_deposit \gset
SELECT public.deposit_hold_create(:'org1'::uuid, :'owner1'::uuid, :'appt_no_deposit'::uuid) AS result_no_deposit \gset
SELECT is(
  (:'result_no_deposit'::jsonb ->> 'status'),
  'skipped',
  'deposit_hold_create returns status=skipped for a service without a deposit policy'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.deposit_holds WHERE appointment_id = :'appt_no_deposit'::uuid),
  'no deposit_hold row is created when the service has no deposit policy'
);

-- === exactly one active hold per appointment (§3.3) ===
SELECT throws_ok(
  format('select public.deposit_hold_create(%L, %L, %L)', :'org1', :'owner1', :'appt_with_deposit'),
  '23505',
  NULL,
  'a second active hold for the same appointment is rejected by the partial unique index'
);

-- === edge cases: unknown appointment, inconsistent policy ===
SELECT throws_ok(
  format('select public.deposit_hold_create(%L, %L, gen_random_uuid())', :'org1', :'owner1'),
  'P0005',
  NULL,
  'calling deposit_hold_create for a nonexistent appointment raises appointment-not-found'
);

INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_mechanic)
  VALUES (:'org1'::uuid, 'Corte Política Incompleta', 5000, 30, :'group1'::uuid, 'hold')
  RETURNING id AS service_incomplete_policy \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service_incomplete_policy'::uuid, '2026-08-10 13:00+00', '2026-08-10 13:30+00', :'owner1'::uuid)
  RETURNING id AS appt_incomplete_policy \gset
SELECT throws_ok(
  format('select public.deposit_hold_create(%L, %L, %L)', :'org1', :'owner1', :'appt_incomplete_policy'),
  'P0006',
  NULL,
  'deposit_mechanic set without deposit_type/deposit_value raises a clear error instead of a raw not-null violation'
);

-- === snapshot is frozen: changing the service policy later does not affect an existing hold ===
UPDATE public.services SET deposit_value = 9999 WHERE id = :'service_with_deposit'::uuid;
SELECT is(
  (SELECT amount_cents FROM public.deposit_holds WHERE appointment_id = :'appt_with_deposit'::uuid),
  4000::bigint,
  'changing the service deposit policy after the fact does not change an already-created hold (ADR 0011 snapshot)'
);

SELECT * FROM finish();
ROLLBACK;
