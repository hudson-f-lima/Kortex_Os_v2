-- Fase 5.1 do roteiro de comissão (docs/PLANEJAMENTO_COMISSOES.md): fecha a
-- cascata (profissional > serviço > grupo) dentro do checkout. Adiciona o
-- override por profissional (nível 1), estende order_items com a comissão
-- congelada no momento da venda (§4.6) e reescreve checkout_close para
-- resolver a cascata e expandir pacotes em itens de venda por alocação
-- proporcional (§4.4), portando o algoritmo de maior resto de
-- docs/legacy/checkout_math_logic.md para dentro da RPC (mesma razão que já
-- vale para create_package/update_package: não abrir uma segunda fonte de
-- verdade de preço fora da transação atômica).

create table public.professional_service_commissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  professional_id uuid not null,
  service_id uuid not null,
  commission_type text not null check (commission_type in ('percentage', 'fixed')),
  commission_value bigint not null check (commission_value >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, professional_id, service_id),
  check (commission_type is distinct from 'percentage' or commission_value <= 10000),
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  foreign key (organization_id, service_id) references public.services(organization_id, id) on delete restrict
);

alter table public.professional_service_commissions enable row level security;

-- Financial data (what each professional actually gets paid), same shape as
-- cash_entries: read/write restricted to owner/admin/manager (no reception),
-- delete to owner/admin. Defense in depth only — the API path runs as
-- service_role (BYPASSRLS).
create policy professional_service_commissions_select on public.professional_service_commissions for select to authenticated using (private.has_role(organization_id, array['owner','admin','manager']));
create policy professional_service_commissions_insert on public.professional_service_commissions for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy professional_service_commissions_update on public.professional_service_commissions for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy professional_service_commissions_delete on public.professional_service_commissions for delete to authenticated using (private.has_role(organization_id, array['owner','admin']));

create trigger professional_service_commissions_touch before update on public.professional_service_commissions for each row execute function private.touch_updated_at();

grant select, insert, update, delete on public.professional_service_commissions to service_role;

-- order_items gains the commission frozen at checkout time (§4.6). Every
-- 'service' line (including the ones expanded from a package — those are
-- always inserted with kind='service') must carry a professional_id;
-- 'product' lines never carry commission. Both invariants are pushed into
-- the schema, not just the RPC.
alter table public.order_items
  add column professional_id uuid,
  add column commission_type text check (commission_type in ('percentage', 'fixed')),
  add column commission_value bigint check (commission_value >= 0),
  add column commission_cents bigint not null default 0 check (commission_cents >= 0),
  add constraint order_items_commission_pair check (
    (commission_type is null and commission_value is null) or (commission_type is not null and commission_value is not null)
  ),
  add constraint order_items_service_needs_professional check (
    kind <> 'service' or professional_id is not null
  ),
  add constraint order_items_product_no_commission check (
    kind <> 'product' or (professional_id is null and commission_type is null and commission_cents = 0)
  ),
  add constraint order_items_professional_fk foreign key (organization_id, professional_id)
    references public.professionals(organization_id, id);

-- Cascade resolution (§4.1): profissional×serviço override > padrão do
-- serviço > padrão do grupo. coalesce() picks the first non-null in that
-- order — "mais específico vence", nunca soma, nunca média. Every service
-- has a service_group_id (not null) and every group has a default (not
-- null), so this always terminates in a value (Fase 3.1 guarantee).
create or replace function private.resolve_commission(p_organization_id uuid, p_professional_id uuid, p_service_id uuid)
returns table (commission_type text, commission_value bigint)
language sql stable security definer set search_path = pg_catalog, public, private as $$
  select coalesce(psc.commission_type, s.commission_type, sg.default_commission_type),
         coalesce(psc.commission_value, s.commission_value, sg.default_commission_value)
  from public.services s
  join public.service_groups sg on sg.organization_id = s.organization_id and sg.id = s.service_group_id
  left join public.professional_service_commissions psc
    on psc.organization_id = p_organization_id and psc.professional_id = p_professional_id and psc.service_id = p_service_id
  where s.organization_id = p_organization_id and s.id = p_service_id;
