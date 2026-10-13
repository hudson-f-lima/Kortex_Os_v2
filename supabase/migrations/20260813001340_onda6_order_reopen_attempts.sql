-- Onda 6, fatia 055: tentativa de reabertura separada da revisão fechada.
do $$
begin
  if to_regclass('public.orders') is null or to_regclass('public.units') is null then
    raise exception 'pre-flight check failed: orders and units are required';
  end if;

  if to_regclass('public.order_reopen_attempts') is not null then
    raise exception 'pre-flight check failed: public.order_reopen_attempts already exists';
  end if;
end
$$;

create table public.order_reopen_attempts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  order_id uuid not null,
  base_revision_number integer not null check (base_revision_number > 0),
  reason_code text not null check (reason_code in (
    'pricing_error', 'item_correction', 'professional_correction',
    'payment_correction', 'inventory_correction', 'other'
  )),
  reason_detail text not null check (length(btrim(reason_detail)) > 0),
  status text not null default 'requested' check (status in (
    'requested', 'approved', 'rejected', 'opened', 'discarded', 'reclosed'
  )),
  requested_by uuid not null,
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique (organization_id, id, unit_id),
  foreign key (organization_id, unit_id)
    references public.units (organization_id, id) on delete restrict,
  foreign key (organization_id, order_id, unit_id)
    references public.orders (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, requested_by)
    references public.memberships (organization_id, user_id) on delete restrict
);

create unique index order_reopen_attempts_one_active_per_order_idx
  on public.order_reopen_attempts (organization_id, order_id)
  where status in ('requested', 'approved', 'opened');
