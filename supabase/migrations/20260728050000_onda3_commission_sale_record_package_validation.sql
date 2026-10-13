-- Onda 3, fatia 021 (issues/021-order-items-package-linkage.md, DEC-48):
-- redefine commission_sale_record_create() para consumir o vínculo
-- pacote↔pedido que a migration anterior desta fatia acabou de criar
-- (order_items.package_id). Fecha o achado P1 de DEC-47: a RPC aceitava
-- qualquer pacote da organização contra qualquer pedido `closed`, sem
-- provar que aquele pacote foi de fato vendido naquele pedido, e calculava
-- a comissão sobre packages.price_cents (preço de tabela) em vez do valor
-- efetivamente cobrado (rateio/desconto do checkout).
--
-- Duas mudanças, nada além: (1) nova validação — o pedido precisa conter
-- pelo menos um order_item com este package_id; (2) a base de cálculo da
-- comissão percentual passa a ser sum(order_items.total_cents) para aquele
-- (order_id, package_id), não mais packages.price_cents.

do $$
begin
  if to_regclass('public.order_items') is null then
    raise exception 'pre-flight check failed: public.order_items does not exist';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'order_items' and column_name = 'package_id'
  ) then
    raise exception 'pre-flight check failed: public.order_items.package_id does not exist yet (fatia 021 migration 1 must run first)';
  end if;
end $$;

create or replace function public.commission_sale_record_create(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_order_id uuid,
  p_package_id uuid,
  p_seller_professional_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(concat_ws('|', p_order_id, p_package_id, p_seller_professional_id), 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_order public.orders%rowtype;
  v_package_sold_cents bigint;
  v_commission_type text;
  v_commission_value bigint;
  v_commission_cents bigint;
  v_record_id uuid;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
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
  if v_existing.response is not null then
    return v_existing.response;
  end if;

  select * into v_order from public.orders where organization_id = p_organization_id and id = p_order_id;
  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;
  if v_order.status <> 'closed' then
    raise exception 'order is not closed' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.packages where organization_id = p_organization_id and id = p_package_id) then
    raise exception 'package not found' using errcode = 'P0002';
  end if;

  -- Fatia 021 (DEC-48, fecha o achado P1): o pacote precisa de fato ter sido
  -- vendido neste pedido — checkout_close agora carimba package_id em cada
  -- order_item expandido de uma venda de pacote. Sem essa checagem, a RPC
  -- aceitava qualquer pacote da organização contra qualquer pedido closed.
  select coalesce(sum(total_cents), 0) into v_package_sold_cents
  from public.order_items
  where organization_id = p_organization_id and order_id = p_order_id and package_id = p_package_id;
  if v_package_sold_cents = 0 then
    raise exception 'package was not sold in this order' using errcode = 'P0002';
  end if;

  if not exists (select 1 from public.professionals where organization_id = p_organization_id and id = p_seller_professional_id) then
    raise exception 'professional not found' using errcode = 'P0002';
  end if;

  select rc.commission_type, rc.commission_value into v_commission_type, v_commission_value
  from private.resolve_sale_commission(p_organization_id, p_package_id) rc;

  if v_commission_type is null then
    v_response := jsonb_build_object('skipped', true, 'reason', 'package has no sale commission configured');
  else
    -- Fatia 021 (DEC-48, fecha o achado P1b): base de cálculo passa a ser
    -- o valor efetivamente cobrado neste pedido (v_package_sold_cents, já
    -- líquido do rateio por maior-resto de checkout_close), não mais
    -- packages.price_cents — que ignorava desconto e podia divergir do que
    -- o cliente de fato pagou.
    v_commission_cents := case when v_commission_type = 'percentage'
      then round(v_package_sold_cents * v_commission_value / 10000.0)::bigint
      else v_commission_value end;

    insert into public.commission_sale_records(
      organization_id, unit_id, order_id, package_id, professional_id,
      commission_type, commission_value, commission_cents
    ) values (
      p_organization_id, v_order.unit_id, p_order_id, p_package_id, p_seller_professional_id,
      v_commission_type, v_commission_value, v_commission_cents
    ) returning id into v_record_id;

    v_response := jsonb_build_object(
      'skipped', false,
      'id', v_record_id,
      'commission_type', v_commission_type,
      'commission_value', v_commission_value,
      'commission_cents', v_commission_cents,
      'status', 'accrued'
    );
  end if;

  update private.idempotency_keys
  set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.commission_sale_record_create(uuid, uuid, text, uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.commission_sale_record_create(uuid, uuid, text, uuid, uuid, uuid) to service_role;
