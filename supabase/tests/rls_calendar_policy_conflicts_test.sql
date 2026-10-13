BEGIN;
SELECT plan(22);

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

SELECT (public.create_organization(:'owner1'::uuid, 'Org Conflicts', 'org-conflicts')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid);

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Um') RETURNING id AS professional1 \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Grupo Um', 'percentage', 1000) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 60, :'group1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset

-- Appointment futuro confirmado, terca-feira (dow=2), 10:00-11:00 local (unit timezone America/Sao_Paulo, -03).
INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
VALUES (:'org1'::uuid, :'unit1'::uuid, :'client1'::uuid, :'professional1'::uuid, :'service1'::uuid, '2026-09-01 10:00:00-03'::timestamptz, '2026-09-01 11:00:00-03'::timestamptz, 'confirmed', :'owner1'::uuid)
RETURNING id AS appt1 \gset

-- 2ª unidade em timezone diferente (America/New_York), para o teste do
-- achado de auditoria: feriado org-wide precisa usar o timezone de CADA
-- unidade, não o da unidade default.
SELECT (public.unit_create(:'org1'::uuid, :'owner1'::uuid, 'Unit NY')).id AS unit_ny \gset
UPDATE public.units SET timezone = 'America/New_York' WHERE organization_id = :'org1'::uuid AND id = :'unit_ny'::uuid;
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional NY') RETURNING id AS professional_ny \gset
SELECT public.professional_unit_assign(:'org1'::uuid, :'owner1'::uuid, :'professional_ny'::uuid, :'unit_ny'::uuid);
-- 23:30 de 1/set no fuso de NY (-04 em setembro, DST) = 03:30 de 2/set em UTC.
-- Se o trigger (incorretamente) usasse o timezone da unidade default
-- (America/Sao_Paulo, -03) para converter, essa mesma instante viraria
-- 00:30 de 2/set — data errada, o feriado de 1/set não bateria.
INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
VALUES (:'org1'::uuid, :'unit_ny'::uuid, :'client1'::uuid, :'professional_ny'::uuid, :'service1'::uuid, '2026-09-01 23:30:00-04'::timestamptz, '2026-09-02 00:30:00-04'::timestamptz, 'confirmed', :'owner1'::uuid)
RETURNING id AS appt_ny \gset

GRANT SELECT, INSERT, UPDATE ON public.calendar_policies TO authenticated;
GRANT SELECT, INSERT ON public.professional_shifts TO authenticated;
GRANT SELECT, INSERT ON public.calendar_holidays TO authenticated;
GRANT SELECT, INSERT ON public.calendar_exceptions TO authenticated;
GRANT SELECT, INSERT ON public.calendar_time_off TO authenticated;
GRANT SELECT, UPDATE ON public.calendar_policy_conflicts TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);

-- Behavior 1: política vigente ANTES do appointment cobre 09:00-18:00 (fixture inicial), sem conflito ainda.
SELECT lives_ok(
  format('insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"2": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'),
  'owner1 creates the initial calendar_policies (covers the appointment)'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid)::int,
  0,
  'no conflict recorded when the appointment already fits the policy'
);

-- Behavior 2: nova versão da política, vigente ANTES do appointment, estreita o horário para 12:00-18:00 — appt1 (10h-11h) fica de fora.
SELECT lives_ok(
  format('insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"2": [{"start":"12:00","end":"18:00"}]}'::jsonb, '2026-08-01 00:00:00-03'::timestamptz, :'owner1'),
  'owner1 narrows unit1 hours, now excluding appt1''s time'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND appointment_id = :'appt1'::uuid AND source_type = 'calendar_policy')::int,
  1,
  'narrowing calendar_policies hours records exactly one conflict for appt1'
);

-- Behavior 3: turno do profissional (dentro do novo horario 12:00-18:00) tambem restringe mais ainda (13:00-18:00) — appt1 ja tinha conflito, agora tambem via professional_shift.
SELECT lives_ok(
  format('insert into public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', :'unit1', '{"2": [{"start":"13:00","end":"18:00"}]}'::jsonb, '2026-08-02 00:00:00-03'::timestamptz, :'owner1'),
  'owner1 creates a professional_shifts version narrower than appt1''s time'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND appointment_id = :'appt1'::uuid AND source_type = 'professional_shift')::int,
  1,
  'narrowing professional_shifts hours records a conflict for appt1'
);

-- Behavior 4: feriado com unit_opens = false no dia do appt1 gera conflito.
SELECT lives_ok(
  format('insert into public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, unit_opens, created_by) values (%L, %L, %L, %L, %L, %L, %L)',
    :'org1', :'unit1', '2026-09-01'::date, 'Feriado Fechado', 'custom', false, :'owner1'),
  'owner1 creates a closed holiday on appt1''s date'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND appointment_id = :'appt1'::uuid AND source_type = 'calendar_holiday')::int,
  1,
  'holiday with unit_opens = false records a conflict for appt1'
);

