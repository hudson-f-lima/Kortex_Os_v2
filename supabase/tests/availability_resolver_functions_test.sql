BEGIN;
SELECT plan(16);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org Resolver', 'org-resolver')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
SELECT (public.unit_create(:'org1'::uuid, :'owner1'::uuid, 'Unit NY')).id AS unit_ny \gset
UPDATE public.units SET timezone = 'America/New_York' WHERE organization_id = :'org1'::uuid AND id = :'unit_ny'::uuid;

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Um') RETURNING id AS professional1 \gset

INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"2": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'professional1'::uuid, :'unit1'::uuid, '{"2": [{"start":"10:00","end":"16:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'professional1'::uuid, :'unit1'::uuid, '{"2": [{"start":"11:00","end":"15:00"}]}'::jsonb, '2026-09-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit_ny'::uuid, '{"2": [{"start":"09:00","end":"17:00"}]}'::jsonb, '2026-09-01 00:00:00-04'::timestamptz, :'owner1'::uuid);

-- === resolve_professional_shift ===

SELECT is(
  (SELECT blocks FROM private.resolve_professional_shift(:'org1'::uuid, :'professional1'::uuid, :'unit1'::uuid, '2026-08-04'::date)),
  '[{"start":"10:00","end":"16:00"}]'::jsonb,
  'resolve_professional_shift returns the blocks of the version in effect before the second version starts'
);
SELECT is(
  (SELECT blocks FROM private.resolve_professional_shift(:'org1'::uuid, :'professional1'::uuid, :'unit1'::uuid, '2026-09-08'::date)),
  '[{"start":"11:00","end":"15:00"}]'::jsonb,
  'resolve_professional_shift returns the blocks of the second (narrower) version after it starts'
);
SELECT is(
  (SELECT blocks FROM private.resolve_professional_shift(:'org1'::uuid, :'professional1'::uuid, :'unit1'::uuid, '2025-12-01'::date)),
  null::jsonb,
  'resolve_professional_shift returns no row before any version existed'
);

-- === timezone: unidade em fuso diferente de America/Sao_Paulo ===

SELECT is(
  (SELECT blocks FROM private.resolve_calendar_policy(:'org1'::uuid, :'unit_ny'::uuid, '2026-09-01'::date)),
  '[{"start":"09:00","end":"17:00"}]'::jsonb,
  'resolve_calendar_policy resolves correctly for a unit in America/New_York (valid_from stored as that timezone''s local midnight, not UTC or Sao_Paulo)'
);

-- === resolve_calendar_overrides: precedencia de 4 tiers ===

-- Tier 4: folga do profissional.
INSERT INTO public.calendar_time_off (organization_id, professional_id, starts_at, ends_at, created_by)
  VALUES (:'org1'::uuid, :'professional1'::uuid, '2026-10-05 00:00:00-03'::timestamptz, '2026-10-06 00:00:00-03'::timestamptz, :'owner1'::uuid);
SELECT is(
  (SELECT (is_open, reason) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, :'professional1'::uuid, '2026-10-05'::date)),
  (false, 'time_off'::text),
  'tier 4 (time_off) is returned when nothing higher precedence applies'
);

-- Tier 3: abertura excepcional (sem tier 1/2 concorrente nesse dia).
INSERT INTO public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by)
  VALUES (:'org1'::uuid, 'exceptional_opening', 'unit', :'unit1'::uuid, '2026-10-10 09:00:00-03'::timestamptz, '2026-10-10 20:00:00-03'::timestamptz, true, 'Vespera de festa', :'owner1'::uuid);
SELECT is(
  (SELECT (is_open, reason) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, :'professional1'::uuid, '2026-10-10'::date)),
  (true, 'exceptional_opening'::text),
  'tier 3 (exceptional_opening) wins over no override at all'
);

-- Tier 2: feriado fechado no mesmo dia da abertura excepcional de outro dia (dia distinto, sem conflito).
INSERT INTO public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, unit_opens, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '2026-10-12'::date, 'Feriado Fechado', 'custom', false, :'owner1'::uuid);
SELECT is(
  (SELECT (is_open, reason) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, :'professional1'::uuid, '2026-10-12'::date)),
  (false, 'exceptional_closure_or_holiday'::text),
  'tier 2 (holiday, unit_opens = false) is returned'
);

