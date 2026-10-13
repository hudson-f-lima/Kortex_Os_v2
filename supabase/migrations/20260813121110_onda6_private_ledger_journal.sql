-- Onda 6, fatia 056 (DEC-62/DEC-66, ADR 0025): um unico write-path
-- privado para o KortexFlow e journal deterministico de checkout. Nenhum
-- Command publico, feature flag ou fluxo legado e ativado nesta migration.
do $$
begin
  if to_regclass('private.idempotency_keys') is null
     or to_regclass('public.kortex_accounts') is null
     or to_regclass('public.kortex_ledger_transactions') is null
     or to_regclass('public.kortex_ledger_entries') is null
     or to_regclass('public.orders') is null
     or to_regclass('public.order_items') is null
     or to_regclass('public.payments') is null
     or to_regclass('public.order_ledger_links') is null
     or not exists (
       select 1 from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public'
         and p.proname = 'kortex_ledger_post'
         and pg_get_function_identity_arguments(p.oid) = 'p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_unit_id uuid, p_entries jsonb'
     ) then
    raise exception 'pre-flight check failed: ledger and Onda 6 dependencies are required';
  end if;

  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname in ('kortex_ledger_post_entries', 'checkout_ledger_post')
  ) then
    raise exception 'pre-flight check failed: Onda 6 ledger primitives already exist';
  end if;
end
$$;

-- O write-path abaixo e intencionalmente privado: as duas fachadas que o
-- chamam fazem a autorizacao de negocio antes de chegar aqui. Mantem a mesma
-- semantica de idempotencia, validacao tenant/unit e criacao atomica de conta
-- por entidade da RPC administrativa anterior.
create function private.kortex_ledger_post_entries(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_unit_id uuid,
  p_entries jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_unit_id::text || p_entries::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_response jsonb;
  v_transaction_id uuid;
  v_entry jsonb;
  v_account_id uuid;
  v_debit_total bigint;
  v_credit_total bigint;
begin
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;

  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;

  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then
    return v_existing.response;
  end if;

  select
    coalesce(sum((e ->> 'amount_cents')::bigint) filter (where e ->> 'direction' = 'debit'), 0),
    coalesce(sum((e ->> 'amount_cents')::bigint) filter (where e ->> 'direction' = 'credit'), 0)
  into v_debit_total, v_credit_total
  from jsonb_array_elements(p_entries) e;

  if v_debit_total = 0 or v_debit_total <> v_credit_total then
    raise exception 'unbalanced ledger entries: debit % != credit %', v_debit_total, v_credit_total using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_entries) e
    where e ->> 'account_id' is not null
      and not exists (
        select 1 from public.kortex_accounts ka
        where ka.id = (e ->> 'account_id')::uuid
          and ka.organization_id = p_organization_id
          and ka.unit_id = p_unit_id
      )
  ) then
    raise exception 'entry references an account outside organization % / unit %', p_organization_id, p_unit_id using errcode = 'P0002';
  end if;

  insert into public.kortex_ledger_transactions(organization_id, unit_id, created_by)
  values (p_organization_id, p_unit_id, p_actor_user_id)
  returning id into v_transaction_id;

  for v_entry in select * from jsonb_array_elements(p_entries)
  loop
    if v_entry ->> 'account_id' is not null then
      v_account_id := (v_entry ->> 'account_id')::uuid;
    else
      insert into public.kortex_accounts(organization_id, unit_id, kind, client_id, professional_id)
      values (
        p_organization_id, p_unit_id, v_entry ->> 'kind',
        nullif(v_entry ->> 'client_id', '')::uuid,
        nullif(v_entry ->> 'professional_id', '')::uuid
      )
      on conflict do nothing;

      select id into v_account_id from public.kortex_accounts
      where organization_id = p_organization_id
        and unit_id = p_unit_id
        and kind = v_entry ->> 'kind'
        and client_id is not distinct from nullif(v_entry ->> 'client_id', '')::uuid
        and professional_id is not distinct from nullif(v_entry ->> 'professional_id', '')::uuid;
    end if;

    insert into public.kortex_ledger_entries(organization_id, unit_id, transaction_id, account_id, direction, amount_cents)
    values (p_organization_id, p_unit_id, v_transaction_id, v_account_id, v_entry ->> 'direction', (v_entry ->> 'amount_cents')::bigint);
  end loop;

  v_response := jsonb_build_object('transaction_id', v_transaction_id, 'status', 'posted');
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

