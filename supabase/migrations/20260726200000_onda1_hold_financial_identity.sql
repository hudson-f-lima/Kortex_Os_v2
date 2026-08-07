-- Onda 1 remediation, fatia 1.
--
-- A autorização de depósito não é uma referência viva ao agendamento. Ela é
-- uma obrigação financeira criada para uma identidade congelada
-- (cliente+serviço+profissional+unidade+ocorrência). Reconstituir esta
-- identidade a partir de um agendamento já mutado pode apropriar dinheiro de
-- outra pessoa; por isso a migration falha fechada se houver holds legados.

alter table public.deposit_holds
  add column client_id uuid,
  add column service_id uuid,
  add column professional_id uuid;

do $$
begin
  if exists (select 1 from public.deposit_holds) then
    raise exception using
      errcode = 'P0009',
      message = 'deposit_holds legacy rows require manual financial identity resolution before this migration';
  end if;
end;
$$;

alter table public.deposit_holds
  alter column client_id set not null,
  alter column service_id set not null,
  alter column professional_id set not null,
  add constraint deposit_holds_org_client_fk
    foreign key (organization_id, client_id) references public.clients(organization_id, id),
  add constraint deposit_holds_org_service_fk
    foreign key (organization_id, service_id) references public.services(organization_id, id),
  add constraint deposit_holds_org_professional_fk
    foreign key (organization_id, professional_id) references public.professionals(organization_id, id);

-- Lifecycle transitions may update status/updated_at only. A hold must never
-- be redirected to a different client, service, professional or payment
-- intent after it exists.
create or replace function private.guard_deposit_hold_financial_identity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.organization_id is distinct from old.organization_id
    or new.unit_id is distinct from old.unit_id
    or new.appointment_id is distinct from old.appointment_id
    or new.payment_intent_id is distinct from old.payment_intent_id
    or new.client_id is distinct from old.client_id
    or new.service_id is distinct from old.service_id
    or new.professional_id is distinct from old.professional_id
    or new.mechanic is distinct from old.mechanic
    or new.amount_cents is distinct from old.amount_cents
    or new.no_show_commission_type is distinct from old.no_show_commission_type
    or new.no_show_commission_value is distinct from old.no_show_commission_value
    or new.expires_at is distinct from old.expires_at
    or new.created_by is distinct from old.created_by
  then
    raise exception 'deposit hold financial identity is immutable' using errcode = '55000';
  end if;
  return new;
end;
$$;

drop trigger if exists deposit_holds_financial_identity_guard on public.deposit_holds;
create trigger deposit_holds_financial_identity_guard
before update on public.deposit_holds
for each row execute function private.guard_deposit_hold_financial_identity();

-- Generic appointment updates cannot mutate the financial identity while a
-- hold is active. A future explicit replan command owns release+reissue.
create or replace function private.reject_active_hold_identity_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.client_id is distinct from old.client_id
    or new.service_id is distinct from old.service_id
    or new.professional_id is distinct from old.professional_id
  then
    perform 1
    from public.deposit_holds dh
    where dh.organization_id = old.organization_id
      and dh.appointment_id = old.id
      and dh.status = 'active'
    for update;

    if found then
      raise exception 'active deposit hold requires the explicit replan command before client, service or professional can change'
        using errcode = 'P0007';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists appointments_active_hold_identity_guard on public.appointments;
create trigger appointments_active_hold_identity_guard
before update on public.appointments
for each row execute function private.reject_active_hold_identity_change();

create or replace function public.deposit_hold_create(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_appointment_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_appointment public.appointments%rowtype;
  v_service public.services%rowtype;
  v_amount_cents bigint;
  v_expires_at timestamptz;
  v_payment_intent_id uuid := gen_random_uuid();
  v_provider_reference text := gen_random_uuid()::text;
  v_deposit_hold_id uuid := gen_random_uuid();
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager', 'reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;

  select * into v_appointment
  from public.appointments
  where organization_id = p_organization_id and id = p_appointment_id
  for update;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0005';
  end if;

  select * into v_service
  from public.services
  where organization_id = p_organization_id and id = v_appointment.service_id;

  if v_service.deposit_mechanic is null then
    return jsonb_build_object('status', 'skipped');
  end if;

  if v_service.deposit_type is null or v_service.deposit_value is null then
    raise exception 'service deposit policy is incomplete: deposit_mechanic requires deposit_type and deposit_value'
      using errcode = 'P0006';
  end if;

  v_amount_cents := case when v_service.deposit_type = 'percentage'
    then round(v_service.price_cents * v_service.deposit_value / 10000.0)::bigint
    else v_service.deposit_value end;
  v_expires_at := case when v_service.deposit_mechanic = 'hold' then now() + interval '5 days' else null end;

  insert into public.payment_intents(
    id, organization_id, unit_id, order_id, purpose, provider, provider_reference, amount_cents, status, created_by
  ) values (
    v_payment_intent_id, p_organization_id, v_appointment.unit_id, null, 'deposit', 'internal', v_provider_reference,
    v_amount_cents, 'requires_capture', p_actor_user_id
  );

  insert into public.deposit_holds(
    id, organization_id, unit_id, appointment_id, payment_intent_id,
    client_id, service_id, professional_id,
    mechanic, amount_cents, no_show_commission_type, no_show_commission_value, status, expires_at, created_by
  ) values (
    v_deposit_hold_id, p_organization_id, v_appointment.unit_id, p_appointment_id, v_payment_intent_id,
    v_appointment.client_id, v_appointment.service_id, v_appointment.professional_id,
    v_service.deposit_mechanic, v_amount_cents, v_service.no_show_commission_type, v_service.no_show_commission_value,
    'active', v_expires_at, p_actor_user_id
  );

  select jsonb_build_object(
    'id', dh.id, 'appointment_id', dh.appointment_id, 'payment_intent_id', dh.payment_intent_id,
    'client_id', dh.client_id, 'service_id', dh.service_id, 'professional_id', dh.professional_id,
    'mechanic', dh.mechanic, 'amount_cents', dh.amount_cents,
    'no_show_commission_type', dh.no_show_commission_type, 'no_show_commission_value', dh.no_show_commission_value,
    'status', dh.status, 'expires_at', dh.expires_at, 'created_at', dh.created_at
  ) into v_response
  from public.deposit_holds dh
  where dh.id = v_deposit_hold_id;

  return jsonb_build_object('status', 'created', 'deposit_hold', v_response);
end;
$$;
revoke all on function public.deposit_hold_create(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.deposit_hold_create(uuid, uuid, uuid) to service_role;

revoke all on function private.guard_deposit_hold_financial_identity() from public;
revoke all on function private.reject_active_hold_identity_change() from public;
