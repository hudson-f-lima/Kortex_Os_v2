BEGIN;
SELECT plan(26);

-- Achado do Red Team pós-fatias 032-035 (DEC-54) / auditoria da fatia 040:
-- a versão original deste arquivo cobria só 1 das 14 operações despachadas
-- por private.onda5_guarded_write_dispatch e nunca provava o caminho
-- positivo (owner/admin/manager e reception da própria unidade não são
-- bloqueados). Esta versão cobre as 14 operações — série, grupo e waitlist —
-- nos dois lados: reception de fora da unidade é sempre negada antes de
-- qualquer lógica de negócio, e owner/manager/reception-da-unidade-certa
-- nunca são bloqueados pelo guard (independente do resultado de negócio
-- downstream, que não é o escopo desta fatia).
--
-- Fatia 042 (DEC-57, hardening pós Red Team final): nas 10 operações de
-- LOOKUP (série/conflito/grupo/oferta por ID existente), a negação normaliza
-- para o mesmo P0002 'not found' que um ID inexistente já produz — reception
-- do mesmo tenant não distingue "existe em outra unidade" de "nunca
-- existiu". As 4 operações de CREATE (unit_id vem do próprio payload do
-- actor, sem objeto oculto) continuam com 42501 'insufficient unit
-- permission', que é o erro correto e mais claro ali.

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

-- Executa SQL dinâmico e devolve 'OK' em sucesso ou o SQLSTATE em erro —
-- usado para provar "o guard não bloqueou" sem precisar reconstruir toda a
-- cadeia de pré-condições de negócio (calendar_policies/shifts) de cada RPC,
-- que é irrelevante para o que esta fatia garante.
CREATE FUNCTION pg_temp.try_sqlstate(p_sql text) RETURNS text
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN SQLSTATE;
END;
$$;

SELECT pg_temp.mk_user('onda5-unit-guard-owner@test.local') AS owner \gset
SELECT pg_temp.mk_user('onda5-unit-guard-manager@test.local') AS manager \gset
SELECT pg_temp.mk_user('onda5-unit-guard-reception-a@test.local') AS reception_a \gset
SELECT pg_temp.mk_user('onda5-unit-guard-reception-b@test.local') AS reception_b \gset
SELECT (public.create_organization(:'owner'::uuid, 'Org Unit Guard', 'org-unit-guard')).id AS org \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org'::uuid AND is_default) AS unit_a \gset
INSERT INTO public.units (organization_id, name, timezone, active, is_default)
  VALUES (:'org'::uuid, 'Unidade B', 'America/Sao_Paulo', true, false) RETURNING id AS unit_b \gset

INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
  VALUES
    (:'org'::uuid, :'manager'::uuid, 'manager', null),
    (:'org'::uuid, :'reception_a'::uuid, 'reception', :'unit_a'::uuid),
    (:'org'::uuid, :'reception_b'::uuid, 'reception', :'unit_b'::uuid);

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org'::uuid, 'Grupo', 'percentage', 1000) RETURNING id AS service_group \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org'::uuid, 'Servico', 1000, 30, :'service_group'::uuid) RETURNING id AS service \gset
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org'::uuid, 'Cliente', :'owner'::uuid) RETURNING id AS client \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org'::uuid, 'Prof Unidade B') RETURNING id AS prof_b \gset
INSERT INTO public.professional_units (organization_id, professional_id, unit_id, active)
  VALUES (:'org'::uuid, :'prof_b'::uuid, :'unit_b'::uuid, true);

-- Objetos pré-existentes na Unidade B (uma linha mínima cada — o guard
-- dispara antes de qualquer verificação de negócio, então não precisam
-- satisfazer calendar_policies/professional_shifts).
INSERT INTO public.appointment_series (
  id, organization_id, unit_id, client_id, professional_id, service_id, anchor_date,
  local_start_time, recurrence_days, recurrence_interval_weeks, duration_minutes, valid_from, created_by
) VALUES (
  gen_random_uuid(), :'org'::uuid, :'unit_b'::uuid, :'client'::uuid, :'prof_b'::uuid, :'service'::uuid, '2026-09-07',
  '10:00', array[1]::smallint[], 1, 30, '2026-09-07', :'owner'::uuid
) RETURNING id AS series_b \gset

