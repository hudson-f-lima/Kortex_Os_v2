-- KortexOS 5.1.2 — Onda 2, fatia 012: kortex_accounts (razão auxiliar + plano
-- de contas por unidade). Implementa docs/adr/0019-onda2-kortexflow-ledger-fundacao.md
-- e issues/012-kortex-accounts-chart-of-accounts.md (DEC-41).
-- Fora de escopo desta fatia: contas por entidade (client_wallet/staff_current_account)
-- não nascem aqui — criação sob demanda é responsabilidade da fatia 013
-- (kortex_ledger_post), primeira a referenciá-las.

create table public.kortex_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  kind text not null check (kind in (
    'cash', 'revenue_service', 'revenue_product', 'commission_expense',
    'tip_liability', 'refund_expense', 'benefit_obligation_liability',
    'client_wallet', 'staff_current_account'
  )),
  client_id uuid,
  professional_id uuid,
  created_at timestamptz not null default now(),
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  foreign key (organization_id, client_id) references public.clients(organization_id, id) on delete restrict,
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  check (
    (kind not in ('client_wallet', 'staff_current_account') and client_id is null and professional_id is null)
    or (kind = 'client_wallet' and client_id is not null and professional_id is null)
    or (kind = 'staff_current_account' and professional_id is not null and client_id is null)
  )
);

alter table public.kortex_accounts enable row level security;

create policy kortex_accounts_select on public.kortex_accounts for select to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager']));

create unique index kortex_accounts_fixed_unique_idx on public.kortex_accounts(organization_id, unit_id, kind) where kind not in ('client_wallet', 'staff_current_account');
create unique index kortex_accounts_client_wallet_unique_idx on public.kortex_accounts(organization_id, unit_id, kind, client_id) where kind = 'client_wallet';
create unique index kortex_accounts_staff_current_account_unique_idx on public.kortex_accounts(organization_id, unit_id, kind, professional_id) where kind = 'staff_current_account';

-- ============================================================================
-- Seed: toda unidade nova ganha as 7 contas fixas do plano de contas.
-- Contas por entidade (client_wallet/staff_current_account) não nascem aqui.
-- ============================================================================

create or replace function private.seed_kortex_fixed_accounts_for_unit()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  insert into public.kortex_accounts (organization_id, unit_id, kind)
  select new.organization_id, new.id, k
  from unnest(array[
    'cash', 'revenue_service', 'revenue_product', 'commission_expense',
    'tip_liability', 'refund_expense', 'benefit_obligation_liability'
  ]) as k;
  return new;
end;
$$;
revoke all on function private.seed_kortex_fixed_accounts_for_unit() from public, anon, authenticated;

create trigger units_seed_kortex_fixed_accounts
after insert on public.units
for each row execute function private.seed_kortex_fixed_accounts_for_unit();

-- ============================================================================
-- Backfill retroativo: cobre toda unidade que já existe hoje em staging/local
-- (nasceu antes desta migration, portanto antes do trigger acima existir).
-- Idempotente via NOT EXISTS — seguro rodar de novo mesmo se 0 linhas afetadas.
-- ============================================================================

insert into public.kortex_accounts (organization_id, unit_id, kind)
select u.organization_id, u.id, k.kind
from public.units u
cross join unnest(array[
  'cash', 'revenue_service', 'revenue_product', 'commission_expense',
  'tip_liability', 'refund_expense', 'benefit_obligation_liability'
]) as k(kind)
where not exists (
  select 1 from public.kortex_accounts ka
  where ka.organization_id = u.organization_id and ka.unit_id = u.id and ka.kind = k.kind
);
