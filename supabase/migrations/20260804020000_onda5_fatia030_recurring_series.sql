-- Onda 5, fatia 030 (issues/030-onda5-recurring-series.md, DEC-51/DEC-52).
-- Implementa
-- docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md
-- §3.1/§4.1/§4.2 — appointment_series, appointments.series_id, extensão de
-- create_appointment com metadados server-owned e consulta obrigatória ao
-- Availability Resolver (funções private.resolve_* da Onda 4) para origens
-- não-diretas. Decisão fechada por interview (2026-08-04): materialização
-- tudo-ou-nada nesta fatia — qualquer ocorrência que colida aborta a série
-- inteira (rollback); a fatia 031 troca esse comportamento por
-- materialização parcial + registro em appointment_series_conflicts, sem
-- reabrir este schema. Nenhuma rota Express nesta fatia (decisão fechada,
-- 2026-08-04) — só SQL + pgTAP.
--
-- "Titular imutável" (Blueprint §3.1.9) NÃO estende update_appointment
-- nesta fatia — decisão fechada por interview (2026-08-04), achado do Red
-- Team: update_appointment já é chamado por
-- public.appointment_replan_with_hold (Onda 1 remediação, fatia 3b,
-- 20260726203000), o comando explícito e auditado (libera hold antigo,
-- troca client_id, emite hold novo com a identidade nova) que já cumpre o
-- que o Blueprint pede — bloquear update_appointment globalmente quebraria
-- esse caminho já testado (rpc_appointment_replan_with_hold_test.sql) e o
-- guard P0007 de identidade financeira já existente
-- (rpc_deposit_hold_financial_identity_test.sql). "Titular imutável" fica
-- escopado às RPCs novas desta Onda (appointment_series_update nunca
-- aceita/repassa client_id ao editar uma ocorrência), não a update_appointment.

