-- Onda 5, fatia 035 (issues/035-onda5-waitlist-acceptance.md). Prova o
-- Aceite: um único vencedor por onda, replay do token falha, rollback não
-- deixa appointment órfão, oferta expirada não reserva slot e isolamento de
-- tenant na aceitação. "Concorrência" aqui é provada pela mutua exclusão
-- lógica do CAS (uma sessão pgTAP é sequencial por natureza) — a mesma
-- invariante que garante que duas transações reais só possam ter uma
-- vencedora, pois a segunda sempre encontra status <> 'OFFERED' após a
-- primeira committar.
BEGIN;
SELECT plan(15);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-waitlist-accept-owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Waitlist Accept', 'org-waitlist-accept')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS sgroup1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'sgroup1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof A') RETURNING id AS profa \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Vencedor', :'owner1'::uuid) RETURNING id AS client_winner \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Perdedor', :'owner1'::uuid) RETURNING id AS client_loser \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Token Errado', :'owner1'::uuid) RETURNING id AS client_badtoken \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Colisao', :'owner1'::uuid) RETURNING id AS client_collision \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Expirado', :'owner1'::uuid) RETURNING id AS client_expired \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Decline', :'owner1'::uuid) RETURNING id AS client_decline \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Expire Job', :'owner1'::uuid) RETURNING id AS client_expirejob \gset

-- 2026-09-07 é segunda-feira (dow=1), aberta 09:00-18:00.
INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'profa'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);

-- Onda com 2 entradas (vencedora e perdedora) para o mesmo slot exato.
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wla-entry-winner-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'client_id', :'client_winner'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true)
) -> 'entry' ->> 'id')::uuid AS entry_winner \gset
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wla-entry-loser-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'client_id', :'client_loser'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true)
) -> 'entry' ->> 'id')::uuid AS entry_loser \gset

SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wla-match-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T13:00:00Z')
) AS match_response \gset

SELECT id AS offer_winner, token_hash AS offer_winner_hash
  FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_winner'::uuid \gset
SELECT id AS offer_loser FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_loser'::uuid \gset
SELECT (:'match_response'::jsonb -> 'offers') AS offers_array \gset

-- Extrai o token bruto de cada oferta da resposta do matcher (nunca do
-- banco — só o hash é persistido).
SELECT (x ->> 'token') AS token_winner FROM jsonb_array_elements(:'offers_array'::jsonb) x
  WHERE (x ->> 'waitlist_entry_id')::uuid = :'entry_winner'::uuid \gset

-- Behavior 1 (issue 035, vencedor único): aceitar a oferta da entrada
-- vencedora cria o appointment e resolve tudo em uma transação.
SELECT public.waitlist_offer_accept(
  :'org1'::uuid, :'owner1'::uuid, 'wla-accept-0001',
  jsonb_build_object('offer_id', :'offer_winner'::uuid, 'token', :'token_winner')
) AS accept_response \gset
SELECT is(
  (SELECT status FROM public.waitlist_entries WHERE id = :'entry_winner'::uuid),
  'BOOKED',
  'the winning entry becomes BOOKED'
);
SELECT is(
  (SELECT client_id FROM public.appointments WHERE id = ((:'accept_response'::jsonb -> 'appointment' ->> 'id')::uuid)),
  :'client_winner'::uuid,
  'the created appointment belongs to the winning entry''s client'
);

-- Behavior 2 (issue 035, único vencedor — a irmã perde a corrida): a onda
-- inteira resolve numa transação; a entrada perdedora volta pra ACTIVE e a
-- oferta dela vira SUPERSEDED, sem qualquer chamada própria.
SELECT is(
  (SELECT status FROM public.waitlist_entries WHERE id = :'entry_loser'::uuid),
  'ACTIVE',
  'the sibling entry returns to ACTIVE once the wave resolves — never a second BOOKED'
);
SELECT is(
  (SELECT status FROM public.waitlist_offers WHERE id = :'offer_loser'::uuid),
  'SUPERSEDED',
  'the sibling offer becomes SUPERSEDED, proving mutual exclusion within the wave'
);