-- Tier 1: exceção pontual autorizada vence sobre o feriado fechado do tier 2 no MESMO dia.
INSERT INTO public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by, authorized_by)
  VALUES (:'org1'::uuid, 'punctual_override', 'unit', :'unit1'::uuid, '2026-10-12 08:00:00-03'::timestamptz, '2026-10-12 12:00:00-03'::timestamptz, true, 'Abriu excepcionalmente no feriado', :'owner1'::uuid, :'owner1'::uuid);
SELECT is(
  (SELECT (is_open, reason) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, :'professional1'::uuid, '2026-10-12'::date)),
  (true, 'punctual_override'::text),
  'tier 1 (punctual_override) wins over tier 2 (holiday closure) on the same date'
);

-- Nenhum override: resolve_calendar_overrides nao retorna linha.
SELECT is(
  (SELECT count(*) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, :'professional1'::uuid, '2026-11-01'::date))::int,
  0,
  'resolve_calendar_overrides returns no row when nothing applies (falls through to tiers 5/6)'
);

-- Tier 2 via calendar_exceptions (exceptional_closure), independente de feriado.
INSERT INTO public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by)
  VALUES (:'org1'::uuid, 'exceptional_closure', 'unit', :'unit1'::uuid, '2026-11-02 00:00:00-03'::timestamptz, '2026-11-03 00:00:00-03'::timestamptz, false, 'Reforma', :'owner1'::uuid);
SELECT is(
  (SELECT (is_open, reason) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, :'professional1'::uuid, '2026-11-02'::date)),
  (false, 'exceptional_closure_or_holiday'::text),
  'tier 2 via calendar_exceptions.exceptional_closure (no holiday involved) is returned'
);

-- Feriado org-wide (unit_id null) tambem conta para o tier 2.
INSERT INTO public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, unit_opens, created_by)
  VALUES (:'org1'::uuid, null, '2026-12-25'::date, 'Natal', 'national', false, :'owner1'::uuid);
SELECT is(
  (SELECT (is_open, reason) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, :'professional1'::uuid, '2026-12-25'::date)),
  (false, 'exceptional_closure_or_holiday'::text),
  'an org-wide holiday (unit_id null) is honored by resolve_calendar_overrides too'
);
SELECT is(
  (SELECT (is_open, reason) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit_ny'::uuid, :'professional1'::uuid, '2026-12-25'::date)),
  (false, 'exceptional_closure_or_holiday'::text),
  'the org-wide holiday also applies to a different unit of the same organization'
);

-- resolve_calendar_overrides sem profissional (p_professional_id null) ignora tier 4 e ainda funciona nos tiers 1-3.
SELECT is(
  (SELECT (is_open, reason) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, null::uuid, '2026-10-12'::date)),
  (true, 'punctual_override'::text),
  'resolve_calendar_overrides works with p_professional_id null (unit-wide query), still honoring tier 1'
);
SELECT is(
  (SELECT count(*) FROM private.resolve_calendar_overrides(:'org1'::uuid, :'unit1'::uuid, null::uuid, '2026-10-05'::date))::int,
  0,
  'with p_professional_id null, tier 4 (time_off, which is professional-specific) never applies'
);

-- Funcoes revoke all from authenticated (chamadas apenas internamente / por outras funcoes security definer).
SELECT ok(
  NOT has_function_privilege('authenticated', 'private.resolve_professional_shift(uuid,uuid,uuid,date)', 'EXECUTE'),
  'authenticated has no direct EXECUTE on resolve_professional_shift'
);
SELECT ok(
  NOT has_function_privilege('authenticated', 'private.resolve_calendar_overrides(uuid,uuid,uuid,date)', 'EXECUTE'),
  'authenticated has no direct EXECUTE on resolve_calendar_overrides'
);

SELECT * FROM finish();
ROLLBACK;