-- ============================================================================
-- Pre-flight check (DEC-44 item 2)
-- ============================================================================
do $$
begin
  if to_regclass('public.appointments') is null then
    raise exception 'pre-flight failed: public.appointments does not exist';
  end if;
  if to_regclass('public.units') is null then
    raise exception 'pre-flight failed: public.units does not exist';
  end if;
  if to_regclass('public.professional_units') is null then
    raise exception 'pre-flight failed: public.professional_units does not exist';
  end if;
  if to_regprocedure('private.resolve_calendar_policy(uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_calendar_policy does not exist';
  end if;
  if to_regprocedure('private.resolve_professional_shift(uuid,uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_professional_shift does not exist';
  end if;
  if to_regprocedure('private.resolve_calendar_overrides(uuid,uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_calendar_overrides does not exist';
  end if;
  if to_regclass('public.appointment_series') is not null then
    raise exception 'pre-flight failed: public.appointment_series already exists';
  end if;
end $$;

-- ============================================================================
-- 1. appointment_series (Blueprint §4.1)
-- ============================================================================

create table public.appointment_series (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  client_id uuid not null,
  professional_id uuid not null,
  service_id uuid not null,
  anchor_date date not null,
  local_start_time text not null check (local_start_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'),
  recurrence_days smallint[] not null check (
    array_length(recurrence_days, 1) > 0
    and recurrence_days <@ array[0, 1, 2, 3, 4, 5, 6]::smallint[]
  ),
  recurrence_interval_weeks smallint not null default 1 check (recurrence_interval_weeks > 0),
  duration_minutes integer not null check (duration_minutes > 0),
  status text not null default 'active' check (status in ('active', 'paused', 'cancelled')),
  valid_from date not null,
  valid_until date,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_until is null or valid_until >= valid_from),
  unique (organization_id, id, unit_id),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  foreign key (organization_id, client_id) references public.clients(organization_id, id),
  foreign key (organization_id, service_id) references public.services(organization_id, id),
  foreign key (organization_id, professional_id, unit_id)
    references public.professional_units(organization_id, professional_id, unit_id),
  foreign key (organization_id, created_by) references public.memberships(organization_id, user_id) on delete restrict
);

create index appointment_series_unit_status_idx on public.appointment_series(organization_id, unit_id, status);

create trigger appointment_series_touch before update on public.appointment_series
  for each row execute function private.touch_updated_at();

alter table public.appointment_series enable row level security;

-- Leitura: mesmo padrão unit-aware de deposit_holds/professional_shifts
-- (não usa somente is_member — isso vazaria entre unidades da mesma org).
create policy appointment_series_select on public.appointment_series for select to authenticated using (
  private.can_access_fact_unit(
    organization_id, unit_id,
    array['owner', 'admin'],
    array['manager', 'reception', 'professional']
  )
);
-- Escrita: nenhum grant direto a authenticated — só via RPCs security
-- definer (appointment_series_create/_update/_cancel/_extend_window,
-- Etapa 8 desta mesma fatia, mais abaixo).

-- ============================================================================
-- 2. appointments.series_id (Blueprint §4.2) — aditiva, nullable, unit-safe
-- ============================================================================

alter table public.appointments add column series_id uuid;
alter table public.appointments add constraint appointments_org_series_unit_fk
  foreign key (organization_id, series_id, unit_id)
  references public.appointment_series(organization_id, id, unit_id);

create index appointments_series_idx on public.appointments(organization_id, series_id) where series_id is not null;

-- ============================================================================
-- 3. private.onda5_series_occurrence_dates — matemática pura de recorrência
--    (deep module: interface pequena, testável isoladamente por pgTAP sem
--    fixture nenhuma). recurrence_days usa a mesma convenção 0=domingo
--    ...6=sábado de extract(dow from date).
-- ============================================================================

create or replace function private.onda5_series_occurrence_dates(
  p_anchor_date date,
  p_recurrence_days smallint[],
  p_recurrence_interval_weeks smallint,
  p_valid_from date,
  p_valid_until date,
  p_window_start date,
  p_window_end date
)
returns setof date
language sql
stable
set search_path = pg_catalog
as $$
  -- semana-base ancorada no domingo da semana de anchor_date (mesma
  -- numeração 0=domingo de extract(dow)), para que "a cada N semanas"
  -- seja relativo à própria série, não a um calendário absoluto.
  with anchor_week as (
    select p_anchor_date - (extract(dow from p_anchor_date))::int as week_start
  ),
  candidate_dates as (
    select d::date as candidate_date
    from generate_series(
      greatest(p_window_start, p_valid_from),
      least(p_window_end, coalesce(p_valid_until, p_window_end)),
      '1 day'::interval
    ) as d
  )
  select cd.candidate_date
  from candidate_dates cd, anchor_week aw
  where cd.candidate_date >= p_anchor_date
    and extract(dow from cd.candidate_date)::smallint = any(p_recurrence_days)
    and (
      (cd.candidate_date - (extract(dow from cd.candidate_date))::int - aw.week_start) / 7
    ) % p_recurrence_interval_weeks = 0
  order by cd.candidate_date;
$$;

revoke all on function private.onda5_series_occurrence_dates(date, smallint[], smallint, date, date, date, date)
  from public, anon, authenticated;

-- ============================================================================
-- 4. private.onda5_range_within_blocks — contenção de [start,end) minutos
--    dentro de algum bloco {"start":"HH:MM","end":"HH:MM"} (mesmo formato de
--    calendar_policies/professional_shifts.weekly_schedule, ver
--    private.valid_weekly_schedule). Deep module: interface pequena, sem
--    I/O, testável isoladamente — usado por create_appointment abaixo para
--    validar um candidato único, não a grade inteira (isso é do Express,
--    Onda 4 §3.4, Rota A).
-- ============================================================================

create or replace function private.onda5_range_within_blocks(
  p_blocks jsonb,
  p_start_minutes integer,
  p_end_minutes integer
)
returns boolean
language sql
immutable
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from jsonb_array_elements(coalesce(p_blocks, '[]'::jsonb)) as block
    where (extract(hour from (block ->> 'start')::time) * 60 + extract(minute from (block ->> 'start')::time)) <= p_start_minutes
      and p_end_minutes <= (extract(hour from (block ->> 'end')::time) * 60 + extract(minute from (block ->> 'end')::time))
  );
$$;

revoke all on function private.onda5_range_within_blocks(jsonb, integer, integer) from public, anon, authenticated;

-- ============================================================================
-- 5. create_appointment (extensão) — Blueprint §4.2. Preserva a assinatura
--    e o comportamento de todo chamador legado (origin ausente = 'direct',
--    unit_id ausente = default-fill trigger como sempre). Para origin em
--    (series, group, waitlist): unit_id passa a ser obrigatório, e o
--    candidato é validado contra o Availability Resolver (mesmas funções
--    private.resolve_* da Onda 4, chamadas diretamente — create_appointment
--    já roda security definer com `private` no search_path, não precisa do
--    Express para isso; o Express só orquestra a GRADE inteira, Blueprint
--    Onda 4 §3.4). `group` ainda não tem tabela própria (fatia 032) — aceito
--    como origin válido desde já porque não referencia nenhum objeto novo,
--    só valida unit_id explícito; a FK de group_id nasce em fatia futura.
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
  -- Onda 5 (fatia 030): metadados server-owned, todos opcionais para
  -- preservar chamadores legados.
  v_origin text := coalesce(p_payload ->> 'origin', 'direct');
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_series_id uuid := nullif(p_payload ->> 'series_id', '')::uuid;
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

  -- Consulta obrigatória ao Availability Resolver (Blueprint §3.1.3) para
  -- toda origem não-direta: um candidato fora de política/turno, ou num dia
  -- fechado por override, nunca vira appointment — mesmo em rota nova.
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
  end if;

  insert into public.appointments(
    id, organization_id, client_id, professional_id, service_id,
    starts_at, ends_at, status, created_by,
    resolved_duration_minutes, resolved_eligibility_source, resolved_at,
    unit_id, series_id
  ) values (
    v_appointment_id, p_organization_id, v_client_id, v_professional_id, v_service_id,
    v_starts_at, v_ends_at, v_status, v_user_id,
    v_duration, v_source, now(),
    v_unit_id, v_series_id
  );

  select jsonb_build_object(
    'id', a.id, 'organization_id', a.organization_id, 'client_id', a.client_id, 'professional_id', a.professional_id,
    'service_id', a.service_id, 'starts_at', a.starts_at, 'ends_at', a.ends_at,
    'status', a.status, 'version', a.version,
    'resolved_duration_minutes', a.resolved_duration_minutes,
    'resolved_eligibility_source', a.resolved_eligibility_source,
    'resolved_at', a.resolved_at, 'created_at', a.created_at, 'updated_at', a.updated_at,
    'unit_id', a.unit_id, 'series_id', a.series_id
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
-- 6. appointment_series_create (Blueprint §3.1.1/§5). Materialização
--    tudo-ou-nada da janela rolante de 8 semanas (56 dias, [valid_from,
--    valid_from+55]) — qualquer ocorrência que não passe pelo
--    create_appointment estendido (Resolver, exclusion constraint) faz a
--    RPC inteira levantar exceção e reverter, incluindo a própria linha de
--    appointment_series (nenhuma transação parcial commitada). Chave
--    idempotente por ocorrência é determinística (series_id +
--    occurrence_date, Blueprint §3.1.5): um retry com a MESMA chave de
--    série reprocessa create_appointment com as mesmas chaves de
--    ocorrência, então cada uma resolve para a resposta já persistida
--    (idempotency_keys), nunca duplica.
-- ============================================================================

create or replace function public.appointment_series_create(
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
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_anchor_date date := nullif(p_payload ->> 'anchor_date', '')::date;
  v_local_start_time text := p_payload ->> 'local_start_time';
  v_recurrence_days smallint[];
  v_recurrence_interval_weeks smallint := coalesce((p_payload ->> 'recurrence_interval_weeks')::smallint, 1);
  v_duration_minutes integer := nullif(p_payload ->> 'duration_minutes', '')::integer;
  v_valid_from date := nullif(p_payload ->> 'valid_from', '')::date;
  v_valid_until date := nullif(p_payload ->> 'valid_until', '')::date;
  v_series_id uuid := gen_random_uuid();
  v_timezone text;
  v_window_end date;
  v_occurrence_date date;
  v_occurrence_starts_at timestamptz;
  v_occurrence_key text;
  v_create_result jsonb;
  v_appointments jsonb := '[]'::jsonb;
  v_series_row public.appointment_series%rowtype;
  v_series_json jsonb;
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

  select array_agg(x::smallint) into v_recurrence_days
  from jsonb_array_elements_text(coalesce(p_payload -> 'recurrence_days', '[]'::jsonb)) x;

  if v_client_id is null or v_professional_id is null or v_service_id is null or v_unit_id is null
    or v_anchor_date is null or v_local_start_time is null or v_recurrence_days is null
    or v_duration_minutes is null or v_valid_from is null
  then
    raise exception 'client_id, professional_id, service_id, unit_id, anchor_date, local_start_time, recurrence_days, duration_minutes and valid_from are required' using errcode = '22023';
  end if;

  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = v_unit_id;
  if v_timezone is null then
    raise exception 'unit not found' using errcode = 'P0002';
  end if;

  insert into public.appointment_series(
    id, organization_id, unit_id, client_id, professional_id, service_id,
    anchor_date, local_start_time, recurrence_days, recurrence_interval_weeks,
    duration_minutes, valid_from, valid_until, created_by
  ) values (
    v_series_id, p_organization_id, v_unit_id, v_client_id, v_professional_id, v_service_id,
    v_anchor_date, v_local_start_time, v_recurrence_days, v_recurrence_interval_weeks,
    v_duration_minutes, v_valid_from, v_valid_until, v_user_id
  );

  -- Janela rolante de 8 semanas = 56 dias corridos [valid_from, valid_from+55]
  -- (Blueprint §2.1). Ver private.onda5_series_occurrence_dates para a
  -- convenção de limite inclusivo.
  v_window_end := v_valid_from + 55;

  for v_occurrence_date in
    select d from private.onda5_series_occurrence_dates(
      v_anchor_date, v_recurrence_days, v_recurrence_interval_weeks,
      v_valid_from, v_valid_until, v_valid_from, v_window_end
    ) d
  loop
    v_occurrence_starts_at := (v_occurrence_date::text || ' ' || v_local_start_time)::timestamp at time zone v_timezone;
    v_occurrence_key := 'onda5-series-occ:' || v_series_id::text || ':' || v_occurrence_date::text;

    v_create_result := public.create_appointment(
      p_organization_id, v_user_id, v_occurrence_key,
      jsonb_build_object(
        'client_id', v_client_id, 'professional_id', v_professional_id, 'service_id', v_service_id,
        'starts_at', v_occurrence_starts_at, 'origin', 'series',
        'unit_id', v_unit_id, 'series_id', v_series_id, 'duration_minutes', v_duration_minutes
      )
    );
    v_appointments := v_appointments || jsonb_build_array(v_create_result -> 'appointment');
  end loop;

  select * into v_series_row from public.appointment_series
  where organization_id = p_organization_id and id = v_series_id;
  v_series_json := jsonb_build_object(
    'id', v_series_row.id, 'organization_id', v_series_row.organization_id, 'unit_id', v_series_row.unit_id,
    'client_id', v_series_row.client_id, 'professional_id', v_series_row.professional_id, 'service_id', v_series_row.service_id,
    'anchor_date', v_series_row.anchor_date, 'local_start_time', v_series_row.local_start_time,
    'recurrence_days', v_series_row.recurrence_days, 'recurrence_interval_weeks', v_series_row.recurrence_interval_weeks,
    'duration_minutes', v_series_row.duration_minutes, 'status', v_series_row.status,
    'valid_from', v_series_row.valid_from, 'valid_until', v_series_row.valid_until
  );

  v_response := jsonb_build_object('status', 'applied', 'series', v_series_json, 'appointments', v_appointments);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_series_create(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_series_create(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- 7. appointment_series_extend_window (Blueprint §3.1.6/§5). Idempotência
--    por construção, não por cursor de estado: recalcula a janela de 8
--    semanas a partir de as_of_date (default current_date, parâmetro
--    explícito só para permitir teste determinístico e reprocessamento
--    operacional) e deixa a chave idempotente POR OCORRÊNCIA (mesma
--    construção de appointment_series_create) decidir sozinha o que já
--    existe — nenhuma data já materializada é reescrita (create_appointment
--    apenas retorna a resposta já persistida em idempotency_keys). Série
--    pausada é no-op seguro, nunca erro — um job periódico não pode
--    quebrar ao encontrar uma série pausada.
-- ============================================================================

create or replace function public.appointment_series_extend_window(
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
  v_series_id uuid := nullif(p_payload ->> 'series_id', '')::uuid;
  v_as_of_date date := coalesce(nullif(p_payload ->> 'as_of_date', '')::date, current_date);
  v_series public.appointment_series%rowtype;
  v_timezone text;
  v_window_start date;
  v_window_end date;
  v_occurrence_date date;
  v_occurrence_starts_at timestamptz;
  v_occurrence_key text;
  v_create_result jsonb;
  v_appointments jsonb := '[]'::jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_series_id is null then
    raise exception 'series_id is required' using errcode = '22023';
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

  -- Achado do Red Team de implementação (2026-08-04): sem FOR UPDATE aqui,
  -- um appointment_series_update(THIS_AND_FUTURE) concorrente na mesma
  -- série podia intercalar com esta leitura — extend_window materializaria
  -- ocorrências sob o padrão ANTIGO (já superado pelo update) depois que o
  -- cancelamento em lote do update já tivesse rodado, deixando appointments
  -- órfãos sob um padrão que a série não reflete mais. Mesmo lock de linha
  -- que appointment_series_update/_cancel já usam serializa os dois.
  select * into v_series from public.appointment_series
  where organization_id = p_organization_id and id = v_series_id
  for update;
  if not found then
    raise exception 'series not found' using errcode = 'P0002';
  end if;

  if v_series.status <> 'active' then
    return jsonb_build_object('status', 'skipped', 'reason', 'series is not active', 'series_id', v_series_id, 'appointments', '[]'::jsonb);
  end if;

  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = v_series.unit_id;

  v_window_start := greatest(v_series.valid_from, v_as_of_date);
  v_window_end := v_window_start + 55;

  for v_occurrence_date in
    select d from private.onda5_series_occurrence_dates(
      v_series.anchor_date, v_series.recurrence_days, v_series.recurrence_interval_weeks,
      v_series.valid_from, v_series.valid_until, v_window_start, v_window_end
    ) d
  loop
    v_occurrence_starts_at := (v_occurrence_date::text || ' ' || v_series.local_start_time)::timestamp at time zone v_timezone;
    v_occurrence_key := 'onda5-series-occ:' || v_series_id::text || ':' || v_occurrence_date::text;

    v_create_result := public.create_appointment(
      p_organization_id, v_user_id, v_occurrence_key,
      jsonb_build_object(
        'client_id', v_series.client_id, 'professional_id', v_series.professional_id, 'service_id', v_series.service_id,
        'starts_at', v_occurrence_starts_at, 'origin', 'series',
        'unit_id', v_series.unit_id, 'series_id', v_series_id, 'duration_minutes', v_series.duration_minutes
      )
    );
    v_appointments := v_appointments || jsonb_build_array(v_create_result -> 'appointment');
  end loop;

  v_response := jsonb_build_object('status', 'applied', 'series_id', v_series_id, 'appointments', v_appointments);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_series_extend_window(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_series_extend_window(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- 8. appointment_series_update (Blueprint §3.1.7/§3.1.8/§3.1.9). Dois
--    escopos: THIS_OCCURRENCE delega para update_appointment na ocorrência
--    endereçada por (series_id, occurrence_date convertida pelo timezone da
--    unidade) — nunca por local_start_time literal, que pode ter mudado
--    numa edição anterior; THIS_AND_FUTURE cancela as ocorrências futuras
--    ainda não iniciadas, atualiza os campos da série (coalesce com o
--    valor atual) e, se o resultado for status='active', rematerializa a
--    janela a partir de greatest(valid_from, current_date) — mesmo loop de
--    appointment_series_extend_window. "Titular imutável" (§3.1.9) fica
--    aqui: client_id nunca é aceito, em nenhum escopo.
-- ============================================================================

create or replace function public.appointment_series_update(
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
  v_series_id uuid := nullif(p_payload ->> 'series_id', '')::uuid;
  v_scope text := p_payload ->> 'scope';
  v_series public.appointment_series%rowtype;
  v_timezone text;
  v_occurrence_date date;
  v_target_appointment_id uuid;
  v_update_result jsonb;
  v_window_start date;
  v_window_end date;
  v_occ_date date;
  v_occ_starts_at timestamptz;
  v_occ_key text;
  v_create_result jsonb;
  v_appointments jsonb := '[]'::jsonb;
  v_series_json jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_payload ? 'client_id' then
    raise exception 'appointment_series_update never accepts client_id (series titleholder is immutable)' using errcode = '22023';
  end if;
  if v_series_id is null or v_scope not in ('THIS_OCCURRENCE', 'THIS_AND_FUTURE') then
    raise exception 'series_id and a valid scope (THIS_OCCURRENCE or THIS_AND_FUTURE) are required' using errcode = '22023';
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

  select * into v_series from public.appointment_series
  where organization_id = p_organization_id and id = v_series_id
  for update;
  if not found then
    raise exception 'series not found' using errcode = 'P0002';
  end if;

  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = v_series.unit_id;

  if v_scope = 'THIS_OCCURRENCE' then
    v_occurrence_date := nullif(p_payload ->> 'occurrence_date', '')::date;
    if v_occurrence_date is null then
      raise exception 'occurrence_date is required for scope THIS_OCCURRENCE' using errcode = '22023';
    end if;

    -- Endereça pela data civil local da ocorrência, não por
    -- local_start_time literal — uma edição anterior já pode ter movido o
    -- horário desta mesma ocorrência.
    select id into v_target_appointment_id
    from public.appointments
    where organization_id = p_organization_id and series_id = v_series_id
      and (starts_at at time zone v_timezone)::date = v_occurrence_date
      and status in ('scheduled', 'confirmed');
    if v_target_appointment_id is null then
      raise exception 'occurrence not found for the given date' using errcode = 'P0002';
    end if;

    v_update_result := public.update_appointment(p_organization_id, v_user_id, p_idempotency_key || ':occ', v_target_appointment_id, p_payload);
    v_response := jsonb_build_object('status', 'applied', 'scope', 'THIS_OCCURRENCE', 'appointment', v_update_result -> 'appointment');
  else
    -- THIS_AND_FUTURE: cancela ocorrências futuras ainda não iniciadas,
    -- aplica os campos novos na série (coalesce), rematerializa se ficar
    -- ativa.
    update public.appointments
    set status = 'cancelled'
    where organization_id = p_organization_id and series_id = v_series_id
      and status in ('scheduled', 'confirmed')
      and starts_at > now();

    update public.appointment_series set
      local_start_time = coalesce(p_payload ->> 'local_start_time', local_start_time),
      recurrence_days = case when p_payload ? 'recurrence_days' then (
        select array_agg(x::smallint) from jsonb_array_elements_text(p_payload -> 'recurrence_days') x
      ) else recurrence_days end,
      recurrence_interval_weeks = coalesce((p_payload ->> 'recurrence_interval_weeks')::smallint, recurrence_interval_weeks),
      duration_minutes = coalesce((p_payload ->> 'duration_minutes')::integer, duration_minutes),
      professional_id = coalesce((p_payload ->> 'professional_id')::uuid, professional_id),
      status = coalesce(p_payload ->> 'status', status),
      valid_from = coalesce((p_payload ->> 'valid_from')::date, valid_from),
      valid_until = case when p_payload ? 'valid_until' then nullif(p_payload ->> 'valid_until', '')::date else valid_until end
    where organization_id = p_organization_id and id = v_series_id
    returning * into v_series;

    if v_series.status = 'active' then
      v_window_start := greatest(v_series.valid_from, current_date);
      v_window_end := v_window_start + 55;
      for v_occ_date in
        select d from private.onda5_series_occurrence_dates(
          v_series.anchor_date, v_series.recurrence_days, v_series.recurrence_interval_weeks,
          v_series.valid_from, v_series.valid_until, v_window_start, v_window_end
        ) d
      loop
        v_occ_starts_at := (v_occ_date::text || ' ' || v_series.local_start_time)::timestamp at time zone v_timezone;
        -- Achado do Red Team (2026-08-04): a chave por ocorrência NÃO pode
        -- reaproveitar o namespace da materialização original aqui — a
        -- ocorrência daquela data pode ter acabado de ser cancelada pelo
        -- UPDATE logo acima (mesma transação), e create_appointment
        -- retornaria a resposta em cache da idempotency_key antiga (o
        -- appointment já cancelado), nunca criando um novo. Namespace pela
        -- chave idempotente da própria chamada de edição — cada edição tem
        -- seu epoch de materialização isolado; um retry da MESMA edição já
        -- é resolvido pelo curto-circuito no topo da função.
        v_occ_key := 'onda5-series-occ:' || v_series_id::text || ':' || v_occ_date::text || ':' || p_idempotency_key;
        v_create_result := public.create_appointment(
          p_organization_id, v_user_id, v_occ_key,
          jsonb_build_object(
            'client_id', v_series.client_id, 'professional_id', v_series.professional_id, 'service_id', v_series.service_id,
            'starts_at', v_occ_starts_at, 'origin', 'series',
            'unit_id', v_series.unit_id, 'series_id', v_series_id, 'duration_minutes', v_series.duration_minutes
          )
        );
        v_appointments := v_appointments || jsonb_build_array(v_create_result -> 'appointment');
      end loop;
    end if;

    v_series_json := jsonb_build_object(
      'id', v_series.id, 'status', v_series.status, 'valid_from', v_series.valid_from, 'valid_until', v_series.valid_until,
      'local_start_time', v_series.local_start_time, 'recurrence_days', v_series.recurrence_days,
      'recurrence_interval_weeks', v_series.recurrence_interval_weeks
    );
    v_response := jsonb_build_object('status', 'applied', 'scope', 'THIS_AND_FUTURE', 'series', v_series_json, 'appointments', v_appointments);
  end if;

  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_series_update(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_series_update(uuid, uuid, text, jsonb) to service_role;

-- ============================================================================
-- 9. appointment_series_cancel (Blueprint §3.1.8/§5). Mesmo endereçamento
--    de THIS_OCCURRENCE de appointment_series_update; THIS_AND_FUTURE
--    cancela todas as ocorrências futuras ainda não iniciadas E termina a
--    série (status='cancelled', terminal — nunca rematerializa de novo,
--    diferente de 'paused' que é retomável).
-- ============================================================================

create or replace function public.appointment_series_cancel(
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
  v_series_id uuid := nullif(p_payload ->> 'series_id', '')::uuid;
  v_scope text := p_payload ->> 'scope';
  v_series public.appointment_series%rowtype;
  v_timezone text;
  v_occurrence_date date;
  v_target_appointment_id uuid;
  v_update_result jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_series_id is null or v_scope not in ('THIS_OCCURRENCE', 'THIS_AND_FUTURE') then
    raise exception 'series_id and a valid scope (THIS_OCCURRENCE or THIS_AND_FUTURE) are required' using errcode = '22023';
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

  select * into v_series from public.appointment_series
  where organization_id = p_organization_id and id = v_series_id
  for update;
  if not found then
    raise exception 'series not found' using errcode = 'P0002';
  end if;

  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = v_series.unit_id;

  if v_scope = 'THIS_OCCURRENCE' then
    v_occurrence_date := nullif(p_payload ->> 'occurrence_date', '')::date;
    if v_occurrence_date is null then
      raise exception 'occurrence_date is required for scope THIS_OCCURRENCE' using errcode = '22023';
    end if;

    select id into v_target_appointment_id
    from public.appointments
    where organization_id = p_organization_id and series_id = v_series_id
      and (starts_at at time zone v_timezone)::date = v_occurrence_date
      and status in ('scheduled', 'confirmed');
    if v_target_appointment_id is null then
      raise exception 'occurrence not found for the given date' using errcode = 'P0002';
    end if;

    v_update_result := public.update_appointment(
      p_organization_id, v_user_id, p_idempotency_key || ':occ', v_target_appointment_id,
      jsonb_build_object('status', 'cancelled', 'version', p_payload -> 'version')
    );
    v_response := jsonb_build_object('status', 'applied', 'scope', 'THIS_OCCURRENCE', 'appointment', v_update_result -> 'appointment');
  else
    update public.appointments
    set status = 'cancelled'
    where organization_id = p_organization_id and series_id = v_series_id
      and status in ('scheduled', 'confirmed')
      and starts_at > now();

    update public.appointment_series set status = 'cancelled'
    where organization_id = p_organization_id and id = v_series_id;

    v_response := jsonb_build_object('status', 'applied', 'scope', 'THIS_AND_FUTURE', 'series_id', v_series_id);
  end if;

  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_series_cancel(uuid, uuid, text, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_series_cancel(uuid, uuid, text, jsonb) to service_role;
