-- KortexOS 5.1.2 — Onda 2, fatia 013: kortex_ledger_transactions/entries +
-- RPC kortex_ledger_post (porta única de escrita) + projeção nível 1
-- (kortex_account_balances). Implementa docs/adr/0019-onda2-kortexflow-ledger-fundacao.md
-- e issues/013-kortex-ledger-post-double-entry.md (DEC-41).
-- Fora de escopo desta fatia: client_wallets/staff_current_accounts (projeção
-- nível 2) nascem na fatia 014, que consome esta trigger nível 1.

-- kortex_accounts ainda não tinha unique(organization_id, id) — necessário
-- para a FK composta tenant-safe de kortex_ledger_entries.account_id abaixo.
alter table public.kortex_accounts add constraint kortex_accounts_org_id_unique unique (organization_id, id);

create table public.kortex_ledger_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  description text,
  created_by uuid,
  created_at timestamptz not null default now(),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  unique (organization_id, id)
);

alter table public.kortex_ledger_transactions enable row level security;
create policy kortex_ledger_transactions_select on public.kortex_ledger_transactions for select to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager']));

create table public.kortex_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  transaction_id uuid not null,
  account_id uuid not null,
  direction text not null check (direction in ('debit', 'credit')),
  amount_cents bigint not null check (amount_cents > 0),
  created_at timestamptz not null default now(),
  foreign key (organization_id, transaction_id) references public.kortex_ledger_transactions(organization_id, id) on delete restrict,
  foreign key (organization_id, account_id) references public.kortex_accounts(organization_id, id) on delete restrict
);

create index kortex_ledger_entries_transaction_idx on public.kortex_ledger_entries(organization_id, transaction_id);
create index kortex_ledger_entries_account_idx on public.kortex_ledger_entries(organization_id, account_id);

alter table public.kortex_ledger_entries enable row level security;
create policy kortex_ledger_entries_select on public.kortex_ledger_entries for select to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager']));

create table public.kortex_account_balances (
  account_id uuid primary key,
  organization_id uuid not null,
  unit_id uuid not null,
  balance_cents bigint not null default 0,
  updated_at timestamptz not null default now(),
  foreign key (organization_id, account_id) references public.kortex_accounts(organization_id, id) on delete restrict
);

alter table public.kortex_account_balances enable row level security;
create policy kortex_account_balances_select on public.kortex_account_balances for select to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager']));

-- ============================================================================
-- kortex_ledger_post — única porta de escrita em kortex_ledger_entries.
-- p_entries: array de objetos { account_id | (kind, client_id, professional_id),
-- direction: 'debit'|'credit', amount_cents }. Quando account_id vem null,
-- resolve/cria a conta por entidade sob demanda (achado #1 do Red Team:
-- ON CONFLICT DO NOTHING + SELECT, nunca SELECT seguido de INSERT
-- desprotegido). Quando account_id vem preenchido, valida tenant antes de
-- qualquer INSERT (achado #2). Autorização: owner/admin/manager (achado #3).
-- ============================================================================

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
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner', 'admin', 'manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
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
  if v_existing.response is not null then return v_existing.response; end if;

  -- Double-entry (Blueprint §3): valida ANTES de inserir qualquer coisa.
  select
    coalesce(sum((e ->> 'amount_cents')::bigint) filter (where e ->> 'direction' = 'debit'), 0),
    coalesce(sum((e ->> 'amount_cents')::bigint) filter (where e ->> 'direction' = 'credit'), 0)
  into v_debit_total, v_credit_total
  from jsonb_array_elements(p_entries) e;

  if v_debit_total = 0 or v_debit_total <> v_credit_total then
    raise exception 'unbalanced ledger entries: debit % != credit %', v_debit_total, v_credit_total using errcode = '22023';
  end if;

  -- Achado #2: todo account_id explícito no payload precisa pertencer a
  -- p_organization_id E a p_unit_id — checado antes de qualquer INSERT.
  -- Nenhuma entrada é aceita para uma conta de unidade diferente de
  -- p_unit_id, mesmo dentro da mesma organização (Blueprint §3).
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
      -- Achado #1: cria sob demanda via ON CONFLICT DO NOTHING, depois lê —
      -- nunca SELECT seguido de INSERT desprotegido.
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
revoke all on function public.kortex_ledger_post(uuid, uuid, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.kortex_ledger_post(uuid, uuid, text, uuid, jsonb) to service_role;

-- ============================================================================
-- Trigger nível 1: kortex_account_balances é sempre derivável recalculando
-- SUM(kortex_ledger_entries) do zero (Gate 13) — a trigger só existe para dar
-- leitura O(1). Convenção: balance_cents = SUM(debit) - SUM(credit) por conta.
-- Nenhum grant de INSERT/UPDATE a authenticated/anon; service_role tem grant
-- de tabela completo por padrão da plataforma (mesma disciplina de todo o
-- schema) — a garantia de porta única é procedural (só o backend chama
-- kortex_ledger_post), não um lockout de grant contra service_role.
-- ============================================================================

create or replace function private.project_kortex_account_balance()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_delta bigint := case when new.direction = 'debit' then new.amount_cents else -new.amount_cents end;
begin
  insert into public.kortex_account_balances(account_id, organization_id, unit_id, balance_cents, updated_at)
  values (new.account_id, new.organization_id, new.unit_id, v_delta, now())
  on conflict (account_id) do update
    set balance_cents = public.kortex_account_balances.balance_cents + excluded.balance_cents,
        updated_at = now();
  return new;
end;
$$;
revoke all on function private.project_kortex_account_balance() from public, anon, authenticated;

create trigger kortex_ledger_entries_project_balance
after insert on public.kortex_ledger_entries
for each row execute function private.project_kortex_account_balance();
