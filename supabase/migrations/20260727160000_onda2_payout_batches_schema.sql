-- KortexOS 5.1.2 — Onda 2, fatia 016: payout_batches/payout_batch_items,
-- schema puro. Implementa docs/adr/0019-onda2-kortexflow-ledger-fundacao.md
-- e issues/016-payout-batches-schema.md (DEC-41). Fecha as 5 fatias da Onda 2.
-- Sem produtor nesta Onda — repasse real depende de comissão real, que
-- depende da Onda 2b (ativação). Mesmo padrão cabeçalho+linhas de
-- orders/order_items e de kortex_ledger_transactions/entries.

create table public.payout_batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  period_start date not null,
  period_end date not null,
  status text not null default 'draft' check (status in ('draft', 'processing', 'paid', 'failed')),
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict,
  unique (organization_id, id),
  check (period_end >= period_start)
);

create index payout_batches_unit_idx on public.payout_batches(organization_id, unit_id, status);

alter table public.payout_batches enable row level security;
create policy payout_batches_select on public.payout_batches for select to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager']));

create table public.payout_batch_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  payout_batch_id uuid not null,
  professional_id uuid not null,
  amount_cents bigint not null check (amount_cents > 0),
  status text not null default 'pending' check (status in ('pending', 'paid', 'failed')),
  created_at timestamptz not null default now(),
  foreign key (organization_id, payout_batch_id) references public.payout_batches(organization_id, id) on delete restrict,
  foreign key (organization_id, professional_id) references public.staff_current_accounts(organization_id, professional_id) on delete restrict
);

create index payout_batch_items_batch_idx on public.payout_batch_items(organization_id, payout_batch_id);
create index payout_batch_items_professional_idx on public.payout_batch_items(organization_id, professional_id);

alter table public.payout_batch_items enable row level security;
create policy payout_batch_items_select on public.payout_batch_items for select to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager']));
