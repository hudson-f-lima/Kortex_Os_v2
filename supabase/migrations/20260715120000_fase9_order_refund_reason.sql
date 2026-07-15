-- Fase 9 — motivo obrigatório em order_refund (ADR 0006 §"Motivo do estorno").
-- Correção operacional (void) segue fora de escopo (depende de cash_sessions,
-- fase própria ainda não numerada); order_refund cobre só o caso real de
-- desistência/inadimplência do cliente, exigindo a taxonomia mínima definida
-- no ADR: customer_cancellation | customer_default.

alter table public.orders
  add column refund_reason text check (refund_reason in ('customer_cancellation', 'customer_default'));

drop function if exists public.order_refund(uuid, uuid, text, uuid);

create or replace function public.order_refund(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_order_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_hash text := encode(digest(p_order_id::text || coalesce(p_reason, ''), 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_response jsonb;
  v_order public.orders%rowtype;
  v_item record;
  v_stock integer;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_reason is null or p_reason not in ('customer_cancellation', 'customer_default') then
    raise exception 'reason must be customer_cancellation or customer_default' using errcode = '22023';
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

  select * into v_order from public.orders
  where organization_id = p_organization_id and id = p_order_id
  for update;

  if not found then raise exception 'order not found' using errcode = 'P0002'; end if;
  if v_order.status = 'refunded' then
    raise exception 'order already refunded' using errcode = 'P0001';
  end if;
  if v_order.status <> 'closed' then
    raise exception 'only closed orders can be refunded' using errcode = 'P0001';
  end if;

  update public.orders set status = 'refunded', refund_reason = p_reason
  where organization_id = p_organization_id and id = p_order_id;

  insert into public.cash_entries(
    organization_id, order_id, kind, amount_cents, description, created_by
  ) values (
    p_organization_id, p_order_id, 'refund', v_order.total_cents, 'Estorno de pedido', v_user_id
  );

  for v_item in
    select product_id, quantity from public.order_items
    where organization_id = p_organization_id and order_id = p_order_id and kind = 'product'
  loop
    select stock_on_hand into v_stock from public.products
    where organization_id = p_organization_id and id = v_item.product_id
    for update;

    if found then
      update public.products
      set stock_on_hand = stock_on_hand + v_item.quantity
      where organization_id = p_organization_id and id = v_item.product_id
      returning stock_on_hand into v_stock;

      insert into public.inventory_movements(
        organization_id, product_id, order_id, reason,
        quantity_delta, balance_after, created_by
      ) values (
        p_organization_id, v_item.product_id, p_order_id, 'return',
        v_item.quantity, v_stock, v_user_id
      );
    end if;
  end loop;

  v_response := jsonb_build_object(
    'order_id', p_order_id,
    'organization_id', p_organization_id,
    'status', 'refunded'
  );
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.order_refund(uuid, uuid, text, uuid, text) from public, anon, authenticated;
grant execute on function public.order_refund(uuid, uuid, text, uuid, text) to service_role;
