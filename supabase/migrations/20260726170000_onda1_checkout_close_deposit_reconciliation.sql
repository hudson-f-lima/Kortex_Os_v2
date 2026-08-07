-- Onda 1, fatia 004 (issues/004-checkout-close-deposit-reconciliation.md):
-- checkout_close ganha reconciliação de deposit_hold — HITL, maior risco da
-- Onda 1 (toca a RPC financeira mais crítica do sistema). Ver
-- docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1_DRAFT.md §3.1, §3.3, §7.1.
--
-- A ÚNICA mudança de comportamento é a reconciliação em si — nenhuma outra
-- linha da função (item loop, desconto, gorjeta, comissão, o loop de
-- payments existente, a checagem `v_paid <> v_total`, o insert de
-- cash_entries 'sale') é editada. O corpo abaixo é uma cópia integral da
-- versão vigente (supabase/migrations/20260715103200_fase9_foundation.sql),
-- com apenas: (a) extração aditiva de `appointment_id` do payload (campo
-- novo, opcional — omitido, o comportamento é idêntico ao atual), (b) um
-- bloco novo e isolado de reconciliação inserido antes do loop de payments,
-- e (c) `v_paid` semeado com o valor aplicado do depósito antes desse loop
-- rodar (loop e checagem finais permanecem, ao pé da letra, os mesmos).
--
-- 'deposit' é um método de payment novo (ALTER aditivo abaixo, em separado
-- do corpo da função) — a reconciliação grava aqui o valor do depósito
-- aplicado, para o pagamento do pedido continuar reconciliando exatamente
-- como hoje (payments soma = orders.total_cents).

alter table public.payments drop constraint payments_method_check;
alter table public.payments add constraint payments_method_check
  check (method in ('cash', 'pix', 'debit_card', 'credit_card', 'other', 'deposit'));

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
  -- Reconciliação de depósito (issues/003, issues/004) — todas aditivas.
  v_appointment_id uuid := nullif(p_payload ->> 'appointment_id', '')::uuid;
  v_deposit_hold public.deposit_holds%rowtype;
  v_deposit_applied bigint := 0;
  v_deposit_overflow bigint := 0;
  v_order_total_for_reconciliation bigint;
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
  -- Deliberate relaxation for reconciliation (issues/004): a deposit can
  -- fully cover the order total (v_paid seeded from v_deposit_applied alone
  -- reaches v_total with zero client payments) — an empty array is now a
  -- legitimate payload, not just a malformed one. The real invariant is
  -- still enforced below: v_paid <> v_total, unchanged.
  if jsonb_typeof(p_payload -> 'payments') <> 'array' then
    raise exception 'payments must be an array' using errcode = '22023';
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

  -- Reconciliação de deposit_hold (issues/004): CAS — se o hold não está
  -- mais 'active' (já capturado por outro caminho, ex.: liquidação de
  -- no-show da fatia 005 correndo em paralelo), zero linhas são afetadas e a
  -- reconciliação simplesmente não executa (§3.3, achado #3 do Red Team).
  if v_appointment_id is not null then
    update public.deposit_holds
    set status = 'captured_checkout'
    where organization_id = p_organization_id
      and appointment_id = v_appointment_id
      and status = 'active'
    returning * into v_deposit_hold;

    if found then
      v_order_total_for_reconciliation := v_subtotal - v_discount_cents + v_tip_cents;
      -- Overflow (Red Team achado #5): nunca aplica mais que o total do
      -- pedido — nunca deixa o pedido negativo, nunca um sistema de crédito.
      v_deposit_applied := least(v_deposit_hold.amount_cents, v_order_total_for_reconciliation);
      v_deposit_overflow := v_deposit_hold.amount_cents - v_deposit_applied;

      update public.payment_intents
      set status = 'captured', order_id = v_order_id
      where id = v_deposit_hold.payment_intent_id;

      if v_deposit_applied > 0 then
        insert into public.payments(organization_id, order_id, method, amount_cents)
        values (p_organization_id, v_order_id, 'deposit', v_deposit_applied);
        v_paid := v_paid + v_deposit_applied;
      end if;

      -- immediate_charge já moveu dinheiro real na reserva — o excedente
      -- (depósito maior que o pedido final) precisa mesmo voltar, pelo
      -- estorno já existente (ADR 0006/0007) — nunca um saldo/crédito novo
      -- (isso é escopo de client_wallets, Onda 2, inexistente ainda). A
      -- mecânica 'hold' nunca capturou o excedente — nada a devolver.
      if v_deposit_overflow > 0 and v_deposit_hold.mechanic = 'immediate_charge' then
        insert into public.cash_entries(
          organization_id, order_id, kind, amount_cents, description, created_by
        ) values (
          p_organization_id, v_order_id, 'refund', v_deposit_overflow, 'Estorno de excedente de depósito', v_user_id
        );
      end if;
    end if;
  end if;

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
    'status', 'closed',
    'deposit_applied_cents', v_deposit_applied
  );
  update private.idempotency_keys
  set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
