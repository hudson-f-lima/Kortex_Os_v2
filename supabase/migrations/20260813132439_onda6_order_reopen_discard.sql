-- Onda 6, fatia 058 (DEC-62/DEC-66, ADR-0025): Commands server-owned para
-- solicitar/aprovar, abrir e descartar reabertura. Nao ha DML direto em fatos
-- financeiros; cada transicao trava o pedido, e os efeitos sao append-only.
do $$
begin
  if to_regclass('public.orders') is null
     or to_regclass('public.order_revisions') is null
     or to_regclass('public.order_reopen_attempts') is null
     or to_regclass('public.order_reopen_attempt_events') is null
     or to_regclass('public.order_ledger_links') is null
     or to_regclass('public.order_financial_locks') is null
     or to_regclass('public.inventory_movements') is null
     or to_regprocedure('private.kortex_ledger_post_entries(uuid,uuid,text,uuid,jsonb)') is null then
    raise exception 'pre-flight check failed: Onda 6 reopen dependencies are required';
  end if;

  if to_regprocedure('public.order_reopen_request(uuid,uuid,text,uuid,text,text)') is not null
     or to_regprocedure('public.order_reopen_approve(uuid,uuid,text,uuid,uuid)') is not null
     or to_regprocedure('public.order_reopen(uuid,uuid,text,uuid,uuid)') is not null
     or to_regprocedure('public.order_reopen_discard(uuid,uuid,text,uuid,uuid)') is not null then
    raise exception 'pre-flight check failed: Onda 6 reopen Commands already exist';
  end if;
end
$$;

create function private.onda6_checkout_reopen_enabled(p_organization_id uuid)
returns boolean
language sql
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(o.settings -> 'checkout_reopen_enabled' = 'true'::jsonb, false)
  from public.organizations o
  where o.id = p_organization_id
$$;

-- O snapshot e a fonte para a compensacao operacional; os movimentos novos
-- continuam auditaveis e nunca reescrevem a venda v1.
create function private.onda6_apply_snapshot_inventory(
  p_organization_id uuid,
  p_order_id uuid,
  p_revision_number integer,
  p_actor_user_id uuid,
  p_restore boolean
) returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_snapshot jsonb;
  v_effect jsonb;
  v_product_id uuid;
  v_sale_delta integer;
  v_delta integer;
  v_stock integer;
