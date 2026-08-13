-- Onda 6, fatia 057 (DEC-62/DEC-66, ADR-0025): o checkout legado continua
-- intocado quando checkout_reopen_enabled e falso/ausente. No ramo ativo, a
-- mesma transacao acrescenta journal, snapshot v1 e link de closure.
do $$
begin
  if to_regclass('public.organizations') is null
     or to_regclass('public.orders') is null
     or to_regclass('public.order_items') is null
     or to_regclass('public.payments') is null
     or to_regclass('public.order_revisions') is null
     or to_regclass('public.order_ledger_links') is null
     or to_regprocedure('public.checkout_close(uuid,uuid,text,jsonb)') is null
     or to_regprocedure('private.checkout_ledger_post(uuid,uuid,text,uuid,integer,text)') is null then
    raise exception 'pre-flight check failed: checkout_close and Onda 6 ledger dependencies are required';
  end if;

  if to_regprocedure('private.checkout_close_legacy(uuid,uuid,text,jsonb)') is not null then
    raise exception 'pre-flight check failed: private.checkout_close_legacy already exists';
  end if;
end
$$;

-- Mantem literalmente o corpo vigente do checkout numa primitive privada.
-- A fachada abaixo so escolhe o ramo e, quando autorizado pela flag, anexa
-- fatos novos depois que o fechamento legado ja validou tudo.
alter function public.checkout_close(uuid, uuid, text, jsonb)
  rename to checkout_close_legacy;
alter function public.checkout_close_legacy(uuid, uuid, text, jsonb)
  set schema private;