$$;
revoke all on function private.resolve_commission(uuid, uuid, uuid) from public, anon, authenticated;

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
    subtotal_cents, discount_cents, total_cents,
    created_by, closed_at
  ) values (
    v_order_id,
    p_organization_id,
    nullif(p_payload ->> 'client_id', '')::uuid,
    'closed', 0, 0, 0, v_user_id, now()
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
      select rc.commission_type, rc.commission_value into v_commission_type, v_commission_value
      from private.resolve_commission(p_organization_id, v_professional_id, v_ref_id) rc;
      v_commission_cents := case when v_commission_type = 'percentage'
        then round(v_total * v_commission_value / 10000.0)::bigint
        else v_commission_value * v_quantity end;

      insert into public.order_items(
        organization_id, order_id, kind, service_id, product_id,
        description, quantity, unit_price_cents, total_cents,
        professional_id, commission_type, commission_value, commission_cents
      ) values (
        p_organization_id, v_order_id, 'service', v_ref_id, null,
        v_description, v_quantity, v_unit_price, v_total,
        v_professional_id, v_commission_type, v_commission_value, v_commission_cents
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

      -- Largest-remainder allocation (port of allocateProportional from
      -- docs/legacy/checkout_math_logic.md §2): floor each share, then hand
      -- out the leftover cents to the components with the largest fractional
      -- remainder (ties broken by weight, then service_id for determinism)
      -- so the allocated amounts sum exactly to the package price.
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

        select rc.commission_type, rc.commission_value into v_commission_type, v_commission_value
        from private.resolve_commission(p_organization_id, v_professional_id, v_row.service_id) rc;
        -- Fixed commission is value x quantity actually delivered (the
        -- package_items quantity), even though the exploded order_item line
        -- below always carries quantity=1 (see comment on the insert).
        v_commission_cents := case when v_commission_type = 'percentage'
          then round(v_row.allocated_cents * v_commission_value / 10000.0)::bigint
          else v_commission_value * v_row.quantity end;

        -- One order_item per package component, quantity=1 and
        -- unit_price_cents=total_cents=allocated value. Folding the
        -- component's quantity into the allocated weight (instead of
        -- exposing it as this row's quantity) avoids needing the allocated
        -- cents to divide evenly by that quantity to satisfy the
        -- total_cents = unit_price_cents * quantity constraint.
        insert into public.order_items(
          organization_id, order_id, kind, service_id, product_id,
          description, quantity, unit_price_cents, total_cents,
          professional_id, commission_type, commission_value, commission_cents
        ) values (
          p_organization_id, v_order_id, 'service', v_row.service_id, null,
          v_row.name, 1, v_row.allocated_cents, v_row.allocated_cents,
          v_professional_id, v_commission_type, v_commission_value, v_commission_cents
        );
        v_subtotal := v_subtotal + v_row.allocated_cents;
      end loop;

    else
      raise exception 'unsupported item kind' using errcode = '22023';
    end if;
  end loop;

  for v_payment in select value from jsonb_array_elements(p_payload -> 'payments') loop
    v_amount := (v_payment ->> 'amount_cents')::bigint;
    if v_amount <= 0 then raise exception 'payment must be positive' using errcode = '22023'; end if;
    insert into public.payments(organization_id, order_id, method, amount_cents)
    values (p_organization_id, v_order_id, v_payment ->> 'method', v_amount);
    v_paid := v_paid + v_amount;
  end loop;

  if v_paid <> v_subtotal then
    raise exception 'payments do not reconcile with order total' using errcode = '22023';
  end if;

  update public.orders
  set subtotal_cents = v_subtotal, total_cents = v_subtotal
  where organization_id = p_organization_id and id = v_order_id;

  insert into public.cash_entries(
    organization_id, order_id, kind, amount_cents, description, created_by
  ) values (
    p_organization_id, v_order_id, 'sale', v_subtotal, 'Checkout', v_user_id
  );

  v_response := jsonb_build_object(
    'order_id', v_order_id,
    'organization_id', p_organization_id,
    'total_cents', v_subtotal,
    'status', 'closed'
  );
  update private.idempotency_keys
  set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