begin
  select r.snapshot into v_snapshot
  from public.order_revisions r
  where r.organization_id = p_organization_id
    and r.order_id = p_order_id
    and r.revision_number = p_revision_number;
  if v_snapshot is null then
    raise exception 'order revision snapshot not found' using errcode = 'P0002';
  end if;

  for v_effect in
    select value
    from jsonb_array_elements(coalesce(v_snapshot #> '{effects,inventory_movements}', '[]'::jsonb))
  loop
    v_product_id := (v_effect ->> 'product_id')::uuid;
    v_sale_delta := (v_effect ->> 'quantity_delta')::integer;
    if v_product_id is null or v_sale_delta >= 0 then
      raise exception 'invalid inventory snapshot for order revision' using errcode = '22023';
    end if;
    v_delta := case when p_restore then -v_sale_delta else v_sale_delta end;

    select p.stock_on_hand into v_stock
    from public.products p
    where p.organization_id = p_organization_id and p.id = v_product_id
    for update;
    if not found then
      raise exception 'snapshot product not found' using errcode = 'P0002';
    end if;
    if v_stock + v_delta < 0 then
      raise exception 'insufficient stock to restore order revision' using errcode = 'P0001';
    end if;

    update public.products
    set stock_on_hand = stock_on_hand + v_delta
    where organization_id = p_organization_id and id = v_product_id
    returning stock_on_hand into v_stock;

    insert into public.inventory_movements(
      organization_id, product_id, order_id, reason,
      quantity_delta, balance_after, created_by
    ) values (
      p_organization_id, v_product_id, p_order_id,
      case when p_restore then 'return' else 'sale' end,
      v_delta, v_stock, p_actor_user_id
    );
  end loop;
end;
$$;

-- A primitive de 056 fica fechada para chamadas externas. Esta extensao usa
-- somente fatos vinculados: closure -> reversal e reversal -> restore.
create function private.onda6_reopen_ledger_post(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_parent_idempotency_key text,
  p_order_id uuid,
  p_revision_number integer,
  p_operation text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_order public.orders%rowtype;
  v_source_kind text;
  v_child_key text;
  v_source_transaction_id uuid;
  v_entries jsonb;
begin
  if p_parent_idempotency_key is null or length(p_parent_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_parent_idempotency_key like 'o6-ledger:%' then
    raise exception 'reserved idempotency key namespace' using errcode = '22023';
  end if;
  if p_operation not in ('reversal', 'restore') then
    raise exception 'unsupported reopen ledger operation' using errcode = '22023';
  end if;
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
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

  v_source_kind := case when p_operation = 'reversal' then 'closure' else 'reversal' end;
  select l.ledger_transaction_id into v_source_transaction_id
  from public.order_ledger_links l
  where l.organization_id = p_organization_id
    and l.order_id = p_order_id
    and l.unit_id = v_order.unit_id
    and l.revision_number = p_revision_number
    and l.kind = v_source_kind;
  if v_source_transaction_id is null then
    raise exception '% ledger link not found', v_source_kind using errcode = 'P0002';
  end if;

  select jsonb_agg(jsonb_build_object(
    'account_id', e.account_id,
    'direction', case when e.direction = 'debit' then 'credit' else 'debit' end,
    'amount_cents', e.amount_cents
  ) order by e.id)
  into v_entries
  from public.kortex_ledger_entries e
  where e.organization_id = p_organization_id
    and e.unit_id = v_order.unit_id
    and e.transaction_id = v_source_transaction_id;
  if v_entries is null then
    raise exception 'source ledger transaction is empty' using errcode = 'P0002';
  end if;

  v_child_key := 'o6-ledger:' || encode(digest(
    p_parent_idempotency_key || ':' || p_order_id::text || ':' || p_revision_number::text || ':' || p_operation,
    'sha256'
  ), 'hex');
  return private.kortex_ledger_post_entries(
    p_organization_id, p_actor_user_id, v_child_key, v_order.unit_id, v_entries
  );
end;
$$;

create function public.order_reopen_request(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_order_id uuid,
  p_reason_code text,
  p_reason_detail text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(concat_ws(':', p_order_id::text, coalesce(p_reason_code, ''), coalesce(p_reason_detail, '')), 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_order public.orders%rowtype;
  v_attempt_id uuid;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_reason_code is null
     or p_reason_code not in ('pricing_error','item_correction','professional_correction','payment_correction','inventory_correction','other')
     or p_reason_detail is null or length(btrim(p_reason_detail)) = 0 then
    raise exception 'invalid reopen reason' using errcode = '22023';
  end if;
  if not private.onda6_checkout_reopen_enabled(p_organization_id) then
    raise exception 'checkout reopen is disabled' using errcode = 'P0001';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode = '22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;

  select * into v_order from public.orders
  where organization_id = p_organization_id and id = p_order_id for update;
  if not found then raise exception 'order not found' using errcode = 'P0002'; end if;
  if v_order.status <> 'closed' then raise exception 'only closed orders can be reopened' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.order_ledger_links l where l.organization_id = p_organization_id and l.order_id = p_order_id and l.unit_id = v_order.unit_id and l.revision_number = v_order.current_revision and l.kind = 'closure') then
    raise exception 'legacy order cannot be reopened' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.order_financial_locks l where l.organization_id = p_organization_id and l.order_id = p_order_id and l.unit_id = v_order.unit_id and l.revision_number = v_order.current_revision and l.enforcement = 'terminal')
     or exists (select 1 from public.payment_intents pi where pi.organization_id = p_organization_id and pi.order_id = p_order_id and pi.status = 'captured') then
    raise exception 'order has a terminal financial lock' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.order_reopen_attempts a where a.organization_id = p_organization_id and a.order_id = p_order_id and a.status in ('requested','approved','opened')) then
    raise exception 'order already has an active reopen attempt' using errcode = 'P0001';
  end if;

  insert into public.order_reopen_attempts(organization_id, unit_id, order_id, base_revision_number, reason_code, reason_detail, requested_by)
  values (p_organization_id, v_order.unit_id, p_order_id, v_order.current_revision, p_reason_code, btrim(p_reason_detail), p_actor_user_id)
  returning id into v_attempt_id;
  insert into public.order_reopen_attempt_events(organization_id, unit_id, reopen_attempt_id, event_type, actor_id, payload)
  values (p_organization_id, v_order.unit_id, v_attempt_id, 'requested', p_actor_user_id, jsonb_build_object('reason_code', p_reason_code));
  v_response := jsonb_build_object('order_id', p_order_id, 'reopen_attempt_id', v_attempt_id, 'status', 'requested');
  update private.idempotency_keys set response = v_response where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

create function public.order_reopen_approve(
  p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_order_id uuid, p_reopen_attempt_id uuid
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_order_id::text || ':' || p_reopen_attempt_id::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_order public.orders%rowtype;
  v_attempt public.order_reopen_attempts%rowtype;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner']) then raise exception 'insufficient organization permission' using errcode = '42501'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key' using errcode = '22023'; end if;
  insert into private.idempotency_keys(organization_id, key, request_hash, created_by) values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id) on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys where organization_id = p_organization_id and key = p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode = '22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;
  select * into v_order from public.orders where organization_id = p_organization_id and id = p_order_id for update;
  if not found then raise exception 'order not found' using errcode = 'P0002'; end if;
  select * into v_attempt from public.order_reopen_attempts where organization_id = p_organization_id and id = p_reopen_attempt_id and order_id = p_order_id and unit_id = v_order.unit_id for update;
  if not found or v_attempt.status <> 'requested' then raise exception 'reopen attempt is not awaiting approval' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.order_financial_locks l where l.organization_id = p_organization_id and l.order_id = p_order_id and l.unit_id = v_order.unit_id and l.revision_number = v_order.current_revision and l.source_type = 'cash_close' and l.enforcement = 'action_request_required') then
    raise exception 'cash close approval is not required' using errcode = 'P0001';
  end if;
  update public.order_reopen_attempts set status = 'approved', resolved_at = now() where id = v_attempt.id;
  insert into public.order_reopen_attempt_events(organization_id, unit_id, reopen_attempt_id, event_type, actor_id) values (p_organization_id, v_order.unit_id, v_attempt.id, 'approved', p_actor_user_id);
  v_response := jsonb_build_object('order_id', p_order_id, 'reopen_attempt_id', v_attempt.id, 'status', 'approved');
  update private.idempotency_keys set response = v_response where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

create function public.order_reopen(
  p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_order_id uuid, p_reopen_attempt_id uuid
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_order_id::text || ':' || p_reopen_attempt_id::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_order public.orders%rowtype;
  v_attempt public.order_reopen_attempts%rowtype;
  v_ledger_response jsonb;
  v_ledger_transaction_id uuid;
  v_cash_close boolean;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager']) then raise exception 'insufficient organization permission' using errcode = '42501'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key' using errcode = '22023'; end if;
  if not private.onda6_checkout_reopen_enabled(p_organization_id) then raise exception 'checkout reopen is disabled' using errcode = 'P0001'; end if;
  insert into private.idempotency_keys(organization_id, key, request_hash, created_by) values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id) on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys where organization_id = p_organization_id and key = p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode = '22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;
  select * into v_order from public.orders where organization_id = p_organization_id and id = p_order_id for update;
  if not found then raise exception 'order not found' using errcode = 'P0002'; end if;
  if v_order.status <> 'closed' then raise exception 'only closed orders can be reopened' using errcode = 'P0001'; end if;
  select * into v_attempt from public.order_reopen_attempts where organization_id = p_organization_id and id = p_reopen_attempt_id and order_id = p_order_id and unit_id = v_order.unit_id and base_revision_number = v_order.current_revision for update;
  if not found then raise exception 'reopen attempt not found' using errcode = 'P0002'; end if;
  if not exists (select 1 from public.order_ledger_links l where l.organization_id = p_organization_id and l.order_id = p_order_id and l.unit_id = v_order.unit_id and l.revision_number = v_order.current_revision and l.kind = 'closure') then raise exception 'legacy order cannot be reopened' using errcode = 'P0001'; end if;
  if exists (select 1 from public.order_financial_locks l where l.organization_id = p_organization_id and l.order_id = p_order_id and l.unit_id = v_order.unit_id and l.revision_number = v_order.current_revision and l.enforcement = 'terminal') or exists (select 1 from public.payment_intents pi where pi.organization_id = p_organization_id and pi.order_id = p_order_id and pi.status = 'captured') then raise exception 'order has a terminal financial lock' using errcode = 'P0001'; end if;
  select exists(select 1 from public.order_financial_locks l where l.organization_id = p_organization_id and l.order_id = p_order_id and l.unit_id = v_order.unit_id and l.revision_number = v_order.current_revision and l.source_type = 'cash_close' and l.enforcement = 'action_request_required') into v_cash_close;
  if (v_cash_close and (v_attempt.status <> 'approved' or not exists (select 1 from public.order_reopen_attempt_events e join public.memberships m on m.organization_id = e.organization_id and m.user_id = e.actor_id where e.organization_id = p_organization_id and e.reopen_attempt_id = v_attempt.id and e.event_type = 'approved' and m.role = 'owner' and m.active))) or (not v_cash_close and v_attempt.status <> 'requested') then raise exception 'owner approval required for cash close' using errcode = 'P0001'; end if;
  perform private.onda6_apply_snapshot_inventory(p_organization_id, p_order_id, v_order.current_revision, p_actor_user_id, true);
  v_ledger_response := private.onda6_reopen_ledger_post(p_organization_id, p_actor_user_id, p_idempotency_key, p_order_id, v_order.current_revision, 'reversal');
  v_ledger_transaction_id := (v_ledger_response ->> 'transaction_id')::uuid;
  insert into public.order_ledger_links(organization_id, unit_id, order_id, revision_number, ledger_transaction_id, kind) values (p_organization_id, v_order.unit_id, p_order_id, v_order.current_revision, v_ledger_transaction_id, 'reversal');
  update public.orders set status = 'reopened' where organization_id = p_organization_id and id = p_order_id;
  update public.order_reopen_attempts set status = 'opened', resolved_at = now() where id = v_attempt.id;
  insert into public.order_reopen_attempt_events(organization_id, unit_id, reopen_attempt_id, event_type, actor_id) values (p_organization_id, v_order.unit_id, v_attempt.id, 'opened', p_actor_user_id);
  v_response := jsonb_build_object('order_id', p_order_id, 'reopen_attempt_id', v_attempt.id, 'status', 'reopened', 'revision_number', v_order.current_revision);
  update private.idempotency_keys set response = v_response where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

create function public.order_reopen_discard(
  p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_order_id uuid, p_reopen_attempt_id uuid
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_hash text := encode(digest(p_order_id::text || ':' || p_reopen_attempt_id::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_order public.orders%rowtype;
  v_attempt public.order_reopen_attempts%rowtype;
  v_ledger_response jsonb;
  v_ledger_transaction_id uuid;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager']) then raise exception 'insufficient organization permission' using errcode = '42501'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then raise exception 'invalid idempotency key' using errcode = '22023'; end if;
  insert into private.idempotency_keys(organization_id, key, request_hash, created_by) values (p_organization_id, p_idempotency_key, v_hash, p_actor_user_id) on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys where organization_id = p_organization_id and key = p_idempotency_key for update;
  if v_existing.request_hash <> v_hash then raise exception 'idempotency key reused with different payload' using errcode = '22023'; end if;
  if v_existing.response is not null then return v_existing.response; end if;
  select * into v_order from public.orders where organization_id = p_organization_id and id = p_order_id for update;
  if not found then raise exception 'order not found' using errcode = 'P0002'; end if;
  if v_order.status <> 'reopened' then raise exception 'only reopened orders can be discarded' using errcode = 'P0001'; end if;
  select * into v_attempt from public.order_reopen_attempts where organization_id = p_organization_id and id = p_reopen_attempt_id and order_id = p_order_id and unit_id = v_order.unit_id and base_revision_number = v_order.current_revision for update;
  if not found or v_attempt.status <> 'opened' then raise exception 'opened reopen attempt not found' using errcode = 'P0002'; end if;
  if not exists (select 1 from public.order_ledger_links l where l.organization_id = p_organization_id and l.order_id = p_order_id and l.unit_id = v_order.unit_id and l.revision_number = v_order.current_revision and l.kind = 'reversal') then raise exception 'reversal ledger link not found' using errcode = 'P0002'; end if;
  perform private.onda6_apply_snapshot_inventory(p_organization_id, p_order_id, v_order.current_revision, p_actor_user_id, false);
  v_ledger_response := private.onda6_reopen_ledger_post(p_organization_id, p_actor_user_id, p_idempotency_key, p_order_id, v_order.current_revision, 'restore');
  v_ledger_transaction_id := (v_ledger_response ->> 'transaction_id')::uuid;
  insert into public.order_ledger_links(organization_id, unit_id, order_id, revision_number, ledger_transaction_id, kind) values (p_organization_id, v_order.unit_id, p_order_id, v_order.current_revision, v_ledger_transaction_id, 'restore');
  update public.orders set status = 'closed' where organization_id = p_organization_id and id = p_order_id;
  update public.order_reopen_attempts set status = 'discarded', resolved_at = now() where id = v_attempt.id;
  insert into public.order_reopen_attempt_events(organization_id, unit_id, reopen_attempt_id, event_type, actor_id) values (p_organization_id, v_order.unit_id, v_attempt.id, 'discarded', p_actor_user_id);
  v_response := jsonb_build_object('order_id', p_order_id, 'reopen_attempt_id', v_attempt.id, 'status', 'closed', 'revision_number', v_order.current_revision);
  update private.idempotency_keys set response = v_response where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

revoke all on function private.onda6_checkout_reopen_enabled(uuid) from public, anon, authenticated, service_role;
revoke all on function private.onda6_apply_snapshot_inventory(uuid,uuid,integer,uuid,boolean) from public, anon, authenticated, service_role;
revoke all on function private.onda6_reopen_ledger_post(uuid,uuid,text,uuid,integer,text) from public, anon, authenticated, service_role;
revoke all on function public.order_reopen_request(uuid,uuid,text,uuid,text,text) from public, anon, authenticated;
revoke all on function public.order_reopen_approve(uuid,uuid,text,uuid,uuid) from public, anon, authenticated;
revoke all on function public.order_reopen(uuid,uuid,text,uuid,uuid) from public, anon, authenticated;
revoke all on function public.order_reopen_discard(uuid,uuid,text,uuid,uuid) from public, anon, authenticated;
grant execute on function public.order_reopen_request(uuid,uuid,text,uuid,text,text) to service_role;
grant execute on function public.order_reopen_approve(uuid,uuid,text,uuid,uuid) to service_role;
grant execute on function public.order_reopen(uuid,uuid,text,uuid,uuid) to service_role;
grant execute on function public.order_reopen_discard(uuid,uuid,text,uuid,uuid) to service_role;
