-- Onda 6, fatia 061 (DEC-62/DEC-66, ADR-0025): o Red Team de
-- implementacao confirmou que os produtores de fatos financeiros precisavam
-- disputar a mesma linha de orders que os Commands de reabertura. Esta
-- migration e estritamente forward-only: fecha a corrida sem ativar a flag
-- nem alterar o contrato de checkout/refund legado.
do $$
begin
  if to_regclass('public.orders') is null
     or to_regclass('public.order_financial_locks') is null
     or to_regclass('public.commission_sale_records') is null
     or to_regprocedure('public.commission_sale_record_create(uuid,uuid,text,uuid,uuid,uuid)') is null then
    raise exception 'pre-flight check failed: Onda 6 financial lock and commission dependencies are required';
  end if;

  if to_regprocedure('private.onda6_guard_financial_lock_producer()') is not null then
    raise exception 'pre-flight check failed: Onda 6 financial lock producer guard already exists';
  end if;
end
$$;

-- Todo produtor de lock serializa no pedido vivo. Assim, se order_reopen
-- venceu primeiro, nenhum lock de uma revisao antiga pode nascer depois;
-- se o produtor venceu, order_reopen reavalia a trava apos obter esta mesma
-- linha. A revisao deve ser a corrente no instante do insert.
create function private.onda6_guard_financial_lock_producer()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_order public.orders%rowtype;
begin
  select * into v_order
  from public.orders
  where organization_id = new.organization_id
    and id = new.order_id
  for update;

  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;
  if v_order.unit_id <> new.unit_id then
    raise exception 'financial lock unit does not match order' using errcode = '23503';
  end if;
  if v_order.status <> 'closed' then
    raise exception 'financial lock requires a closed order' using errcode = 'P0001';
  end if;
  if v_order.current_revision <> new.revision_number then
    raise exception 'financial lock revision is no longer current' using errcode = 'P0021';
  end if;

  return new;
end;
$$;

create trigger order_financial_locks_order_serialization
before insert on public.order_financial_locks
for each row execute function private.onda6_guard_financial_lock_producer();

-- A RPC da Onda 3 continua com sua superficie e idempotencia originais, mas
-- passa a fixar a mesma linha de orders antes de validar o status e calcular
-- a comissao. O parametro nao carrega revisao; portanto a revisao corrente
-- e capturada somente apos o lock e nunca serve para validar um estado lido
-- antes de uma reabertura concorrente.
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
  v_current_revision integer;
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

  select * into v_order
  from public.orders
  where organization_id = p_organization_id and id = p_order_id
  for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;
  if v_order.status <> 'closed' then
    raise exception 'order is not closed' using errcode = 'P0001';
  end if;
  v_current_revision := v_order.current_revision;
  if v_current_revision < 1 then
    raise exception 'order current revision is invalid' using errcode = 'P0021';
  end if;

  if not exists (select 1 from public.packages where organization_id = p_organization_id and id = p_package_id) then
    raise exception 'package not found' using errcode = 'P0002';
  end if;

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

revoke all on function private.onda6_guard_financial_lock_producer()
  from public, anon, authenticated, service_role;
revoke all on function public.commission_sale_record_create(uuid, uuid, text, uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.commission_sale_record_create(uuid, uuid, text, uuid, uuid, uuid)
  to service_role;
