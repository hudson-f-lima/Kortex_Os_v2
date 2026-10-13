-- KortexOS 5.1.2 — Onda 4, fatia 023: calendar_policies + professional_shifts.
-- Implementa docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md
-- (APROVADO, DEC-49), §2, §3.1, §3.8, §4.
--
-- Ajuste de sequenciamento em relação ao fatiamento original (issues/023, /027):
-- private.resolve_calendar_policy() nasce aqui, não na fatia 027, porque o
-- trigger de turno ⊆ horário desta própria fatia (regra CRÍTICO, Master §2.4)
-- já precisa dela. A fatia 027 estende o Resolver com resolve_professional_shift
-- e resolve_calendar_overrides (que dependem de calendar_holidays/calendar_exceptions/
-- calendar_time_off, ainda inexistentes) — não redefine esta função.

-- ============================================================================
-- Pre-flight check (DEC-44 item 2)
-- ============================================================================
do $$
begin
  if to_regclass('public.units') is null then
    raise exception 'pre-flight failed: public.units does not exist';
  end if;
  if to_regclass('public.professional_units') is null then
    raise exception 'pre-flight failed: public.professional_units does not exist';
  end if;
  if to_regclass('public.calendar_policies') is not null then
    raise exception 'pre-flight failed: public.calendar_policies already exists';
  end if;
end;
$$;

-- ============================================================================
-- 1. private.valid_weekly_schedule — validação de forma do jsonb de grade semanal
-- ============================================================================

create or replace function private.valid_weekly_schedule(p_schedule jsonb)
returns boolean
language plpgsql
stable
set search_path = pg_catalog
as $$
declare
  v_key text;
  v_day_blocks jsonb;
  v_block jsonb;
  v_prev_end text;
  v_start text;
  v_end text;
begin
  if p_schedule is null or jsonb_typeof(p_schedule) <> 'object' then
    return false;
  end if;

  for v_key in select jsonb_object_keys(p_schedule) loop
    if v_key !~ '^[0-6]$' then
      return false;
    end if;

    v_day_blocks := p_schedule -> v_key;
    if jsonb_typeof(v_day_blocks) <> 'array' then
      return false;
    end if;

    v_prev_end := null;
    for v_block in select * from jsonb_array_elements(v_day_blocks) loop
      if jsonb_typeof(v_block) <> 'object' then
        return false;
      end if;
      v_start := v_block ->> 'start';
      v_end := v_block ->> 'end';
      if v_start is null or v_end is null then
        return false;
      end if;
      if v_start !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or v_end !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then
        return false;
      end if;
      if v_start >= v_end then
        return false;
      end if;
      if v_prev_end is not null and v_start < v_prev_end then
        return false;
      end if;
      v_prev_end := v_end;
    end loop;
  end loop;

  return true;
end;
$$;

-- ============================================================================
-- 2. calendar_policies
-- ============================================================================

create extension if not exists btree_gist;

create table public.calendar_policies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  weekly_schedule jsonb not null check (private.valid_weekly_schedule(weekly_schedule)),
  valid_from timestamptz not null,
  valid_to timestamptz null,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  exclude using gist (
    organization_id with =,
    unit_id with =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'), '[)') with &&
  )
);

create index calendar_policies_unit_valid_from_idx on public.calendar_policies(organization_id, unit_id, valid_from);

alter table public.calendar_policies enable row level security;

create policy calendar_policies_select
on public.calendar_policies for select to authenticated
using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin', 'manager'],
    array['reception', 'professional']
  )
);

create policy calendar_policies_insert
on public.calendar_policies for insert to authenticated
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

-- Nenhuma policy de UPDATE/DELETE: linha fechada é imutável (Blueprint §3.1);
-- a única mutação (fechar valid_to) é feita pelo trigger abaixo, que roda
-- security definer e portanto não depende de grant de RLS.

-- ============================================================================
-- 3. Trigger de vigência: fecha a versão anterior, valida ordem cronológica
-- ============================================================================

create or replace function private.close_previous_calendar_policy_version()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_open record;
begin
  select id, valid_from into v_open
  from public.calendar_policies
  where organization_id = new.organization_id
    and unit_id = new.unit_id
    and valid_to is null
  for update;

  if found then
    if new.valid_from <= v_open.valid_from then
      raise exception 'calendar policy version out of order' using errcode = '22023';
    end if;
    update public.calendar_policies
    set valid_to = new.valid_from
    where id = v_open.id;
  end if;

  return new;
end;
$$;

revoke all on function private.close_previous_calendar_policy_version() from public, anon, authenticated;

create trigger calendar_policies_close_previous_version
before insert on public.calendar_policies
for each row execute function private.close_previous_calendar_policy_version();

-- ============================================================================
-- 4. private.resolve_calendar_policy — 1ª função do Availability Resolver (D07)
--    Nasce aqui porque o trigger de turno ⊆ horário (seção 6) já a consome.
-- ============================================================================

