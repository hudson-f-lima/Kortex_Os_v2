-- KortexOS 5.1.2 — Onda 4, fatia 025: calendar_policy_conflicts + trigger de
-- detecção. Implementa
-- docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md
-- (APROVADO, DEC-49), §2, §3.2, §3.8, §4.
--
-- A tentativa intermediária de isentar professional_shifts por
-- calendar_exceptions.exceptional_opening foi removida após auditoria: uma
-- exceção pontual não autoriza uma definição recorrente de turno.

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
  if not exists (
    select 1 from pg_constraint where conname = 'appointments_org_id_unit_unique'
  ) then
    raise exception 'pre-flight failed: appointments_org_id_unit_unique does not exist';
  end if;
  if to_regclass('public.calendar_policy_conflicts') is not null then
    raise exception 'pre-flight failed: public.calendar_policy_conflicts already exists';
  end if;
end;
$$;

-- ============================================================================
-- 1. calendar_policy_conflicts
-- ============================================================================

create table public.calendar_policy_conflicts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  source_type text not null check (source_type in ('calendar_policy', 'professional_shift', 'calendar_holiday', 'calendar_exception', 'calendar_time_off')),
  source_id uuid not null,
  appointment_id uuid not null,
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  detected_at timestamptz not null default now(),
  resolved_by uuid null,
  resolved_at timestamptz null,
  resolution_note text null,
  check ((status = 'open') = (resolved_by is null and resolved_at is null)),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  foreign key (organization_id, appointment_id, unit_id) references public.appointments(organization_id, id, unit_id) on delete restrict
);

create index calendar_policy_conflicts_unit_status_idx on public.calendar_policy_conflicts(organization_id, unit_id, status);

alter table public.calendar_policy_conflicts enable row level security;

create policy calendar_policy_conflicts_select
on public.calendar_policy_conflicts for select to authenticated
using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin', 'manager'],
    array[]::text[]
  )
);

create policy calendar_policy_conflicts_update
on public.calendar_policy_conflicts for update to authenticated
using (private.has_role(organization_id, array['owner', 'admin', 'manager']))
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

-- Sem policy de INSERT: só o trigger abaixo (security definer) escreve.

-- ============================================================================
-- 2. Helper: um profissional está "ocupado" por um appointment num intervalo?
--    Usado pelos 5 triggers de detecção abaixo.
-- ============================================================================

