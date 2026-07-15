-- Fase 9 — Fundação Financeira (Camada 1)

alter table public.orders
  drop constraint orders_total_cents_check;
alter table public.orders
  add column tip_cents bigint not null default 0 check (tip_cents >= 0),
  add constraint orders_total_cents_check check (total_cents >= 0 and total_cents = subtotal_cents - discount_cents + tip_cents);

alter table public.order_items
  add column discount_cents bigint not null default 0 check (discount_cents >= 0),
  add column tip_cents bigint not null default 0 check (tip_cents >= 0);

create or replace function public.cash_entry_manual(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_kind text,
  p_amount_cents bigint,
  p_description text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_hash text := encode(digest(p_kind || p_amount_cents::text || p_description, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_response jsonb;
  v_entry_id uuid;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_kind not in ('income', 'expense') then
    raise exception 'kind must be income or expense' using errcode = '22023';
  end if;
  if p_amount_cents <= 0 then
    raise exception 'amount must be positive' using errcode = '22023';
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

  insert into public.cash_entries(
    organization_id, kind, amount_cents, description, created_by
  ) values (
    p_organization_id, p_kind, p_amount_cents, p_description, v_user_id
  ) returning id into v_entry_id;

  v_response := jsonb_build_object(
    'cash_entry_id', v_entry_id,
    'organization_id', p_organization_id,
    'status', 'success'
  );
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.cash_entry_manual(uuid, uuid, text, text, bigint, text) from public, anon, authenticated;
grant execute on function public.cash_entry_manual(uuid, uuid, text, text, bigint, text) to service_role;

create or replace function public.order_refund(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_order_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_hash text := encode(digest(p_order_id::text, 'sha256'), 'hex');
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

  update public.orders set status = 'refunded'
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
revoke all on function public.order_refund(uuid, uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.order_refund(uuid, uuid, text, uuid) to service_role;

create or replace function public.checkout_close(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_item jsonb;
  v_payment jsonb;
  v_kind text;
  v_ref_id uuid;
  v_quantity integer;
  v_unit_price bigint;
  v_description text;
  v_stock integer;
  v_subtotal bigint := 0;
  v_paid bigint := 0;
  v_amount bigint;
  v_response jsonb;
  v_professional_id uuid;
  v_commission_type text;
  v_commission_value bigint;
  v_commission_cents bigint;
  v_total bigint;
  v_professionals_map jsonb;
  v_weight_total numeric;
  v_row record;
  v_discount_cents bigint := coalesce((p_payload ->> 'discount_cents')::bigint, 0);
  v_tip_cents bigint := coalesce((p_payload ->> 'tip_cents')::bigint, 0);
  v_service_total bigint;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload -> 'items') <> 'array' or jsonb_array_length(p_payload -> 'items') = 0 then
    raise exception 'items must be a non-empty array' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload -> 'payments') <> 'array' or jsonb_array_length(p_payload -> 'payments') = 0 then
    raise exception 'payments must be a non-empty array' using errcode = '22023';
  end if;
  if v_discount_cents < 0 or v_tip_cents < 0 then
    raise exception 'discount and tip must be positive' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, v_user_id)
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

  insert into public.orders(
    id, organization_id, client_id, status,
    subtotal_cents, discount_cents, tip_cents, total_cents,
    created_by, closed_at
  ) values (
    v_order_id,
    p_organization_id,
    nullif(p_payload ->> 'client_id', '')::uuid,
    'closed', 0, 0, 0, 0, v_user_id, now()
  );

  for v_item in select value from jsonb_array_elements(p_payload -> 'items') loop
    v_kind := v_item ->> 'kind';
    v_quantity := (v_item ->> 'quantity')::integer;
    if v_quantity <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;

    if v_kind = 'product' then
      v_ref_id := (v_item ->> 'id')::uuid;
      select p.price_cents, p.name, p.stock_on_hand
      into v_unit_price, v_description, v_stock
      from public.products p
      where p.organization_id = p_organization_id and p.id = v_ref_id and p.active
      for update;
      if not found then raise exception 'active product not found' using errcode = 'P0002'; end if;
      if v_stock < v_quantity then raise exception 'insufficient stock' using errcode = 'P0001'; end if;

      update public.products
      set stock_on_hand = stock_on_hand - v_quantity
      where organization_id = p_organization_id and id = v_ref_id
      returning stock_on_hand into v_stock;

      insert into public.inventory_movements(
        organization_id, product_id, order_id, reason,
        quantity_delta, balance_after, created_by
      ) values (
        p_organization_id, v_ref_id, v_order_id, 'sale',
        -v_quantity, v_stock, v_user_id
      );

      insert into public.order_items(
        organization_id, order_id, kind, service_id, product_id,
        description, quantity, unit_price_cents, total_cents,
        professional_id, commission_type, commission_value, commission_cents
      ) values (
        p_organization_id, v_order_id, 'product', null, v_ref_id,
        v_description, v_quantity, v_unit_price, v_unit_price * v_quantity,
        null, null, null, 0
      );
      v_subtotal := v_subtotal + (v_unit_price * v_quantity);

    elsif v_kind = 'service' then
      v_ref_id := (v_item ->> 'id')::uuid;
      v_professional_id := (v_item ->> 'professional_id')::uuid;
      if v_professional_id is null then
        raise exception 'professional_id is required for service items' using errcode = '22023';
      end if;

      select s.price_cents, s.name
      into v_unit_price, v_description
      from public.services s
      where s.organization_id = p_organization_id and s.id = v_ref_id and s.active;
      if not found then raise exception 'active service not found' using errcode = 'P0002'; end if;

      if not exists (
        select 1 from public.professionals pr
        where pr.organization_id = p_organization_id and pr.id = v_professional_id and pr.active
      ) then
        raise exception 'active professional not found' using errcode = 'P0002';
      end if;

      v_total := v_unit_price * v_quantity;

      insert into public.order_items(
        organization_id, order_id, kind, service_id, product_id,
        description, quantity, unit_price_cents, total_cents,
        professional_id, commission_type, commission_value, commission_cents
      ) values (
        p_organization_id, v_order_id, 'service', v_ref_id, null,
        v_description, v_quantity, v_unit_price, v_total,
        v_professional_id, null, null, 0
      );
      v_subtotal := v_subtotal + v_total;

    elsif v_kind = 'package' then
      v_ref_id := (v_item ->> 'id')::uuid;
      if v_quantity <> 1 then
        raise exception 'package quantity must be exactly 1 (sell identical packages as separate items)' using errcode = '22023';
      end if;

      select price_cents into v_unit_price
      from public.packages
      where organization_id = p_organization_id and id = v_ref_id and active;
      if not found then raise exception 'active package not found' using errcode = 'P0002'; end if;

      v_professionals_map := v_item -> 'professionals';
      if v_professionals_map is null or jsonb_typeof(v_professionals_map) <> 'object' then
        raise exception 'professionals must be an object mapping service_id to professional_id' using errcode = '22023';
      end if;

      if not exists (
        select 1 from public.package_items where organization_id = p_organization_id and package_id = v_ref_id
      ) then
        raise exception 'active package not found' using errcode = 'P0002';
      end if;

      if (select count(*) from jsonb_object_keys(v_professionals_map)) <>
         (select count(*) from public.package_items where organization_id = p_organization_id and package_id = v_ref_id)
      or exists (
        select 1 from jsonb_object_keys(v_professionals_map) as k
        where not exists (
          select 1 from public.package_items pi
          where pi.organization_id = p_organization_id and pi.package_id = v_ref_id and pi.service_id::text = k
        )
      ) then
        raise exception 'professionals must map exactly the package components' using errcode = '22023';
      end if;

      select coalesce(sum(s.price_cents * pi.quantity), 0) into v_weight_total
      from public.package_items pi
      join public.services s on s.organization_id = pi.organization_id and s.id = pi.service_id
      where pi.organization_id = p_organization_id and pi.package_id = v_ref_id;
      if v_weight_total <= 0 then
        raise exception 'package components must have a positive combined price to allocate the package price' using errcode = '22023';
      end if;

      for v_row in
        with base as (
          select pi.service_id, pi.quantity, s.price_cents, s.name, s.active,
                 (s.price_cents * pi.quantity)::numeric as weight
          from public.package_items pi
          join public.services s on s.organization_id = pi.organization_id and s.id = pi.service_id
          where pi.organization_id = p_organization_id and pi.package_id = v_ref_id
        ),
        raw as (
          select *, (v_unit_price * weight / v_weight_total) as raw_value
          from base
        ),
        floored as (
          select *, floor(raw_value)::bigint as floor_value, (raw_value - floor(raw_value)) as frac
          from raw
        ),
        ranked as (
          select *, row_number() over (order by frac desc, weight desc, service_id) as rn
          from floored
        ),
        remainder as (
          select (v_unit_price - coalesce(sum(floor_value), 0))::bigint as remainder_cents from floored
        )
        select ranked.service_id, ranked.quantity, ranked.name, ranked.active,
               ranked.floor_value + case when ranked.rn <= remainder.remainder_cents then 1 else 0 end as allocated_cents
        from ranked, remainder
      loop
        if not v_row.active then
          raise exception 'active service not found' using errcode = 'P0002';
        end if;

        v_professional_id := (v_professionals_map ->> v_row.service_id::text)::uuid;
        if v_professional_id is null then
          raise exception 'professionals must map exactly the package components' using errcode = '22023';
        end if;
        if not exists (
          select 1 from public.professionals pr
          where pr.organization_id = p_organization_id and pr.id = v_professional_id and pr.active
        ) then
          raise exception 'active professional not found' using errcode = 'P0002';
        end if;

        insert into public.order_items(
          organization_id, order_id, kind, service_id, product_id,
          description, quantity, unit_price_cents, total_cents,
          professional_id, commission_type, commission_value, commission_cents
        ) values (
          p_organization_id, v_order_id, 'service', v_row.service_id, null,
          v_row.name, 1, v_row.allocated_cents, v_row.allocated_cents,
          v_professional_id, null, null, 0
        );
        v_subtotal := v_subtotal + v_row.allocated_cents;
      end loop;

    else
      raise exception 'unsupported item kind' using errcode = '22023';
    end if;
  end loop;

  if v_subtotal = 0 and (v_discount_cents > 0 or v_tip_cents > 0) then
    raise exception 'cannot apply discount or tip to empty order' using errcode = '22023';
  end if;
  if v_discount_cents > v_subtotal then
    raise exception 'discount cannot exceed subtotal' using errcode = '22023';
  end if;

  if v_discount_cents > 0 then
    with base as (
      select id, total_cents as weight
      from public.order_items
      where organization_id = p_organization_id and order_id = v_order_id
    ),
    raw as (
      select id, (v_discount_cents * weight::numeric / v_subtotal) as raw_value
      from base
    ),
    floored as (
      select id, floor(raw_value)::bigint as floor_value, (raw_value - floor(raw_value)) as frac
      from raw
    ),
    ranked as (
      select id, floor_value, row_number() over (order by frac desc, id) as rn
      from floored
    ),
    remainder as (
      select (v_discount_cents - coalesce(sum(floor_value), 0))::bigint as remainder_cents from floored
    )
    update public.order_items oi
    set discount_cents = r.floor_value + case when r.rn <= rem.remainder_cents then 1 else 0 end
    from ranked r, remainder rem
    where oi.id = r.id;
  end if;

  if v_tip_cents > 0 then
    select coalesce(sum(total_cents), 0) into v_service_total
    from public.order_items
    where organization_id = p_organization_id and order_id = v_order_id and kind = 'service';

    if v_service_total <= 0 then
       raise exception 'cannot apply tip without service items' using errcode = '22023';
    end if;

    with base as (
      select id, total_cents as weight
      from public.order_items
      where organization_id = p_organization_id and order_id = v_order_id and kind = 'service'
    ),
    raw as (
      select id, (v_tip_cents * weight::numeric / v_service_total) as raw_value
      from base
    ),
    floored as (
      select id, floor(raw_value)::bigint as floor_value, (raw_value - floor(raw_value)) as frac
      from raw
    ),
    ranked as (
      select id, floor_value, row_number() over (order by frac desc, id) as rn
      from floored
    ),
    remainder as (
      select (v_tip_cents - coalesce(sum(floor_value), 0))::bigint as remainder_cents from floored
    )
    update public.order_items oi
    set tip_cents = r.floor_value + case when r.rn <= rem.remainder_cents then 1 else 0 end
    from ranked r, remainder rem
    where oi.id = r.id;
  end if;

  for v_row in 
    select id, professional_id, service_id, (total_cents - discount_cents) as net_cents, quantity
    from public.order_items
    where organization_id = p_organization_id and order_id = v_order_id and kind = 'service'
  loop
    select rc.commission_type, rc.commission_value into v_commission_type, v_commission_value
    from private.resolve_commission(p_organization_id, v_row.professional_id, v_row.service_id) rc;

    v_commission_cents := case when v_commission_type = 'percentage'
      then round(v_row.net_cents * v_commission_value / 10000.0)::bigint
      else v_commission_value * v_row.quantity end;

    update public.order_items
    set commission_type = v_commission_type,
        commission_value = v_commission_value,
        commission_cents = v_commission_cents
    where id = v_row.id;
  end loop;

  for v_payment in select value from jsonb_array_elements(p_payload -> 'payments') loop
    v_amount := (v_payment ->> 'amount_cents')::bigint;
    if v_amount <= 0 then raise exception 'payment must be positive' using errcode = '22023'; end if;
    insert into public.payments(organization_id, order_id, method, amount_cents)
    values (p_organization_id, v_order_id, v_payment ->> 'method', v_amount);
    v_paid := v_paid + v_amount;
  end loop;

  v_total := v_subtotal - v_discount_cents + v_tip_cents;

  if v_paid <> v_total then
    raise exception 'payments do not reconcile with order total' using errcode = '22023';
  end if;

  update public.orders
  set subtotal_cents = v_subtotal, 
      discount_cents = v_discount_cents, 
      tip_cents = v_tip_cents, 
      total_cents = v_total
  where organization_id = p_organization_id and id = v_order_id;

  insert into public.cash_entries(
    organization_id, order_id, kind, amount_cents, description, created_by
  ) values (
    p_organization_id, v_order_id, 'sale', v_total, 'Checkout', v_user_id
  );

  v_response := jsonb_build_object(
    'order_id', v_order_id,
    'organization_id', p_organization_id,
    'total_cents', v_total,
    'status', 'closed'
  );
  update private.idempotency_keys
  set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
