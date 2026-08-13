-- Onda 6, fatia 055: fatos financeiros e de auditoria da reabertura.
-- Esta migration apenas cria a fundacao fisica. Nenhum Command, RPC ou fluxo
-- historico de checkout/refund e alterado aqui.
do $$
begin
  if to_regclass('public.orders') is null
     or to_regclass('public.order_revisions') is null
     or to_regclass('public.order_reopen_attempts') is null
     or to_regclass('public.order_reopen_attempt_events') is null
     or to_regclass('public.kortex_ledger_transactions') is null then
    raise exception 'pre-flight check failed: Onda 6 dependencies are required';
  end if;

  if to_regclass('public.order_ledger_links') is not null
     or to_regclass('public.order_financial_locks') is not null
     or to_regclass('public.order_payment_adjustments') is not null then
    raise exception 'pre-flight check failed: Onda 6 financial facts already exist';
  end if;
end
$$;

-- As tres chaves compostas abaixo sao a base para FKs tenant-safe e
-- unit-safe dos novos fatos. Cada combinacao ja e unica pelo id primario;
-- as constraints tornam essa propriedade referenciavel pelo Postgres.
alter table public.payments
  add constraint payments_org_id_unit_unique unique (organization_id, id, unit_id);

alter table public.cash_entries
  add constraint cash_entries_org_id_unit_unique unique (organization_id, id, unit_id);

alter table public.kortex_ledger_transactions
  add constraint kortex_ledger_transactions_org_id_unit_unique
    unique (organization_id, id, unit_id);

alter table public.order_reopen_attempts
  add constraint order_reopen_attempts_base_revision_fk
    foreign key (organization_id, order_id, base_revision_number)
    references public.order_revisions (organization_id, order_id, revision_number)
    on delete restrict;

create table public.order_ledger_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  order_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  ledger_transaction_id uuid not null,
  kind text not null check (kind in ('closure', 'reversal', 'restore')),
  created_at timestamptz not null default now(),
  unique (organization_id, id, unit_id),
  unique (organization_id, order_id, revision_number, kind),
  foreign key (organization_id, unit_id)
    references public.units (organization_id, id) on delete restrict,
  foreign key (organization_id, order_id, unit_id)
    references public.orders (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, order_id, revision_number)
    references public.order_revisions (organization_id, order_id, revision_number) on delete restrict,
  foreign key (organization_id, ledger_transaction_id, unit_id)
    references public.kortex_ledger_transactions (organization_id, id, unit_id) on delete restrict
);

create table public.order_financial_locks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  order_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  source_type text not null check (source_type in (
    'cash_close', 'staff_payout', 'psp_settlement', 'fiscal_emission',
    'captured_payment_intent'
  )),
  source_id uuid not null,
  enforcement text not null check (enforcement in ('action_request_required', 'terminal')),
  created_by uuid not null,
  locked_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (organization_id, id, unit_id),
  unique (organization_id, order_id, revision_number, source_type, source_id),
  foreign key (organization_id, unit_id)
    references public.units (organization_id, id) on delete restrict,
  foreign key (organization_id, order_id, unit_id)
    references public.orders (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, order_id, revision_number)
    references public.order_revisions (organization_id, order_id, revision_number) on delete restrict,
  foreign key (organization_id, created_by)
    references public.memberships (organization_id, user_id) on delete restrict
);

create table public.order_payment_adjustments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  order_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  payment_id uuid not null,
  cash_entry_id uuid,
  reopen_attempt_id uuid,
  kind text not null check (kind in ('reversal', 'restore', 'refund_allocation')),
  amount_cents bigint not null check (amount_cents > 0),
  created_by uuid not null,
  created_at timestamptz not null default now(),
  unique (organization_id, id, unit_id),
  unique (organization_id, order_id, revision_number, payment_id, kind),
  foreign key (organization_id, unit_id)
    references public.units (organization_id, id) on delete restrict,
  foreign key (organization_id, order_id, unit_id)
    references public.orders (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, order_id, revision_number)
    references public.order_revisions (organization_id, order_id, revision_number) on delete restrict,
  foreign key (organization_id, payment_id, unit_id)
    references public.payments (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, cash_entry_id, unit_id)
    references public.cash_entries (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, reopen_attempt_id, unit_id)
    references public.order_reopen_attempts (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, created_by)
    references public.memberships (organization_id, user_id) on delete restrict
);

-- Fatos de auditoria e financeiros nunca recebem edicao ou exclusao por DML,
-- inclusive pelo backend service-role. Uma correcao futura acrescenta fatos.
create or replace function private.guard_onda6_append_only()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  raise exception 'Onda 6 financial facts are append-only' using errcode = '55000';
end;
$$;

revoke all on function private.guard_onda6_append_only()
  from public, anon, authenticated, service_role;

create trigger order_reopen_attempt_events_append_only
  before update or delete on public.order_reopen_attempt_events
  for each row execute function private.guard_onda6_append_only();

create trigger order_ledger_links_append_only
  before update or delete on public.order_ledger_links
  for each row execute function private.guard_onda6_append_only();

create trigger order_financial_locks_append_only
  before update or delete on public.order_financial_locks
  for each row execute function private.guard_onda6_append_only();

create trigger order_payment_adjustments_append_only
  before update or delete on public.order_payment_adjustments
  for each row execute function private.guard_onda6_append_only();

-- Leitura de gestao e unit-aware; a escrita fica deliberadamente sem policy
-- e sem grant para authenticated/anon, reservada aos Commands futuros.
alter table public.order_revisions enable row level security;
alter table public.order_reopen_attempts enable row level security;
alter table public.order_reopen_attempt_events enable row level security;
alter table public.order_ledger_links enable row level security;
alter table public.order_financial_locks enable row level security;
alter table public.order_payment_adjustments enable row level security;

grant select on table
  public.order_revisions,
  public.order_reopen_attempts,
  public.order_reopen_attempt_events,
  public.order_ledger_links,
  public.order_financial_locks,
  public.order_payment_adjustments
to authenticated;

revoke insert, update, delete on table
  public.order_revisions,
  public.order_reopen_attempts,
  public.order_reopen_attempt_events,
  public.order_ledger_links,
  public.order_financial_locks,
  public.order_payment_adjustments
from anon, authenticated;

create policy order_revisions_select on public.order_revisions for select to authenticated using (
  private.can_access_fact_unit(organization_id, unit_id, array['owner', 'admin', 'manager'], array[]::text[])
);

create policy order_reopen_attempts_select on public.order_reopen_attempts for select to authenticated using (
  private.can_access_fact_unit(organization_id, unit_id, array['owner', 'admin', 'manager'], array[]::text[])
);

create policy order_reopen_attempt_events_select on public.order_reopen_attempt_events for select to authenticated using (
  private.can_access_fact_unit(organization_id, unit_id, array['owner', 'admin', 'manager'], array[]::text[])
);

create policy order_ledger_links_select on public.order_ledger_links for select to authenticated using (
  private.can_access_fact_unit(organization_id, unit_id, array['owner', 'admin', 'manager'], array[]::text[])
);

create policy order_financial_locks_select on public.order_financial_locks for select to authenticated using (
  private.can_access_fact_unit(organization_id, unit_id, array['owner', 'admin', 'manager'], array[]::text[])
);

create policy order_payment_adjustments_select on public.order_payment_adjustments for select to authenticated using (
  private.can_access_fact_unit(organization_id, unit_id, array['owner', 'admin', 'manager'], array[]::text[])
);
