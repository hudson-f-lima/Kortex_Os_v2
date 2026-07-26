-- Onda 1, fatia 002 (issues/002-payment-intents-webhook-outbox.md):
-- uniqueness/dead-letter invariants of payment_intents/psp_webhook_events,
-- grant lockdown, and RLS isolation (org-wide vs unit-scoped, cross-tenant,
-- cross-unit) for payment_intents.
BEGIN;
SELECT plan(18);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

CREATE FUNCTION pg_temp.login_as(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  SET LOCAL role authenticated;
END;
$$;

CREATE FUNCTION pg_temp.logout() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  RESET role;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('professional1@test.local') AS professional_user1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org Payment', 'org-payment')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Payment Two', 'org-payment-two')).id AS org2 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.units (organization_id, name, timezone) VALUES (:'org1'::uuid, 'Filial Dois', 'America/Sao_Paulo')
  RETURNING id AS unit2 \gset

INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid),
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null),
  (:'org1'::uuid, :'professional_user1'::uuid, 'professional', :'unit1'::uuid);

INSERT INTO public.payment_intents (organization_id, unit_id, purpose, provider, provider_reference, amount_cents)
  VALUES (:'org1'::uuid, :'unit1'::uuid, 'deposit', 'stub_psp', 'pi_ext_unit1', 2000)
  RETURNING id AS intent_unit1 \gset
INSERT INTO public.payment_intents (organization_id, unit_id, purpose, provider, provider_reference, amount_cents)
  VALUES (:'org1'::uuid, :'unit2'::uuid, 'deposit', 'stub_psp', 'pi_ext_unit2', 3000)
  RETURNING id AS intent_unit2 \gset

-- === schema-level invariants ===
SELECT throws_ok(
  format(
    $sql$insert into public.payment_intents (organization_id, unit_id, purpose, provider, provider_reference, amount_cents)
    values (%L, %L, 'deposit', 'stub_psp', 'pi_ext_unit1', 500)$sql$,
    :'org1', :'unit1'
  ),
  '23505',
  NULL,
  'a second payment_intent with the same (organization_id, provider, provider_reference) is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.payment_intents (organization_id, unit_id, purpose, provider, provider_reference, amount_cents, status)
    values (%L, %L, 'deposit', 'stub_psp', 'pi_ext_bad_status', 500, 'paid')$sql$,
    :'org1', :'unit1'
  ),
  '23514',
  NULL,
  'an invalid payment_intents.status is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.payment_intents (organization_id, unit_id, purpose, provider, provider_reference, amount_cents)
    values (%L, %L, 'refund', 'stub_psp', 'pi_ext_bad_purpose', 500)$sql$,
    :'org1', :'unit1'
  ),
  '23514',
  NULL,
  'an invalid payment_intents.purpose is rejected'
);

INSERT INTO public.psp_webhook_events (provider, provider_event_id, event_type, payload)
  VALUES ('stub_psp', 'evt_dup', 'payment_intent.captured', '{}'::jsonb);
SELECT throws_ok(
  $sql$insert into public.psp_webhook_events (provider, provider_event_id, event_type, payload)
  values ('stub_psp', 'evt_dup', 'payment_intent.captured', '{}'::jsonb)$sql$,
  '23505',
  NULL,
  'a second psp_webhook_events row with the same (provider, provider_event_id) is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.psp_webhook_events (organization_id, unit_id, payment_intent_id, provider, provider_event_id, event_type, payload)
    values (%L, null, null, 'stub_psp', 'evt_partial', 'payment_intent.captured', '{}'::jsonb)$sql$,
    :'org1'
  ),
  '23514',
  NULL,
  'organization_id set without unit_id/payment_intent_id (partial dead-letter) is rejected'
);
SELECT lives_ok(
  $sql$insert into public.psp_webhook_events (provider, provider_event_id, event_type, payload)
  values ('stub_psp', 'evt_deadletter', 'payment_intent.captured', '{}'::jsonb)$sql$,
  'a full dead-letter (organization_id/unit_id/payment_intent_id all NULL) is accepted'
);
SELECT lives_ok(
  format(
    $sql$insert into public.psp_webhook_events (organization_id, unit_id, payment_intent_id, provider, provider_event_id, event_type, payload)
    values (%L, %L, %L, 'stub_psp', 'evt_matched', 'payment_intent.captured', '{}'::jsonb)$sql$,
    :'org1', :'unit1', :'intent_unit1'
  ),
  'a fully matched event (organization_id/unit_id/payment_intent_id all set and consistent) is accepted'
);

-- === grant lockdown ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.payment_intents', 'INSERT'),
  'authenticated has no direct INSERT grant on payment_intents'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.payment_intents', 'UPDATE'),
  'authenticated has no direct UPDATE grant on payment_intents'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.psp_webhook_events', 'SELECT'),
  'authenticated has no SELECT grant on psp_webhook_events at all — system-only data'
);
SELECT ok(
  NOT has_table_privilege('anon', 'public.psp_webhook_events', 'SELECT'),
  'anon has no SELECT grant on psp_webhook_events either'
);

-- === RLS: org-wide vs unit-scoped SELECT, cross-tenant, cross-unit ===
GRANT SELECT ON public.payment_intents TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.payment_intents WHERE id = :'intent_unit1'::uuid),
  'owner1 (org-wide role) can select a payment_intent in unit1'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.payment_intents WHERE id = :'intent_unit2'::uuid),
  'owner1 (org-wide role) can also select a payment_intent in unit2'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.payment_intents WHERE id = :'intent_unit2'::uuid),
  'manager1 (org-wide role, no unit_id on membership) can select a payment_intent in unit2'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.payment_intents WHERE id = :'intent_unit1'::uuid),
  'reception1 (scoped to unit1) can select a payment_intent in unit1'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.payment_intents WHERE id = :'intent_unit2'::uuid),
  'reception1 (scoped to unit1) cannot select a payment_intent in unit2 (cross-unit)'
);

SELECT pg_temp.login_as(:'professional_user1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.payment_intents WHERE id = :'intent_unit1'::uuid),
  'professional1 (scoped to unit1) can select a payment_intent in unit1'
);

SELECT pg_temp.login_as(:'owner2'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.payment_intents WHERE organization_id = :'org1'::uuid),
  'owner2 (org2) cannot see any payment_intent from org1 (cross-tenant)'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
