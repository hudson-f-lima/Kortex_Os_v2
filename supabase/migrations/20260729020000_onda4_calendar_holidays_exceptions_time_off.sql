-- KortexOS 5.1.2 — Onda 4, fatia 024: calendar_holidays + calendar_exceptions
-- + calendar_time_off. Implementa
-- docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md
-- (APROVADO, DEC-49), §2, §3.5, §3.8, §4.

-- ============================================================================
-- Pre-flight check (DEC-44 item 2)
-- ============================================================================
do $$
begin
  if to_regclass('public.units') is null then
    raise exception 'pre-flight failed: public.units does not exist';
  end if;
  if to_regclass('public.professionals') is null then
    raise exception 'pre-flight failed: public.professionals does not exist';
  end if;
  if to_regclass('public.calendar_holidays') is not null then
    raise exception 'pre-flight failed: public.calendar_holidays already exists';
  end if;
end;
$$;

-- ============================================================================
-- 1. calendar_holidays
-- ============================================================================

create table public.calendar_holidays (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid null,
  holiday_date date not null,
  name text not null check (length(trim(name)) between 1 and 120),
  holiday_type text not null check (holiday_type in ('national', 'state', 'municipal', 'custom')),
  unit_opens boolean not null default false,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_by uuid,
  updated_at timestamptz not null default now(),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict
);

create unique index calendar_holidays_org_wide_unique_idx on public.calendar_holidays(organization_id, holiday_date) where unit_id is null;
create unique index calendar_holidays_unit_unique_idx on public.calendar_holidays(organization_id, unit_id, holiday_date) where unit_id is not null;

create trigger calendar_holidays_touch before update on public.calendar_holidays for each row execute function private.touch_updated_at();

alter table public.calendar_holidays enable row level security;

-- SELECT: papéis org-wide sempre veem; papéis unit-scoped veem feriados
-- org-wide (unit_id is null, aplica a todas as unidades) OU específicos da
-- própria unidade — private.can_access_fact_unit não serve aqui sozinha
-- porque comparação com unit_id nulo nunca é verdadeira (lógica de 3 valores
-- do SQL), o que esconderia todo feriado org-wide de reception/professional.
create policy calendar_holidays_select
on public.calendar_holidays for select to authenticated
using (
  private.has_role(organization_id, array['owner', 'admin', 'manager'])
  or (
    unit_id is null
    and private.is_member(organization_id)
  )
  or private.can_access_fact_unit(organization_id, unit_id, array[]::text[], array['reception', 'professional'])
);

create policy calendar_holidays_insert
on public.calendar_holidays for insert to authenticated
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

create policy calendar_holidays_update
on public.calendar_holidays for update to authenticated
using (private.has_role(organization_id, array['owner', 'admin', 'manager']))
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

create policy calendar_holidays_delete
on public.calendar_holidays for delete to authenticated
using (private.has_role(organization_id, array['owner', 'admin']));

-- ============================================================================
-- 2. calendar_exceptions — consolida 3 dos 8 objetos de política do Master
--    §2.2 (exceção pontual, fechamento excepcional, abertura excepcional).
-- ============================================================================

create table public.calendar_exceptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  exception_type text not null check (exception_type in ('punctual_override', 'exceptional_closure', 'exceptional_opening')),
  scope text not null check (scope in ('unit', 'professional')),
  unit_id uuid not null,
  professional_id uuid null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_open boolean not null,
  reason text not null check (length(trim(reason)) between 1 and 500),
  authored_by uuid not null,
  authorized_by uuid null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check ((scope = 'professional') = (professional_id is not null)),
  check (exception_type <> 'punctual_override' or authorized_by is not null),
  check (exception_type <> 'exceptional_closure' or is_open = false),
  check (exception_type <> 'exceptional_opening' or is_open = true),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  -- Correção de achado de auditoria pós-implementação (2026-07-29): a FK
  -- acima só garante que o profissional existe na organização, não que ele
  -- tem vínculo com a MESMA unit_id desta exceção — permitia criar uma
  -- exceção scope='professional' para um profissional que nunca atuou
  -- naquela unidade. FK composta contra professional_units fecha isso; como
  -- professional_id é nullable e o padrão de FK é MATCH SIMPLE, ela só é
  -- avaliada quando professional_id não é nulo (scope='professional') —
  -- linhas scope='unit' (professional_id sempre nulo, pelo check acima)
  -- não são afetadas.
  foreign key (organization_id, professional_id, unit_id) references public.professional_units(organization_id, professional_id, unit_id) on delete restrict
);

create index calendar_exceptions_unit_range_idx on public.calendar_exceptions(organization_id, unit_id, starts_at, ends_at);

alter table public.calendar_exceptions enable row level security;

create policy calendar_exceptions_select
on public.calendar_exceptions for select to authenticated
using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin', 'manager'],
    array['reception', 'professional']
  )
);

create policy calendar_exceptions_insert
on public.calendar_exceptions for insert to authenticated
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

-- Nenhuma policy de UPDATE/DELETE: exceção pontual expira naturalmente por
-- ends_at ou é superada por uma exceção nova, mesmo princípio de imutabilidade
-- já usado em calendar_policies (Blueprint §3.8 — sem grant de UPDATE/DELETE).

-- ============================================================================
-- 3. calendar_time_off — folga/férias do profissional (org-wide, sem unit_id
--    próprio: o profissional pode atuar em mais de uma unidade).
-- ============================================================================

create table public.calendar_time_off (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  professional_id uuid not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text null,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  exclude using gist (
    organization_id with =,
    professional_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  )
);

create index calendar_time_off_professional_idx on public.calendar_time_off(organization_id, professional_id, starts_at);

alter table public.calendar_time_off enable row level security;

-- Sem unit_id na própria linha: papéis org-wide sempre veem; papéis
-- unit-scoped (reception/professional) veem a folga de um profissional
-- somente se esse profissional tiver vínculo ativo com a MESMA unidade da
-- membership de quem consulta (não a organização inteira) — evita o mesmo
-- vazamento entre unidades já corrigido nas demais tabelas desta Onda.
-- security definer (mesmo motivo de private.can_access_fact_unit): a policy
-- roda com o privilégio do papel authenticated, que não tem grant direto em
-- memberships/professional_units — sem security definer, a subquery falharia
-- com "permission denied" antes mesmo de a RLS dessas tabelas ser avaliada.
create or replace function private.can_access_professional_time_off(
  p_organization_id uuid,
  p_professional_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.memberships m
    join public.professional_units pu
      on pu.organization_id = m.organization_id
     and pu.unit_id = m.unit_id
     and pu.active
    where m.organization_id = p_organization_id
      and m.user_id = (select auth.uid())
      and m.active
      and m.role in ('reception', 'professional')
      and pu.professional_id = p_professional_id
  );
$$;

revoke all on function private.can_access_professional_time_off(uuid, uuid) from public, anon;
grant execute on function private.can_access_professional_time_off(uuid, uuid) to authenticated;

create policy calendar_time_off_select
on public.calendar_time_off for select to authenticated
using (
  private.has_role(organization_id, array['owner', 'admin', 'manager'])
  or private.can_access_professional_time_off(organization_id, professional_id)
);

create policy calendar_time_off_insert
on public.calendar_time_off for insert to authenticated
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

-- Sem policy de UPDATE/DELETE nesta fatia: folga cadastrada incorretamente é
-- corrigida por uma folga nova + fim manual da antiga, não edição in-place —
-- mesmo racional de não permitir reescrever histórico já usado nas demais
-- tabelas de política desta Onda. Revisitável se virar necessidade real.
