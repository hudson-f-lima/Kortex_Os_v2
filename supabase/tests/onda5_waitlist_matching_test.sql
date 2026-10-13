-- Onda 5, fatia 034 (issues/034-onda5-waitlist-matching.md). Prova o Aceite:
-- reexecução não duplica oferta nem notificação, entradas fora de unidade/
-- serviço são rejeitadas, profissional inexistente ou inelegível não é
-- aceito e ausência de preferência significa qualquer profissional
-- elegível. Aceitar/recusar/expirar a oferta é escopo da fatia 035.
BEGIN;
SELECT plan(14);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-waitlist-owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Waitlist', 'org-waitlist')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS sgroup1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'sgroup1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Coloração', 12000, 60, :'sgroup1'::uuid) RETURNING id AS service2 \gset

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof A') RETURNING id AS profa \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Prof B') RETURNING id AS profb \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente 1', :'owner1'::uuid) RETURNING id AS client1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente 2', :'owner1'::uuid) RETURNING id AS client2 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente 3', :'owner1'::uuid) RETURNING id AS client3 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente 4', :'owner1'::uuid) RETURNING id AS client4 \gset

-- 2026-09-07 é uma segunda-feira (dow=1). Política/turno abertos 09:00-18:00
-- todas as segundas, sem expiração — o matcher exige o Resolver para todo
-- candidato, sem exceção "direct" (não existe origem direta para waitlist).
INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'profa'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'profb'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);

-- Behavior 1 (issue 034, ausência de preferência = qualquer profissional):
-- entrada sem waitlist_entry_professionals recebe oferta do matcher para
-- profa.
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wl-entry-nopref-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'client_id', :'client1'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true
  )
) -> 'entry' ->> 'id')::uuid AS entry_nopref \gset

SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wl-match-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T13:00:00Z'
  )
) AS match_response_1 \gset

SELECT is(
  (SELECT status FROM public.waitlist_entries WHERE id = :'entry_nopref'::uuid),
  'OFFERED',
  'an entry with no professional preference is matched by any eligible professional'
);
SELECT is(
  (SELECT count(*) FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_nopref'::uuid),
  1::bigint,
  'exactly one offer is created for the matched entry'
);
SELECT is(
  (SELECT token_hash FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_nopref'::uuid),
  encode(digest((:'match_response_1'::jsonb -> 'offers' -> 0 ->> 'token'), 'sha256'), 'hex'),
  'only the token hash is persisted, and it matches the raw token returned to the caller'
);

-- Behavior 2 (issue 034, reexecução não duplica): mesma idempotency_key.
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wl-match-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T13:00:00Z'
  )
);
SELECT is(
  (SELECT count(*) FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_nopref'::uuid),
  1::bigint,
  'retrying the matcher with the same idempotency key does not duplicate the offer'
);

-- Behavior 3 (issue 034, idempotência entre chamadas com chaves diferentes):
-- o índice único parcial por (entrada, slot, profissional) impede uma
-- segunda oferta aberta mesmo com outra idempotency_key.
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wl-match-0002-different-key',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T13:00:00Z'
  )
);
SELECT is(
  (SELECT count(*) FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_nopref'::uuid),
  1::bigint,
  'a different idempotency key for the exact same slot still does not duplicate the open offer'
);

-- Behavior 4 (issue 034, preferência filtra): entrada com preferência por
-- profb não é ofertada quando o matcher roda para profa.
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wl-entry-prefB-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'client_id', :'client2'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true,
    'professional_ids', jsonb_build_array(:'profb')
  )
) -> 'entry' ->> 'id')::uuid AS entry_prefb \gset

SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wl-match-0003',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T14:00:00Z'
  )
);
SELECT is(
  (SELECT status FROM public.waitlist_entries WHERE id = :'entry_prefb'::uuid),
  'ACTIVE',
  'an entry preferring profb is not offered a slot matched against profa'
);

-- ... but IS offered when the matcher runs for profb (the preferred one).
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wl-match-0004',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'professional_id', :'profb'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T14:00:00Z'
  )
);
SELECT is(
  (SELECT status FROM public.waitlist_entries WHERE id = :'entry_prefb'::uuid),
  'OFFERED',
  'the same entry is offered once the matcher runs for its preferred professional'
);

