-- Onda 1 remediation, fatia 3b.
-- Explicit replan is the sole path that releases a hold authorization and
-- changes the frozen appointment identity in one idempotent transaction.

create or replace function public.appointment_replan_with_hold(
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
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_hold public.deposit_holds%rowtype;
  v_update_result jsonb;
  v_hold_result jsonb;
  v_response jsonb;
  v_internal_key text := 'replan:' || encode(digest(p_idempotency_key, 'sha256'), 'hex');
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager', 'reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing
  from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then
    return v_existing.response;
  end if;

  perform 1
  from public.appointments
  where organization_id = p_organization_id and id = p_appointment_id
  for update;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0005';
  end if;

  select * into v_hold
  from public.deposit_holds
  where organization_id = p_organization_id
    and appointment_id = p_appointment_id
    and status = 'active'
  for update;
  if not found then
    raise exception 'replan requires an active deposit hold' using errcode = 'P0013';
  end if;
  if v_hold.mechanic = 'immediate_charge' then
    raise exception 'immediate_charge replan requires a real refund command' using errcode = 'P0008';
  end if;

  update public.deposit_holds
  set status = 'released'
  where id = v_hold.id and status = 'active';
  update public.payment_intents
  set status = 'canceled'
  where id = v_hold.payment_intent_id and status = 'requires_capture';

  v_update_result := public.update_appointment(
    p_organization_id,
    p_actor_user_id,
    v_internal_key,
    p_appointment_id,
    p_payload
  );
  if v_update_result ->> 'status' <> 'applied' then
    raise exception 'replan requires an applied appointment update' using errcode = 'P0001';
  end if;

  v_hold_result := public.deposit_hold_create(
    p_organization_id,
    p_actor_user_id,
    p_appointment_id
  );
  v_response := jsonb_build_object(
    'status', 'applied',
    'appointment', v_update_result -> 'appointment',
    'released_hold_id', v_hold.id,
    'deposit_hold', case when v_hold_result ->> 'status' = 'created' then v_hold_result -> 'deposit_hold' else null end
  );
  update private.idempotency_keys
  set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

revoke all on function public.appointment_replan_with_hold(uuid, uuid, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.appointment_replan_with_hold(uuid, uuid, text, uuid, jsonb) to service_role;
