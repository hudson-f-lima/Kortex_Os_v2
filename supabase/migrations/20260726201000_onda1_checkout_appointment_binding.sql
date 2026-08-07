-- Onda 1 remediation, fatia 2.
--
-- A comanda de um agendamento grava a ocorrência e o hold que a liquidou.
-- O caminho novo é separado de checkout_close para preservar o fluxo walk-in
-- existente e reduzir o risco de regressão da RPC financeira histórica.

alter table public.appointments
  add constraint appointments_org_id_unit_unique unique (organization_id, id, unit_id);

alter table public.deposit_holds
  add constraint deposit_holds_org_id_appointment_unit_unique
    unique (organization_id, id, appointment_id, unit_id);

alter table public.orders
  add column appointment_id uuid,
  add column deposit_hold_id uuid,
  add constraint orders_org_appointment_unit_fk
    foreign key (organization_id, appointment_id, unit_id)
    references public.appointments(organization_id, id, unit_id)
    not valid,
  add constraint orders_org_hold_appointment_unit_fk
    foreign key (organization_id, deposit_hold_id, appointment_id, unit_id)
    references public.deposit_holds(organization_id, id, appointment_id, unit_id)
    not valid;

alter table public.orders validate constraint orders_org_appointment_unit_fk;
alter table public.orders validate constraint orders_org_hold_appointment_unit_fk;

create unique index orders_one_financial_order_per_appointment_idx
  on public.orders(organization_id, appointment_id)
  where appointment_id is not null;

create or replace function public.checkout_close_appointment(
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
  v_appointment public.appointments%rowtype;
  v_active_hold public.deposit_holds%rowtype;
  v_default_unit_id uuid;
  v_payload jsonb;
  v_response jsonb;
  v_order_id uuid;
  v_linked_hold_id uuid;
  v_expected_service_id uuid;
  v_expected_professional_id uuid;
begin
  if p_appointment_id is null then
    raise exception 'appointment_id is required for appointment checkout' using errcode = '22023';
  end if;

  -- Every command that changes appointment/hold money locks this pair in the
  -- same order: appointment first, active hold second.
  select * into v_appointment
  from public.appointments
  where organization_id = p_organization_id and id = p_appointment_id
  for update;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0005';
  end if;

  if v_appointment.status not in ('in_service', 'completed') then
    raise exception 'appointment must be in_service or completed before checkout' using errcode = 'P0010';
  end if;

  -- The current checkout implementation has no explicit unit parameter and
  -- its immutable children inherit the default unit. Until that API is
  -- promoted, reject non-default occurrences rather than crossing units.
  select id into v_default_unit_id
  from public.units
  where organization_id = p_organization_id and is_default and active;
  if v_default_unit_id is null then
    raise exception 'organization has no active default unit' using errcode = 'P0011';
  end if;
  if v_appointment.unit_id <> v_default_unit_id then
    raise exception 'appointment checkout for a non-default unit is not yet supported by the server-owned checkout contract'
      using errcode = 'P0011';
  end if;

  select * into v_active_hold
  from public.deposit_holds
  where organization_id = p_organization_id
    and appointment_id = p_appointment_id
    and status = 'active'
  for update;

  if found and v_active_hold.expires_at is not null and v_active_hold.expires_at <= now() then
    update public.deposit_holds
    set status = 'expired'
    where id = v_active_hold.id and status = 'active';
    update public.payment_intents
    set status = 'canceled'
    where id = v_active_hold.payment_intent_id and status = 'requires_capture';
    -- Returning a domain result (rather than raising) commits the terminal
    -- expiry transition while letting Express map it to a safe 409 response.
    return jsonb_build_object('status', 'deposit_expired', 'appointment_id', p_appointment_id);
  end if;

  if found and (
    v_active_hold.client_id <> v_appointment.client_id
    or v_active_hold.service_id <> v_appointment.service_id
    or v_active_hold.professional_id <> v_appointment.professional_id
    or v_active_hold.unit_id <> v_appointment.unit_id
  ) then
    raise exception 'active deposit hold financial identity does not match its appointment' using errcode = 'P0010';
  end if;

  v_expected_service_id := coalesce(v_active_hold.service_id, v_appointment.service_id);
  v_expected_professional_id := coalesce(v_active_hold.professional_id, v_appointment.professional_id);
  -- Validate the occurrence against the command before checkout_close can
  -- create any financial row. Packages are expanded here just as they are in
  -- checkout_close, so a package remains a legitimate way to sell the booked
  -- service when it assigns the booked professional to that component.
  if not exists (
    select 1
    from jsonb_array_elements(p_payload -> 'items') as item(value)
    where (
      item.value ->> 'kind' = 'service'
      and (item.value ->> 'id')::uuid = v_expected_service_id
      and (item.value ->> 'professional_id')::uuid = v_expected_professional_id
    ) or (
      item.value ->> 'kind' = 'package'
      and exists (
        select 1
        from public.package_items pi
        where pi.organization_id = p_organization_id
          and pi.package_id = (item.value ->> 'id')::uuid
          and pi.service_id = v_expected_service_id
          and (item.value -> 'professionals' ->> pi.service_id::text)::uuid = v_expected_professional_id
      )
    )
  ) then
    raise exception 'checkout items do not contain the appointment service and professional' using errcode = 'P0010';
  end if;

  -- The client and appointment are derived here, never accepted from the
  -- external command body. checkout_close remains the established atomic
  -- calculator for totals, stock, commissions and payments.
  v_payload := (p_payload - 'client_id' - 'appointment_id') || jsonb_build_object(
    'client_id', v_appointment.client_id,
    'appointment_id', p_appointment_id
  );
  v_response := public.checkout_close(
    p_organization_id,
    p_actor_user_id,
    p_idempotency_key,
    v_payload
  );
  v_order_id := (v_response ->> 'order_id')::uuid;

  -- Defense in depth: validate the final expanded order too. The payload
  -- guard above is fail-closed before effects; this guard protects any future
  -- change in package expansion semantics.
  if not exists (
    select 1
    from public.order_items oi
    where oi.organization_id = p_organization_id
      and oi.order_id = v_order_id
      and oi.kind = 'service'
      and oi.service_id = v_expected_service_id
      and oi.professional_id = v_expected_professional_id
  ) then
    raise exception 'checkout items do not contain the appointment service and professional' using errcode = 'P0010';
  end if;

  select dh.id into v_linked_hold_id
  from public.deposit_holds dh
  join public.payment_intents pi
    on pi.organization_id = dh.organization_id and pi.id = dh.payment_intent_id
  where dh.organization_id = p_organization_id
    and dh.appointment_id = p_appointment_id
    and pi.order_id = v_order_id
  limit 1;

  update public.orders
  set appointment_id = p_appointment_id,
      deposit_hold_id = coalesce(deposit_hold_id, v_linked_hold_id)
  where organization_id = p_organization_id and id = v_order_id;

  return v_response;
end;
$$;

revoke all on function public.checkout_close_appointment(uuid, uuid, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.checkout_close_appointment(uuid, uuid, text, uuid, jsonb) to service_role;
