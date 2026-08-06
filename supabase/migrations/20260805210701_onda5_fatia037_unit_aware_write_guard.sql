set check_function_bodies = off;

CREATE OR REPLACE FUNCTION private.assert_actor_can_write_fact_unit(p_organization_id uuid, p_actor_user_id uuid, p_unit_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if not exists (
    select 1
    from public.memberships m
    join public.organizations o on o.id = m.organization_id and o.active
    where m.organization_id = p_organization_id
      and m.user_id = p_actor_user_id
      and m.active
      and (
        m.role in ('owner', 'admin', 'manager')
        or (m.role = 'reception' and m.unit_id = p_unit_id)
      )
  ) then
    raise exception 'insufficient unit permission' using errcode = '42501';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.assert_actor_can_write_onda5_target(p_organization_id uuid, p_actor_user_id uuid, p_operation text, p_payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
declare
  v_unit_id uuid := private.onda5_write_target_unit(p_organization_id, p_operation, p_payload);
begin
  if v_unit_id is null then
    -- Mantém o contrato anterior para ID inexistente ou de outro tenant: o
    -- corpo original decide o erro `not found`, sem revelar unidade alguma.
    return;
  end if;
  perform private.assert_actor_can_write_fact_unit(p_organization_id, p_actor_user_id, v_unit_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION private.onda5_guarded_write_dispatch(p_operation text, p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
begin
  perform private.assert_actor_can_write_onda5_target(p_organization_id, p_actor_user_id, p_operation, p_payload);
  case p_operation
    when 'appointment_series_create' then return public.appointment_series_create_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'appointment_series_extend_window' then return public.appointment_series_extend_window_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'appointment_series_update' then return public.appointment_series_update_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'appointment_series_cancel' then return public.appointment_series_cancel_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'appointment_series_conflict_retry' then return public.appointment_series_conflict_retry_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'appointment_group_create' then return public.appointment_group_create_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'appointment_group_member_add' then return public.appointment_group_member_add_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'appointment_group_update' then return public.appointment_group_update_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'appointment_group_cancel' then return public.appointment_group_cancel_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'waitlist_entry_create' then return public.waitlist_entry_create_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'waitlist_matcher_run' then return public.waitlist_matcher_run_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'waitlist_offer_accept' then return public.waitlist_offer_accept_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'waitlist_offer_decline' then return public.waitlist_offer_decline_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
    when 'waitlist_offer_expire' then return public.waitlist_offer_expire_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
  end case;
  raise exception 'unsupported Onda 5 write operation' using errcode = '22023';
end;
$function$
;

CREATE OR REPLACE FUNCTION private.onda5_write_target_unit(p_organization_id uuid, p_operation text, p_payload jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_id uuid;
  v_unit_id uuid;
begin
  if p_operation in ('appointment_series_create', 'appointment_group_create', 'waitlist_entry_create', 'waitlist_matcher_run') then
    return nullif(p_payload ->> 'unit_id', '')::uuid;
  end if;

  if p_operation in ('appointment_series_extend_window', 'appointment_series_update', 'appointment_series_cancel') then
    v_id := nullif(p_payload ->> 'series_id', '')::uuid;
    select unit_id into v_unit_id from public.appointment_series
      where organization_id = p_organization_id and id = v_id;
    return v_unit_id;
  end if;

  if p_operation = 'appointment_series_conflict_retry' then
    v_id := nullif(p_payload ->> 'conflict_id', '')::uuid;
    select s.unit_id into v_unit_id
      from public.appointment_series_conflicts c
      join public.appointment_series s on s.organization_id = c.organization_id and s.id = c.series_id
      where c.organization_id = p_organization_id and c.id = v_id;
    return v_unit_id;
  end if;

  if p_operation in ('appointment_group_member_add', 'appointment_group_update', 'appointment_group_cancel') then
    v_id := nullif(p_payload ->> 'group_id', '')::uuid;
    select unit_id into v_unit_id from public.appointment_groups
      where organization_id = p_organization_id and id = v_id;
    return v_unit_id;
  end if;

  if p_operation in ('waitlist_offer_accept', 'waitlist_offer_decline', 'waitlist_offer_expire') then
    v_id := nullif(p_payload ->> 'offer_id', '')::uuid;
    select unit_id into v_unit_id from public.waitlist_offers
      where organization_id = p_organization_id and id = v_id;
    return v_unit_id;
  end if;

  raise exception 'unsupported Onda 5 write operation' using errcode = '22023';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_group_cancel_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_group_create_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_group_member_add_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_group_update_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_cancel_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_conflict_retry_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_create_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_extend_window_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_update_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.waitlist_entry_create_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_client_id uuid := nullif(p_payload ->> 'client_id', '')::uuid;
  v_service_id uuid := nullif(p_payload ->> 'service_id', '')::uuid;
  v_date_from date := nullif(p_payload ->> 'date_from', '')::date;
  v_date_to date := nullif(p_payload ->> 'date_to', '')::date;
  v_consent boolean := (p_payload ->> 'consent')::boolean;
  v_professional_ids uuid[];
  v_professional_id uuid;
  v_entry_id uuid := gen_random_uuid();
  v_entry_json jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_unit_id is null or v_client_id is null or v_service_id is null or v_date_from is null or v_date_to is null then
    raise exception 'unit_id, client_id, service_id, date_from and date_to are required' using errcode = '22023';
  end if;
  if v_date_to < v_date_from then
    raise exception 'date_to must not be before date_from' using errcode = '22023';
  end if;
  if coalesce(v_consent, false) is not true then
    raise exception 'explicit consent is required to join the waitlist' using errcode = '22023';
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

  if not exists (select 1 from public.units where organization_id = p_organization_id and id = v_unit_id) then
    raise exception 'unit not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.clients where organization_id = p_organization_id and id = v_client_id) then
    raise exception 'client not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.services where organization_id = p_organization_id and id = v_service_id) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;

  select array_agg(x::uuid) into v_professional_ids
  from jsonb_array_elements_text(coalesce(p_payload -> 'professional_ids', '[]'::jsonb)) x;

  if v_professional_ids is not null then
    foreach v_professional_id in array v_professional_ids loop
      if not exists (
        select 1 from public.professional_units
        where organization_id = p_organization_id and unit_id = v_unit_id
          and professional_id = v_professional_id and active
      ) then
        raise exception 'professional is not linked to this unit' using errcode = 'P0002';
      end if;
    end loop;
  end if;

  insert into public.waitlist_entries(id, organization_id, unit_id, client_id, service_id, date_from, date_to, consent_at)
  values (v_entry_id, p_organization_id, v_unit_id, v_client_id, v_service_id, v_date_from, v_date_to, now());

  if v_professional_ids is not null and array_length(v_professional_ids, 1) > 0 then
    insert into public.waitlist_entry_professionals(organization_id, unit_id, waitlist_entry_id, professional_id)
    select p_organization_id, v_unit_id, v_entry_id, x from unnest(v_professional_ids) x;
  end if;

  select jsonb_build_object(
    'id', we.id, 'organization_id', we.organization_id, 'unit_id', we.unit_id, 'client_id', we.client_id,
    'service_id', we.service_id, 'date_from', we.date_from, 'date_to', we.date_to, 'status', we.status
  ) into v_entry_json
  from public.waitlist_entries we where we.id = v_entry_id;

  v_response := jsonb_build_object('status', 'applied', 'entry', v_entry_json);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.waitlist_matcher_run_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
  v_professional_id uuid := nullif(p_payload ->> 'professional_id', '')::uuid;
  v_service_id uuid := nullif(p_payload ->> 'service_id', '')::uuid;
  v_starts_at timestamptz := (p_payload ->> 'starts_at')::timestamptz;
  v_timezone text;
  v_local_date date;
  v_start_minutes integer;
  v_end_minutes integer;
  v_override_open boolean;
  v_override_reason text;
  v_policy_blocks jsonb;
  v_shift_blocks jsonb;
  v_eligible boolean;
  v_duration integer;
  v_ends_at timestamptz;
  v_ttl_minutes integer;
  v_cooldown_hours integer;
  v_offer_wave_id uuid := gen_random_uuid();
  v_entry record;
  v_token text;
  v_token_hash text;
  v_offer_id uuid;
  v_offers jsonb := '[]'::jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_unit_id is null or v_professional_id is null or v_service_id is null or v_starts_at is null then
    raise exception 'unit_id, professional_id, service_id and starts_at are required' using errcode = '22023';
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

  if not exists (select 1 from public.units where organization_id = p_organization_id and id = v_unit_id) then
    raise exception 'unit not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.professionals where organization_id = p_organization_id and id = v_professional_id) then
    raise exception 'professional not found' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.services where organization_id = p_organization_id and id = v_service_id) then
    raise exception 'service not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.professional_units
    where organization_id = p_organization_id and unit_id = v_unit_id and professional_id = v_professional_id and active
  ) then
    raise exception 'professional is not linked to this unit' using errcode = 'P0002';
  end if;

  select r.eligible into v_eligible from private.resolve_eligibility(p_organization_id, v_professional_id, v_service_id) r;
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

  select timezone into v_timezone from public.units where organization_id = p_organization_id and id = v_unit_id;
  v_local_date := (v_starts_at at time zone v_timezone)::date;
  v_start_minutes := extract(hour from (v_starts_at at time zone v_timezone))::int * 60
    + extract(minute from (v_starts_at at time zone v_timezone))::int;
  v_end_minutes := extract(hour from (v_ends_at at time zone v_timezone))::int * 60
    + extract(minute from (v_ends_at at time zone v_timezone))::int;
  if v_end_minutes <= v_start_minutes then
    raise exception 'candidate slot cannot cross local midnight' using errcode = '22023';
  end if;

  select o.is_open, o.reason into v_override_open, v_override_reason
  from private.resolve_calendar_overrides(p_organization_id, v_unit_id, v_professional_id, v_local_date) o;
  if v_override_open is not null and v_override_open = false then
    raise exception 'slot outside calendar availability (%)', v_override_reason using errcode = 'P0006';
  end if;
  select p.blocks into v_policy_blocks from private.resolve_calendar_policy(p_organization_id, v_unit_id, v_local_date) p;
  if not private.onda5_range_within_blocks(v_policy_blocks, v_start_minutes, v_end_minutes) then
    raise exception 'slot outside unit calendar policy' using errcode = 'P0006';
  end if;
  select s.blocks into v_shift_blocks from private.resolve_professional_shift(p_organization_id, v_professional_id, v_unit_id, v_local_date) s;
  if not private.onda5_range_within_blocks(v_shift_blocks, v_start_minutes, v_end_minutes) then
    raise exception 'slot outside professional shift' using errcode = 'P0006';
  end if;

  -- Lê organizations.settings diretamente, com o mesmo coalesce/defaults de
  -- private.onda5_waitlist_settings (fatia 029) — não chama essa função
  -- aqui. Achado do Red Team de implementação: onda5_waitlist_settings usa
  -- private.is_member(), que deriva o membro da sessão JWT autenticada
  -- (request.jwt.claim.sub) para checar tenant mesmo sendo security
  -- definer — desenho correto para uma chamada direta de cliente
  -- autenticado via PostgREST, mas o matcher já validou o actor
  -- explicitamente por private.actor_has_role(p_actor_user_id, ...) acima;
  -- não há sessão JWT alguma quando esta função é chamada internamente
  -- (service_role, sem auth.uid()), então is_member sempre falharia aqui,
  -- mesmo com o actor certo.
  select
    coalesce((o.settings ->> 'waitlist_offer_ttl_minutes')::integer, 30),
    coalesce((o.settings ->> 'waitlist_offer_cooldown_hours')::integer, 6)
    into v_ttl_minutes, v_cooldown_hours
  from public.organizations o
  where o.id = p_organization_id;

  for v_entry in
    select we.* from public.waitlist_entries we
    where we.organization_id = p_organization_id
      and we.unit_id = v_unit_id
      and we.service_id = v_service_id
      and we.status = 'ACTIVE'
      and we.date_from <= v_local_date and we.date_to >= v_local_date
      and (we.cooldown_until is null or we.cooldown_until <= now())
      and (
        not exists (
          select 1 from public.waitlist_entry_professionals wep
          where wep.organization_id = p_organization_id and wep.waitlist_entry_id = we.id
        )
        or exists (
          select 1 from public.waitlist_entry_professionals wep
          where wep.organization_id = p_organization_id and wep.waitlist_entry_id = we.id
            and wep.professional_id = v_professional_id
        )
      )
    order by we.created_at
    for update
  loop
    v_token := encode(gen_random_bytes(32), 'hex');
    v_token_hash := encode(digest(v_token, 'sha256'), 'hex');
    v_offer_id := gen_random_uuid();

    insert into public.waitlist_offers(
      id, organization_id, unit_id, waitlist_entry_id, offer_wave_id,
      candidate_starts_at, candidate_ends_at, candidate_professional_id,
      token_hash, expires_at, cooldown_until, idempotency_key
    ) values (
      v_offer_id, p_organization_id, v_unit_id, v_entry.id, v_offer_wave_id,
      v_starts_at, v_ends_at, v_professional_id,
      v_token_hash, now() + (v_ttl_minutes || ' minutes')::interval,
      now() + (v_cooldown_hours || ' hours')::interval,
      p_idempotency_key || ':entry:' || v_entry.id::text
    )
    on conflict (organization_id, waitlist_entry_id, candidate_starts_at, candidate_professional_id)
      where status = 'OFFERED'
    do nothing;

    if found then
      update public.waitlist_entries
      set status = 'OFFERED', last_offered_at = now(), attempt_count = attempt_count + 1
      where organization_id = p_organization_id and id = v_entry.id;

      -- Fatia 039: o token bruto vive apenas no outbox privado, criado na
      -- mesma transação da oferta. Um worker FCM só o observa após commit;
      -- ausência de dispositivo simplesmente não cria trabalho de entrega.
      insert into private.waitlist_offer_push_outbox(
        organization_id, offer_id, client_id, client_user_id, device_id, payload
      )
      select
        p_organization_id, v_offer_id, v_entry.client_id, d.user_id, d.id,
        jsonb_build_object(
          'type', 'waitlist_offer', 'offer_id', v_offer_id,
          'token', v_token,
          'deep_link', '/waitlist/offers/' || v_offer_id::text || '?token=' || v_token
        )
      from public.client_push_devices d
      join public.client_app_identities cai
        on cai.organization_id = d.organization_id
       and cai.client_id = d.client_id
       and cai.user_id = d.user_id
      where d.organization_id = p_organization_id
        and d.client_id = v_entry.client_id
      on conflict (offer_id, device_id) do nothing;

      v_offers := v_offers || jsonb_build_array(jsonb_build_object(
        'id', v_offer_id, 'waitlist_entry_id', v_entry.id, 'offer_wave_id', v_offer_wave_id,
        'candidate_starts_at', v_starts_at, 'candidate_ends_at', v_ends_at,
        'candidate_professional_id', v_professional_id,
        'expires_at', now() + (v_ttl_minutes || ' minutes')::interval,
        'token', v_token
      ));
    end if;
  end loop;

  v_response := jsonb_build_object('status', 'applied', 'offer_wave_id', v_offer_wave_id, 'offers', v_offers);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.waitlist_offer_accept_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_offer_id uuid := nullif(p_payload ->> 'offer_id', '')::uuid;
  v_token text := p_payload ->> 'token';
  v_offer public.waitlist_offers%rowtype;
  v_entry public.waitlist_entries%rowtype;
  v_create_result jsonb;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_offer_id is null or v_token is null or length(v_token) = 0 then
    raise exception 'offer_id and token are required' using errcode = '22023';
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

  -- CAS (Blueprint §3.3.6): trava a oferta antes de qualquer decisão. Nunca
  -- vaza se o offer_id existe em outro tenant — organization_id erra junto
  -- com o id, então uma oferta de outro tenant simplesmente não é
  -- encontrada (mesma disciplina de toda outra RPC desta trilha).
  select * into v_offer from public.waitlist_offers
  where organization_id = p_organization_id and id = v_offer_id
  for update;
  if not found then
    raise exception 'waitlist offer not found' using errcode = 'P0002';
  end if;

  -- "Vencida" é uma condição de tempo real, não só o status persistido: uma
  -- oferta com expires_at no passado nunca reserva o slot, mesmo que o job
  -- de expiração (waitlist_offer_expire) ainda não tenha rodado.
  if v_offer.status <> 'OFFERED' or v_offer.expires_at <= now() then
    raise exception 'waitlist offer is not open for a decision' using errcode = 'P0023';
  end if;
  if encode(digest(v_token, 'sha256'), 'hex') <> v_offer.token_hash then
    raise exception 'waitlist offer token does not match' using errcode = 'P0024';
  end if;

  select * into v_entry from public.waitlist_entries
  where organization_id = p_organization_id and id = v_offer.waitlist_entry_id
  for update;
  if not found then
    raise exception 'waitlist entry not found' using errcode = 'P0002';
  end if;

  -- HOLDING é puramente transacional (Blueprint §3.3.2): nasce e morre
  -- dentro desta mesma transação, nunca observável após commit.
  update public.waitlist_entries set status = 'HOLDING' where organization_id = p_organization_id and id = v_entry.id;

  v_create_result := public.create_appointment(
    p_organization_id, p_actor_user_id, p_idempotency_key || ':appointment',
    jsonb_build_object(
      'client_id', v_entry.client_id, 'professional_id', v_offer.candidate_professional_id,
      'service_id', v_entry.service_id, 'starts_at', v_offer.candidate_starts_at,
      'origin', 'waitlist', 'unit_id', v_offer.unit_id
    )
  );
  if v_create_result ->> 'status' <> 'applied' then
    raise exception 'waitlist acceptance requires an applied appointment' using errcode = 'P0001';
  end if;

  update public.waitlist_offers set status = 'ACCEPTED', responded_at = now()
  where organization_id = p_organization_id and id = v_offer_id;
  update public.waitlist_entries set status = 'BOOKED'
  where organization_id = p_organization_id and id = v_entry.id;

  -- Ofertas irmãs da mesma onda perdem a corrida (Blueprint §3.3.7): viram
  -- SUPERSEDED e suas entradas voltam para ACTIVE, sujeitas ao cooldown já
  -- calculado quando a oferta foi criada.
  update public.waitlist_entries we set
    status = 'ACTIVE',
    cooldown_until = wo.cooldown_until
  from public.waitlist_offers wo
  where wo.organization_id = p_organization_id and wo.offer_wave_id = v_offer.offer_wave_id
    and wo.id <> v_offer_id and wo.status = 'OFFERED'
    and we.organization_id = p_organization_id and we.id = wo.waitlist_entry_id;

  update public.waitlist_offers
  set status = 'SUPERSEDED', responded_at = now()
  where organization_id = p_organization_id and offer_wave_id = v_offer.offer_wave_id
    and id <> v_offer_id and status = 'OFFERED';

  v_response := jsonb_build_object(
    'status', 'applied', 'appointment', v_create_result -> 'appointment',
    'waitlist_entry_id', v_entry.id, 'offer_id', v_offer_id
  );
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.waitlist_offer_decline_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_offer_id uuid := nullif(p_payload ->> 'offer_id', '')::uuid;
  v_token text := p_payload ->> 'token';
  v_offer public.waitlist_offers%rowtype;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_offer_id is null or v_token is null or length(v_token) = 0 then
    raise exception 'offer_id and token are required' using errcode = '22023';
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

  select * into v_offer from public.waitlist_offers
  where organization_id = p_organization_id and id = v_offer_id
  for update;
  if not found then
    raise exception 'waitlist offer not found' using errcode = 'P0002';
  end if;
  if v_offer.status <> 'OFFERED' or v_offer.expires_at <= now() then
    raise exception 'waitlist offer is not open for a decision' using errcode = 'P0023';
  end if;
  if encode(digest(v_token, 'sha256'), 'hex') <> v_offer.token_hash then
    raise exception 'waitlist offer token does not match' using errcode = 'P0024';
  end if;

  update public.waitlist_offers set status = 'DECLINED', responded_at = now()
  where organization_id = p_organization_id and id = v_offer_id;
  update public.waitlist_entries set status = 'ACTIVE', cooldown_until = v_offer.cooldown_until
  where organization_id = p_organization_id and id = v_offer.waitlist_entry_id;

  v_response := jsonb_build_object('status', 'applied', 'offer_id', v_offer_id, 'waitlist_entry_id', v_offer.waitlist_entry_id);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.waitlist_offer_expire_unsafe(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_offer_id uuid := nullif(p_payload ->> 'offer_id', '')::uuid;
  v_offer public.waitlist_offers%rowtype;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if v_offer_id is null then
    raise exception 'offer_id is required' using errcode = '22023';
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

  select * into v_offer from public.waitlist_offers
  where organization_id = p_organization_id and id = v_offer_id
  for update;
  if not found then
    raise exception 'waitlist offer not found' using errcode = 'P0002';
  end if;
  if v_offer.status <> 'OFFERED' or v_offer.expires_at > now() then
    raise exception 'waitlist offer is not open for a decision' using errcode = 'P0023';
  end if;

  update public.waitlist_offers set status = 'EXPIRED', responded_at = now()
  where organization_id = p_organization_id and id = v_offer_id;
  update public.waitlist_entries set status = 'ACTIVE', cooldown_until = v_offer.cooldown_until
  where organization_id = p_organization_id and id = v_offer.waitlist_entry_id;

  v_response := jsonb_build_object('status', 'applied', 'offer_id', v_offer_id, 'waitlist_entry_id', v_offer.waitlist_entry_id);
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.appointment_group_cancel(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_group_cancel', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.appointment_group_create(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_group_create', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.appointment_group_member_add(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_group_member_add', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.appointment_group_update(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_group_update', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_cancel(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_series_cancel', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_conflict_retry(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_series_conflict_retry', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_create(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_series_create', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_extend_window(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_series_extend_window', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.appointment_series_update(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('appointment_series_update', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.waitlist_entry_create(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
declare
  v_unit_id uuid := nullif(p_payload ->> 'unit_id', '')::uuid;
begin
  if v_unit_id is null then
    raise exception 'unit_id is required' using errcode = '22023';
  end if;
  perform private.assert_actor_can_write_fact_unit(p_organization_id, p_actor_user_id, v_unit_id);
  return public.waitlist_entry_create_unsafe(p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.waitlist_matcher_run(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('waitlist_matcher_run', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.waitlist_offer_accept(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('waitlist_offer_accept', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.waitlist_offer_decline(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('waitlist_offer_decline', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
      $function$
;

CREATE OR REPLACE FUNCTION public.waitlist_offer_expire(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private', 'extensions'
AS $function$
      begin
        return private.onda5_guarded_write_dispatch('waitlist_offer_expire', p_organization_id, p_actor_user_id, p_idempotency_key, p_payload);
      end;
$function$
;

revoke all on function public.appointment_series_create_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.appointment_series_extend_window_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.appointment_series_update_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.appointment_series_cancel_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.appointment_series_conflict_retry_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.appointment_group_create_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.appointment_group_member_add_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.appointment_group_update_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.appointment_group_cancel_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.waitlist_entry_create_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.waitlist_matcher_run_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.waitlist_offer_accept_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.waitlist_offer_decline_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.waitlist_offer_expire_unsafe(uuid, uuid, text, jsonb) from public, anon, authenticated, service_role;
