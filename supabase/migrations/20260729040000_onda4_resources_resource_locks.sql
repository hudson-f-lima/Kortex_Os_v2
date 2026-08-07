-- KortexOS 5.1.2 — Onda 4, fatia 026: resources + resource_locks + RPCs.
-- Implementa docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md
-- (APROVADO, DEC-49), §2, §3.3, §3.8, §4.

-- ============================================================================
-- Pre-flight check (DEC-44 item 2)
-- ============================================================================
do $$
begin
  if to_regclass('public.units') is null then
    raise exception 'pre-flight failed: public.units does not exist';
  end if;
  if to_regclass('public.appointments') is null then
    raise exception 'pre-flight failed: public.appointments does not exist';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'appointments_org_id_unit_unique') then
    raise exception 'pre-flight failed: appointments_org_id_unit_unique does not exist';
  end if;
  if to_regclass('public.resources') is not null then
    raise exception 'pre-flight failed: public.resources already exists';
  end if;
end;
$$;

-- ============================================================================
-- 1. resources
-- ============================================================================

create table public.resources (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  name text not null check (length(trim(name)) between 1 and 120),
  resource_type text not null check (resource_type in ('room', 'chair', 'equipment', 'other')),
  capacity integer null check (capacity >= 1),
  active boolean not null default true,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_by uuid,
  updated_at timestamptz not null default now(),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  unique (organization_id, id, unit_id)
);

create unique index resources_name_unique_idx on public.resources(organization_id, unit_id, lower(trim(name)));
create index resources_unit_active_idx on public.resources(organization_id, unit_id, active);

create trigger resources_touch before update on public.resources for each row execute function private.touch_updated_at();

alter table public.resources enable row level security;

create policy resources_select
on public.resources for select to authenticated
using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin', 'manager'],
    array['reception', 'professional']
  )
);

create policy resources_insert
on public.resources for insert to authenticated
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

create policy resources_update
on public.resources for update to authenticated
using (private.has_role(organization_id, array['owner', 'admin', 'manager']))
with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

-- Sem policy de DELETE: desativação via active = false, mesmo padrão de units.

-- ============================================================================
-- 2. resource_locks
-- ============================================================================

create extension if not exists btree_gist;

create table public.resource_locks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  resource_id uuid not null,
  appointment_id uuid null,
  lock_reason text not null check (lock_reason in ('appointment', 'maintenance', 'blocked')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'active' check (status in ('active', 'released', 'expired')),
  version bigint not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  released_by uuid,
  released_at timestamptz,
  check (ends_at > starts_at),
  check ((lock_reason = 'appointment') = (appointment_id is not null)),
  check ((status = 'active') = (released_by is null and released_at is null)),
  foreign key (organization_id, resource_id, unit_id) references public.resources(organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, appointment_id, unit_id) references public.appointments(organization_id, id, unit_id) on delete restrict,
  exclude using gist (
    organization_id with =,
    resource_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status = 'active')
);

create index resource_locks_unit_status_idx on public.resource_locks(organization_id, unit_id, status);

alter table public.resource_locks enable row level security;

create policy resource_locks_select
on public.resource_locks for select to authenticated
using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin', 'manager'],
    array['reception', 'professional']
  )
);

-- Sem policy de INSERT/UPDATE/DELETE: só as RPCs abaixo (security definer) escrevem.

create or replace function private.enforce_resource_lock_version()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'UPDATE' then
    new.version := old.version + 1;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_resource_lock_version() from public, anon, authenticated;

create trigger resource_locks_increment_version
before update on public.resource_locks
for each row execute function private.enforce_resource_lock_version();

-- ============================================================================
-- 3. RPCs: resource_lock_create / resource_lock_release
-- ============================================================================

