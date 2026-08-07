-- Onda 1 remediation, fatia 4: a mesma entrega PSP que chegou cedo é
-- reprocessada com segurança depois que o payment_intent existe.
BEGIN;
SELECT plan(7);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner-webhook-reprocess@test.local') AS owner_id \gset
SELECT (public.create_organization(:'owner_id'::uuid, 'Org Webhook Reprocess', 'org-webhook-reprocess')).id AS org_id \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org_id'::uuid AND is_default) AS unit_id \gset

SELECT public.psp_webhook_event_ingest(
  'stub_psp',
  'evt-reprocess-001',
  'payment_intent.captured',
  'provider-ref-reprocess-001',
  'captured',
  jsonb_build_object('provider_reference', 'provider-ref-reprocess-001', 'status', 'captured')
) AS first_result \gset
SELECT is((:'first_result'::jsonb ->> 'matched')::boolean, false, 'an early event is retained as unmatched dead-letter');

INSERT INTO public.payment_intents (
  organization_id, unit_id, purpose, provider, provider_reference, amount_cents, status, created_by
) VALUES (
  :'org_id'::uuid, :'unit_id'::uuid, 'deposit', 'stub_psp', 'provider-ref-reprocess-001', 2500, 'requires_capture', :'owner_id'::uuid
) RETURNING id AS intent_id \gset

SELECT public.psp_webhook_event_ingest(
  'stub_psp',
  'evt-reprocess-001',
  'payment_intent.captured',
  'provider-ref-reprocess-001',
  'captured',
  jsonb_build_object('provider_reference', 'provider-ref-reprocess-001', 'status', 'captured')
) AS replay_result \gset
SELECT is((:'replay_result'::jsonb ->> 'matched')::boolean, true, 'replaying the same event retries a previously unmatched dead-letter');
SELECT is((SELECT payment_intent_id FROM public.psp_webhook_events WHERE provider = 'stub_psp' AND provider_event_id = 'evt-reprocess-001'), :'intent_id'::uuid, 'the event is linked to the newly available intent');
SELECT is((SELECT status FROM public.payment_intents WHERE id = :'intent_id'::uuid), 'captured', 'the intent status is updated atomically with the event');
SELECT ok((SELECT processed_at FROM public.psp_webhook_events WHERE provider = 'stub_psp' AND provider_event_id = 'evt-reprocess-001') IS NOT NULL, 'the reprocessed event is marked processed');

SELECT public.psp_webhook_event_reprocess(
  (SELECT id FROM public.psp_webhook_events WHERE provider = 'stub_psp' AND provider_event_id = 'evt-reprocess-001')
) AS manual_replay \gset
SELECT is((:'manual_replay'::jsonb ->> 'duplicate')::boolean, true, 'manual reprocess is a no-op after successful processing');
SELECT is((SELECT count(*) FROM public.psp_webhook_events WHERE provider = 'stub_psp' AND provider_event_id = 'evt-reprocess-001'), 1::bigint, 'dedup keeps exactly one durable event row');

SELECT * FROM finish();
ROLLBACK;
