-- Onda 6, fatia 059 (DEC-62/DEC-66, ADR-0025): Command atomico para
-- refechar a versao viva de uma comanda reaberta. O snapshot preserva v1;
-- este Command substitui somente o read-model vivo e acrescenta os fatos v2.
do $$
begin
  if to_regclass('public.orders') is null
     or to_regclass('public.order_revisions') is null
     or to_regclass('public.order_reopen_attempts') is null
     or to_regclass('public.order_reopen_attempt_events') is null
     or to_regclass('public.order_ledger_links') is null
     or to_regclass('public.order_payment_adjustments') is null
     or to_regprocedure('private.checkout_ledger_post(uuid,uuid,text,uuid,integer,text)') is null then
    raise exception 'pre-flight check failed: Onda 6 reclose dependencies are required';
  end if;
  if to_regprocedure('public.order_reclose(uuid,uuid,text,uuid,uuid,jsonb)') is not null then
    raise exception 'pre-flight check failed: public.order_reclose already exists';
  end if;
end
$$;

-- Recalcula somente os fatos vivos de itens/pagamentos da revisao nova. A
-- interface aceita o mesmo payload de checkout, mas nao aceita appointment:
-- um deposito ja capturado nao pode ser reaplicado em uma reabertura.
create function private.onda6_reclose_apply_payload(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_order_id uuid,
  p_unit_id uuid,
  p_revision_number integer,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_item jsonb;
  v_payment jsonb;
  v_kind text;
  v_ref_id uuid;
  v_quantity integer;
  v_unit_price bigint;
  v_description text;
  v_stock integer;
  v_inventory_id uuid;
  v_subtotal bigint := 0;
  v_paid bigint := 0;
  v_amount bigint;
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
  v_inventory_effects jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_payload -> 'items') <> 'array' or jsonb_array_length(p_payload -> 'items') = 0 then
    raise exception 'items must be a non-empty array' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload -> 'payments') <> 'array' or jsonb_array_length(p_payload -> 'payments') = 0 then
    raise exception 'payments must be a non-empty array' using errcode = '22023';
  end if;
  if v_discount_cents < 0 or v_tip_cents < 0 then
    raise exception 'discount and tip must be non-negative' using errcode = '22023';
  end if;

  for v_item in select value from jsonb_array_elements(p_payload -> 'items') loop
    v_kind := v_item ->> 'kind';
    v_quantity := (v_item ->> 'quantity')::integer;
    if v_quantity is null or v_quantity <= 0 then
      raise exception 'quantity must be positive' using errcode = '22023';
    end if;

    if v_kind = 'product' then
      v_ref_id := (v_item ->> 'id')::uuid;
      select p.price_cents, p.name, p.stock_on_hand into v_unit_price, v_description, v_stock
      from public.products p
      where p.organization_id = p_organization_id and p.id = v_ref_id and p.active
      for update;
      if not found then raise exception 'active product not found' using errcode = 'P0002'; end if;
      if v_stock < v_quantity then raise exception 'insufficient stock' using errcode = 'P0001'; end if;
      update public.products set stock_on_hand = stock_on_hand - v_quantity
      where organization_id = p_organization_id and id = v_ref_id
      returning stock_on_hand into v_stock;
      insert into public.inventory_movements(organization_id, unit_id, product_id, order_id, reason, quantity_delta, balance_after, created_by)
      values (p_organization_id, p_unit_id, v_ref_id, p_order_id, 'sale', -v_quantity, v_stock, p_actor_user_id)
      returning id into v_inventory_id;
      v_inventory_effects := v_inventory_effects || jsonb_build_array(jsonb_build_object(
        'id', v_inventory_id, 'product_id', v_ref_id, 'reason', 'sale', 'quantity_delta', -v_quantity, 'balance_after', v_stock
      ));
      insert into public.order_items(organization_id, unit_id, order_id, kind, service_id, product_id, description, quantity, unit_price_cents, total_cents, professional_id, commission_type, commission_value, commission_cents, package_id)
      values (p_organization_id, p_unit_id, p_order_id, 'product', null, v_ref_id, v_description, v_quantity, v_unit_price, v_unit_price * v_quantity, null, null, null, 0, null);
      v_subtotal := v_subtotal + v_unit_price * v_quantity;

    elsif v_kind = 'service' then
      v_ref_id := (v_item ->> 'id')::uuid;
      v_professional_id := (v_item ->> 'professional_id')::uuid;
      if v_professional_id is null then raise exception 'professional_id is required for service items' using errcode = '22023'; end if;
      select s.price_cents, s.name into v_unit_price, v_description
      from public.services s where s.organization_id = p_organization_id and s.id = v_ref_id and s.active;
      if not found then raise exception 'active service not found' using errcode = 'P0002'; end if;
      if not exists (select 1 from public.professionals pr where pr.organization_id = p_organization_id and pr.id = v_professional_id and pr.active) then
        raise exception 'active professional not found' using errcode = 'P0002';
      end if;
      insert into public.order_items(organization_id, unit_id, order_id, kind, service_id, product_id, description, quantity, unit_price_cents, total_cents, professional_id, commission_type, commission_value, commission_cents, package_id)
      values (p_organization_id, p_unit_id, p_order_id, 'service', v_ref_id, null, v_description, v_quantity, v_unit_price, v_unit_price * v_quantity, v_professional_id, null, null, 0, null);
      v_subtotal := v_subtotal + v_unit_price * v_quantity;

    elsif v_kind = 'package' then
      v_ref_id := (v_item ->> 'id')::uuid;
      if v_quantity <> 1 then raise exception 'package quantity must be exactly 1' using errcode = '22023'; end if;
      select price_cents into v_unit_price from public.packages where organization_id = p_organization_id and id = v_ref_id and active;
      if not found then raise exception 'active package not found' using errcode = 'P0002'; end if;
      v_professionals_map := v_item -> 'professionals';
      if v_professionals_map is null or jsonb_typeof(v_professionals_map) <> 'object' then
        raise exception 'professionals must be an object mapping service_id to professional_id' using errcode = '22023';
      end if;
      if (select count(*) from jsonb_object_keys(v_professionals_map)) <> (select count(*) from public.package_items where organization_id = p_organization_id and package_id = v_ref_id)
         or exists (select 1 from jsonb_object_keys(v_professionals_map) k where not exists (select 1 from public.package_items pi where pi.organization_id = p_organization_id and pi.package_id = v_ref_id and pi.service_id::text = k)) then
        raise exception 'professionals must map exactly the package components' using errcode = '22023';
      end if;
      select coalesce(sum(s.price_cents * pi.quantity), 0) into v_weight_total
      from public.package_items pi join public.services s on s.organization_id = pi.organization_id and s.id = pi.service_id
      where pi.organization_id = p_organization_id and pi.package_id = v_ref_id;
      if v_weight_total <= 0 then raise exception 'package components must have a positive combined price' using errcode = '22023'; end if;
      for v_row in
        with base as (
          select pi.service_id, pi.quantity, s.name, s.active, (s.price_cents * pi.quantity)::numeric weight
          from public.package_items pi join public.services s on s.organization_id = pi.organization_id and s.id = pi.service_id
          where pi.organization_id = p_organization_id and pi.package_id = v_ref_id
        ), raw as (
          select *, v_unit_price * weight / v_weight_total raw_value from base
        ), floored as (
          select *, floor(raw_value)::bigint floor_value, raw_value - floor(raw_value) frac from raw
        ), ranked as (
          select *, row_number() over (order by frac desc, weight desc, service_id) rn from floored
        ), remainder as (
          select (v_unit_price - coalesce(sum(floor_value), 0))::bigint cents from floored
        )
        select ranked.service_id, ranked.quantity, ranked.name, ranked.active, ranked.floor_value + case when ranked.rn <= remainder.cents then 1 else 0 end allocated_cents
        from ranked cross join remainder
      loop
        if not v_row.active then raise exception 'active service not found' using errcode = 'P0002'; end if;
        v_professional_id := (v_professionals_map ->> v_row.service_id::text)::uuid;
        if v_professional_id is null or not exists (select 1 from public.professionals pr where pr.organization_id = p_organization_id and pr.id = v_professional_id and pr.active) then
          raise exception 'active professional not found' using errcode = 'P0002';
        end if;
        insert into public.order_items(organization_id, unit_id, order_id, kind, service_id, product_id, description, quantity, unit_price_cents, total_cents, professional_id, commission_type, commission_value, commission_cents, package_id)
        values (p_organization_id, p_unit_id, p_order_id, 'service', v_row.service_id, null, v_row.name, 1, v_row.allocated_cents, v_row.allocated_cents, v_professional_id, null, null, 0, v_ref_id);
        v_subtotal := v_subtotal + v_row.allocated_cents;
      end loop;
    else
      raise exception 'unsupported item kind' using errcode = '22023';
    end if;
  end loop;

  if v_discount_cents > v_subtotal then raise exception 'discount cannot exceed subtotal' using errcode = '22023'; end if;
  if v_tip_cents > 0 then
    select coalesce(sum(total_cents), 0) into v_service_total from public.order_items where organization_id = p_organization_id and order_id = p_order_id and unit_id = p_unit_id and kind = 'service';
    if v_service_total <= 0 then raise exception 'cannot apply tip without service items' using errcode = '22023'; end if;
  end if;
  if v_discount_cents > 0 then
    with base as (select id, total_cents weight from public.order_items where organization_id = p_organization_id and order_id = p_order_id and unit_id = p_unit_id),
    raw as (select *, v_discount_cents * weight::numeric / v_subtotal raw_value from base),
    floored as (select *, floor(raw_value)::bigint floor_value, raw_value - floor(raw_value) frac from raw),
    ranked as (select *, row_number() over (order by frac desc, id) rn from floored),
    remainder as (select (v_discount_cents - coalesce(sum(floor_value),0))::bigint cents from floored)
    update public.order_items oi set discount_cents = r.floor_value + case when r.rn <= rem.cents then 1 else 0 end from ranked r cross join remainder rem where oi.id = r.id;
  end if;
  if v_tip_cents > 0 then
    with base as (select id, total_cents weight from public.order_items where organization_id = p_organization_id and order_id = p_order_id and unit_id = p_unit_id and kind = 'service'),
    raw as (select *, v_tip_cents * weight::numeric / v_service_total raw_value from base),
    floored as (select *, floor(raw_value)::bigint floor_value, raw_value - floor(raw_value) frac from raw),
    ranked as (select *, row_number() over (order by frac desc, id) rn from floored),
    remainder as (select (v_tip_cents - coalesce(sum(floor_value),0))::bigint cents from floored)
    update public.order_items oi set tip_cents = r.floor_value + case when r.rn <= rem.cents then 1 else 0 end from ranked r cross join remainder rem where oi.id = r.id;
  end if;
  for v_row in select id, professional_id, service_id, total_cents - discount_cents net_cents, quantity from public.order_items where organization_id = p_organization_id and order_id = p_order_id and unit_id = p_unit_id and kind = 'service' loop
    select commission_type, commission_value into v_commission_type, v_commission_value from private.resolve_commission(p_organization_id, v_row.professional_id, v_row.service_id);
    v_commission_cents := case when v_commission_type = 'percentage' then round(v_row.net_cents * v_commission_value / 10000.0)::bigint else v_commission_value * v_row.quantity end;
    update public.order_items set commission_type = v_commission_type, commission_value = v_commission_value, commission_cents = v_commission_cents where id = v_row.id;
  end loop;
  for v_payment in select value from jsonb_array_elements(p_payload -> 'payments') loop
    v_amount := (v_payment ->> 'amount_cents')::bigint;
    if v_amount is null or v_amount <= 0 or (v_payment ->> 'method') not in ('cash','pix','debit_card','credit_card','other') then raise exception 'invalid payment' using errcode = '22023'; end if;
    insert into public.payments(organization_id, unit_id, order_id, revision_number, method, amount_cents) values (p_organization_id, p_unit_id, p_order_id, p_revision_number, v_payment ->> 'method', v_amount);
    v_paid := v_paid + v_amount;
  end loop;
  v_total := v_subtotal - v_discount_cents + v_tip_cents;
  if v_paid <> v_total then raise exception 'payments do not reconcile with order total' using errcode = '22023'; end if;
  return jsonb_build_object('subtotal_cents', v_subtotal, 'discount_cents', v_discount_cents, 'tip_cents', v_tip_cents, 'total_cents', v_total, 'inventory_effects', v_inventory_effects);
