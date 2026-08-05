-- Onda 5, remediação forward-only da fatia 030 (DEC-51/DEC-52).
-- Corrige o desvio contra o Blueprint §3.1: recorrência materializa cada
-- ocorrência independentemente, persiste conflitos e permite retry fechado.

do $$
begin
  if to_regclass('public.appointment_series') is null then
    raise exception 'pre-flight failed: public.appointment_series does not exist';
  end if;
  if to_regclass('public.appointments') is null then
    raise exception 'pre-flight failed: public.appointments does not exist';
  end if;
  if to_regprocedure('public.create_appointment(uuid,uuid,text,jsonb)') is null then
    raise exception 'pre-flight failed: public.create_appointment does not exist';
  end if;
  if to_regclass('public.appointment_series_conflicts') is not null then
    raise exception 'pre-flight failed: public.appointment_series_conflicts already exists';
  end if;
end $$;

create table public.appointment_series_conflicts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  series_id uuid not null,
  occurrence_date date not null,
  candidate_starts_at timestamptz not null,
  candidate_ends_at timestamptz not null,
  reason_code text not null,
  idempotency_key text not null check (length(idempotency_key) between 8 and 200),
  status text not null default 'OPEN' check (status in ('OPEN', 'RESOLVED')),
  appointment_id uuid,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (candidate_ends_at > candidate_starts_at),
  check ((status = 'OPEN' and appointment_id is null and resolved_at is null)
      or (status = 'RESOLVED' and appointment_id is not null and resolved_at is not null)),
  unique (organization_id, id, unit_id),
  unique (organization_id, series_id, occurrence_date),
  unique (organization_id, idempotency_key),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  foreign key (organization_id, series_id, unit_id)
    references public.appointment_series(organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, appointment_id, unit_id)
    references public.appointments(organization_id, id, unit_id) on delete restrict
);

create index appointment_series_conflicts_open_idx
  on public.appointment_series_conflicts(organization_id, unit_id, series_id, occurrence_date)
  where status = 'OPEN';

alter table public.appointment_series_conflicts enable row level security;
create policy appointment_series_conflicts_select
  on public.appointment_series_conflicts for select to authenticated using (
    private.can_access_fact_unit(
      organization_id, unit_id,
      array['owner', 'admin'],
      array['manager', 'reception', 'professional']
    )
  );