create or replace function private.resolve_calendar_policy(
  p_organization_id uuid,
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
  from public.calendar_policies
  where organization_id = p_organization_id
    and unit_id = p_unit_id
    and valid_from <= v_wall_clock
    and v_wall_clock < coalesce(valid_to, 'infinity'::timestamptz);

  if v_schedule is null then
    return;
  end if;

  return query select coalesce(v_schedule -> v_dow, '[]'::jsonb);
end;
$$;

revoke all on function private.resolve_calendar_policy(uuid, uuid, date) from public, anon, authenticated;

-- ============================================================================
-- 5. professional_shifts — mesma forma de vigência, escopo profissional×unidade
-- ============================================================================

create table public.professional_shifts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  professional_id uuid not null,
  unit_id uuid not null,
  weekly_schedule jsonb not null check (private.valid_weekly_schedule(weekly_schedule)),
  valid_from timestamptz not null,
  valid_to timestamptz null,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  foreign key (organization_id, professional_id, unit_id)
    references public.professional_units(organization_id, professional_id, unit_id) on delete restrict,
  exclude using gist (
    organization_id with =,
    professional_id with =,
    unit_id with =,
    tstzrange(valid_from, coalesce(valid_to, 'infinity'), '[)') with &&
  )
);

create index professional_shifts_prof_unit_valid_from_idx on public.professional_shifts(organization_id, professional_id, unit_id, valid_from);

alter table public.professional_shifts enable row level security;

create policy professional_shifts_select
on public.professional_shifts for select to authenticated
using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin', 'manager'],
    array['reception', 'professional']
  )
);

create policy professional_shifts_insert
on public.professional_shifts for insert to authenticated
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

-- ============================================================================
-- 6. Trigger de vigência de professional_shifts: fecha versão anterior, valida
--    ordem cronológica, e valida a regra CRÍTICO "turno ⊆ horário da unidade"
--    (Master §2.4) — sem a isenção de calendar_exceptions (exceptional_opening),
--    que só existe a partir da fatia 024/025; documentado como limitação desta
--    fatia, não escondida.
-- ============================================================================

create or replace function private.close_previous_professional_shift_version()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_open record;
  v_policy_blocks jsonb;
  v_dow text;
  v_shift_block jsonb;
  v_policy_block jsonb;
  v_covered boolean;
begin
  -- A FK para professional_units só garante que ALGUMA linha de vínculo já
  -- existiu; ela não filtra por active (uma FK não pode expressar isso). O
  -- vínculo precisa estar ativo agora, não apenas ter existido algum dia.
  if not exists (
    select 1 from public.professional_units
    where organization_id = new.organization_id
      and professional_id = new.professional_id
      and unit_id = new.unit_id
      and active
  ) then
    raise exception 'professional has no active link to this unit' using errcode = '22023';
  end if;

  select id, valid_from into v_open
  from public.professional_shifts
  where organization_id = new.organization_id
    and professional_id = new.professional_id
    and unit_id = new.unit_id
    and valid_to is null
  for update;

  if found then
    if new.valid_from <= v_open.valid_from then
      raise exception 'professional shift version out of order' using errcode = '22023';
    end if;
    update public.professional_shifts
    set valid_to = new.valid_from
    where id = v_open.id;
  end if;

  -- turno ⊆ horário da unidade (Master §2.4, CRÍTICO), checado dia a dia.
  -- Não usa private.resolve_calendar_policy (que resolve uma data civil única)
  -- porque o turno é uma grade recorrente por dia da semana, não uma data —
  -- consulta calendar_policies diretamente pela versão vigente em new.valid_from.
  for v_dow in select jsonb_object_keys(new.weekly_schedule) loop
    select p.weekly_schedule -> v_dow into v_policy_blocks
    from public.calendar_policies p
    where p.organization_id = new.organization_id
      and p.unit_id = new.unit_id
      and p.valid_from <= new.valid_from
      and new.valid_from < coalesce(p.valid_to, 'infinity'::timestamptz);

    if v_policy_blocks is null then
      v_policy_blocks := '[]'::jsonb;
    end if;

    for v_shift_block in select * from jsonb_array_elements(new.weekly_schedule -> v_dow) loop
      v_covered := false;
      for v_policy_block in select * from jsonb_array_elements(v_policy_blocks) loop
        if (v_shift_block ->> 'start') >= (v_policy_block ->> 'start')
           and (v_shift_block ->> 'end') <= (v_policy_block ->> 'end') then
          v_covered := true;
          exit;
        end if;
      end loop;
      if not v_covered then
        raise exception 'shift outside unit hours without exceptional opening' using errcode = '22023';
      end if;
    end loop;
  end loop;

  return new;
end;
$$;

revoke all on function private.close_previous_professional_shift_version() from public, anon, authenticated;

create trigger professional_shifts_close_previous_version
before insert on public.professional_shifts
for each row execute function private.close_previous_professional_shift_version();
