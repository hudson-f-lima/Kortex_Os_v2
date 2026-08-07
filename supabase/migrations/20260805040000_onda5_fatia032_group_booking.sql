-- Onda 5, fatia 032 (issues/032-onda5-group-booking.md, DEC-51/DEC-52).
-- Implementa
-- docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md
-- §3.2/§4.4/§4.2 — appointment_groups (agregado-pai) e appointments.group_id
-- (filhos independentes). Aplicada DEPOIS da fatia 033 (participantes/
-- titular) porque cada filho de grupo depende do trigger de titular já
-- existir para ganhar sua linha em appointment_participants automaticamente.
--
-- Diferente da recorrência (fatia 030/031), criação de grupo é tudo-ou-nada
-- por desenho (Blueprint §3.2.2) — não existe conceito de "conflito
-- persistente" aqui: uma falha em qualquer filho propaga a exceção para
-- fora da função inteira, revertendo a transação completa (incluindo a
-- própria linha de appointment_groups). Sem savepoint por filho, ao
-- contrário de private.onda5_materialize_series_occurrence.
--
-- appointment_groups.status é inteiramente derivado dos filhos (nunca
-- setado "à mão" fora das RPCs desta fatia e do trigger de sincronização) —
-- leitura literal de "o grupo fica ativo enquanto existir filho futuro
-- confirmado; fica cancelado quando todos os filhos futuros forem
-- cancelados" (§3.2.6), generalizada para todos os filhos (não só os
-- futuros): SCHEDULED enquanto nenhum filho está cancelado, PARTIAL quando
-- parte foi cancelada, COMPLETED quando todo filho não-cancelado chegou a
-- completed, CANCELLED quando todos os filhos foram cancelados. DRAFT
-- permanece um estado válido do enum sem produtor nesta fatia (reservado
-- para um fluxo futuro de rascunho) — criação atômica nunca deixa um grupo
-- inacabado.

do $$
begin
  if to_regclass('public.appointments') is null then
    raise exception 'pre-flight failed: public.appointments does not exist';
  end if;
  if to_regclass('public.appointment_participants') is null then
    raise exception 'pre-flight failed: public.appointment_participants does not exist (fatia 033 must run first)';
  end if;
  if to_regprocedure('public.create_appointment(uuid,uuid,text,jsonb)') is null then
    raise exception 'pre-flight failed: public.create_appointment does not exist';
  end if;
  if not exists (select 1 from pg_constraint where conname = 'appointments_org_id_unit_unique') then
    raise exception 'pre-flight failed: appointments_org_id_unit_unique does not exist';
  end if;
  if to_regclass('public.appointment_groups') is not null then
    raise exception 'pre-flight failed: public.appointment_groups already exists';
  end if;
end $$;

-- ============================================================================
-- 1. appointment_groups (Blueprint §4.4)
-- ============================================================================

create table public.appointment_groups (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  requester_client_id uuid not null,
  status text not null default 'SCHEDULED' check (status in ('DRAFT', 'SCHEDULED', 'PARTIAL', 'CANCELLED', 'COMPLETED')),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id, unit_id),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  foreign key (organization_id, requester_client_id) references public.clients(organization_id, id),
  foreign key (organization_id, created_by) references public.memberships(organization_id, user_id) on delete restrict
);

create index appointment_groups_unit_status_idx on public.appointment_groups(organization_id, unit_id, status);

create trigger appointment_groups_touch before update on public.appointment_groups
  for each row execute function private.touch_updated_at();

alter table public.appointment_groups enable row level security;

create policy appointment_groups_select on public.appointment_groups for select to authenticated using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin'],
    array['manager', 'reception', 'professional']
  )
);
-- Escrita: nenhum grant direto a authenticated — só via RPCs security
-- definer (appointment_group_create/_update/_cancel/_member_add, abaixo).

-- ============================================================================
-- 2. appointments.group_id (Blueprint §4.2/§4.4) — aditiva, nullable,
--    unit-safe. create_appointment já validava unit_id para origin='group'
--    desde a fatia 030 (comentário: "group ainda não tem tabela própria");
--    esta fatia acrescenta a coluna e a validação do group_id em si.
-- ============================================================================

alter table public.appointments add column group_id uuid;
alter table public.appointments add constraint appointments_org_group_unit_fk
  foreign key (organization_id, group_id, unit_id)
  references public.appointment_groups(organization_id, id, unit_id);

