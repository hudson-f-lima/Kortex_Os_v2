-- Onda 1 remediation, fatia 3.
--
-- Appointment status changes are the lifecycle boundary for a deposit. The
-- trigger runs in the same transaction as update_appointment, so cancellation
-- and no-show can never leave a partially changed financial state.

create or replace function private.apply_appointment_deposit_hold_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hold public.deposit_holds%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_commission_cents bigint;
  v_actor_user_id uuid := nullif(current_setting('app.kortex_actor_user_id', true), '')::uuid;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  select * into v_hold
  from public.deposit_holds
  where organization_id = new.organization_id
    and appointment_id = new.id
    and status = 'active'
  for update;
  if not found then
    return new;
  end if;

  if new.status = 'cancelled' then
    if v_hold.mechanic = 'immediate_charge' then
      raise exception 'immediate_charge cancellation requires a real refund command'
        using errcode = 'P0008';
    end if;

    update public.deposit_holds
    set status = 'released'
    where id = v_hold.id and status = 'active';
    update public.payment_intents
    set status = 'canceled'
    where id = v_hold.payment_intent_id and status = 'requires_capture';
    return new;
  end if;

  if new.status <> 'no_show' then
    return new;
  end if;

  -- Expiration is terminal but not a false financial capture. The appointment
  -- can still be recorded as no_show; it simply has no collectible hold.
  if v_hold.expires_at is not null and v_hold.expires_at <= now() then
    update public.deposit_holds
    set status = 'expired'
    where id = v_hold.id and status = 'active';
    update public.payment_intents
    set status = 'canceled'
    where id = v_hold.payment_intent_id and status = 'requires_capture';
    return new;
  end if;

  update public.deposit_holds
  set status = 'captured_no_show'
  where id = v_hold.id and status = 'active'
  returning * into v_hold;
  if not found then
    return new;
  end if;

  v_commission_cents := case v_hold.no_show_commission_type
    when 'percentage' then round(v_hold.amount_cents * v_hold.no_show_commission_value / 10000.0)::bigint
    when 'fixed' then v_hold.no_show_commission_value
    else 0
  end;

  insert into public.orders(
    id, organization_id, unit_id, client_id, appointment_id, deposit_hold_id, status,
    subtotal_cents, discount_cents, tip_cents, total_cents, created_by, closed_at
  ) values (
    v_order_id, new.organization_id, v_hold.unit_id, v_hold.client_id, new.id, v_hold.id, 'closed',
    v_hold.amount_cents, 0, 0, v_hold.amount_cents, coalesce(v_actor_user_id, new.created_by), now()
  );

  insert into public.order_items(
    organization_id, unit_id, order_id, kind, service_id, product_id,
    description, quantity, unit_price_cents, total_cents,
    professional_id, commission_type, commission_value, commission_cents
  ) values (
    new.organization_id, v_hold.unit_id, v_order_id, 'service', v_hold.service_id, null,
    'No-show', 1, v_hold.amount_cents, v_hold.amount_cents,
    v_hold.professional_id, v_hold.no_show_commission_type, v_hold.no_show_commission_value, v_commission_cents
  );

  insert into public.payments(organization_id, unit_id, order_id, method, amount_cents)
  values (new.organization_id, v_hold.unit_id, v_order_id, 'deposit', v_hold.amount_cents);
  insert into public.cash_entries(organization_id, unit_id, order_id, kind, amount_cents, description, created_by)
  values (
    new.organization_id, v_hold.unit_id, v_order_id, 'sale', v_hold.amount_cents, 'No-show',
    coalesce(v_actor_user_id, new.created_by)
  );
  update public.payment_intents
  set status = 'captured', order_id = v_order_id
  where id = v_hold.payment_intent_id;

  return new;
end;
$$;

drop trigger if exists appointments_deposit_hold_lifecycle on public.appointments;
create trigger appointments_deposit_hold_lifecycle
after update of status on public.appointments
for each row execute function private.apply_appointment_deposit_hold_lifecycle();

revoke all on function private.apply_appointment_deposit_hold_lifecycle() from public;
