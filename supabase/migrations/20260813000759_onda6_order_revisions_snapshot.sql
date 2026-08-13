-- Onda 6, fatia 055: o histórico de fechamento é um fato separado do pedido
-- vivo. A imutabilidade e RLS entram em ciclos seguintes desta mesma fatia.
do $$
begin
  if to_regclass('public.orders') is null or to_regclass('public.units') is null then
    raise exception 'pre-flight check failed: orders and units are required';
  end if;

  if to_regclass('public.order_revisions') is not null then
    raise exception 'pre-flight check failed: public.order_revisions already exists';
  end if;
end
$$;

create table public.order_revisions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  order_id uuid not null,
  revision_number integer not null check (revision_number > 0),
  snapshot jsonb not null,
  closed_by uuid not null,
  closed_at timestamptz not null,
  created_at timestamptz not null default now(),
  unique (organization_id, order_id, revision_number),
  unique (organization_id, id, unit_id),
  foreign key (organization_id, unit_id)
    references public.units (organization_id, id) on delete restrict,
  foreign key (organization_id, order_id, unit_id)
    references public.orders (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, closed_by)
    references public.memberships (organization_id, user_id) on delete restrict
);