create function public.checkout_close(
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
  v_enabled boolean := false;
  v_existing_response jsonb;
  v_response jsonb;
  v_order_id uuid;
  v_order public.orders%rowtype;
  v_ledger_response jsonb;
  v_ledger_transaction_id uuid;
begin
  -- Somente o boolean JSON literal true ativa o caminho novo. Ausencia,
  -- null e qualquer outro valor mantem o comportamento legado.
  select coalesce(o.settings -> 'checkout_reopen_enabled' = 'true'::jsonb, false)
  into v_enabled
  from public.organizations o
  where o.id = p_organization_id;

  if not v_enabled then
    return private.checkout_close_legacy(
      p_organization_id,
      p_actor_user_id,
      p_idempotency_key,
      p_payload
    );
  end if;

  -- Um replay cuja resposta pai ja foi consolidada continua sendo apenas um
  -- replay. Em especial, ligar a flag depois de um checkout legado nunca o
  -- promove retroativamente a pedido versionado.
  select ik.response
  into v_existing_response
  from private.idempotency_keys ik
  where ik.organization_id = p_organization_id
    and ik.key = p_idempotency_key
  for update;

  if v_existing_response is not null then
    return private.checkout_close_legacy(
      p_organization_id,
      p_actor_user_id,
      p_idempotency_key,
      p_payload
    );
  end if;

  v_response := private.checkout_close_legacy(
    p_organization_id,
    p_actor_user_id,
    p_idempotency_key,
    p_payload
  );
  v_order_id := (v_response ->> 'order_id')::uuid;

  select *
  into v_order
  from public.orders o
  where o.organization_id = p_organization_id
    and o.id = v_order_id
  for update;
  if not found then
    raise exception 'checkout order not found' using errcode = 'P0002';
  end if;

  v_ledger_response := private.checkout_ledger_post(
    p_organization_id,
    p_actor_user_id,
    p_idempotency_key,
    v_order_id,
    v_order.current_revision,
    'checkout_close'
  );
  v_ledger_transaction_id := (v_ledger_response ->> 'transaction_id')::uuid;
  if v_ledger_transaction_id is null then
    raise exception 'checkout ledger post did not return a transaction' using errcode = 'P0002';
  end if;

  -- A versao e historico canonico, nao read-model paralelo: ela preserva os
  -- fatos efetivamente gravados pelo checkout, inclusive os efeitos de
  -- estoque/caixa e a transacao que os torna reversiveis no ledger.
  insert into public.order_revisions (
    organization_id,
    unit_id,
    order_id,
    revision_number,
    snapshot,
    closed_by,
    closed_at
  ) values (
    p_organization_id,
    v_order.unit_id,
    v_order.id,
    v_order.current_revision,
    jsonb_build_object(
      'version', 1,
      'order', jsonb_build_object(
        'id', v_order.id,
        'organization_id', v_order.organization_id,
        'unit_id', v_order.unit_id,
        'revision_number', v_order.current_revision,
        'client_id', v_order.client_id,
        'appointment_id', v_order.appointment_id,
        'deposit_hold_id', v_order.deposit_hold_id,
        'status', v_order.status,
        'subtotal_cents', v_order.subtotal_cents,
        'discount_cents', v_order.discount_cents,
        'tip_cents', v_order.tip_cents,
        'total_cents', v_order.total_cents,
        'created_by', v_order.created_by,
        'closed_at', v_order.closed_at
      ),
      'items', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', oi.id,
          'kind', oi.kind,
          'service_id', oi.service_id,
          'product_id', oi.product_id,
          'package_id', oi.package_id,
          'description', oi.description,
          'quantity', oi.quantity,
          'unit_price_cents', oi.unit_price_cents,
          'total_cents', oi.total_cents,
          'discount_cents', oi.discount_cents,
          'tip_cents', oi.tip_cents,
          'professional_id', oi.professional_id,
          'commission_type', oi.commission_type,
          'commission_value', oi.commission_value,
          'commission_cents', oi.commission_cents
        ) order by oi.id)
        from public.order_items oi
        where oi.organization_id = p_organization_id
          and oi.order_id = v_order.id
          and oi.unit_id = v_order.unit_id
      ), '[]'::jsonb),
      'payments', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', p.id,
          'method', p.method,
          'amount_cents', p.amount_cents,
          'revision_number', p.revision_number,
          'created_at', p.created_at
        ) order by p.id)
        from public.payments p
        where p.organization_id = p_organization_id
          and p.order_id = v_order.id
          and p.unit_id = v_order.unit_id
          and p.revision_number = v_order.current_revision
      ), '[]'::jsonb),
      'effects', jsonb_build_object(
        'inventory_movements', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', im.id,
            'product_id', im.product_id,
            'reason', im.reason,
            'quantity_delta', im.quantity_delta,
            'balance_after', im.balance_after
          ) order by im.id)
          from public.inventory_movements im
          where im.organization_id = p_organization_id
            and im.order_id = v_order.id
            and im.unit_id = v_order.unit_id
        ), '[]'::jsonb),
        'cash_entries', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', ce.id,
            'kind', ce.kind,
            'amount_cents', ce.amount_cents,
            'description', ce.description
          ) order by ce.id)
          from public.cash_entries ce
          where ce.organization_id = p_organization_id
            and ce.order_id = v_order.id
            and ce.unit_id = v_order.unit_id
        ), '[]'::jsonb)
      ),
      'ledger', jsonb_build_object(
        'closure_transaction_id', v_ledger_transaction_id
      )
    ),
    v_order.created_by,
    v_order.closed_at
  );

  insert into public.order_ledger_links (
    organization_id,
    unit_id,
    order_id,
    revision_number,
    ledger_transaction_id,
    kind
  ) values (
    p_organization_id,
    v_order.unit_id,
    v_order.id,
    v_order.current_revision,
    v_ledger_transaction_id,
    'closure'
  );

  return v_response;
end;
$$;

-- O corpo legado virou helper interno e a fachada publica preserva exatamente
-- a superficie de grants anterior: somente o backend service-role a chama.
revoke all on function private.checkout_close_legacy(uuid, uuid, text, jsonb)
  from public, anon, authenticated, service_role;
revoke all on function public.checkout_close(uuid, uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.checkout_close(uuid, uuid, text, jsonb)
  to service_role;