create or replace function public.resource_lock_create(
  p_organization_id uuid,
  p_unit_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_resource_id uuid,
  p_lock_reason text,
  p_appointment_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_reason text
)
returns public.resource_locks
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_membership public.memberships;
  v_hash text := encode(digest(
    jsonb_build_object(
      'resource_id', p_resource_id, 'lock_reason', p_lock_reason, 'appointment_id', p_appointment_id,
      'starts_at', p_starts_at, 'ends_at', p_ends_at
    )::text, 'sha256'
  ), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_lock public.resource_locks;
begin
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;

  if p_reason is not null and length(trim(p_reason)) > 500 then
    raise exception 'resource lock reason is too long' using errcode = '22023';
  end if;

  select * into v_membership
  from public.memberships
  where organization_id = p_organization_id and user_id = p_actor_user_id and active;

  if not found or not (
    v_membership.role in ('owner', 'admin', 'manager')
    or (v_membership.role in ('reception') and v_membership.unit_id = p_unit_id)
  ) then
    raise exception 'actor is not authorized to create a resource lock in this unit' using errcode = '42501';
  end if;

  if (p_lock_reason = 'appointment') <> (p_appointment_id is not null) then
    raise exception 'appointment_id must be set if and only if lock_reason = appointment' using errcode = '22023';
  end if;

  insert into private.idempotency_keys (organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;

  select * into v_existing
  from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;

  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with a different payload' using errcode = '22023';
  end if;

  if v_existing.response is not null then
    select * into v_lock from public.resource_locks where id = (v_existing.response ->> 'id')::uuid;
    return v_lock;
  end if;

  if p_lock_reason = 'appointment' then
    if not exists (
      select 1 from public.appointments
      where organization_id = p_organization_id and id = p_appointment_id and unit_id = p_unit_id
    ) then
      raise exception 'appointment does not belong to this organization/unit' using errcode = '22023';
    end if;
  end if;

  begin
    insert into public.resource_locks (
      organization_id, unit_id, resource_id, appointment_id, lock_reason,
      starts_at, ends_at, created_by
    ) values (
      p_organization_id, p_unit_id, p_resource_id, p_appointment_id, p_lock_reason,
      p_starts_at, p_ends_at, p_actor_user_id
    )
    returning * into v_lock;
  exception
    when exclusion_violation then
      raise exception 'resource is already locked for this time range' using errcode = '23P01';
  end;

  update private.idempotency_keys
  set response = jsonb_build_object('id', v_lock.id)
  where organization_id = p_organization_id and key = p_idempotency_key;

  return v_lock;
end;
$$;

revoke all on function public.resource_lock_create(uuid, uuid, uuid, text, uuid, text, uuid, timestamptz, timestamptz, text) from public, anon, authenticated;
grant execute on function public.resource_lock_create(uuid, uuid, uuid, text, uuid, text, uuid, timestamptz, timestamptz, text) to service_role;

create or replace function public.resource_lock_release(
  p_organization_id uuid,
  p_unit_id uuid,
  p_actor_user_id uuid,
  p_resource_lock_id uuid,
  p_version bigint
)
returns public.resource_locks
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_membership public.memberships;
  v_current public.resource_locks;
  v_result public.resource_locks;
begin
  select * into v_membership
  from public.memberships
  where organization_id = p_organization_id and user_id = p_actor_user_id and active;

  if not found or not (
    v_membership.role in ('owner', 'admin', 'manager')
    or (v_membership.role in ('reception') and v_membership.unit_id = p_unit_id)
  ) then
    raise exception 'actor is not authorized to release a resource lock in this unit' using errcode = '42501';
  end if;

  select * into v_current
  from public.resource_locks
  where id = p_resource_lock_id and organization_id = p_organization_id and unit_id = p_unit_id
  for update;

  if not found then
    raise exception 'resource lock not found' using errcode = '22023';
  end if;

  -- Correção de achado de auditoria pós-implementação (2026-07-29): a versão
  -- original só comparava version, então uma segunda chamada de release com
  -- a version JÁ atualizada (devolvida pela primeira chamada) passava sem
  -- erro e reescrevia released_by/released_at — inclusive por um ator
  -- diferente do que liberou originalmente. status precisa estar 'active'.
  if v_current.status <> 'active' then
    raise exception 'resource lock is not active' using errcode = '22023';
  end if;

  if v_current.version <> p_version then
    raise exception 'resource lock version conflict' using errcode = 'P0004';
  end if;

  update public.resource_locks
  set status = 'released', released_by = p_actor_user_id, released_at = now()
  where id = p_resource_lock_id
  returning * into v_result;

  return v_result;
end;
$$;

revoke all on function public.resource_lock_release(uuid, uuid, uuid, uuid, bigint) from public, anon, authenticated;
grant execute on function public.resource_lock_release(uuid, uuid, uuid, uuid, bigint) to service_role;
