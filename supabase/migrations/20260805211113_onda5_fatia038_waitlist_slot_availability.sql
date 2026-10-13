set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.onda5_waitlist_empty_match_response(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_response jsonb := jsonb_build_object('status', 'applied', 'offer_wave_id', gen_random_uuid(), 'offers', '[]'::jsonb);
begin
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
   where organization_id = p_organization_id and key = p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then
    return v_existing.response;
  end if;
  update private.idempotency_keys set response = v_response
   where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$function$
;
CREATE OR REPLACE FUNCTION private.onda5_waitlist_slot_is_available(p_organization_id uuid, p_unit_id uuid, p_professional_id uuid, p_service_id uuid, p_starts_at timestamp with time zone)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_duration integer;
  v_ends_at timestamptz;
  v_timezone text;
  v_local_date date;
  v_start_minutes integer;
  v_end_minutes integer;
  v_override_open boolean;
  v_override_reason text;
  v_policy_blocks jsonb;
  v_shift_blocks jsonb;
  v_eligible boolean;
begin
  if p_unit_id is null or p_professional_id is null or p_service_id is null or p_starts_at is null then
    return true;
  end if;
  if not exists (select 1 from public.units where organization_id = p_organization_id and id = p_unit_id)
     or not exists (select 1 from public.professionals where organization_id = p_organization_id and id = p_professional_id)
     or not exists (select 1 from public.services where organization_id = p_organization_id and id = p_service_id)
     or not exists (
       select 1 from public.professional_units
       where organization_id = p_organization_id and unit_id = p_unit_id and professional_id = p_professional_id and active
     ) then
    return true;
  end if;

  select r.eligible into v_eligible
    from private.resolve_eligibility(p_organization_id, p_professional_id, p_service_id) r;
  if not v_eligible then
    raise exception 'professional is not eligible for this service' using errcode = 'P0003';
  end if;

  select coalesce(psc.duration_override_minutes, s.duration_minutes) into v_duration
    from public.services s
    left join public.professional_service_capabilities psc
      on psc.organization_id = p_organization_id
     and psc.professional_id = p_professional_id
     and psc.service_id = p_service_id
   where s.organization_id = p_organization_id and s.id = p_service_id;
  v_ends_at := p_starts_at + (v_duration || ' minutes')::interval;
  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = p_unit_id;
  v_local_date := (p_starts_at at time zone v_timezone)::date;
  v_start_minutes := extract(hour from (p_starts_at at time zone v_timezone))::int * 60 + extract(minute from (p_starts_at at time zone v_timezone))::int;
  v_end_minutes := extract(hour from (v_ends_at at time zone v_timezone))::int * 60 + extract(minute from (v_ends_at at time zone v_timezone))::int;
  if v_end_minutes <= v_start_minutes then
    raise exception 'candidate slot cannot cross local midnight' using errcode = '22023';
  end if;

  select o.is_open, o.reason into v_override_open, v_override_reason
    from private.resolve_calendar_overrides(p_organization_id, p_unit_id, p_professional_id, v_local_date) o;
  if v_override_open is not null and v_override_open = false then
    raise exception 'slot outside calendar availability (%)', v_override_reason using errcode = 'P0006';
  end if;
  select p.blocks into v_policy_blocks from private.resolve_calendar_policy(p_organization_id, p_unit_id, v_local_date) p;
  if not private.onda5_range_within_blocks(v_policy_blocks, v_start_minutes, v_end_minutes) then
    raise exception 'slot outside unit calendar policy' using errcode = 'P0006';
  end if;
  select s.blocks into v_shift_blocks from private.resolve_professional_shift(p_organization_id, p_professional_id, p_unit_id, v_local_date) s;
  if not private.onda5_range_within_blocks(v_shift_blocks, v_start_minutes, v_end_minutes) then
    raise exception 'slot outside professional shift' using errcode = 'P0006';
  end if;

  return not exists (
    select 1 from public.appointments a
    where a.organization_id = p_organization_id
      and a.unit_id = p_unit_id
      and a.professional_id = p_professional_id
      and a.status in ('scheduled', 'confirmed')
      and tstzrange(a.starts_at, a.ends_at, '[)') && tstzrange(p_starts_at, v_ends_at, '[)')
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.waitlist_matcher_run(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_professional_id uuid := nullif(p_payload ->> 'professional_id', '')::uuid;
  v_service_id uuid := nullif(p_payload ->> 'service_id', '')::uuid;
  v_starts_at timestamptz := (p_payload ->> 'starts_at')::timestamptz;
begin
  perform private.assert_actor_can_write_onda5_target(p_organization_id, p_actor_user_id, 'waitlist_matcher_run', p_payload);
  if not private.onda5_waitlist_slot_is_available(p_organization_id, v_unit_id, v_professional_id, v_service_id, v_starts_at) then
    return private.onda5_waitlist_empty_match_response(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
  end if;
  return public.waitlist_matcher_run_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
end;
$function$
;