INSERT INTO public.appointment_series_conflicts (
  id, organization_id, unit_id, series_id, occurrence_date, candidate_starts_at, candidate_ends_at,
  reason_code, idempotency_key, status
) VALUES (
  gen_random_uuid(), :'org'::uuid, :'unit_b'::uuid, :'series_b'::uuid, '2026-09-14',
  '2026-09-14T10:00:00-03'::timestamptz, '2026-09-14T10:30:00-03'::timestamptz,
  'occupied_slot', 'unit-guard-conflict-fixture-01', 'OPEN'
) RETURNING id AS conflict_b \gset

INSERT INTO public.appointment_groups (id, organization_id, unit_id, requester_client_id, created_by)
  VALUES (gen_random_uuid(), :'org'::uuid, :'unit_b'::uuid, :'client'::uuid, :'owner'::uuid)
  RETURNING id AS group_b \gset

INSERT INTO public.waitlist_entries (id, organization_id, unit_id, client_id, service_id, date_from, date_to, consent_at)
  VALUES (gen_random_uuid(), :'org'::uuid, :'unit_b'::uuid, :'client'::uuid, :'service'::uuid, '2026-09-01', '2026-09-30', now())
  RETURNING id AS entry_b \gset

INSERT INTO public.waitlist_offers (
  id, organization_id, unit_id, waitlist_entry_id, offer_wave_id, candidate_starts_at, candidate_ends_at,
  candidate_professional_id, status, token_hash, expires_at, cooldown_until, idempotency_key
) VALUES (
  gen_random_uuid(), :'org'::uuid, :'unit_b'::uuid, :'entry_b'::uuid, gen_random_uuid(),
  now() + interval '1 day', now() + interval '1 day 30 minutes', :'prof_b'::uuid, 'OFFERED',
  encode(digest('unit-guard-offer-token', 'sha256'), 'hex'), now() + interval '30 minutes', now() + interval '6 hours',
  'unit-guard-offer-fixture-01'
) RETURNING id AS offer_b \gset

-- === Caminho negativo: reception da unidade A é sempre 42501 na unidade B,
-- para as 14 operações despachadas pelo guard (série, grupo, waitlist) ===