end;
$$;

create function public.order_reclose(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_order_id uuid,
  p_reopen_attempt_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(concat_ws(':', p_order_id::text, p_reopen_attempt_id::text, p_payload::text), 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_order public.orders%rowtype;
  v_attempt public.order_reopen_attempts%rowtype;
  v_new_revision integer;
  v_v1_total bigint;
  v_result jsonb;
  v_delta bigint;
  v_cash_entry_id uuid;
  v_cash_effects jsonb := '[]'::jsonb;
  v_refund_allocations jsonb := '[]'::jsonb;
  v_ledger_response jsonb;
  v_ledger_transaction_id uuid;
  v_row record;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager']) then raise exception 'insufficient organization permission' using errcode = '42501'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key' using errcode = '22023'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or exists (select 1 from jsonb_object_keys(p_payload) k where k not in ('client_id','items','payments','discount_cents','tip_cents')) then raise exception 'invalid reclose payload' using errcode = '22023'; end if;
  if not private.onda6_checkout_reopen_enabled(p_organization_id) then raise exception 'checkout reopen is disabled' using errcode = 'P0001'; end if;
  insert into private.idempotency_keys(organization_id, key, request_hash, created_by) values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id) on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys where organization_id = p_organization_id and key = p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode = '22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;
  select * into v_order from public.orders where organization_id = p_organization_id and id = p_order_id for update;
  if not found then raise exception 'order not found' using errcode = 'P0002'; end if;
  if v_order.status <> 'reopened' then raise exception 'only reopened orders can be reclosed' using errcode = 'P0001'; end if;
  select * into v_attempt from public.order_reopen_attempts where organization_id = p_organization_id and id = p_reopen_attempt_id and order_id = p_order_id and unit_id = v_order.unit_id and base_revision_number = v_order.current_revision for update;
  if not found or v_attempt.status <> 'opened' then raise exception 'opened reopen attempt not found' using errcode = 'P0002'; end if;
  if exists (select 1 from public.order_financial_locks l where l.organization_id = p_organization_id and l.order_id = p_order_id and l.unit_id = v_order.unit_id and l.revision_number = v_order.current_revision and l.enforcement = 'terminal') or exists (select 1 from public.payment_intents pi where pi.organization_id = p_organization_id and pi.order_id = p_order_id and pi.status = 'captured') then raise exception 'order has a terminal financial lock' using errcode = 'P0001'; end if;
  v_v1_total := v_order.total_cents;
  v_new_revision := v_order.current_revision + 1;
  delete from public.order_items where organization_id = p_organization_id and order_id = p_order_id and unit_id = v_order.unit_id;
  v_result := private.onda6_reclose_apply_payload(p_organization_id, p_actor_user_id, p_order_id, v_order.unit_id, v_new_revision, p_payload);
  update public.orders set client_id = nullif(p_payload ->> 'client_id','')::uuid, subtotal_cents = (v_result ->> 'subtotal_cents')::bigint, discount_cents = (v_result ->> 'discount_cents')::bigint, tip_cents = (v_result ->> 'tip_cents')::bigint, total_cents = (v_result ->> 'total_cents')::bigint, current_revision = v_new_revision, closed_at = now() where organization_id = p_organization_id and id = p_order_id returning * into v_order;
  v_delta := v_order.total_cents - v_v1_total;
  if v_delta > 0 then
    insert into public.cash_entries(organization_id, unit_id, order_id, kind, amount_cents, description, created_by) values (p_organization_id, v_order.unit_id, p_order_id, 'sale', v_delta, 'Order reclose delta', p_actor_user_id) returning id into v_cash_entry_id;
    v_cash_effects := jsonb_build_array(jsonb_build_object('id', v_cash_entry_id, 'kind', 'sale', 'amount_cents', v_delta, 'description', 'Order reclose delta'));
  elsif v_delta < 0 then
    insert into public.cash_entries(organization_id, unit_id, order_id, kind, amount_cents, description, created_by) values (p_organization_id, v_order.unit_id, p_order_id, 'refund', -v_delta, 'Order reclose delta', p_actor_user_id) returning id into v_cash_entry_id;
    if (select coalesce(sum(p.amount_cents - coalesce(a.adjusted_cents,0)),0) from public.payments p left join lateral (select sum(x.amount_cents) adjusted_cents from public.order_payment_adjustments x where x.organization_id = p_organization_id and x.payment_id = p.id and x.kind = 'refund_allocation') a on true where p.organization_id = p_organization_id and p.order_id = p_order_id and p.unit_id = v_order.unit_id and p.revision_number = v_attempt.base_revision_number) < -v_delta then raise exception 'insufficient original payment balance for refund' using errcode = 'P0001'; end if;
    for v_row in
      with balances as (
        select p.id, p.amount_cents - coalesce(sum(a.amount_cents) filter (where a.kind = 'refund_allocation'), 0) balance
        from public.payments p left join public.order_payment_adjustments a on a.organization_id = p.organization_id and a.payment_id = p.id
        where p.organization_id = p_organization_id and p.order_id = p_order_id and p.unit_id = v_order.unit_id and p.revision_number = v_attempt.base_revision_number
        group by p.id, p.amount_cents
      ), raw as (select *, (-v_delta) * balance::numeric / (select sum(balance) from balances) raw_value from balances),
      floored as (select *, floor(raw_value)::bigint floor_value, raw_value - floor(raw_value) frac from raw),
      ranked as (select *, row_number() over (order by frac desc, id) rn from floored),
      remainder as (select ((-v_delta) - coalesce(sum(floor_value),0))::bigint cents from floored)
      select id, floor_value + case when rn <= remainder.cents then 1 else 0 end amount_cents from ranked cross join remainder where balance > 0
    loop
      if v_row.amount_cents > 0 then
        v_refund_allocations := v_refund_allocations || jsonb_build_array(jsonb_build_object('payment_id', v_row.id, 'amount_cents', v_row.amount_cents));
      end if;
    end loop;
    v_cash_effects := jsonb_build_array(jsonb_build_object('id', v_cash_entry_id, 'kind', 'refund', 'amount_cents', -v_delta, 'description', 'Order reclose delta'));
  end if;
  v_ledger_response := private.checkout_ledger_post(p_organization_id, p_actor_user_id, p_idempotency_key, p_order_id, v_new_revision, 'order_reclose');
  v_ledger_transaction_id := (v_ledger_response ->> 'transaction_id')::uuid;
  if v_ledger_transaction_id is null then raise exception 'reclose ledger post did not return a transaction' using errcode = 'P0002'; end if;
  insert into public.order_revisions(organization_id, unit_id, order_id, revision_number, snapshot, closed_by, closed_at)
  values (p_organization_id, v_order.unit_id, p_order_id, v_new_revision, jsonb_build_object(
    'version', v_new_revision,
    'order', jsonb_build_object('id', v_order.id, 'organization_id', v_order.organization_id, 'unit_id', v_order.unit_id, 'revision_number', v_new_revision, 'client_id', v_order.client_id, 'appointment_id', v_order.appointment_id, 'deposit_hold_id', v_order.deposit_hold_id, 'status', 'closed', 'subtotal_cents', v_order.subtotal_cents, 'discount_cents', v_order.discount_cents, 'tip_cents', v_order.tip_cents, 'total_cents', v_order.total_cents, 'created_by', v_order.created_by, 'closed_at', v_order.closed_at),
    'items', coalesce((select jsonb_agg(jsonb_build_object('id',oi.id,'kind',oi.kind,'service_id',oi.service_id,'product_id',oi.product_id,'package_id',oi.package_id,'description',oi.description,'quantity',oi.quantity,'unit_price_cents',oi.unit_price_cents,'total_cents',oi.total_cents,'discount_cents',oi.discount_cents,'tip_cents',oi.tip_cents,'professional_id',oi.professional_id,'commission_type',oi.commission_type,'commission_value',oi.commission_value,'commission_cents',oi.commission_cents) order by oi.id) from public.order_items oi where oi.organization_id = p_organization_id and oi.order_id = p_order_id and oi.unit_id = v_order.unit_id), '[]'::jsonb),
    'payments', coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'method',p.method,'amount_cents',p.amount_cents,'revision_number',p.revision_number,'created_at',p.created_at) order by p.id) from public.payments p where p.organization_id = p_organization_id and p.order_id = p_order_id and p.unit_id = v_order.unit_id and p.revision_number = v_new_revision), '[]'::jsonb),
    'effects', jsonb_build_object('inventory_movements', coalesce(v_result -> 'inventory_effects','[]'::jsonb), 'cash_entries', v_cash_effects),
    'ledger', jsonb_build_object('closure_transaction_id', v_ledger_transaction_id)
  ), p_actor_user_id, v_order.closed_at);
  for v_row in select value from jsonb_array_elements(v_refund_allocations) loop
    insert into public.order_payment_adjustments(
      organization_id, unit_id, order_id, revision_number, payment_id,
      cash_entry_id, reopen_attempt_id, kind, amount_cents, created_by
    ) values (
      p_organization_id, v_order.unit_id, p_order_id, v_new_revision,
      (v_row.value ->> 'payment_id')::uuid, v_cash_entry_id, v_attempt.id,
      'refund_allocation', (v_row.value ->> 'amount_cents')::bigint, p_actor_user_id
    );
  end loop;
  insert into public.order_ledger_links(organization_id, unit_id, order_id, revision_number, ledger_transaction_id, kind) values (p_organization_id, v_order.unit_id, p_order_id, v_new_revision, v_ledger_transaction_id, 'closure');
  update public.orders set status = 'closed' where organization_id = p_organization_id and id = p_order_id;
  update public.order_reopen_attempts set status = 'reclosed', resolved_at = now() where id = v_attempt.id;
  insert into public.order_reopen_attempt_events(organization_id, unit_id, reopen_attempt_id, event_type, actor_id, payload) values (p_organization_id, v_order.unit_id, v_attempt.id, 'reclosed', p_actor_user_id, jsonb_build_object('revision_number', v_new_revision, 'cash_delta_cents', v_delta));
  v_response := jsonb_build_object('order_id', p_order_id, 'organization_id', p_organization_id, 'total_cents', v_order.total_cents, 'status', 'closed', 'revision_number', v_new_revision, 'cash_delta_cents', v_delta);
  update private.idempotency_keys set response = v_response where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

revoke all on function private.onda6_reclose_apply_payload(uuid,uuid,uuid,uuid,integer,jsonb) from public, anon, authenticated, service_role;
revoke all on function public.order_reclose(uuid,uuid,text,uuid,uuid,jsonb) from public, anon, authenticated;
grant execute on function public.order_reclose(uuid,uuid,text,uuid,uuid,jsonb) to service_role;