create index appointments_group_idx on public.appointments(organization_id, group_id) where group_id is not null;

-- ============================================================================
-- 3. Sincronização de status do grupo — recomputa a partir dos filhos reais
--    toda vez que o status de um filho muda, e é chamada explicitamente
--    pelas próprias RPCs de grupo logo após mutarem filhos (create/cancel/
--    member_add). appointments continua a única fonte de verdade de
--    ocupação (Blueprint §1); este status é só um resumo derivado, nunca a
--    fonte primária.
-- ============================================================================

create or replace function private.onda5_recompute_group_status(
  p_organization_id uuid,
  p_group_id uuid
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_total integer;
  v_cancelled integer;
  v_completed integer;
begin
  select count(*), count(*) filter (where status = 'cancelled'), count(*) filter (where status = 'completed')
  into v_total, v_cancelled, v_completed
  from public.appointments
  where organization_id = p_organization_id and group_id = p_group_id;

  if v_total = 0 then
    return;
  end if;

  update public.appointment_groups set status = (
    case
      when v_cancelled = v_total then 'CANCELLED'
      when v_completed = (v_total - v_cancelled) then 'COMPLETED'
      when v_cancelled > 0 then 'PARTIAL'
      else 'SCHEDULED'
    end
  )
  where organization_id = p_organization_id and id = p_group_id;
end;
$$;
revoke all on function private.onda5_recompute_group_status(uuid, uuid) from public, anon, authenticated;

create or replace function private.onda5_on_group_child_status_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.group_id is not null and old.status is distinct from new.status then
    perform private.onda5_recompute_group_status(new.organization_id, new.group_id);
  end if;
  return new;
end;
$$;
revoke all on function private.onda5_on_group_child_status_change() from public, anon, authenticated;

create trigger appointments_group_status_sync
  after update of status on public.appointments
  for each row execute function private.onda5_on_group_child_status_change();

-- ============================================================================
-- 4. create_appointment (extensão) — Blueprint §4.2/§4.4. 3ª revisão desta
--    função (fatia 030 introduziu origin/unit_id/series_id; esta acrescenta
--    group_id). Preserva assinatura e comportamento de todo chamador
--    existente — group_id é opcional, só obrigatório/validado quando
--    origin='group'.
-- ============================================================================

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
  v_origin text := coalesce(p_payload ->> 'origin', 'direct');
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_series_id uuid := nullif(p_payload ->> 'series_id', '')::uuid;
  v_group_id uuid := nullif(p_payload ->> 'group_id', '')::uuid;
  v_duration_override integer := nullif(p_payload ->> 'duration_minutes', '')::integer;
  v_timezone text;
  v_local_date date;
  v_start_minutes integer;
  v_end_minutes integer;
  v_override_open boolean;
  v_override_reason text;
  v_policy_blocks jsonb;
  v_shift_blocks jsonb;
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
  if v_origin not in ('direct', 'series', 'group', 'waitlist') then
    raise exception 'invalid origin' using errcode = '22023';
  end if;
  if v_origin <> 'direct' and v_unit_id is null then
    raise exception 'unit_id is required for origin <> direct' using errcode = '22023';
  end if;
  if v_origin = 'group' and v_group_id is null then
    raise exception 'group_id is required for origin group' using errcode = '22023';
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
  if v_unit_id is not null and not exists (
    select 1 from public.units where organization_id = p_organization_id and id = v_unit_id
  ) then
    raise exception 'unit not found' using errcode = 'P0002';
  end if;

  select r.eligible, r.source into v_eligible, v_source
  from private.resolve_eligibility(p_organization_id, v_professional_id, v_service_id) r;
  if not v_eligible then
    raise exception 'professional is not eligible for this service' using errcode = 'P0003';
  end if;

  if v_duration_override is not null then
    if v_duration_override <= 0 then
      raise exception 'duration_minutes must be positive' using errcode = '22023';
    end if;
    v_duration := v_duration_override;
  else
    select coalesce(psc.duration_override_minutes, s.duration_minutes) into v_duration
    from public.services s
    left join public.professional_service_capabilities psc
      on psc.organization_id = p_organization_id
     and psc.professional_id = v_professional_id
     and psc.service_id = v_service_id
    where s.organization_id = p_organization_id and s.id = v_service_id;
  end if;

  v_ends_at := v_starts_at + (v_duration || ' minutes')::interval;

  if v_origin <> 'direct' then
    select timezone into v_timezone from public.units
    where organization_id = p_organization_id and id = v_unit_id;

    v_local_date := (v_starts_at at time zone v_timezone)::date;
    v_start_minutes := extract(hour from (v_starts_at at time zone v_timezone))::int * 60
      + extract(minute from (v_starts_at at time zone v_timezone))::int;
    v_end_minutes := extract(hour from (v_ends_at at time zone v_timezone))::int * 60
      + extract(minute from (v_ends_at at time zone v_timezone))::int;
    if v_end_minutes <= v_start_minutes then
      raise exception 'origin candidate cannot cross local midnight' using errcode = '22023';
    end if;

    select o.is_open, o.reason into v_override_open, v_override_reason
    from private.resolve_calendar_overrides(p_organization_id, v_unit_id, v_professional_id, v_local_date) o;
    if v_override_open is not null and v_override_open = false then
      raise exception 'slot outside calendar availability (%)' , v_override_reason using errcode = 'P0006';
    end if;

    select p.blocks into v_policy_blocks
    from private.resolve_calendar_policy(p_organization_id, v_unit_id, v_local_date) p;
    if not private.onda5_range_within_blocks(v_policy_blocks, v_start_minutes, v_end_minutes) then
      raise exception 'slot outside unit calendar policy' using errcode = 'P0006';
    end if;

    select s.blocks into v_shift_blocks
    from private.resolve_professional_shift(p_organization_id, v_professional_id, v_unit_id, v_local_date) s;
    if not private.onda5_range_within_blocks(v_shift_blocks, v_start_minutes, v_end_minutes) then
      raise exception 'slot outside professional shift' using errcode = 'P0006';
    end if;

    if v_series_id is not null and not exists (
      select 1 from public.appointment_series
      where organization_id = p_organization_id and id = v_series_id and unit_id = v_unit_id
    ) then
      raise exception 'series not found' using errcode = 'P0002';
    end if;

    if v_group_id is not null and not exists (
      select 1 from public.appointment_groups
      where organization_id = p_organization_id and id = v_group_id and unit_id = v_unit_id
    ) then
      raise exception 'group not found' using errcode = 'P0002';
    end if;
  end if;

  insert into public.appointments(
    id, organization_id, client_id, professional_id, service_id,
    starts_at, ends_at, status, created_by,
    resolved_duration_minutes, resolved_eligibility_source, resolved_at,
    unit_id, series_id, group_id
  ) values (
    v_appointment_id, p_organization_id, v_client_id, v_professional_id, v_service_id,
    v_starts_at, v_ends_at, v_status, v_user_id,
    v_duration, v_source, now(),
    v_unit_id, v_series_id, v_group_id
  );

  select jsonb_build_object(
    'id', a.id, 'organization_id', a.organization_id, 'client_id', a.client_id, 'professional_id', a.professional_id,
    'service_id', a.service_id, 'starts_at', a.starts_at, 'ends_at', a.ends_at,
    'status', a.status, 'version', a.version,
    'resolved_duration_minutes', a.resolved_duration_minutes,
    'resolved_eligibility_source', a.resolved_eligibility_source,
    'resolved_at', a.resolved_at, 'created_at', a.created_at, 'updated_at', a.updated_at,
    'unit_id', a.unit_id, 'series_id', a.series_id, 'group_id', a.group_id
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

-- ============================================================================
-- 5. appointment_group_create (Blueprint §3.2.1/§3.2.2/§5). Tudo-ou-nada:
--    qualquer filho que falhe (elegibilidade, Resolver, colisão de agenda)
--    propaga a exceção para fora da função, revertendo toda a transação —
--    incluindo a própria linha de appointment_groups, nunca persistida
--    sozinha.
-- ============================================================================

create or replace function public.appointment_group_create(
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
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_requester_client_id uuid := nullif(p_payload ->> 'requester_client_id', '')::uuid;
  v_service_id uuid := nullif(p_payload ->> 'service_id', '')::uuid;
  v_starts_at timestamptz := (p_payload ->> 'starts_at')::timestamptz;
  v_participants jsonb := coalesce(p_payload -> 'participants', '[]'::jsonb);
  v_participant jsonb;
  v_group_id uuid := gen_random_uuid();
  v_create_result jsonb;
  v_appointments jsonb := '[]'::jsonb;
  v_group public.appointment_groups%rowtype;
  v_group_json jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_unit_id is null or v_requester_client_id is null or v_service_id is null or v_starts_at is null then
    raise exception 'unit_id, requester_client_id, service_id and starts_at are required' using errcode = '22023';
  end if;
  -- Duas verificações separadas, nesta ordem: jsonb_array_length lança erro
  -- nativo (não o nosso 22023 amigável) se aplicada a um jsonb que não é
  -- array, e o Postgres não garante avaliação em curto-circuito de `or`.
  if jsonb_typeof(v_participants) <> 'array' then
    raise exception 'participants must be an array with between 2 and 10 entries' using errcode = '22023';
  end if;
  if jsonb_array_length(v_participants) not between 2 and 10 then
    raise exception 'participants must be an array with between 2 and 10 entries' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  insert into public.appointment_groups(id, organization_id, unit_id, requester_client_id, created_by)
  values (v_group_id, p_organization_id, v_unit_id, v_requester_client_id, p_actor_user_id);

  for v_participant in select * from jsonb_array_elements(v_participants)
  loop
    if nullif(v_participant ->> 'client_id', '') is null or nullif(v_participant ->> 'professional_id', '') is null then
      raise exception 'each participant requires client_id and professional_id' using errcode = '22023';
    end if;

    v_create_result := public.create_appointment(
      p_organization_id, p_actor_user_id,
      p_idempotency_key || ':child:' || (v_participant ->> 'client_id'),
      jsonb_build_object(
        'client_id', (v_participant ->> 'client_id')::uuid,
        'professional_id', (v_participant ->> 'professional_id')::uuid,
        'service_id', v_service_id, 'starts_at', v_starts_at, 'origin', 'group',
        'unit_id', v_unit_id, 'group_id', v_group_id
      )
    );
    v_appointments := v_appointments || jsonb_build_array(v_create_result -> 'appointment');
  end loop;

  perform private.onda5_recompute_group_status(p_organization_id, v_group_id);

  select * into v_group from public.appointment_groups
  where organization_id = p_organization_id and id = v_group_id;
  v_group_json := jsonb_build_object(
    'id', v_group.id, 'organization_id', v_group.organization_id, 'unit_id', v_group.unit_id,
    'requester_client_id', v_group.requester_client_id, 'status', v_group.status
  );

  v_response := jsonb_build_object('status', 'applied', 'group', v_group_json, 'appointments', v_appointments);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_group_create(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_group_create(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- 6. appointment_group_member_add (Blueprint §3.2.5/§5). Deriva unit_id/
--    service_id/starts_at de um filho ativo já existente — appointments
--    continua a única fonte de verdade, o grupo nunca guarda cópia própria
--    desses campos. Falha do novo filho não desfaz o grupo (a exceção só
--    reverte a criação deste filho, esta é a única mutação da RPC).
-- ============================================================================

create or replace function public.appointment_group_member_add(
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
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_group_id uuid := nullif(p_payload ->> 'group_id', '')::uuid;
  v_client_id uuid := nullif(p_payload ->> 'client_id', '')::uuid;
  v_professional_id uuid := nullif(p_payload ->> 'professional_id', '')::uuid;
  v_group public.appointment_groups%rowtype;
  v_reference public.appointments%rowtype;
  v_active_count integer;
  v_create_result jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_group_id is null or v_client_id is null or v_professional_id is null then
    raise exception 'group_id, client_id and professional_id are required' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  select * into v_group from public.appointment_groups
  where organization_id = p_organization_id and id = v_group_id
  for update;
  if not found then
    raise exception 'group not found' using errcode = 'P0002';
  end if;
  if v_group.status = 'CANCELLED' then
    raise exception 'cannot add a member to a cancelled group' using errcode = 'P0001';
  end if;

  select count(*) into v_active_count
  from public.appointments
  where organization_id = p_organization_id and group_id = v_group_id and status <> 'cancelled';
  if v_active_count >= 10 then
    raise exception 'group already has the maximum of 10 active participants' using errcode = '22023';
  end if;

  select * into v_reference from public.appointments
  where organization_id = p_organization_id and group_id = v_group_id and status <> 'cancelled'
  order by created_at asc
  limit 1;
  if not found then
    raise exception 'group has no active occurrence to derive shared attributes from' using errcode = 'P0002';
  end if;

  v_create_result := public.create_appointment(
    p_organization_id, p_actor_user_id, p_idempotency_key || ':child',
    jsonb_build_object(
      'client_id', v_client_id, 'professional_id', v_professional_id, 'service_id', v_reference.service_id,
      'starts_at', v_reference.starts_at, 'origin', 'group',
      'unit_id', v_group.unit_id, 'group_id', v_group_id
    )
  );

  perform private.onda5_recompute_group_status(p_organization_id, v_group_id);

  v_response := jsonb_build_object('status', 'applied', 'appointment', v_create_result -> 'appointment');
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_group_member_add(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_group_member_add(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- 7. appointment_group_update (Blueprint §3.2.5/§5) — reagenda o horário de
--    início compartilhado atomicamente em todos os filhos não cancelados;
--    qualquer colisão reverte a RPC inteira, nenhum filho muda sozinho.
-- ============================================================================

create or replace function public.appointment_group_update(
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
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_group_id uuid := nullif(p_payload ->> 'group_id', '')::uuid;
  v_starts_at timestamptz := (p_payload ->> 'starts_at')::timestamptz;
  v_child record;
  v_update_result jsonb;
  v_appointments jsonb := '[]'::jsonb;
  v_response jsonb;
begin
  if p_payload ? 'client_id' then
    raise exception 'appointment_group_update never accepts client_id (titleholder is immutable)' using errcode = '22023';
  end if;
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_group_id is null or v_starts_at is null then
    raise exception 'group_id and starts_at are required' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  -- Só trava a linha do grupo (existência + serialização com outra
  -- appointment_group_update/_cancel concorrente na mesma onda) — nenhum
  -- campo do grupo em si é lido aqui, então não há necessidade de capturar
  -- a linha inteira numa variável.
  perform 1 from public.appointment_groups
  where organization_id = p_organization_id and id = v_group_id
  for update;
  if not found then
    raise exception 'group not found' using errcode = 'P0002';
  end if;

  for v_child in
    select id, version from public.appointments
    where organization_id = p_organization_id and group_id = v_group_id and status in ('scheduled', 'confirmed')
    order by id
  loop
    v_update_result := public.update_appointment(
      p_organization_id, p_actor_user_id, p_idempotency_key || ':child:' || v_child.id,
      v_child.id, jsonb_build_object('starts_at', v_starts_at, 'version', v_child.version)
    );
    v_appointments := v_appointments || jsonb_build_array(v_update_result -> 'appointment');
  end loop;

  v_response := jsonb_build_object('status', 'applied', 'group_id', v_group_id, 'appointments', v_appointments);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_group_update(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_group_update(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- 8. appointment_group_cancel (Blueprint §3.2.6/§5) — cancela todos os
--    filhos não cancelados; o status do grupo vira CANCELLED pelo próprio
--    trigger de sincronização assim que o último filho transiciona.
-- ============================================================================

create or replace function public.appointment_group_cancel(
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
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_group_id uuid := nullif(p_payload ->> 'group_id', '')::uuid;
  v_child record;
  v_update_result jsonb;
  v_appointments jsonb := '[]'::jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_group_id is null then
    raise exception 'group_id is required' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  -- Só trava a linha do grupo (mesma disciplina de appointment_group_update
  -- acima) — nenhum campo do grupo é lido, o status final é derivado pelo
  -- trigger assim que os filhos transicionam para cancelled.
  perform 1 from public.appointment_groups
  where organization_id = p_organization_id and id = v_group_id
  for update;
  if not found then
    raise exception 'group not found' using errcode = 'P0002';
  end if;

  for v_child in
    select id, version from public.appointments
    where organization_id = p_organization_id and group_id = v_group_id and status in ('scheduled', 'confirmed')
    order by id
  loop
    v_update_result := public.update_appointment(
      p_organization_id, p_actor_user_id, p_idempotency_key || ':child:' || v_child.id,
      v_child.id, jsonb_build_object('status', 'cancelled', 'version', v_child.version)
    );
    v_appointments := v_appointments || jsonb_build_array(v_update_result -> 'appointment');
  end loop;

  v_response := jsonb_build_object('status', 'applied', 'group_id', v_group_id, 'appointments', v_appointments);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_group_cancel(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_group_cancel(uuid, uuid, text, jsonb) to service_role;
