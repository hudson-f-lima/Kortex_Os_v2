-- KortexOS 5.1.2 — Onda 2, fatia 015: benefit_obligations, schema puro.
-- Implementa docs/adr/0019-onda2-kortexflow-ledger-fundacao.md e
-- issues/015-benefit-obligations-schema.md (DEC-41).
-- Fundação sem produtor — D18 (Subscription Engine) não existe ainda.
-- Nenhum fluxo desta Onda insere linha aqui. source_reference é texto livre
-- (não FK): plan/corporate/partner não têm tabela própria ainda; forçar FK
-- só para package deixaria a coluna inconsistente entre os 4 tipos.

create table public.benefit_obligations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  client_id uuid not null,
  source_type text not null check (source_type in ('package', 'plan', 'corporate', 'partner')),
  source_reference text,
  total_cents bigint not null check (total_cents >= 0),
  consumed_cents bigint not null default 0 check (consumed_cents >= 0),
  status text not null check (status in ('active', 'expired', 'exhausted', 'cancelled')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, client_id) references public.clients(organization_id, id) on delete restrict,
  check (consumed_cents <= total_cents)
);

create index benefit_obligations_client_idx on public.benefit_obligations(organization_id, client_id);

create trigger benefit_obligations_touch before update on public.benefit_obligations for each row execute function private.touch_updated_at();

alter table public.benefit_obligations enable row level security;
create policy benefit_obligations_select on public.benefit_obligations for select to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager']));