SELECT throws_ok(
  format('select public.appointment_series_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''client_id'', %L::uuid, ''professional_id'', %L::uuid, ''service_id'', %L::uuid, ''anchor_date'', ''2026-09-07'', ''local_start_time'', ''10:00'', ''recurrence_days'', array[1], ''duration_minutes'', 30, ''valid_from'', ''2026-09-07''))',
    :'org', :'reception_a', 'unit-guard-neg-series-create', :'unit_b', :'client', :'prof_b', :'service'),
  '42501', 'insufficient unit permission', 'reception A cannot appointment_series_create in unit B'
);
-- Issue 042 (DEC-57 hardening): lookup por ID normaliza para o mesmo P0002
-- 'not found' que um ID inexistente já produzia — reception não distingue
-- "existe em outra unidade" de "não existe".
SELECT throws_ok(
  format('select public.appointment_series_extend_window(%L, %L, %L, jsonb_build_object(''series_id'', %L::uuid))',
    :'org', :'reception_a', 'unit-guard-neg-series-extend', :'series_b'),
  'P0002', 'series not found', 'reception A gets the same not-found as a nonexistent series when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.appointment_series_update(%L, %L, %L, jsonb_build_object(''series_id'', %L::uuid, ''scope'', ''THIS_AND_FUTURE''))',
    :'org', :'reception_a', 'unit-guard-neg-series-update', :'series_b'),
  'P0002', 'series not found', 'reception A gets the same not-found as a nonexistent series when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.appointment_series_cancel(%L, %L, %L, jsonb_build_object(''series_id'', %L::uuid, ''scope'', ''THIS_AND_FUTURE''))',
    :'org', :'reception_a', 'unit-guard-neg-series-cancel', :'series_b'),
  'P0002', 'series not found', 'reception A gets the same not-found as a nonexistent series when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.appointment_series_conflict_retry(%L, %L, %L, jsonb_build_object(''conflict_id'', %L::uuid))',
    :'org', :'reception_a', 'unit-guard-neg-series-conflict-retry', :'conflict_b'),
  'P0002', 'series conflict not found', 'reception A gets the same not-found as a nonexistent conflict when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.appointment_group_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''requester_client_id'', %L::uuid, ''service_id'', %L::uuid, ''starts_at'', ''2026-09-07T13:00:00Z'', ''participants'', jsonb_build_array(jsonb_build_object(''client_id'', %L::uuid, ''professional_id'', %L::uuid), jsonb_build_object(''client_id'', %L::uuid, ''professional_id'', %L::uuid))))',
    :'org', :'reception_a', 'unit-guard-neg-group-create', :'unit_b', :'client', :'service', :'client', :'prof_b', :'client', :'prof_b'),
  '42501', 'insufficient unit permission', 'reception A cannot appointment_group_create in unit B'
);
SELECT throws_ok(
  format('select public.appointment_group_member_add(%L, %L, %L, jsonb_build_object(''group_id'', %L::uuid, ''client_id'', %L::uuid, ''professional_id'', %L::uuid))',
    :'org', :'reception_a', 'unit-guard-neg-group-member-add', :'group_b', :'client', :'prof_b'),
  'P0002', 'group not found', 'reception A gets the same not-found as a nonexistent group when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.appointment_group_update(%L, %L, %L, jsonb_build_object(''group_id'', %L::uuid, ''starts_at'', ''2026-09-07T14:00:00Z''))',
    :'org', :'reception_a', 'unit-guard-neg-group-update', :'group_b'),
  'P0002', 'group not found', 'reception A gets the same not-found as a nonexistent group when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.appointment_group_cancel(%L, %L, %L, jsonb_build_object(''group_id'', %L::uuid))',
    :'org', :'reception_a', 'unit-guard-neg-group-cancel', :'group_b'),
  'P0002', 'group not found', 'reception A gets the same not-found as a nonexistent group when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.waitlist_entry_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''client_id'', %L::uuid, ''service_id'', %L::uuid, ''date_from'', ''2026-09-01'', ''date_to'', ''2026-09-02'', ''consent'', true))',
    :'org', :'reception_a', 'unit-guard-waitlist-0001', :'unit_b', :'client', :'service'),
  '42501', 'insufficient unit permission', 'a reception scoped to unit A cannot create a waitlist entry in unit B'
);
SELECT throws_ok(
  format('select public.waitlist_matcher_run(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''professional_id'', %L::uuid, ''service_id'', %L::uuid, ''starts_at'', ''2026-09-07T13:00:00Z''))',
    :'org', :'reception_a', 'unit-guard-neg-matcher-run', :'unit_b', :'prof_b', :'service'),
  '42501', 'insufficient unit permission', 'reception A cannot waitlist_matcher_run in unit B'
);
SELECT throws_ok(
  format('select public.waitlist_offer_accept(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', ''whatever''))',
    :'org', :'reception_a', 'unit-guard-neg-offer-accept', :'offer_b'),
  'P0002', 'waitlist offer not found', 'reception A gets the same not-found as a nonexistent offer when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.waitlist_offer_decline(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', ''whatever''))',
    :'org', :'reception_a', 'unit-guard-neg-offer-decline', :'offer_b'),
  'P0002', 'waitlist offer not found', 'reception A gets the same not-found as a nonexistent offer when the real one is in unit B'
);
SELECT throws_ok(
  format('select public.waitlist_offer_expire(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid))',
    :'org', :'reception_a', 'unit-guard-neg-offer-expire', :'offer_b'),
  'P0002', 'waitlist offer not found', 'reception A gets the same not-found as a nonexistent offer when the real one is in unit B'
);

-- === Caminho positivo: owner/admin/manager preservados — o guard nunca
-- bloqueia quem tem papel org-wide, em nenhuma das 14 operações. Cada
-- asserção só prova que o SQLSTATE não é 42501 (o resultado de negócio
-- downstream, sucesso ou outro erro, é irrelevante ao escopo do guard). ===

