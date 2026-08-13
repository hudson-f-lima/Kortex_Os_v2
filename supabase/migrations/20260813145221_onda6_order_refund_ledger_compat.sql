-- Onda 6 / fatia 060: a existencia do closure link, e nao a flag atual,
-- decide se o estorno precisa reverter o KortexFlow. Pedidos sem link ficam
-- bit a bit no caminho legado; pedidos versionados ganham reversao append-only.
do $$
begin
  if to_regclass('public.orders') is null
     or to_regclass('public.order_items') is null
     or to_regclass('public.order_revisions') is null
     or to_regclass('public.order_ledger_links') is null
     or to_regclass('public.cash_entries') is null
     or to_regclass('public.inventory_movements') is null
     or not exists (
       select 1
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public'
         and p.proname = 'order_refund'
         and pg_get_function_identity_arguments(p.oid) = 'p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_order_id uuid, p_reason text'
     )
     or to_regprocedure('private.checkout_ledger_post(uuid,uuid,text,uuid,integer,text)') is null then
    raise exception 'pre-flight check failed: order_refund and Onda 6 ledger dependencies are required';
  end if;
end
$$;

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
  v_hash text := encode(digest(p_order_id::text || coalesce(p_reason, ''), 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_response jsonb;
  v_order public.orders%rowtype;
  v_revision_id uuid;
  v_closure_transaction_id uuid;
  v_ledger_response jsonb;
  v_reversal_transaction_id uuid;
  v_item record;
  v_stock integer;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_reason is null or p_reason not in ('customer_cancellation', 'customer_default') then
    raise exception 'reason must be customer_cancellation or customer_default' using errcode = '22023';
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
  if v_existing.response is not null then return v_existing.response; end if;

  select * into v_order
  from public.orders
  where organization_id = p_organization_id and id = p_order_id
  for update;

  if not found then raise exception 'order not found' using errcode = 'P0002'; end if;
  if v_order.status = 'refunded' then raise exception 'order already refunded' using errcode = 'P0001'; end if;
  if v_order.status <> 'closed' then raise exception 'only closed orders can be refunded' using errcode = 'P0001'; end if;

  -- A closure link proves this exact revision was versioned. Do not inspect
  -- checkout_reopen_enabled here: toggling it only gates new closures.
  select l.ledger_transaction_id into v_closure_transaction_id
  from public.order_ledger_links l
  where l.organization_id = p_organization_id
    and l.order_id = p_order_id
    and l.unit_id = v_order.unit_id
    and l.revision_number = v_order.current_revision
    and l.kind = 'closure'
  for update;

  if v_closure_transaction_id is not null then
    select r.id into v_revision_id
    from public.order_revisions r
    where r.organization_id = p_organization_id
      and r.order_id = p_order_id
      and r.unit_id = v_order.unit_id
      and r.revision_number = v_order.current_revision
    for update;

    if v_revision_id is null then
      raise exception 'current order revision not found for closure ledger link' using errcode = 'P0002';
    end if;

    v_ledger_response := private.checkout_ledger_post(
      p_organization_id,
      p_actor_user_id,
      p_idempotency_key,
      p_order_id,
      v_order.current_revision,
      'order_refund'
    );
    v_reversal_transaction_id := (v_ledger_response ->> 'transaction_id')::uuid;
    if v_reversal_transaction_id is null then
      raise exception 'refund ledger reversal did not return a transaction' using errcode = 'P0002';
    end if;

    insert into public.order_ledger_links(
      organization_id, unit_id, order_id, revision_number, ledger_transaction_id, kind
    ) values (
      p_organization_id, v_order.unit_id, p_order_id, v_order.current_revision, v_reversal_transaction_id, 'reversal'
    );
  end if;

  -- Preserve the established refund effects and response contract for both
  -- paths. The only additive behavior above is the versioned ledger reversal.
  update public.orders
  set status = 'refunded', refund_reason = p_reason
  where organization_id = p_organization_id and id = p_order_id;

  insert into public.cash_entries(
    organization_id, unit_id, order_id, kind, amount_cents, description, created_by
  ) values (
    p_organization_id, v_order.unit_id, p_order_id, 'refund', v_order.total_cents, 'Estorno de pedido', p_actor_user_id
  );

  for v_item in
    select product_id, quantity
    from public.order_items
    where organization_id = p_organization_id and order_id = p_order_id and unit_id = v_order.unit_id and kind = 'product'
  loop
    select stock_on_hand into v_stock
    from public.products
    where organization_id = p_organization_id and id = v_item.product_id
    for update;

    if found then
      update public.products
      set stock_on_hand = stock_on_hand + v_item.quantity
      where organization_id = p_organization_id and id = v_item.product_id
      returning stock_on_hand into v_stock;

      insert into public.inventory_movements(
        organization_id, unit_id, product_id, order_id, reason, quantity_delta, balance_after, created_by
      ) values (
        p_organization_id, v_order.unit_id, v_item.product_id, p_order_id, 'return',
        v_item.quantity, v_stock, p_actor_user_id
      );
    end if;
  end loop;

  v_response := jsonb_build_object(
    'order_id', p_order_id,
    'organization_id', p_organization_id,
    'status', 'refunded'
  );
  update private.idempotency_keys
  set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

revoke all on function public.order_refund(uuid, uuid, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.order_refund(uuid, uuid, text, uuid, text)
  to service_role;
