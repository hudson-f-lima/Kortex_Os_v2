-- Onda 6, fatia 055: fechamento histórico não é alterável nem removível.
do $$
begin
  if to_regclass('public.order_revisions') is null then
    raise exception 'pre-flight check failed: public.order_revisions does not exist';
  end if;

  if exists (
    select 1 from pg_trigger
     where tgrelid = 'public.order_revisions'::regclass
       and tgname = 'order_revisions_immutable_guard'
       and not tgisinternal
  ) then
    raise exception 'pre-flight check failed: order_revisions_immutable_guard already exists';
  end if;
end
$$;

create function private.guard_order_revision_immutable()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  raise exception 'order revision is immutable' using errcode = '55000';
end;
$$;

revoke all on function private.guard_order_revision_immutable()
  from public, anon, authenticated, service_role;

create trigger order_revisions_immutable_guard
before update or delete on public.order_revisions
for each row execute function private.guard_order_revision_immutable();