-- A RPC administrativa preserva exatamente sua alçada: a extração do corpo
-- nao concede recepcao nem acesso direto ao helper privado.
create or replace function public.kortex_ledger_post(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_unit_id uuid,
  p_entries jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;

  return private.kortex_ledger_post_entries(
    p_organization_id,
    p_actor_user_id,
    p_idempotency_key,
    p_unit_id,
    p_entries
  );
end;
$$;

-- O helper recebe somente fatos ja persistidos pelo Command. Para closure,
-- recalcula o rateio de maior resto com o mesmo desempate de checkout_close
-- (frac desc, id) e nunca recebe receita, desconto ou comissao do cliente.
-- Para refund, ele apenas inverte a transacao closure ja vinculada a versao.
create function private.checkout_ledger_post(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_parent_idempotency_key text,
  p_order_id uuid,
  p_revision_number integer,
  p_command text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_order public.orders%rowtype;
  v_operation text;
  v_child_key text;
  v_entries jsonb;
  v_payment_total bigint;
  v_item_total bigint;
  v_source_transaction_id uuid;
begin
  if p_parent_idempotency_key is null or length(p_parent_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_parent_idempotency_key like 'o6-ledger:%' then
    raise exception 'reserved idempotency key namespace' using errcode = '22023';
  end if;
  if p_revision_number is null or p_revision_number <= 0 then
    raise exception 'invalid order revision' using errcode = '22023';
  end if;

  if p_command = 'checkout_close' then
    v_operation := 'closure';
  elsif p_command = 'order_reclose' then
    v_operation := 'closure';
  elsif p_command = 'order_refund' then
    v_operation := 'reversal';
  else
    raise exception 'unsupported internal ledger command' using errcode = '22023';
  end if;

  select * into v_order
  from public.orders
  where organization_id = p_organization_id and id = p_order_id
  for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002';
  end if;
  if v_order.current_revision <> p_revision_number then
    raise exception 'order revision is no longer current' using errcode = 'P0021';
  end if;

  -- owner/admin/manager are organization-wide. reception is intentionally
  -- narrower: closing through the private helper must stay in the unit held
  -- by its active membership, even though the Command itself runs definer.
  if p_command = 'checkout_close' then
    if not exists (
      select 1
      from public.memberships m
      where m.organization_id = p_organization_id
        and m.user_id = p_actor_user_id
        and m.active
        and (
          m.role in ('owner', 'admin', 'manager')
          or (m.role = 'reception' and m.unit_id = v_order.unit_id)
        )
    ) then
      raise exception 'insufficient organization permission' using errcode = '42501';
    end if;
  elsif not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;

  v_child_key := 'o6-ledger:' || encode(
    digest(
      p_parent_idempotency_key || ':' || p_order_id::text || ':' || p_revision_number::text || ':' || v_operation,
      'sha256'
    ),
    'hex'
  );

  if v_operation = 'closure' then
    select coalesce(sum(oi.total_cents), 0) into v_item_total
    from public.order_items oi
    where oi.organization_id = p_organization_id
      and oi.order_id = p_order_id
      and oi.unit_id = v_order.unit_id;

    if v_item_total <= 0 or v_item_total <> v_order.subtotal_cents
       or v_order.discount_cents > v_item_total then
      raise exception 'order facts do not reconcile for ledger closure' using errcode = '22023';
    end if;

    select coalesce(sum(p.amount_cents), 0) into v_payment_total
    from public.payments p
    where p.organization_id = p_organization_id
      and p.order_id = p_order_id
      and p.unit_id = v_order.unit_id
      and p.revision_number = p_revision_number;

    if v_payment_total <> v_order.total_cents
       or v_payment_total <> v_order.subtotal_cents - v_order.discount_cents + v_order.tip_cents then
      raise exception 'payments do not reconcile with order total' using errcode = '22023';
    end if;

    with base as (
      select oi.id, oi.kind, oi.total_cents, oi.professional_id, oi.commission_cents
      from public.order_items oi
      where oi.organization_id = p_organization_id
        and oi.order_id = p_order_id
        and oi.unit_id = v_order.unit_id
    ), raw as (
      select *, (v_order.discount_cents * total_cents::numeric / v_item_total) as raw_value
      from base
    ), floored as (
      select *, floor(raw_value)::bigint as floor_value, raw_value - floor(raw_value) as frac
      from raw
    ), ranked as (
      select *, row_number() over (order by frac desc, id) as rn
      from floored
    ), remainder as (
      select (v_order.discount_cents - coalesce(sum(floor_value), 0))::bigint as cents
      from floored
    ), normalized as (
      select ranked.kind,
             ranked.professional_id,
             ranked.commission_cents,
             ranked.total_cents - ranked.floor_value
               - case when ranked.rn <= remainder.cents then 1 else 0 end as net_cents
      from ranked cross join remainder
    ), journal as (
      select 10 as sort_order, null::uuid as professional_id,
             jsonb_build_object('kind', 'cash', 'direction', 'debit', 'amount_cents', v_payment_total) as entry
      union all
      select 20, null::uuid,
             jsonb_build_object('kind', 'revenue_service', 'direction', 'credit', 'amount_cents', sum(net_cents))
      from normalized where kind = 'service' having sum(net_cents) > 0
      union all
      select 30, null::uuid,
             jsonb_build_object('kind', 'revenue_product', 'direction', 'credit', 'amount_cents', sum(net_cents))
      from normalized where kind = 'product' having sum(net_cents) > 0
      union all
      select 40, null::uuid,
             jsonb_build_object('kind', 'tip_liability', 'direction', 'credit', 'amount_cents', v_order.tip_cents)
      where v_order.tip_cents > 0
      union all
      select 50, null::uuid,
             jsonb_build_object('kind', 'commission_expense', 'direction', 'debit', 'amount_cents', sum(commission_cents))
      from normalized where kind = 'service' having sum(commission_cents) > 0
      union all
      select 60, professional_id,
             jsonb_build_object(
               'kind', 'staff_current_account',
               'professional_id', professional_id,
               'direction', 'credit',
               'amount_cents', sum(commission_cents)
             )
      from normalized
      where kind = 'service' and commission_cents > 0
      group by professional_id
    )
    select jsonb_agg(entry order by sort_order, professional_id nulls first)
    into v_entries
    from journal;
  else
    select l.ledger_transaction_id into v_source_transaction_id
    from public.order_ledger_links l
    where l.organization_id = p_organization_id
      and l.order_id = p_order_id
      and l.revision_number = p_revision_number
      and l.unit_id = v_order.unit_id
      and l.kind = 'closure';

    if v_source_transaction_id is null then
      raise exception 'closure ledger link not found' using errcode = 'P0002';
    end if;

    select jsonb_agg(
      jsonb_build_object(
        'account_id', e.account_id,
        'direction', case when e.direction = 'debit' then 'credit' else 'debit' end,
        'amount_cents', e.amount_cents
      ) order by e.id
    ) into v_entries
    from public.kortex_ledger_entries e
    where e.organization_id = p_organization_id
      and e.unit_id = v_order.unit_id
      and e.transaction_id = v_source_transaction_id;

    if v_entries is null then
      raise exception 'closure ledger transaction is empty' using errcode = 'P0002';
    end if;
  end if;

  return private.kortex_ledger_post_entries(
    p_organization_id,
    p_actor_user_id,
    v_child_key,
    v_order.unit_id,
    v_entries
  );
end;
$$;

-- Funcoes novas nascem executaveis por PUBLIC no PostgreSQL. Ambas sao
-- helpers internos chamados apenas por SECURITY DEFINER; grants explicitos
-- impedem authenticated/service_role de burlar os Commands.
revoke all on function private.kortex_ledger_post_entries(uuid, uuid, text, uuid, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function private.checkout_ledger_post(uuid, uuid, text, uuid, integer, text)
  from public, anon, authenticated, service_role;

revoke all on function public.kortex_ledger_post(uuid, uuid, text, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.kortex_ledger_post(uuid, uuid, text, uuid, jsonb)
  to service_role;
