-- Onda 5, fatia 039 (issues/039-onda5-waitlist-offer-client-identity.md).
-- A capacidade da oferta só vale em conjunto com a sessão autenticada do
-- AppCliente vinculada ao mesmo cliente no tenant. Push é um outbox
-- transacional; a inbox é o fallback quando não há dispositivo registrado.
BEGIN;
SELECT plan(12);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-client-identity-owner@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('onda5-client-identity-app-winner@test.local') AS app_winner \gset
SELECT pg_temp.mk_user('onda5-client-identity-app-other@test.local') AS app_other \gset
SELECT pg_temp.mk_user('onda5-client-identity-app-unlinked@test.local') AS app_unlinked \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Client Identity', 'org-client-identity')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof A') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente vencedor', :'owner1'::uuid) RETURNING id AS client_winner \gset
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente outro', :'owner1'::uuid) RETURNING id AS client_other \gset
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente sem device', :'owner1'::uuid) RETURNING id AS client_inbox \gset

INSERT INTO public.client_app_identities (organization_id, client_id, user_id)
VALUES
  (:'org1'::uuid, :'client_winner'::uuid, :'app_winner'::uuid),
  (:'org1'::uuid, :'client_other'::uuid, :'app_other'::uuid);

SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.client_push_devices'::regclass),
  'client push devices is protected by RLS'
);

INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'prof1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);

SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wlc-entry-winner-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'client_id', :'client_winner'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true)
) -> 'entry' ->> 'id')::uuid AS entry_winner \gset

-- Um JWT sem vínculo não pode nem registrar um device nem consultar/aceitar.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'app_unlinked', true);
SELECT throws_ok(
  format('select public.client_push_device_register(%L::uuid, %L, %L)', :'org1', 'fcm-unlinked-device-token', 'android'),
  '42501', 'client identity not found',
  'an authenticated but unlinked AppCliente account cannot register a device'
);
RESET ROLE;

-- Só o cliente mapeado pode associar um token FCM ao seu próprio vínculo.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'app_winner', true);
SELECT lives_ok(
  format('select public.client_push_device_register(%L::uuid, %L, %L)', :'org1', 'fcm-winner-device-token', 'android'),
  'the mapped client registers its own FCM device'
);
RESET ROLE;
SELECT is(
  (SELECT user_id FROM public.client_push_devices WHERE organization_id = :'org1'::uuid AND fcm_token = 'fcm-winner-device-token'),
  :'app_winner'::uuid,
  'the registered FCM token is bound to its authenticated client user'
);

SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wlc-match-winner-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T13:00:00Z')
) AS match_winner \gset
SELECT id AS offer_winner FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_winner'::uuid \gset
SELECT (x ->> 'token') AS token_winner
FROM jsonb_array_elements(:'match_winner'::jsonb -> 'offers') x
WHERE (x ->> 'waitlist_entry_id')::uuid = :'entry_winner'::uuid \gset

SELECT is(
  (SELECT count(*) FROM private.waitlist_offer_push_outbox WHERE offer_id = :'offer_winner'::uuid),
  1::bigint,
  'the committed offer creates one FCM outbox record for its registered device'
);
SELECT is(
  (SELECT client_user_id FROM private.waitlist_offer_push_outbox WHERE offer_id = :'offer_winner'::uuid),
  :'app_winner'::uuid,
  'the push outbox is addressed only to the offer owner identity'
);

-- Outra identidade do mesmo tenant não ganha acesso mesmo de posse do token.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'app_other', true);
SELECT throws_ok(
  format('select public.waitlist_offer_accept_client(%L::uuid, %L, %L)', :'offer_winner', 'wlc-accept-other-0001', :'token_winner'),
  'P0002', 'waitlist offer not found',
  'a different linked client cannot accept another client''s offer with a valid token'
);
RESET ROLE;

-- O mesmo cliente autenticado e com a capacidade correta vence uma única vez.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'app_winner', true);
SELECT lives_ok(
  format('select public.waitlist_offer_accept_client(%L::uuid, %L, %L)', :'offer_winner', 'wlc-accept-winner-0001', :'token_winner'),
  'the mapped client accepts its own offer with its opaque capability'
);
RESET ROLE;
SELECT is(
  (SELECT (we.status, a.client_booking_user_id)
   FROM public.waitlist_entries we
   JOIN public.appointments a ON a.organization_id = we.organization_id AND a.client_id = we.client_id
   WHERE we.id = :'entry_winner'::uuid),
  ('BOOKED'::text, :'app_winner'::uuid),
  'client-facing acceptance keeps the canonical state and records the linked AppCliente user'
);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'app_winner', true);
SELECT throws_ok(
  format('select public.waitlist_offer_accept_client(%L::uuid, %L, %L)', :'offer_winner', 'wlc-accept-replay-0001', :'token_winner'),
  'P0023', 'waitlist offer is not open for a decision',
  'replaying a consumed client offer fails under the existing CAS'
);
RESET ROLE;

-- Sem device, a oferta continua acessível pela inbox autenticada (fallback).
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wlc-entry-inbox-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'client_id', :'client_inbox'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true)
) -> 'entry' ->> 'id')::uuid AS entry_inbox \gset
INSERT INTO public.client_app_identities (organization_id, client_id, user_id)
  VALUES (:'org1'::uuid, :'client_inbox'::uuid, :'app_unlinked'::uuid);
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wlc-match-inbox-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T14:00:00Z')
) AS match_inbox \gset
SELECT id AS offer_inbox FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_inbox'::uuid \gset
SELECT is(
  (SELECT count(*) FROM private.waitlist_offer_push_outbox WHERE offer_id = :'offer_inbox'::uuid),
  0::bigint,
  'an offer without a registered device does not create a failed push job'
);
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', :'app_unlinked', true);
SELECT (public.client_waitlist_offer_inbox(:'org1'::uuid) -> 'offers') AS inbox_offers \gset
SELECT ok(
  exists(select 1 from jsonb_array_elements(:'inbox_offers'::jsonb) x where (x ->> 'offer_id')::uuid = :'offer_inbox'::uuid and nullif(x ->> 'token', '') is not null),
  'the authenticated client inbox exposes its still-valid offer and a fresh opaque capability'
);
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
