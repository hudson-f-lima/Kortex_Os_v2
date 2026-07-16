-- Migration to add sync_events table and logging triggers for incremental synchronization
-- Designed to capture inserts, updates, and deletes for projection cache syncing

create table public.sync_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  table_name text not null,
  record_id uuid not null,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  payload jsonb,
  created_at timestamptz not null default now()
);

alter table public.sync_events enable row level security;
grant select on public.sync_events to service_role;

create or replace function private.log_sync_event()
returns trigger language plpgsql security definer set search_path = pg_catalog, public, private as $$
declare
  v_org_id uuid;
  v_rec_id uuid;
  v_payload jsonb;
begin
  if tg_op = 'DELETE' then
    v_org_id := old.organization_id;
    v_rec_id := old.id;
    v_payload := to_jsonb(old);
  else
    v_org_id := new.organization_id;
    v_rec_id := new.id;
    v_payload := to_jsonb(new);
  end if;

  insert into public.sync_events(organization_id, table_name, record_id, action, payload)
  values (v_org_id, tg_table_name, v_rec_id, tg_op, v_payload);

  return null;
end;
$$;
revoke all on function private.log_sync_event() from public, anon, authenticated;

-- Attaching the triggers to track modifications
create trigger clients_sync_trigger
after insert or update or delete on public.clients
for each row execute function private.log_sync_event();

create trigger professionals_sync_trigger
after insert or update or delete on public.professionals
for each row execute function private.log_sync_event();

create trigger services_sync_trigger
after insert or update or delete on public.services
for each row execute function private.log_sync_event();

create trigger products_sync_trigger
after insert or update or delete on public.products
for each row execute function private.log_sync_event();

create trigger packages_sync_trigger
after insert or update or delete on public.packages
for each row execute function private.log_sync_event();

create trigger service_groups_sync_trigger
after insert or update or delete on public.service_groups
for each row execute function private.log_sync_event();

create trigger appointments_sync_trigger
after insert or update or delete on public.appointments
for each row execute function private.log_sync_event();

create trigger capabilities_sync_trigger
after insert or update or delete on public.professional_service_capabilities
for each row execute function private.log_sync_event();

create trigger commissions_sync_trigger
after insert or update or delete on public.professional_service_commissions
for each row execute function private.log_sync_event();