-- Achado de auditoria pós-implementação (2026-07-29): um feriado ORG-WIDE
-- (unit_id nulo) precisa usar o timezone de CADA unidade ao converter
-- starts_at para data civil, não o timezone de uma única unidade (a
-- default). appt_ny (unit_ny, America/New_York) está marcado 23:30 de
-- 1/set NY — em UTC isso é 2/set 03:30. Um feriado org-wide de 1/set só
-- bate com appt_ny se o trigger usar o timezone de unit_ny (NY) para
-- converter, não o de unit1 (São Paulo).
SELECT lives_ok(
  format('insert into public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, unit_opens, created_by) values (%L, null, %L, %L, %L, %L, %L)',
    :'org1', '2026-09-01'::date, 'Feriado Org-Wide', 'national', false, :'owner1'),
  'owner1 creates an org-wide closed holiday matching appt1''s date'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND appointment_id = :'appt_ny'::uuid AND source_type = 'calendar_holiday')::int,
  1,
  'the org-wide holiday correctly flags appt_ny using unit_ny''s own timezone (America/New_York), not unit1''s (America/Sao_Paulo)'
);

-- Behavior 5: feriado com unit_opens = true NAO gera conflito.
SELECT lives_ok(
  format('insert into public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, unit_opens, created_by) values (%L, %L, %L, %L, %L, %L, %L)',
    :'org1', :'unit1', '2026-09-08'::date, 'Feriado Aberto', 'custom', true, :'owner1'),
  'owner1 creates an open holiday on a date with no appointment'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND source_type = 'calendar_holiday')::int,
  3, -- baseline after the previous 2 behaviors: unit1's own closed holiday vs appt1, plus the org-wide closed holiday vs both appt1 and appt_ny
  'holiday with unit_opens = true does not record a new conflict'
);

-- Behavior 6: exceptional_closure cobrindo o horario do appt1 gera conflito.
SELECT lives_ok(
  format('insert into public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by) values (%L, %L, %L, %L, %L, %L, %L, %L, %L)',
    :'org1', 'exceptional_closure', 'unit', :'unit1', '2026-09-01 09:00:00-03'::timestamptz, '2026-09-01 12:00:00-03'::timestamptz, false, 'Manutencao', :'owner1'),
  'owner1 creates an exceptional_closure covering appt1'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND appointment_id = :'appt1'::uuid AND source_type = 'calendar_exception')::int,
  1,
  'exceptional_closure covering the appointment records a conflict'
);

-- Behavior 7: exceptional_opening NAO gera conflito.
SELECT lives_ok(
  format('insert into public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by) values (%L, %L, %L, %L, %L, %L, %L, %L, %L)',
    :'org1', 'exceptional_opening', 'unit', :'unit1', '2026-09-01 09:00:00-03'::timestamptz, '2026-09-01 12:00:00-03'::timestamptz, true, 'Abertura extra', :'owner1'),
  'owner1 creates an exceptional_opening covering appt1'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND source_type = 'calendar_exception')::int,
  1,
  'exceptional_opening does not add a second conflict'
);

-- Behavior 8: folga do profissional cobrindo o horario do appt1 gera conflito.
SELECT lives_ok(
  format('insert into public.calendar_time_off (organization_id, professional_id, starts_at, ends_at, reason, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', '2026-08-31 00:00:00-03'::timestamptz, '2026-09-02 00:00:00-03'::timestamptz, 'Ferias', :'owner1'),
  'owner1 creates time_off covering appt1'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND appointment_id = :'appt1'::uuid AND source_type = 'calendar_time_off')::int,
  1,
  'time_off covering the appointment records a conflict'
);

-- Behavior 9: RLS — fila e Command-facing (owner/admin/manager), nenhum papel unit-scoped enxerga.
SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid)::int,
  0,
  'reception1 (unit-scoped role) cannot see the conflict queue'
);

-- Behavior 10: owner resolve um conflito.
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT lives_ok(
  format('update public.calendar_policy_conflicts set status = %L, resolved_by = %L, resolved_at = now(), resolution_note = %L where organization_id = %L and appointment_id = %L and source_type = %L',
    'resolved', :'owner1', 'Remarcado manualmente', :'org1', :'appt1', 'calendar_policy'),
  'owner1 resolves one conflict'
);
SELECT is(
  (SELECT status FROM public.calendar_policy_conflicts WHERE organization_id = :'org1'::uuid AND appointment_id = :'appt1'::uuid AND source_type = 'calendar_policy'),
  'resolved',
  'the resolved conflict is persisted as resolved'
);

-- Behavior 11 (achado de auditoria pós-implementação, 2026-07-29 — a isenção
-- original foi REMOVIDA, não corrigida: exceptional_opening é uma janela de
-- UMA data, professional_shifts.weekly_schedule é um padrão RECORRENTE
-- semanal; um não pode autorizar o outro permanentemente). Turno fora do
-- horário da unidade continua sempre rejeitado, mesmo com uma
-- exceptional_opening vigente para aquele dia — a exceção autoriza a
-- OCORRÊNCIA pontual (via resolve_calendar_overrides, fatia 027), nunca a
-- definição recorrente do turno.
SELECT throws_ok(
  format('insert into public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', :'unit1', '{"2": [{"start":"09:00","end":"12:00"}]}'::jsonb, '2026-09-01 00:00:00-03'::timestamptz, :'owner1'),
  '22023',
  'shift outside unit hours without exceptional opening',
  'a recurring shift block outside unit hours is still rejected even when a same-day exceptional_opening exists — the exemption was removed, not fixed'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
