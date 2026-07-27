-- KortexOS 5.1.2 — Onda 2, fatia 014: client_wallets/staff_current_accounts
-- (projeção nível 2, agregado org-wide) + self-view do profissional (Gate 02).
-- Implementa docs/adr/0019-onda2-kortexflow-ledger-fundacao.md e
-- issues/014-client-wallets-staff-current-accounts.md (DEC-41).
-- Fora de escopo desta fatia: benefit_obligations (fatia 015) e
-- payout_batches/payout_batch_items (fatia 016) — schema puro, sem produtor.

create table public.client_wallets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  client_id uuid not null,
  balance_cents bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, client_id),
  foreign key (organization_id, client_id) references public.clients(organization_id, id) on delete restrict
);

alter table public.client_wallets enable row level security;
create policy client_wallets_select on public.client_wallets for select to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager', 'reception']));

create table public.staff_current_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  professional_id uuid not null,
  balance_cents bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, professional_id),
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict
);

alter table public.staff_current_accounts enable row level security;
create policy staff_current_accounts_select on public.staff_current_accounts for select to authenticated using (
  private.has_role(organization_id, array['owner', 'admin', 'manager'])
  or exists (
    select 1 from public.professionals p
    where p.organization_id = staff_current_accounts.organization_id
      and p.id = staff_current_accounts.professional_id
      and p.user_id = (select auth.uid())
  )
);

-- ============================================================================
-- Trigger nível 2: disparada quando kortex_account_balances (nível 1) muda
-- numa conta client_wallet/staff_current_account, recalcula a SOMA cruzando
-- todas as unidades daquela pessoa e mantém balance_cents aqui — sempre
-- derivável do nível 1, nunca escrita direta (mesma disciplina do nível 1).
-- ============================================================================

create or replace function private.project_client_staff_aggregate_balance()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_account public.kortex_accounts%rowtype;
  v_total bigint;
begin
  select * into v_account from public.kortex_accounts where id = new.account_id;

  if v_account.kind = 'client_wallet' then
    select coalesce(sum(kab.balance_cents), 0) into v_total
    from public.kortex_account_balances kab
    join public.kortex_accounts ka on ka.id = kab.account_id
    where ka.organization_id = v_account.organization_id
      and ka.kind = 'client_wallet'
      and ka.client_id = v_account.client_id;

    insert into public.client_wallets(organization_id, client_id, balance_cents, updated_at)
    values (v_account.organization_id, v_account.client_id, v_total, now())
    on conflict (organization_id, client_id) do update
      set balance_cents = excluded.balance_cents, updated_at = now();
  elsif v_account.kind = 'staff_current_account' then
    select coalesce(sum(kab.balance_cents), 0) into v_total
    from public.kortex_account_balances kab
    join public.kortex_accounts ka on ka.id = kab.account_id
    where ka.organization_id = v_account.organization_id
      and ka.kind = 'staff_current_account'
      and ka.professional_id = v_account.professional_id;

    insert into public.staff_current_accounts(organization_id, professional_id, balance_cents, updated_at)
    values (v_account.organization_id, v_account.professional_id, v_total, now())
    on conflict (organization_id, professional_id) do update
      set balance_cents = excluded.balance_cents, updated_at = now();
  end if;

  return new;
end;
$$;
revoke all on function private.project_client_staff_aggregate_balance() from public, anon, authenticated;

create trigger kortex_account_balances_project_aggregate
after insert or update on public.kortex_account_balances
for each row execute function private.project_client_staff_aggregate_balance();