-- A private helper is the single materialization boundary.  It deliberately
-- catches only an occurrence failure; the enclosing command remains atomic
-- for its own idempotency response while valid sibling occurrences commit.
create or replace function private.onda5_materialize_series_occurrence(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_series_id uuid,
  p_unit_id uuid,
  p_client_id uuid,
  p_professional_id uuid,
  p_service_id uuid,
  p_duration_minutes integer,
  p_timezone text,
  p_occurrence_date date,
  p_local_start_time text,
  p_occurrence_key text,
  p_retry_open_conflict boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_conflict public.appointment_series_conflicts%rowtype;
  v_starts_at timestamptz := (p_occurrence_date::text || ' ' || p_local_start_time)::timestamp at time zone p_timezone;
  v_result jsonb;
  v_error_code text;
begin
  select * into v_conflict
  from public.appointment_series_conflicts
  where organization_id = p_organization_id
    and series_id = p_series_id
    and occurrence_date = p_occurrence_date
  for update;

  if found and (not p_retry_open_conflict or v_conflict.status <> 'OPEN') then
    return jsonb_build_object('outcome', 'conflict', 'conflict', jsonb_build_object(
      'id', v_conflict.id, 'occurrence_date', v_conflict.occurrence_date,
      'reason_code', v_conflict.reason_code, 'status', v_conflict.status
    ));
  end if;

  begin
    v_result := public.create_appointment(
      p_organization_id, p_actor_user_id, p_occurrence_key,
      jsonb_build_object(
        'client_id', p_client_id, 'professional_id', p_professional_id, 'service_id', p_service_id,
        'starts_at', v_starts_at, 'origin', 'series', 'unit_id', p_unit_id,
        'series_id', p_series_id, 'duration_minutes', p_duration_minutes
      )
    );
  exception when others then
    v_error_code := sqlstate;
    insert into public.appointment_series_conflicts(
      organization_id, unit_id, series_id, occurrence_date, candidate_starts_at,
      candidate_ends_at, reason_code, idempotency_key
    ) values (
      p_organization_id, p_unit_id, p_series_id, p_occurrence_date, v_starts_at,
      v_starts_at + (p_duration_minutes || ' minutes')::interval, v_error_code, p_occurrence_key
    )
    on conflict (organization_id, series_id, occurrence_date) do update set
      candidate_starts_at = excluded.candidate_starts_at,
      candidate_ends_at = excluded.candidate_ends_at,
      reason_code = excluded.reason_code,
      idempotency_key = excluded.idempotency_key
    returning * into v_conflict;

    return jsonb_build_object('outcome', 'conflict', 'conflict', jsonb_build_object(
      'id', v_conflict.id, 'occurrence_date', v_conflict.occurrence_date,
      'reason_code', v_conflict.reason_code, 'status', v_conflict.status
    ));
  end;

  update public.appointment_series_conflicts
  set status = 'RESOLVED',
      appointment_id = (v_result -> 'appointment' ->> 'id')::uuid,
      resolved_at = now()
  where organization_id = p_organization_id
    and series_id = p_series_id
    and occurrence_date = p_occurrence_date
    and status = 'OPEN';

  return jsonb_build_object('outcome', 'materialized', 'appointment', v_result -> 'appointment');
end;
$$;
revoke all on function private.onda5_materialize_series_occurrence(uuid,uuid,uuid,uuid,uuid,uuid,uuid,integer,text,date,text,text,boolean)
  from public, anon, authenticated;

create or replace function public.appointment_series_create(
  p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
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
  v_occurrence_date date;
  v_outcome jsonb;
  v_appointments jsonb := '[]'::jsonb;
  v_conflicts jsonb := '[]'::jsonb;
  v_series public.appointment_series%rowtype;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id) on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys where organization_id = p_organization_id and key = p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode = '22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;

  select array_agg(x::smallint) into v_recurrence_days
  from jsonb_array_elements_text(coalesce(p_payload -> 'recurrence_days', '[]'::jsonb)) x;
  if v_client_id is null or v_professional_id is null or v_service_id is null or v_unit_id is null
    or v_anchor_date is null or v_local_start_time is null or v_recurrence_days is null
    or v_duration_minutes is null or v_valid_from is null then
    raise exception 'client_id, professional_id, service_id, unit_id, anchor_date, local_start_time, recurrence_days, duration_minutes and valid_from are required' using errcode = '22023';
  end if;
  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = v_unit_id;
  if v_timezone is null then raise exception 'unit not found' using errcode = 'P0002'; end if;

  insert into public.appointment_series(
    id, organization_id, unit_id, client_id, professional_id, service_id, anchor_date,
    local_start_time, recurrence_days, recurrence_interval_weeks, duration_minutes, valid_from, valid_until, created_by
  ) values (
    v_series_id, p_organization_id, v_unit_id, v_client_id, v_professional_id, v_service_id, v_anchor_date,
    v_local_start_time, v_recurrence_days, v_recurrence_interval_weeks, v_duration_minutes, v_valid_from, v_valid_until, p_actor_user_id
  ) returning * into v_series;

  for v_occurrence_date in select d from private.onda5_series_occurrence_dates(
    v_anchor_date, v_recurrence_days, v_recurrence_interval_weeks, v_valid_from, v_valid_until, v_valid_from, v_valid_from + 55
  ) d loop
    v_outcome := private.onda5_materialize_series_occurrence(
      p_organization_id, p_actor_user_id, v_series_id, v_unit_id, v_client_id, v_professional_id, v_service_id,
      v_duration_minutes, v_timezone, v_occurrence_date, v_local_start_time,
      'onda5-series-occ:' || v_series_id::text || ':' || v_occurrence_date::text
    );
    if v_outcome ->> 'outcome' = 'materialized' then
      v_appointments := v_appointments || jsonb_build_array(v_outcome -> 'appointment');
    else
      v_conflicts := v_conflicts || jsonb_build_array(v_outcome -> 'conflict');
    end if;
  end loop;
  v_response := jsonb_build_object('status', 'applied', 'series', to_jsonb(v_series), 'appointments', v_appointments, 'conflicts', v_conflicts);
  update private.idempotency_keys set response = v_response where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_series_create(uuid,uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.appointment_series_create(uuid,uuid,text,jsonb) to service_role;

create or replace function public.appointment_series_extend_window(
  p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex'); v_existing private.idempotency_keys%rowtype;
  v_series_id uuid := nullif(p_payload ->> 'series_id', '')::uuid;
  v_as_of_date date := coalesce(nullif(p_payload ->> 'as_of_date', '')::date, current_date);
  v_series public.appointment_series%rowtype; v_timezone text; v_occurrence_date date; v_outcome jsonb;
  v_appointments jsonb := '[]'::jsonb; v_conflicts jsonb := '[]'::jsonb; v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then raise exception 'insufficient organization permission' using errcode = '42501'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key' using errcode = '22023'; end if;
  if v_series_id is null then raise exception 'series_id is required' using errcode = '22023'; end if;
  insert into private.idempotency_keys(organization_id,key,request_hash,created_by) values (p_organization_id,p_idempotency_key,v_hash,p_actor_user_id) on conflict (organization_id,key) do nothing;
  select * into v_existing from private.idempotency_keys where organization_id=p_organization_id and key=p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode='22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;
  select * into v_series from public.appointment_series where organization_id=p_organization_id and id=v_series_id for update;
  if not found then raise exception 'series not found' using errcode='P0002'; end if;
  if v_series.status <> 'active' then
    v_response := jsonb_build_object('status','skipped','reason','series is not active','series_id',v_series_id,'appointments','[]'::jsonb,'conflicts','[]'::jsonb);
    update private.idempotency_keys set response=v_response where organization_id=p_organization_id and key=p_idempotency_key;
    return v_response;
  end if;
  select timezone into v_timezone from public.units where organization_id=p_organization_id and id=v_series.unit_id;
  for v_occurrence_date in select d from private.onda5_series_occurrence_dates(
    v_series.anchor_date,v_series.recurrence_days,v_series.recurrence_interval_weeks,v_series.valid_from,v_series.valid_until,
    greatest(v_series.valid_from,v_as_of_date),greatest(v_series.valid_from,v_as_of_date)+55
  ) d loop
    v_outcome := private.onda5_materialize_series_occurrence(
      p_organization_id,p_actor_user_id,v_series.id,v_series.unit_id,v_series.client_id,v_series.professional_id,v_series.service_id,
      v_series.duration_minutes,v_timezone,v_occurrence_date,v_series.local_start_time,
      'onda5-series-occ:' || v_series.id::text || ':' || v_occurrence_date::text
    );
    if v_outcome ->> 'outcome' = 'materialized' then v_appointments:=v_appointments||jsonb_build_array(v_outcome->'appointment'); else v_conflicts:=v_conflicts||jsonb_build_array(v_outcome->'conflict'); end if;
  end loop;
  v_response:=jsonb_build_object('status','applied','series_id',v_series_id,'appointments',v_appointments,'conflicts',v_conflicts);
  update private.idempotency_keys set response=v_response where organization_id=p_organization_id and key=p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_series_extend_window(uuid,uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.appointment_series_extend_window(uuid,uuid,text,jsonb) to service_role;

-- Updating a future pattern is another materialization entry point.  It uses
-- the same helper, so a newly invalid date cannot roll back valid siblings.
create or replace function public.appointment_series_update(
  p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex'); v_existing private.idempotency_keys%rowtype;
  v_series_id uuid := nullif(p_payload ->> 'series_id', '')::uuid; v_scope text := p_payload ->> 'scope';
  v_series public.appointment_series%rowtype; v_timezone text; v_occurrence_date date; v_target_appointment_id uuid;
  v_update_result jsonb; v_occ_date date; v_outcome jsonb;
  v_appointments jsonb := '[]'::jsonb; v_conflicts jsonb := '[]'::jsonb; v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id,p_actor_user_id,array['owner','admin','manager','reception']) then raise exception 'insufficient organization permission' using errcode='42501'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key' using errcode='22023'; end if;
  if p_payload ? 'client_id' then raise exception 'appointment_series_update never accepts client_id (series titleholder is immutable)' using errcode='22023'; end if;
  if v_series_id is null or v_scope not in ('THIS_OCCURRENCE','THIS_AND_FUTURE') then raise exception 'series_id and a valid scope (THIS_OCCURRENCE or THIS_AND_FUTURE) are required' using errcode='22023'; end if;
  insert into private.idempotency_keys(organization_id,key,request_hash,created_by) values(p_organization_id,p_idempotency_key,v_hash,p_actor_user_id) on conflict(organization_id,key) do nothing;
  select * into v_existing from private.idempotency_keys where organization_id=p_organization_id and key=p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode='22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;
  select * into v_series from public.appointment_series where organization_id=p_organization_id and id=v_series_id for update;
  if not found then raise exception 'series not found' using errcode='P0002'; end if;
  select timezone into v_timezone from public.units where organization_id=p_organization_id and id=v_series.unit_id;
  if v_scope = 'THIS_OCCURRENCE' then
    v_occurrence_date:=nullif(p_payload ->> 'occurrence_date','')::date;
    if v_occurrence_date is null then raise exception 'occurrence_date is required for scope THIS_OCCURRENCE' using errcode='22023'; end if;
    select id into v_target_appointment_id from public.appointments
    where organization_id=p_organization_id and series_id=v_series_id
      and (starts_at at time zone v_timezone)::date=v_occurrence_date and status in ('scheduled','confirmed');
    if v_target_appointment_id is null then raise exception 'occurrence not found for the given date' using errcode='P0002'; end if;
    v_update_result:=public.update_appointment(p_organization_id,p_actor_user_id,p_idempotency_key || ':occ',v_target_appointment_id,p_payload);
    v_response:=jsonb_build_object('status','applied','scope','THIS_OCCURRENCE','appointment',v_update_result->'appointment');
  else
    update public.appointments set status='cancelled'
    where organization_id=p_organization_id and series_id=v_series_id and status in ('scheduled','confirmed') and starts_at>now();
    update public.appointment_series set
      local_start_time=coalesce(p_payload ->> 'local_start_time',local_start_time),
      recurrence_days=case when p_payload ? 'recurrence_days' then (select array_agg(x::smallint) from jsonb_array_elements_text(p_payload -> 'recurrence_days') x) else recurrence_days end,
      recurrence_interval_weeks=coalesce((p_payload ->> 'recurrence_interval_weeks')::smallint,recurrence_interval_weeks),
      duration_minutes=coalesce((p_payload ->> 'duration_minutes')::integer,duration_minutes),
      professional_id=coalesce((p_payload ->> 'professional_id')::uuid,professional_id),
      status=coalesce(p_payload ->> 'status',status), valid_from=coalesce((p_payload ->> 'valid_from')::date,valid_from),
      valid_until=case when p_payload ? 'valid_until' then nullif(p_payload ->> 'valid_until','')::date else valid_until end
    where organization_id=p_organization_id and id=v_series_id returning * into v_series;
    if v_series.status='active' then
      for v_occ_date in select d from private.onda5_series_occurrence_dates(
        v_series.anchor_date,v_series.recurrence_days,v_series.recurrence_interval_weeks,v_series.valid_from,v_series.valid_until,
        greatest(v_series.valid_from,current_date),greatest(v_series.valid_from,current_date)+55
      ) d loop
        v_outcome:=private.onda5_materialize_series_occurrence(
          p_organization_id,p_actor_user_id,v_series.id,v_series.unit_id,v_series.client_id,v_series.professional_id,v_series.service_id,
          v_series.duration_minutes,v_timezone,v_occ_date,v_series.local_start_time,
          'onda5-series-occ:' || v_series.id::text || ':' || v_occ_date::text || ':' || p_idempotency_key
        );
        if v_outcome ->> 'outcome'='materialized' then v_appointments:=v_appointments||jsonb_build_array(v_outcome->'appointment'); else v_conflicts:=v_conflicts||jsonb_build_array(v_outcome->'conflict'); end if;
      end loop;
    end if;
    v_response:=jsonb_build_object('status','applied','scope','THIS_AND_FUTURE','series',to_jsonb(v_series),'appointments',v_appointments,'conflicts',v_conflicts);
  end if;
  update private.idempotency_keys set response=v_response where organization_id=p_organization_id and key=p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_series_update(uuid,uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.appointment_series_update(uuid,uuid,text,jsonb) to service_role;

create or replace function public.appointment_series_conflict_retry(
  p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex'); v_existing private.idempotency_keys%rowtype;
  v_conflict_id uuid := nullif(p_payload ->> 'conflict_id', '')::uuid;
  v_requested_series_id uuid := nullif(p_payload ->> 'series_id', '')::uuid;
  v_conflict public.appointment_series_conflicts%rowtype; v_series public.appointment_series%rowtype;
  v_timezone text; v_outcome jsonb; v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id,p_actor_user_id,array['owner','admin','manager','reception']) then raise exception 'insufficient organization permission' using errcode='42501'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key' using errcode='22023'; end if;
  if v_conflict_id is null then raise exception 'conflict_id is required' using errcode='22023'; end if;
  insert into private.idempotency_keys(organization_id,key,request_hash,created_by) values(p_organization_id,p_idempotency_key,v_hash,p_actor_user_id) on conflict(organization_id,key) do nothing;
  select * into v_existing from private.idempotency_keys where organization_id=p_organization_id and key=p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode='22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;
  select * into v_conflict from public.appointment_series_conflicts where organization_id=p_organization_id and id=v_conflict_id for update;
  if not found then raise exception 'series conflict not found' using errcode='P0002'; end if;
  if v_requested_series_id is not null and v_requested_series_id <> v_conflict.series_id then
    raise exception 'series conflict does not belong to the requested series' using errcode='P0021';
  end if;
  if v_conflict.status <> 'OPEN' then raise exception 'series conflict is not open' using errcode='P0020'; end if;
  select * into v_series from public.appointment_series where organization_id=p_organization_id and id=v_conflict.series_id for update;
  if not found then raise exception 'series not found' using errcode='P0002'; end if;
  select timezone into v_timezone from public.units where organization_id=p_organization_id and id=v_series.unit_id;
  v_outcome:=private.onda5_materialize_series_occurrence(
    p_organization_id,p_actor_user_id,v_series.id,v_series.unit_id,v_series.client_id,v_series.professional_id,v_series.service_id,
    v_series.duration_minutes,v_timezone,v_conflict.occurrence_date,v_series.local_start_time,v_conflict.idempotency_key,true
  );
  if v_outcome ->> 'outcome' <> 'materialized' then
    v_response:=jsonb_build_object('status','conflict_open','conflict',v_outcome->'conflict');
  else
    v_response:=jsonb_build_object('status','applied','conflict_id',v_conflict.id,'appointment',v_outcome->'appointment');
  end if;
  update private.idempotency_keys set response=v_response where organization_id=p_organization_id and key=p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.appointment_series_conflict_retry(uuid,uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.appointment_series_conflict_retry(uuid,uuid,text,jsonb) to service_role;