-- Behavior 3: a oferta perdedora (agora SUPERSEDED) não pode ser aceita
-- separadamente — reforça que só um vencedor é possível por onda.
SELECT throws_ok(
  format(
    'select public.waitlist_offer_accept(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', ''whatever-token-does-not-matter''))',
    :'org1', :'owner1', 'wla-accept-superseded-0001', :'offer_loser'
  ),
  'P0023', 'waitlist offer is not open for a decision',
  'a superseded offer can never be separately accepted'
);

-- Behavior 4 (issue 035, replay do token falha): re-tentar aceitar a MESMA
-- oferta vencedora, já ACCEPTED, com o token correto e uma idempotency_key
-- nova, falha — o CAS por status é o que barra o replay, não só a chave.
SELECT throws_ok(
  format(
    'select public.waitlist_offer_accept(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', %L))',
    :'org1', :'owner1', 'wla-accept-replay-0001', :'offer_winner', :'token_winner'
  ),
  'P0023', 'waitlist offer is not open for a decision',
  'replaying the token on an already-accepted offer fails even with a fresh idempotency key'
);

-- Behavior 5 (token errado): entrada nova, oferta nova, token incorreto.
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wla-entry-badtoken-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'client_id', :'client_badtoken'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true)
) -> 'entry' ->> 'id')::uuid AS entry_badtoken \gset
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wla-match-badtoken-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T14:00:00Z')
);
SELECT id AS offer_badtoken FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_badtoken'::uuid \gset
SELECT throws_ok(
  format(
    'select public.waitlist_offer_accept(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', ''this-is-the-wrong-token''))',
    :'org1', :'owner1', 'wla-accept-badtoken-0001', :'offer_badtoken'
  ),
  'P0024', 'waitlist offer token does not match',
  'accepting with the wrong token is rejected'
);

-- Behavior 6 (issue 035, rollback não deixa appointment órfão): colide o
-- slot exato da oferta com um appointment já existente para o mesmo
-- profissional, então tenta aceitar — create_appointment falha, e a
-- transação inteira reverte, sem deixar a entrada travada em HOLDING nem
-- criar appointment nenhum para o cliente da onda.
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wla-entry-collision-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'client_id', :'client_collision'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true)
) -> 'entry' ->> 'id')::uuid AS entry_collision \gset
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wla-match-collision-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T15:00:00Z')
) AS match_collision_response \gset
SELECT id AS offer_collision FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_collision'::uuid \gset
-- Filtra por waitlist_entry_id: entry_expired (Behavior 7, criada mais
-- adiante) ainda não existe aqui, mas outras entradas ACTIVE sem
-- preferência da mesma unit/service podem compor a mesma onda — não dá
-- para assumir que 'offers' tem exatamente 1 elemento.
SELECT (x ->> 'token') AS token_collision
  FROM jsonb_array_elements(:'match_collision_response'::jsonb -> 'offers') x
  WHERE (x ->> 'waitlist_entry_id')::uuid = :'entry_collision'::uuid \gset

INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by, unit_id)
  VALUES (:'org1'::uuid, :'client_loser'::uuid, :'profa'::uuid, :'service1'::uuid, '2026-09-07T15:00:00Z', '2026-09-07T15:30:00Z', :'owner1'::uuid, :'unit1'::uuid);

SELECT throws_ok(
  format(
    'select public.waitlist_offer_accept(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', %L))',
    :'org1', :'owner1', 'wla-accept-collision-0001', :'offer_collision', :'token_collision'
  ),
  '23P01',
  NULL,
  'a slot collision inside acceptance aborts the whole transaction'
);
SELECT is(
  (SELECT status FROM public.waitlist_offers WHERE id = :'offer_collision'::uuid),
  'OFFERED',
  'the offer is untouched after a rolled-back acceptance — no stuck HOLDING'
);
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE client_id = :'client_collision'::uuid),
  0::bigint,
  'no orphaned appointment is left behind after the rollback'
);