create or replace function private.record_calendar_policy_conflict(
  p_source_type text,
  p_source_id uuid,
  p_organization_id uuid,
  p_unit_id uuid,
  p_appointment_id uuid
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.calendar_policy_conflicts (organization_id, unit_id, source_type, source_id, appointment_id)
  values (p_organization_id, p_unit_id, p_source_type, p_source_id, p_appointment_id);
end;
$$;

revoke all on function private.record_calendar_policy_conflict(text, uuid, uuid, uuid, uuid) from public, anon, authenticated;

-- ============================================================================
-- 3. Trigger: calendar_policies — appointment futuro fora do novo horário
-- ============================================================================

create or replace function private.detect_conflicts_from_calendar_policy()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_timezone text;
  v_appt record;
  v_blocks jsonb;
  v_local_start text;
  v_local_end text;
  v_block jsonb;
  v_covered boolean;
begin
  select timezone into v_timezone from public.units where organization_id = new.organization_id and id = new.unit_id;

  for v_appt in
    select id, organization_id, unit_id, starts_at, ends_at
    from public.appointments
    where organization_id = new.organization_id
      and unit_id = new.unit_id
      and status in ('scheduled', 'confirmed', 'in_service')
      and starts_at >= new.valid_from
      and starts_at < coalesce(new.valid_to, 'infinity'::timestamptz)
  loop
    select blocks into v_blocks from private.resolve_calendar_policy(new.organization_id, new.unit_id, (v_appt.starts_at at time zone v_timezone)::date);
    v_local_start := to_char(v_appt.starts_at at time zone v_timezone, 'HH24:MI');
    v_local_end := to_char(v_appt.ends_at at time zone v_timezone, 'HH24:MI');
    v_covered := false;
    for v_block in select * from jsonb_array_elements(coalesce(v_blocks, '[]'::jsonb)) loop
      if v_local_start >= (v_block ->> 'start') and v_local_end <= (v_block ->> 'end') then
        v_covered := true;
        exit;
      end if;
    end loop;
    if not v_covered then
      perform private.record_calendar_policy_conflict('calendar_policy', new.id, v_appt.organization_id, v_appt.unit_id, v_appt.id);
    end if;
  end loop;

  return new;
end;
$$;

revoke all on function private.detect_conflicts_from_calendar_policy() from public, anon, authenticated;

create trigger calendar_policies_detect_conflicts
after insert on public.calendar_policies
for each row execute function private.detect_conflicts_from_calendar_policy();

-- ============================================================================
-- 4. Trigger: professional_shifts — mesma lógica, escopo do profissional
-- ============================================================================

create or replace function private.detect_conflicts_from_professional_shift()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_timezone text;
  v_appt record;
  v_dow text;
  v_blocks jsonb;
  v_local_start text;
  v_local_end text;
  v_block jsonb;
  v_covered boolean;
begin
  select timezone into v_timezone from public.units where organization_id = new.organization_id and id = new.unit_id;

  for v_appt in
    select id, organization_id, unit_id, starts_at, ends_at
    from public.appointments
    where organization_id = new.organization_id
      and unit_id = new.unit_id
      and professional_id = new.professional_id
      and status in ('scheduled', 'confirmed', 'in_service')
      and starts_at >= new.valid_from
      and starts_at < coalesce(new.valid_to, 'infinity'::timestamptz)
  loop
    v_dow := extract(dow from (v_appt.starts_at at time zone v_timezone))::int::text;
    v_blocks := coalesce(new.weekly_schedule -> v_dow, '[]'::jsonb);
    v_local_start := to_char(v_appt.starts_at at time zone v_timezone, 'HH24:MI');
    v_local_end := to_char(v_appt.ends_at at time zone v_timezone, 'HH24:MI');
    v_covered := false;
    for v_block in select * from jsonb_array_elements(v_blocks) loop
      if v_local_start >= (v_block ->> 'start') and v_local_end <= (v_block ->> 'end') then
        v_covered := true;
        exit;
      end if;
    end loop;
    if not v_covered then
      perform private.record_calendar_policy_conflict('professional_shift', new.id, v_appt.organization_id, v_appt.unit_id, v_appt.id);
    end if;
  end loop;

  return new;
end;
$$;

revoke all on function private.detect_conflicts_from_professional_shift() from public, anon, authenticated;

create trigger professional_shifts_detect_conflicts
after insert on public.professional_shifts
for each row execute function private.detect_conflicts_from_professional_shift();

-- ============================================================================
-- 5. Trigger: calendar_holidays — só quando unit_opens = false (fecha o dia)
-- ============================================================================

create or replace function private.detect_conflicts_from_calendar_holiday()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_appt record;
begin
  if new.unit_opens then
    return new;
  end if;

  -- Correção de achado de auditoria pós-implementação (2026-07-29): a versão
  -- original buscava o timezone de UMA unidade só (a unidade do feriado, ou
  -- a unidade default quando new.unit_id é nulo/org-wide) e usava esse mesmo
  -- timezone para converter starts_at de appointments de QUALQUER unidade da
  -- organização — incorreto sempre que duas unidades da mesma org têm
  -- timezones diferentes (cenário real, ver fatia 027: unidade em
  -- America/Sao_Paulo e outra em America/New_York coexistindo). Corrigido
  -- para fazer join em units por appointment e usar o timezone de CADA
  -- unidade individualmente.
  for v_appt in
    select a.id, a.organization_id, a.unit_id, a.starts_at, a.ends_at
    from public.appointments a
    join public.units u on u.organization_id = a.organization_id and u.id = a.unit_id
    where a.organization_id = new.organization_id
      and (new.unit_id is null or a.unit_id = new.unit_id)
      and a.status in ('scheduled', 'confirmed', 'in_service')
      and (a.starts_at at time zone u.timezone)::date = new.holiday_date
  loop
    perform private.record_calendar_policy_conflict('calendar_holiday', new.id, v_appt.organization_id, v_appt.unit_id, v_appt.id);
  end loop;

  return new;
end;
$$;

revoke all on function private.detect_conflicts_from_calendar_holiday() from public, anon, authenticated;

create trigger calendar_holidays_detect_conflicts
after insert on public.calendar_holidays
for each row execute function private.detect_conflicts_from_calendar_holiday();

-- ============================================================================
-- 6. Trigger: calendar_exceptions — só quando is_open = false (fecha a janela)
-- ============================================================================

create or replace function private.detect_conflicts_from_calendar_exception()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_appt record;
begin
  if new.is_open then
    return new;
  end if;

  for v_appt in
    select a.id, a.organization_id, a.unit_id, a.starts_at, a.ends_at
    from public.appointments a
    where a.organization_id = new.organization_id
      and a.unit_id = new.unit_id
      and (new.professional_id is null or a.professional_id = new.professional_id)
      and a.status in ('scheduled', 'confirmed', 'in_service')
      and tstzrange(a.starts_at, a.ends_at, '[)') && tstzrange(new.starts_at, new.ends_at, '[)')
  loop
    perform private.record_calendar_policy_conflict('calendar_exception', new.id, v_appt.organization_id, v_appt.unit_id, v_appt.id);
  end loop;

  return new;
end;
$$;

revoke all on function private.detect_conflicts_from_calendar_exception() from public, anon, authenticated;

create trigger calendar_exceptions_detect_conflicts
after insert on public.calendar_exceptions
for each row execute function private.detect_conflicts_from_calendar_exception();

-- ============================================================================
-- 7. Trigger: calendar_time_off — profissional fica indisponível na janela
-- ============================================================================

create or replace function private.detect_conflicts_from_calendar_time_off()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_appt record;
begin
  for v_appt in
    select a.id, a.organization_id, a.unit_id, a.starts_at, a.ends_at
    from public.appointments a
    where a.organization_id = new.organization_id
      and a.professional_id = new.professional_id
      and a.status in ('scheduled', 'confirmed', 'in_service')
      and tstzrange(a.starts_at, a.ends_at, '[)') && tstzrange(new.starts_at, new.ends_at, '[)')
  loop
    perform private.record_calendar_policy_conflict('calendar_time_off', new.id, v_appt.organization_id, v_appt.unit_id, v_appt.id);
  end loop;

  return new;
end;
$$;

revoke all on function private.detect_conflicts_from_calendar_time_off() from public, anon, authenticated;

create trigger calendar_time_off_detect_conflicts
after insert on public.calendar_time_off
for each row execute function private.detect_conflicts_from_calendar_time_off();

-- ============================================================================
-- 8. Isenção por exceptional_opening REMOVIDA (achado de auditoria pós-
--    implementação, 2026-07-29) — não é um bug de "faltou comparar a data",
--    é um erro conceitual: professional_shifts.weekly_schedule é um padrão
--    RECORRENTE (repete toda semana); calendar_exceptions.exceptional_opening
--    é uma janela de UMA data específica. Uma abertura excepcional de um dia
--    não pode autorizar, para sempre, um bloco que se repete toda semana — a
--    implementação original comparava só HH:MI, ignorando a data por
--    completo, então uma exceção de 24/12 "abria" o turno recorrente em
--    qualquer outra terça-feira do ano. Não existe correção de data que
--    conserte essa comparação, porque os dois lados têm semânticas de tempo
--    incompatíveis (recorrente vs. instância única). A regra correta:
--    aberturas excepcionais autorizam OCORRÊNCIAS pontuais (avaliadas por
--    private.resolve_calendar_overrides, fatia 027, no momento da consulta
--    de disponibilidade/criação do appointment), nunca a definição do turno
--    recorrente em si. `private.close_previous_professional_shift_version()`
--    permanece exatamente a versão da fatia 023 (containment estrito contra
--    calendar_policies, sem isenção) — esta fatia não a redefine.
-- ============================================================================
