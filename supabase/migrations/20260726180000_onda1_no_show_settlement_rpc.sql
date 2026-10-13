-- Onda 1, fatia 005 (issues/005-no-show-settlement-rpc.md): RPC nova e
-- pequena para liquidar a cobrança de no-show — deliberadamente fora de
-- checkout_close e sem chamar resolve_commission() normal. Ver
-- docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1_DRAFT.md §3.2, §3.3, §7.1.
--
-- Gera um pedido sintético real (order + order_item + payment) para que a
-- comissão de no-show apareça exatamente onde o colaborador já verifica
-- comissão hoje (order_items.commission_cents) — nenhuma trilha paralela.
-- Comissão vem do snapshot já congelado em deposit_holds pela fatia 003
-- (no_show_commission_type/value), nunca de resolve_commission(). Mesmo CAS
-- da fatia 004 (WHERE status = 'active') — mutuamente exclusivo com a
-- reconciliação de checkout, sem idempotency_key própria: a CAS já garante
-- no máximo um efeito financeiro por hold.
create or replace function public.no_show_settlement_create(
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
  v_deposit_hold public.deposit_holds%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_commission_cents bigint;
  v_response jsonb;
begin
  -- Mesmo papel que já governa mudança de status de appointment hoje
  -- (update_appointment/create_appointment) — nenhuma superfície nova (§7.1).
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager', 'reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;

  select * into v_appointment from public.appointments
  where organization_id = p_organization_id and id = p_appointment_id;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0005';
  end if;

  if v_appointment.status <> 'no_show' then
    raise exception 'appointment must already be marked no_show before settlement' using errcode = 'P0001';
  end if;

  -- CAS idêntico à fatia 004: se o hold já não está mais 'active' (nunca
  -- existiu, ou já foi capturado pela reconciliação de checkout correndo em
  -- paralelo), zero linhas são afetadas e a liquidação simplesmente não
  -- executa — sem erro fatal, sem duplicar efeito financeiro (§3.3).
  update public.deposit_holds
  set status = 'captured_no_show'
  where organization_id = p_organization_id
    and appointment_id = p_appointment_id
    and status = 'active'
  returning * into v_deposit_hold;

  if not found then
    return jsonb_build_object('status', 'skipped');
  end if;

  insert into public.orders(
    id, organization_id, client_id, status,
    subtotal_cents, discount_cents, tip_cents, total_cents,
    created_by, closed_at
  ) values (
    v_order_id, p_organization_id, v_appointment.client_id, 'closed',
    v_deposit_hold.amount_cents, 0, 0, v_deposit_hold.amount_cents,
    p_actor_user_id, now()
  );

  -- Comissão vem do snapshot em deposit_holds (fatia 003), nunca de
  -- resolve_commission() — no_show_commission pode não estar configurado
  -- (independente de deposit_mechanic, fatia 001), e nesse caso não há
  -- comissão a aplicar (0, mesmo tratamento de uma linha 'product').
  v_commission_cents := case v_deposit_hold.no_show_commission_type
    when 'percentage' then round(v_deposit_hold.amount_cents * v_deposit_hold.no_show_commission_value / 10000.0)::bigint
    when 'fixed' then v_deposit_hold.no_show_commission_value
    else 0
  end;

  insert into public.order_items(
    organization_id, order_id, kind, service_id, product_id,
    description, quantity, unit_price_cents, total_cents,
    professional_id, commission_type, commission_value, commission_cents
  ) values (
    p_organization_id, v_order_id, 'service', v_appointment.service_id, null,
    'No-show', 1, v_deposit_hold.amount_cents, v_deposit_hold.amount_cents,
    v_appointment.professional_id, v_deposit_hold.no_show_commission_type,
    v_deposit_hold.no_show_commission_value, v_commission_cents
  );

  insert into public.payments(organization_id, order_id, method, amount_cents)
  values (p_organization_id, v_order_id, 'deposit', v_deposit_hold.amount_cents);

  insert into public.cash_entries(
    organization_id, order_id, kind, amount_cents, description, created_by
  ) values (
    p_organization_id, v_order_id, 'sale', v_deposit_hold.amount_cents, 'No-show', p_actor_user_id
  );

  update public.payment_intents
  set status = 'captured', order_id = v_order_id
  where id = v_deposit_hold.payment_intent_id;

  v_response := jsonb_build_object(
    'status', 'settled',
    'order_id', v_order_id,
    'amount_cents', v_deposit_hold.amount_cents,
    'commission_cents', v_commission_cents
  );
  return v_response;
end;
$$;
revoke all on function public.no_show_settlement_create(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.no_show_settlement_create(uuid, uuid, uuid) to service_role;
