-- Fase 10: Capacidades N:N profissional×serviço
-- Permite que um profissional tenha duração/preço/buffers customizados por serviço.

create table public.professional_service_capabilities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  professional_id uuid not null,
  service_id uuid not null,
  duration_override_minutes integer check (duration_override_minutes is null or duration_override_minutes between 5 and 1440),
  buffer_before_min integer not null default 0 check (buffer_before_min >= 0 and buffer_before_min <= 480),
  buffer_after_min integer not null default 0 check (buffer_after_min >= 0 and buffer_after_min <= 480),
  price_override_cents bigint check (price_override_cents is null or price_override_cents >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, professional_id, service_id),
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  foreign key (organization_id, service_id) references public.services(organization_id, id) on delete restrict
);

create index professional_service_capabilities_professional_idx
on public.professional_service_capabilities(organization_id, professional_id)
where active;

create index professional_service_capabilities_service_idx
on public.professional_service_capabilities(organization_id, service_id)
where active;

create trigger professional_service_capabilities_touch
before update on public.professional_service_capabilities
for each row execute function private.touch_updated_at();

alter table public.professional_service_capabilities enable row level security;

create policy professional_service_capabilities_select
on public.professional_service_capabilities for select
to authenticated
using (private.is_member(organization_id));

create policy professional_service_capabilities_insert
on public.professional_service_capabilities for insert
to authenticated
with check (private.has_role(organization_id, array['owner','admin','manager']));

create policy professional_service_capabilities_update
on public.professional_service_capabilities for update
to authenticated
using (private.has_role(organization_id, array['owner','admin','manager']))
with check (private.has_role(organization_id, array['owner','admin','manager']));

create policy professional_service_capabilities_delete
on public.professional_service_capabilities for delete
to authenticated
using (private.has_role(organization_id, array['owner','admin']));