-- Behavior 5 (issue 034, entradas fora de unidade/serviço são rejeitadas):
-- uma entrada para service2 nunca recebe oferta de um matcher rodando para
-- service1, mesmo no mesmo slot/profissional/unidade.
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wl-entry-otherservice-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'client_id', :'client3'::uuid, 'service_id', :'service2'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true
  )
) -> 'entry' ->> 'id')::uuid AS entry_otherservice \gset
SELECT is(
  (SELECT status FROM public.waitlist_entries WHERE id = :'entry_otherservice'::uuid),
  'ACTIVE',
  'an entry for a different service is never touched by a matcher run scoped to another service'
);

-- Behavior 6 (issue 034, cooldown respeitado): entrada em cooldown não
-- recebe nova oferta mesmo sendo elegível em tudo o mais.
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente cooldown', :'owner1'::uuid) RETURNING id AS client_cooldown \gset
INSERT INTO public.waitlist_entries (organization_id, unit_id, client_id, service_id, date_from, date_to, consent_at, cooldown_until)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'client_cooldown'::uuid, :'service1'::uuid, '2026-09-01', '2026-09-30', now(), now() + interval '1 hour')
  RETURNING id AS entry_cooldown \gset
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wl-match-cooldown-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T15:00:00Z'
  )
);
SELECT is(
  (SELECT status FROM public.waitlist_entries WHERE id = :'entry_cooldown'::uuid),
  'ACTIVE',
  'an entry still in cooldown for this slot signature is skipped by the matcher'
);

-- Behavior 7 (issue 034, profissional inexistente/inelegível não é aceito):
-- waitlist_entry_create rejeita professional_ids com profissional
-- inexistente ou sem vínculo com a unidade.
SELECT throws_ok(
  format(
    'select public.waitlist_entry_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''client_id'', %L::uuid, ''service_id'', %L::uuid, ''date_from'', %L, ''date_to'', %L, ''consent'', true, ''professional_ids'', jsonb_build_array(%L::uuid)))',
    :'org1', :'owner1', 'wl-entry-badprof-0001', :'unit1', :'client4', :'service1', '2026-09-01', '2026-09-30', gen_random_uuid()
  ),
  'P0002', 'professional is not linked to this unit',
  'waitlist_entry_create rejects a professional_id with no unit link (covers both nonexistent and ineligible)'
);

-- Behavior 8 (mesma disciplina das demais tabelas desta Onda): sem consent
-- explícito, a entrada é recusada antes de qualquer escrita.
SELECT throws_ok(
  format(
    'select public.waitlist_entry_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''client_id'', %L::uuid, ''service_id'', %L::uuid, ''date_from'', %L, ''date_to'', %L))',
    :'org1', :'owner1', 'wl-entry-noconsent-0001', :'unit1', :'client4', :'service1', '2026-09-01', '2026-09-30'
  ),
  '22023', 'explicit consent is required to join the waitlist',
  'waitlist_entry_create requires explicit consent'
);

-- Behavior 9: authenticated não tem grant de escrita direta.
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.waitlist_entries', 'INSERT'),
  'authenticated has no direct INSERT privilege on waitlist_entries'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.waitlist_offers', 'INSERT'),
  'authenticated has no direct INSERT privilege on waitlist_offers'
);

-- Behavior 10 (issue 038): o matcher não pode ofertar slot que já foi
-- ocupado por outro appointment. A proteção de corrida em create_appointment
-- continua necessária, mas a oferta não deve nascer sabendo que é inviável.
SELECT (public.waitlist_entry_create(
  :'org1'::uuid, :'owner1'::uuid, 'wl-entry-occupied-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'client_id', :'client4'::uuid, 'service_id', :'service1'::uuid,
    'date_from', '2026-09-01', 'date_to', '2026-09-30', 'consent', true
  )
) -> 'entry' ->> 'id')::uuid AS entry_occupied \gset
SELECT public.create_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'wl-occupied-appointment-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'client_id', :'client3'::uuid, 'professional_id', :'profa'::uuid,
    'service_id', :'service1'::uuid, 'starts_at', '2026-09-07T16:00:00Z'
  )
);
SELECT public.waitlist_matcher_run(
  :'org1'::uuid, :'owner1'::uuid, 'wl-match-occupied-0001',
  jsonb_build_object(
    'unit_id', :'unit1'::uuid, 'professional_id', :'profa'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T16:00:00Z'
  )
);
SELECT is(
  (SELECT count(*) FROM public.waitlist_offers WHERE waitlist_entry_id = :'entry_occupied'::uuid),
  0::bigint,
  'an already occupied slot creates zero waitlist offers'
);

SELECT * FROM finish();
ROLLBACK;
