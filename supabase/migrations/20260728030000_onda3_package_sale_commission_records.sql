-- Onda 3, fatia 020 (issues/020-package-sale-commission-records.md,
-- Blueprint §2/§3.4/§3.5/§3.6/§3.8/§4, DEC-46): comissão de venda de
-- pacote, independente da comissão de execução (DEC-15/DEC-18).
-- packages.sale_commission_type/value (campo próprio do pacote, sem
-- cascata) + private.resolve_sale_commission() + commission_sale_records
-- (uma linha por comissão de venda reconhecida) + RPC
-- commission_sale_record_create(). Sem call site automático: o payload de
-- checkout_close não carrega "quem vendeu o pacote" (achado §3.4, distinto
-- de quem executa cada componente) — nenhuma rota Express chama esta RPC
-- ainda. Sem postagem no ledger: kortex_ledger_transaction_id nasce
-- nullable, a Onda 2 segue sem produtor real (§3.5). Clawback (DEC-18) não
-- é automatizado nesta fatia (§3.6) — só o status column permite registro manual.

-- Pre-flight check (DEC-44, otimização 2).
do $$
begin
  if to_regclass('public.packages') is null then
    raise exception 'pre-flight check failed: public.packages does not exist';
  end if;
  if to_regclass('public.orders_org_id_unit_unique') is null then
    raise exception 'pre-flight check failed: public.orders_org_id_unit_unique does not exist (Onda 0)';
  end if;
  if to_regclass('public.kortex_ledger_transactions') is null then
    raise exception 'pre-flight check failed: public.kortex_ledger_transactions does not exist (Onda 2)';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'packages' and column_name = 'sale_commission_type'
  ) then
    raise exception 'pre-flight check failed: public.packages.sale_commission_type already exists';
  end if;
  if to_regclass('public.commission_sale_records') is not null then
    raise exception 'pre-flight check failed: public.commission_sale_records already exists';
  end if;
end $$;

alter table public.packages
  add column sale_commission_type text check (sale_commission_type in ('percentage', 'fixed')),
  add column sale_commission_value bigint check (sale_commission_value is null or sale_commission_value >= 0),
  add constraint packages_sale_commission_pair check (
    (sale_commission_type is null and sale_commission_value is null) or (sale_commission_type is not null and sale_commission_value is not null)
  ),
  add constraint packages_sale_commission_percentage_cap check (
    sale_commission_type is distinct from 'percentage' or sale_commission_value <= 10000
  );

-- Campo flat do pacote (DEC-15): sem cascata, não é profissional×serviço.
create or replace function private.resolve_sale_commission(p_organization_id uuid, p_package_id uuid)
returns table (commission_type text, commission_value bigint)
language sql stable security definer set search_path = pg_catalog, public, private as $$
  select p.sale_commission_type, p.sale_commission_value
  from public.packages p
  where p.organization_id = p_organization_id and p.id = p_package_id;
$$;
revoke all on function private.resolve_sale_commission(uuid, uuid) from public, anon, authenticated;

-- Uma linha por comissão de venda reconhecida. Sem unicidade de chave de
-- negócio (mesmo padrão de order_items): checkout_close não deduplica
-- entradas repetidas de kind='package', vender o mesmo pacote 2x no mesmo
-- pedido pelo mesmo vendedor é cenário legítimo. Exclusividade de
-- gravação é 100% responsabilidade de private.idempotency_keys na RPC.
--
-- Hardening aplicado nesta implementação além do desenho original do
-- Blueprint (§4): order_id/unit_id/package_id/professional_id/
-- commission_type/commission_value são declarados not null. A FK composta
-- de 3 colunas em order_id só garante em nível de banco que o unit_id
-- desnormalizado bate com o unit_id real do pedido quando nenhuma dessas
-- colunas pode ser nula — Postgres usa MATCH SIMPLE por padrão, que
-- satisfaz a FK trivialmente se qualquer coluna for null (comportamento
-- documentado e aceito para inventory_movements/cash_entries, onde
-- order_id É opcional; aqui não há cenário legítimo de comissão de venda
-- sem pedido, então a mesma nulidade abriria uma lacuna real na garantia
-- que o Blueprint descreve).
create table public.commission_sale_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid not null,
  order_id uuid not null,
  package_id uuid not null,
  professional_id uuid not null,
  commission_type text not null check (commission_type in ('percentage', 'fixed')),
  commission_value bigint not null check (commission_value >= 0),
  commission_cents bigint not null check (commission_cents >= 0),
  status text not null default 'accrued' check (status in ('accrued', 'clawed_back')),
  kortex_ledger_transaction_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, order_id, unit_id) references public.orders(organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, package_id) references public.packages(organization_id, id) on delete restrict,
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  foreign key (organization_id, kortex_ledger_transaction_id) references public.kortex_ledger_transactions(organization_id, id) on delete restrict
);

create trigger commission_sale_records_touch
before update on public.commission_sale_records
for each row execute function private.touch_updated_at();

alter table public.commission_sale_records enable row level security;

-- owner/admin/manager org-wide + o profissional vendedor em self-view
-- (mesmo padrão de staff_current_accounts, Onda 2, Gate 02). Nenhum grant
-- de INSERT/UPDATE/DELETE direto para authenticated — só
-- commission_sale_record_create (security definer) escreve nesta tabela.
create policy commission_sale_records_select on public.commission_sale_records for select to authenticated using (
  private.has_role(organization_id, array['owner', 'admin', 'manager'])
  or exists (
    select 1 from public.professionals p
    where p.organization_id = commission_sale_records.organization_id
      and p.id = commission_sale_records.professional_id
      and p.user_id = (select auth.uid())
  )
);

-- RPC: grava uma linha em commission_sale_records a partir de
-- order_id/package_id/p_seller_professional_id explícito. Idempotente
-- (private.idempotency_keys, mesmo padrão de checkout_close/
-- deposit_hold_create). Sem call site automático nesta fatia.
-- search_path inclui `extensions` (além de pg_catalog/public/private, o
-- trio citado pelo achado do red team) porque esta RPC chama digest()
-- (pgcrypto) para a chave de idempotência — mesma necessidade funcional
-- já resolvida da mesma forma em checkout_close/deposit_hold_create.
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
  v_package_price_cents bigint;
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

  select price_cents into v_package_price_cents from public.packages where organization_id = p_organization_id and id = p_package_id;
  if not found then
    raise exception 'package not found' using errcode = 'P0002';
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
      then round(v_package_price_cents * v_commission_value / 10000.0)::bigint
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
