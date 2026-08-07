-- KortexOS 5.1.2 — Onda 4, fatia 027: funções do Availability Resolver
-- (resolve_professional_shift, resolve_calendar_overrides) + chaves de
-- feature flag. Implementa
-- docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md
-- (APROVADO, DEC-49), §2, §3.4, §3.7, §4.
--
-- private.resolve_calendar_policy já nasceu na fatia 023 (o trigger de turno
-- ⊆ horário daquela fatia já precisava dela) — não é redefinida aqui.

-- ============================================================================
-- Pre-flight check (DEC-44 item 2)
-- ============================================================================
do $$
begin
  if to_regclass('public.calendar_policies') is null then
    raise exception 'pre-flight failed: public.calendar_policies does not exist';
  end if;
  if to_regclass('public.professional_shifts') is null then
    raise exception 'pre-flight failed: public.professional_shifts does not exist';
  end if;
  if to_regclass('public.calendar_holidays') is null then
    raise exception 'pre-flight failed: public.calendar_holidays does not exist';
  end if;
  if to_regclass('public.calendar_exceptions') is null then
    raise exception 'pre-flight failed: public.calendar_exceptions does not exist';
  end if;
  if to_regclass('public.calendar_time_off') is null then
    raise exception 'pre-flight failed: public.calendar_time_off does not exist';
  end if;
  if to_regprocedure('private.resolve_calendar_policy(uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_calendar_policy does not exist';
  end if;
end;
$$;

-- ============================================================================
-- 1. private.resolve_professional_shift — análoga a resolve_calendar_policy
-- ============================================================================

create or replace function private.resolve_professional_shift(
  p_organization_id uuid,
  p_professional_id uuid,
  p_unit_id uuid,
  p_date date
)
returns table(blocks jsonb)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_timezone text;
  v_wall_clock timestamptz;
  v_schedule jsonb;
  v_dow text;
begin
  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = p_unit_id;
  if v_timezone is null then
    return;
  end if;

  v_wall_clock := (p_date::text)::timestamp at time zone v_timezone;
  v_dow := extract(dow from p_date)::int::text;

  select weekly_schedule into v_schedule
  from public.professional_shifts
  where organization_id = p_organization_id
    and professional_id = p_professional_id
    and unit_id = p_unit_id
    and valid_from <= v_wall_clock
    and v_wall_clock < coalesce(valid_to, 'infinity'::timestamptz);

  if v_schedule is null then
    return;
  end if;

  return query select coalesce(v_schedule -> v_dow, '[]'::jsonb);
end;
$$;

revoke all on function private.resolve_professional_shift(uuid, uuid, uuid, date) from public, anon, authenticated;

-- ============================================================================
-- 2. private.resolve_calendar_overrides — tiers 1-4 da precedência canônica
--    (Master §2.3): exceção pontual > fechamento/feriado > abertura
--    excepcional > folga. Tiers 5/6 (turno/política padrão) NÃO são desta
--    função — quem os resolve são resolve_professional_shift/resolve_calendar_policy.
-- ============================================================================

create or replace function private.resolve_calendar_overrides(
  p_organization_id uuid,
  p_unit_id uuid,
  p_professional_id uuid,
  p_date date
)
returns table(is_open boolean, reason text)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_timezone text;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_punctual_is_open boolean;
  v_holiday_closed boolean;
  v_exceptional_closure boolean;
  v_exceptional_opening boolean;
  v_time_off boolean;
begin
  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = p_unit_id;
  if v_timezone is null then
    return;
  end if;

  v_day_start := (p_date::text)::timestamp at time zone v_timezone;
  v_day_end := v_day_start + interval '1 day';

  -- Tier 1: exceção pontual autorizada (unit-wide ou deste profissional).
  select e.is_open into v_punctual_is_open
  from public.calendar_exceptions e
  where e.organization_id = p_organization_id
    and e.unit_id = p_unit_id
    and e.exception_type = 'punctual_override'
    and (e.professional_id is null or e.professional_id = p_professional_id)
    and tstzrange(e.starts_at, e.ends_at, '[)') && tstzrange(v_day_start, v_day_end, '[)')
  order by e.starts_at desc
  limit 1;

  if found then
    return query select v_punctual_is_open, 'punctual_override'::text;
    return;
  end if;

  -- Tier 2: fechamento excepcional (reforma/evento) OU feriado sem abertura.
  select exists (
    select 1 from public.calendar_exceptions e
    where e.organization_id = p_organization_id
      and e.unit_id = p_unit_id
      and e.exception_type = 'exceptional_closure'
      and tstzrange(e.starts_at, e.ends_at, '[)') && tstzrange(v_day_start, v_day_end, '[)')
  ) into v_exceptional_closure;

  select exists (
    select 1 from public.calendar_holidays h
    where h.organization_id = p_organization_id
      and (h.unit_id is null or h.unit_id = p_unit_id)
      and h.holiday_date = p_date
      and not h.unit_opens
  ) into v_holiday_closed;

  if v_exceptional_closure or v_holiday_closed then
    return query select false, 'exceptional_closure_or_holiday'::text;
    return;
  end if;

  -- Tier 3: abertura excepcional.
  select exists (
    select 1 from public.calendar_exceptions e
    where e.organization_id = p_organization_id
      and e.unit_id = p_unit_id
      and e.exception_type = 'exceptional_opening'
      and (e.professional_id is null or e.professional_id = p_professional_id)
      and tstzrange(e.starts_at, e.ends_at, '[)') && tstzrange(v_day_start, v_day_end, '[)')
  ) into v_exceptional_opening;

  if v_exceptional_opening then
    return query select true, 'exceptional_opening'::text;
    return;
  end if;

  -- Tier 4: folga/férias do profissional (só se um profissional foi informado).
  if p_professional_id is not null then
    select exists (
      select 1 from public.calendar_time_off t
      where t.organization_id = p_organization_id
        and t.professional_id = p_professional_id
        and tstzrange(t.starts_at, t.ends_at, '[)') && tstzrange(v_day_start, v_day_end, '[)')
    ) into v_time_off;

    if v_time_off then
      return query select false, 'time_off'::text;
      return;
    end if;
  end if;

  -- Nenhum override — Resolver cai para tiers 5/6 (turno/política padrão).
  return;
end;
$$;

revoke all on function private.resolve_calendar_overrides(uuid, uuid, uuid, date) from public, anon, authenticated;