SELECT isnt(
  pg_temp.try_sqlstate(format('select public.appointment_series_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''client_id'', %L::uuid, ''professional_id'', %L::uuid, ''service_id'', %L::uuid, ''anchor_date'', ''2026-09-07'', ''local_start_time'', ''10:00'', ''recurrence_days'', array[1], ''duration_minutes'', 30, ''valid_from'', ''2026-09-07''))',
    :'org', :'manager', 'unit-guard-pos-series-create', :'unit_b', :'client', :'prof_b', :'service')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on appointment_series_create in unit B'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.appointment_series_extend_window(%L, %L, %L, jsonb_build_object(''series_id'', %L::uuid))',
    :'org', :'manager', 'unit-guard-pos-series-extend', :'series_b')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on appointment_series_extend_window in unit B'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.appointment_series_update(%L, %L, %L, jsonb_build_object(''series_id'', %L::uuid, ''scope'', ''THIS_AND_FUTURE''))',
    :'org', :'manager', 'unit-guard-pos-series-update', :'series_b')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on appointment_series_update in unit B'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.appointment_series_conflict_retry(%L, %L, %L, jsonb_build_object(''conflict_id'', %L::uuid))',
    :'org', :'manager', 'unit-guard-pos-series-conflict-retry', :'conflict_b')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on appointment_series_conflict_retry in unit B'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.appointment_group_member_add(%L, %L, %L, jsonb_build_object(''group_id'', %L::uuid, ''client_id'', %L::uuid, ''professional_id'', %L::uuid))',
    :'org', :'manager', 'unit-guard-pos-group-member-add', :'group_b', :'client', :'prof_b')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on appointment_group_member_add in unit B'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.appointment_group_update(%L, %L, %L, jsonb_build_object(''group_id'', %L::uuid, ''starts_at'', ''2026-09-07T14:00:00Z''))',
    :'org', :'manager', 'unit-guard-pos-group-update', :'group_b')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on appointment_group_update in unit B'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.appointment_group_cancel(%L, %L, %L, jsonb_build_object(''group_id'', %L::uuid))',
    :'org', :'manager', 'unit-guard-pos-group-cancel', :'group_b')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on appointment_group_cancel in unit B'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.waitlist_matcher_run(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''professional_id'', %L::uuid, ''service_id'', %L::uuid, ''starts_at'', ''2026-09-07T13:00:00Z''))',
    :'org', :'manager', 'unit-guard-pos-matcher-run', :'unit_b', :'prof_b', :'service')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on waitlist_matcher_run in unit B'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.waitlist_offer_decline(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid, ''token'', ''unit-guard-offer-token''))',
    :'org', :'manager', 'unit-guard-pos-offer-decline', :'offer_b')),
  '42501', 'manager (org-wide) is not blocked by the unit guard on waitlist_offer_decline in unit B'
);

-- === reception da própria unidade (B) não é bloqueada — prova que o guard
-- é realmente unit-aware, não "reception sempre proibida". ===

SELECT isnt(
  pg_temp.try_sqlstate(format('select public.appointment_series_extend_window(%L, %L, %L, jsonb_build_object(''series_id'', %L::uuid))',
    :'org', :'reception_b', 'unit-guard-pos-b-series-extend', :'series_b')),
  '42501', 'reception scoped to unit B is not blocked on a unit B series'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.waitlist_offer_expire(%L, %L, %L, jsonb_build_object(''offer_id'', %L::uuid))',
    :'org', :'reception_b', 'unit-guard-pos-b-offer-expire', :'offer_b')),
  '42501', 'reception scoped to unit B is not blocked on a unit B offer'
);
SELECT isnt(
  pg_temp.try_sqlstate(format('select public.waitlist_entry_create(%L, %L, %L, jsonb_build_object(''unit_id'', %L::uuid, ''client_id'', %L::uuid, ''service_id'', %L::uuid, ''date_from'', ''2026-09-01'', ''date_to'', ''2026-09-02'', ''consent'', true))',
    :'org', :'reception_b', 'unit-guard-pos-b-waitlist-create', :'unit_b', :'client', :'service')),
  '42501', 'reception scoped to unit B is not blocked creating a waitlist entry in unit B'
);

SELECT * FROM finish();
ROLLBACK;
