-- Fase Opção C (ADRs 0010-0013): elegibilidade tri-state, snapshot operacional,
-- e appointments migrando para RPC transacional (create_appointment/update_appointment).

-- ============================================================================
-- ADR 0010: elegibilidade tri-state (INHERIT/ENABLED/DISABLED)
-- ============================================================================

-- (a) professional_service_capabilities.active (boolean) -> eligibility (tri-state)
alter table public.professional_service_capabilities add column eligibility text;
update public.professional_service_capabilities
set eligibility = case when active then 'ENABLED' else 'DISABLED' end;
alter table public.professional_service_capabilities
  alter column eligibility set not null,
  alter column eligibility set default 'ENABLED',
  add constraint professional_service_capabilities_eligibility_check
    check (eligibility in ('INHERIT', 'ENABLED', 'DISABLED'));

drop index if exists public.professional_service_capabilities_professional_idx;
drop index if exists public.professional_service_capabilities_service_idx;
create index professional_service_capabilities_professional_idx
  on public.professional_service_capabilities(organization_id, professional_id);
create index professional_service_capabilities_service_idx
  on public.professional_service_capabilities(organization_id, service_id);

alter table public.professional_service_capabilities drop column active;

-- (b) Atribuição em massa por grupo de serviço (paridade com o relato do Booksy)
create table public.professional_service_group_eligibility (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  professional_id uuid not null,
  service_group_id uuid not null,
  eligibility text not null default 'ENABLED' check (eligibility in ('INHERIT', 'ENABLED', 'DISABLED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, professional_id, service_group_id),
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  foreign key (organization_id, service_group_id) references public.service_groups(organization_id, id) on delete restrict
);

create index professional_service_group_eligibility_professional_idx
  on public.professional_service_group_eligibility(organization_id, professional_id);
create index professional_service_group_eligibility_group_idx
  on public.professional_service_group_eligibility(organization_id, service_group_id);

create trigger professional_service_group_eligibility_touch
before update on public.professional_service_group_eligibility
for each row execute function private.touch_updated_at();

alter table public.professional_service_group_eligibility enable row level security;

create policy professional_service_group_eligibility_select
on public.professional_service_group_eligibility for select
to authenticated
using (private.is_member(organization_id));

create policy professional_service_group_eligibility_insert
on public.professional_service_group_eligibility for insert
to authenticated
with check (private.has_role(organization_id, array['owner','admin','manager']));

create policy professional_service_group_eligibility_update
on public.professional_service_group_eligibility for update
to authenticated
using (private.has_role(organization_id, array['owner','admin','manager']))
with check (private.has_role(organization_id, array['owner','admin','manager']));

create policy professional_service_group_eligibility_delete
on public.professional_service_group_eligibility for delete
to authenticated
using (private.has_role(organization_id, array['owner','admin']));

-- (c) Default por organização — nasce ENABLED para todo tenant existente
alter table public.organizations
  add column default_service_eligibility text not null default 'ENABLED'
    check (default_service_eligibility in ('ENABLED', 'DISABLED'));

-- (d) Resolver: capability > grupo > default da organização ("mais específico vence")
create or replace function private.resolve_eligibility(
  p_organization_id uuid,
  p_professional_id uuid,
  p_service_id uuid
) returns table(eligible boolean, source text)
language plpgsql stable security definer set search_path = pg_catalog, public, private as $$
declare
  v_capability_eligibility text;
  v_group_id uuid;
  v_group_eligibility text;
  v_org_default text;
begin
  select psc.eligibility into v_capability_eligibility
  from public.professional_service_capabilities psc
  where psc.organization_id = p_organization_id
    and psc.professional_id = p_professional_id
    and psc.service_id = p_service_id;

  if v_capability_eligibility is not null and v_capability_eligibility <> 'INHERIT' then
    return query select (v_capability_eligibility = 'ENABLED'), 'capability';
    return;
  end if;

  select s.service_group_id into v_group_id
  from public.services s
  where s.organization_id = p_organization_id and s.id = p_service_id;

  if v_group_id is not null then
    select psge.eligibility into v_group_eligibility
    from public.professional_service_group_eligibility psge
    where psge.organization_id = p_organization_id
      and psge.professional_id = p_professional_id
      and psge.service_group_id = v_group_id;

    if v_group_eligibility is not null and v_group_eligibility <> 'INHERIT' then
      return query select (v_group_eligibility = 'ENABLED'), 'group';
      return;
    end if;
  end if;

  select o.default_service_eligibility into v_org_default
  from public.organizations o
  where o.id = p_organization_id;

  return query select (coalesce(v_org_default, 'ENABLED') = 'ENABLED'), 'org_default';
end;
$$;
-- Só é chamada de dentro de create_appointment/update_appointment (funções
-- security definer de propriedade do superuser da migration) — nunca
-- diretamente por service_role, mesmo padrão de private.actor_has_role.
revoke all on function private.resolve_eligibility(uuid, uuid, uuid) from public, anon, authenticated;

-- ============================================================================
-- ADR 0011: snapshot operacional (congela duração/origem no agendamento)
-- ============================================================================

alter table public.appointments add column resolved_duration_minutes integer;
alter table public.appointments add column resolved_eligibility_source text;
alter table public.appointments add column resolved_at timestamptz not null default now();

-- Backfill: deriva a duração do próprio intervalo já persistido (não há como
-- reconstruir a origem real retroativamente — 'org_default' é só metadado de
-- auditoria, não afeta comportamento; decisão registrada no ADR 0011).
update public.appointments
set resolved_duration_minutes = round(extract(epoch from (ends_at - starts_at)) / 60)::integer,
    resolved_eligibility_source = 'org_default';

alter table public.appointments
  alter column resolved_duration_minutes set not null,
  alter column resolved_eligibility_source set not null,
  alter column resolved_eligibility_source set default 'org_default',
  add constraint appointments_resolved_duration_check check (resolved_duration_minutes between 5 and 1440),
  add constraint appointments_resolved_eligibility_source_check
    check (resolved_eligibility_source in ('capability', 'group', 'org_default'));

-- create_appointment/update_appointment always set resolved_duration_minutes
-- explicitly from the real resolver (never relies on this fallback). This
-- trigger only covers inserts that bypass the RPC entirely (test fixtures
-- creating an appointment incidentally, e.g. to exercise a FK-conflict on
-- deleting a client) — same derivation as the backfill above, so the value
-- stays meaningful instead of an arbitrary placeholder.
create or replace function private.default_appointment_resolved_duration()
returns trigger language plpgsql security definer set search_path = pg_catalog as $$
begin
  if new.resolved_duration_minutes is null then
    new.resolved_duration_minutes := round(extract(epoch from (new.ends_at - new.starts_at)) / 60)::integer;
  end if;
  return new;
end;
$$;
revoke all on function private.default_appointment_resolved_duration() from public, anon, authenticated;
create trigger appointments_default_resolved_duration
before insert on public.appointments
for each row execute function private.default_appointment_resolved_duration();

-- ============================================================================
-- ADR 0012 + 0013: create_appointment / update_appointment (RPC transacional)
-- ============================================================================
-- Absorve para dentro do Postgres o que hoje vive em appointments.service.js:
-- resolução de elegibilidade/duração, idempotência atômica (mesmo padrão de
-- checkout_close/inventory_adjust) e concorrência otimista via `version`.

create or replace function public.create_appointment(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_client_id uuid := nullif(p_payload ->> 'client_id', '')::uuid;
  v_professional_id uuid := nullif(p_payload ->> 'professional_id', '')::uuid;
  v_service_id uuid := nullif(p_payload ->> 'service_id', '')::uuid;
  v_starts_at timestamptz := (p_payload ->> 'starts_at')::timestamptz;
  v_status text := coalesce(p_payload ->> 'status', 'scheduled');
  v_eligible boolean;
  v_source text;
  v_duration integer;
  v_ends_at timestamptz;
  v_appointment_id uuid := gen_random_uuid();
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, v_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  if v_client_id is null or v_professional_id is null or v_service_id is null or v_starts_at is null then
    raise exception 'client_id, professional_id, service_id and starts_at are required' using errcode = '22023';
  end if;

  if not exists (select 1 from public.clients where organization_id = p_organization_id and id = v_client_id) then
    raise exception 'client not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.professionals where organization_id = p_organization_id and id = v_professional_id) then
    raise exception 'professional not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.services where organization_id = p_organization_id and id = v_service_id) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;

  select r.eligible, r.source into v_eligible, v_source
  from private.resolve_eligibility(p_organization_id, v_professional_id, v_service_id) r;
  if not v_eligible then
    raise exception 'professional is not eligible for this service' using errcode = 'P0003';
  end if;

  select coalesce(psc.duration_override_minutes, s.duration_minutes) into v_duration
  from public.services s
  left join public.professional_service_capabilities psc
    on psc.organization_id = p_organization_id
   and psc.professional_id = v_professional_id
   and psc.service_id = v_service_id
  where s.organization_id = p_organization_id and s.id = v_service_id;

  v_ends_at := v_starts_at + (v_duration || ' minutes')::interval;

  insert into public.appointments(
    id, organization_id, client_id, professional_id, service_id,
    starts_at, ends_at, status, created_by,
    resolved_duration_minutes, resolved_eligibility_source, resolved_at
  ) values (
    v_appointment_id, p_organization_id, v_client_id, v_professional_id, v_service_id,
    v_starts_at, v_ends_at, v_status, v_user_id,
    v_duration, v_source, now()
  );

  select jsonb_build_object(
    'id', a.id, 'client_id', a.client_id, 'professional_id', a.professional_id,
    'service_id', a.service_id, 'starts_at', a.starts_at, 'ends_at', a.ends_at,
    'status', a.status, 'version', a.version,
    'resolved_duration_minutes', a.resolved_duration_minutes,
    'resolved_eligibility_source', a.resolved_eligibility_source,
    'resolved_at', a.resolved_at, 'created_at', a.created_at, 'updated_at', a.updated_at
  ) into v_response
  from public.appointments a
  where a.organization_id = p_organization_id and a.id = v_appointment_id;

  v_response := jsonb_build_object('status', 'applied', 'appointment', v_response);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.create_appointment(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.create_appointment(uuid, uuid, text, jsonb) to service_role;

create or replace function public.update_appointment(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_appointment_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_current public.appointments%rowtype;
  v_touches_config boolean;
  v_client_id uuid;
  v_professional_id uuid;
  v_service_id uuid;
  v_starts_at timestamptz;
  v_status text;
  v_confirm boolean := coalesce((p_payload ->> 'confirm')::boolean, false);
  v_eligible boolean;
  v_source text;
  v_duration integer;
  v_ends_at timestamptz;
  v_response jsonb;
  v_appt_json jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, v_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  select * into v_current from public.appointments
  where organization_id = p_organization_id and id = p_appointment_id
  for update;
  if not found then raise exception 'appointment not found' using errcode = 'P0005'; end if;

  if not (p_payload ? 'version') or (p_payload ->> 'version') is null then
    raise exception 'version is required' using errcode = '22023';
  end if;
  if v_current.version <> (p_payload ->> 'version')::bigint then
    raise exception 'appointment version conflict' using errcode = 'P0004';
  end if;

  v_client_id := case when p_payload ? 'client_id' then (p_payload ->> 'client_id')::uuid else v_current.client_id end;
  v_professional_id := case when p_payload ? 'professional_id' then (p_payload ->> 'professional_id')::uuid else v_current.professional_id end;
  v_service_id := case when p_payload ? 'service_id' then (p_payload ->> 'service_id')::uuid else v_current.service_id end;
  v_starts_at := case when p_payload ? 'starts_at' then (p_payload ->> 'starts_at')::timestamptz else v_current.starts_at end;
  v_status := case when p_payload ? 'status' then p_payload ->> 'status' else v_current.status end;
  v_touches_config := (p_payload ? 'professional_id') or (p_payload ? 'service_id');

  if p_payload ? 'client_id' and not exists (
    select 1 from public.clients where organization_id = p_organization_id and id = v_client_id
  ) then
    raise exception 'client not found' using errcode = 'P0002';
  end if;
  if v_touches_config and not exists (
    select 1 from public.professionals where organization_id = p_organization_id and id = v_professional_id
  ) then
    raise exception 'professional not found' using errcode = 'P0002';
  end if;
  if v_touches_config and not exists (
    select 1 from public.services where organization_id = p_organization_id and id = v_service_id
  ) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;

  if v_touches_config then
    -- Reconfiguração real (profissional e/ou serviço mudou): re-resolve do zero.
    select r.eligible, r.source into v_eligible, v_source
    from private.resolve_eligibility(p_organization_id, v_professional_id, v_service_id) r;
    if not v_eligible then
      raise exception 'professional is not eligible for this service' using errcode = 'P0003';
    end if;

    select coalesce(psc.duration_override_minutes, s.duration_minutes) into v_duration
    from public.services s
    left join public.professional_service_capabilities psc
      on psc.organization_id = p_organization_id
     and psc.professional_id = v_professional_id
     and psc.service_id = v_service_id
    where s.organization_id = p_organization_id and s.id = v_service_id;

    v_ends_at := v_starts_at + (v_duration || ' minutes')::interval;

    if not v_confirm then
      -- ADR 0013: Change Plan — mostra o diff, não aplica. Não persiste
      -- resposta de idempotência: é uma leitura, sem mutação, livre para
      -- ser recalculada em qualquer retry com a mesma chave.
      return jsonb_build_object(
        'status', 'confirmation_required',
        'diff', jsonb_build_object(
          'current', jsonb_build_object(
            'professional_id', v_current.professional_id, 'service_id', v_current.service_id,
            'starts_at', v_current.starts_at, 'ends_at', v_current.ends_at,
            'resolved_duration_minutes', v_current.resolved_duration_minutes,
            'resolved_eligibility_source', v_current.resolved_eligibility_source
          ),
          'proposed', jsonb_build_object(
            'professional_id', v_professional_id, 'service_id', v_service_id,
            'starts_at', v_starts_at, 'ends_at', v_ends_at,
            'resolved_duration_minutes', v_duration,
            'resolved_eligibility_source', v_source
          )
        )
      );
    end if;
  else
    -- MOVE_TIME_ONLY (ADR 0011): preserva a duração/origem já congeladas.
    v_duration := v_current.resolved_duration_minutes;
    v_source := v_current.resolved_eligibility_source;
    v_ends_at := v_starts_at + (v_duration || ' minutes')::interval;
  end if;

  update public.appointments set
    client_id = v_client_id,
    professional_id = v_professional_id,
    service_id = v_service_id,
    starts_at = v_starts_at,
    ends_at = v_ends_at,
    status = v_status,
    resolved_duration_minutes = v_duration,
    resolved_eligibility_source = v_source,
    resolved_at = case when v_touches_config then now() else resolved_at end
  where organization_id = p_organization_id and id = p_appointment_id;

  select jsonb_build_object(
    'id', a.id, 'client_id', a.client_id, 'professional_id', a.professional_id,
    'service_id', a.service_id, 'starts_at', a.starts_at, 'ends_at', a.ends_at,
    'status', a.status, 'version', a.version,
    'resolved_duration_minutes', a.resolved_duration_minutes,
    'resolved_eligibility_source', a.resolved_eligibility_source,
    'resolved_at', a.resolved_at, 'created_at', a.created_at, 'updated_at', a.updated_at
  ) into v_appt_json
  from public.appointments a
  where a.organization_id = p_organization_id and a.id = p_appointment_id;

  v_response := jsonb_build_object('status', 'applied', 'appointment', v_appt_json);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.update_appointment(uuid, uuid, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.update_appointment(uuid, uuid, text, uuid, jsonb) to service_role;