-- Behavior 7 (issue 035, oferta expirada não reserva slot): oferta cujo
-- expires_at já passou não pode ser aceita, mesmo com token correto.
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'x', :'owner1'::uuid) RETURNING id AS dummy_client \gset
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wla-entry-expired-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'client_id', :'client_expired'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true)
) -> 'entry' ->> 'id')::uuid AS entry_expired \gset
INSERT INTO public.waitlist_offers (
  organization_id, unit_id, waitlist_entry_id, offer_wave_id, candidate_starts_at, candidate_ends_at,
  candidate_professional_id, token_hash, expires_at, cooldown_until, idempotency_key
) VALUES (
  :'org1'::uuid, :'unit1'::uuid, :'entry_expired'::uuid, gen_random_uuid(), '2026-09-07T16:00:00Z', '2026-09-07T16:30:00Z',
  :'profa'::uuid, encode(digest('expired-raw-token', 'sha256'), 'hex'), now() - interval '1 minute', now() + interval '6 hours',
  'wla-expired-offer-fixture-0001'
) RETURNING id AS offer_expired \gset
SELECT throws_ok(
  format(
    'select public.waitlist_offer_accept(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', ''expired-raw-token''))',
    :'org1', :'owner1', 'wla-accept-expired-0001', :'offer_expired'
  ),
  'P0023', 'waitlist offer is not open for a decision',
  'an offer past its expires_at can never book the slot, even with the correct token'
);

-- Behavior 8 (waitlist_offer_decline): recusa explícita devolve a entrada
-- para ACTIVE com cooldown.
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wla-entry-decline-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'client_id', :'client_decline'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true)
) -> 'entry' ->> 'id')::uuid AS entry_decline \gset
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wla-match-decline-0001',
  jsonb_build_object('unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T17:00:00Z')
) AS match_decline_response \gset
SELECT id AS offer_decline FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_decline'::uuid \gset
-- entry_expired (Behavior 7) segue ACTIVE e sem cooldown aqui — o próprio
-- fixture bruto nunca passou pelo matcher, então nada além do
-- waitlist_offer_expire (Behavior 9, mais adiante) muda seu status. Por
-- isso esta onda também tem 2 ofertas; filtra pela entrada certa.
SELECT (x ->> 'token') AS token_decline
  FROM jsonb_array_elements(:'match_decline_response'::jsonb -> 'offers') x
  WHERE (x ->> 'waitlist_entry_id')::uuid = :'entry_decline'::uuid \gset
SELECT public.waitlist_offer_decline(
  :'org1'::uuid, :'owner1'::uuid, 'wla-decline-0001',
  jsonb_build_object('offer_id', :'offer_decline'::uuid, 'token', :'token_decline')
);
SELECT is(
  (SELECT (status, cooldown_until is not null) FROM public.waitlist_entries WHERE id = :'entry_decline'::uuid),
  ('ACTIVE'::text, true),
  'declining an offer returns the entry to ACTIVE with a cooldown applied'
);

-- Behavior 9 (waitlist_offer_expire): só expira ofertas realmente vencidas.
SELECT throws_ok(
  format(
    'select public.waitlist_offer_expire(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid))',
    :'org1', :'owner1', 'wla-expire-early-0001', :'offer_badtoken'
  ),
  'P0023', 'waitlist offer is not open for a decision',
  'waitlist_offer_expire refuses to expire an offer that has not actually expired yet'
);
SELECT public.waitlist_offer_expire(:'org1'::uuid, :'owner1'::uuid, 'wla-expire-0001', jsonb_build_object('offer_id', :'offer_expired'::uuid));
SELECT is(
  (SELECT status FROM public.waitlist_entries WHERE id = :'entry_expired'::uuid),
  'ACTIVE',
  'expiring a truly expired offer returns its entry to ACTIVE'
);

-- Behavior 10 (issue 035, isolamento de tenant): um actor de outro tenant
-- nunca encontra (e muito menos aceita) uma oferta deste tenant.
SELECT pg_temp.mk_user('onda5-waitlist-accept-owner2@test.local') AS owner2 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Waitlist Accept Two', 'org-waitlist-accept-2')).id AS org2 \gset
SELECT throws_ok(
  format(
    'select public.waitlist_offer_accept(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', %L))',
    :'org2', :'owner2', 'wla-accept-crosstenant-0001', :'offer_badtoken', 'this-is-the-wrong-token'
  ),
  'P0002', 'waitlist offer not found',
  'an offer from another tenant is never found, let alone accepted'
);

SELECT * FROM finish();
ROLLBACK;
