-- Onda 6 remediation: a discarded attempt permits a later attempt on the
-- same immutable revision. Reversal and restore ledger facts are therefore
-- attributable to their attempt, rather than unique only by revision/kind.
do $$
begin
  if to_regclass('public.order_ledger_links') is null
     or to_regclass('public.order_reopen_attempts') is null
     or to_regclass('public.order_reopen_attempt_events') is null then
    raise exception 'pre-flight check failed: Onda 6 reopen ledger facts are required';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'order_ledger_links'
      and column_name = 'reopen_attempt_id'
  ) then
    raise exception 'pre-flight check failed: order_ledger_links.reopen_attempt_id already exists';
  end if;
end
$$;

alter table public.order_ledger_links
  add column reopen_attempt_id uuid;

alter table public.order_ledger_links
  add constraint order_ledger_links_reopen_attempt_fk
  foreign key (organization_id, reopen_attempt_id, unit_id)
  references public.order_reopen_attempts (organization_id, id, unit_id)
  on delete restrict;

alter table public.order_ledger_links
  drop constraint if exists order_ledger_links_organization_id_order_id_revision_number_key;

-- The existing append-only trigger correctly protects runtime facts but must
-- be paused for this one-time, deterministic attribution of the facts already
-- written by the first staging deployment.
alter table public.order_ledger_links disable trigger order_ledger_links_append_only;
update public.order_ledger_links l
set reopen_attempt_id = (
  select a.id
  from public.order_reopen_attempts a
  where a.organization_id = l.organization_id
    and a.unit_id = l.unit_id
    and a.order_id = l.order_id
    and a.base_revision_number = l.revision_number
    and a.status in ('opened', 'discarded', 'reclosed')
    and exists (
      select 1
      from public.order_reopen_attempt_events e
      where e.organization_id = a.organization_id
        and e.reopen_attempt_id = a.id
        and e.event_type = case l.kind when 'reversal' then 'opened' else 'discarded' end
    )
  order by a.requested_at desc, a.id desc
  limit 1
)
where l.reopen_attempt_id is null
  and l.kind in ('reversal', 'restore');
alter table public.order_ledger_links enable trigger order_ledger_links_append_only;

create unique index order_ledger_links_one_non_attempt_kind_per_revision_idx
  on public.order_ledger_links (organization_id, order_id, revision_number, kind)
  where reopen_attempt_id is null;

create unique index order_ledger_links_one_kind_per_attempt_idx
  on public.order_ledger_links (organization_id, order_id, revision_number, kind, reopen_attempt_id)
  where reopen_attempt_id is not null;

create function private.onda6_attach_reopen_attempt_to_ledger_link()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_attempt public.order_reopen_attempts%rowtype;
begin
  if new.kind = 'closure' then
    if new.reopen_attempt_id is not null then
      raise exception 'closure ledger link cannot reference a reopen attempt' using errcode = '22023';
    end if;
    return new;
  end if;

  if new.kind not in ('reversal', 'restore') then
    raise exception 'invalid order ledger link kind' using errcode = '22023';
  end if;

  if new.reopen_attempt_id is null then
    select * into v_attempt
    from public.order_reopen_attempts
    where organization_id = new.organization_id
      and unit_id = new.unit_id
      and order_id = new.order_id
      and base_revision_number = new.revision_number
      and (
        (new.kind = 'reversal' and status in ('requested', 'approved'))
        or (new.kind = 'restore' and status = 'opened')
      )
    for update;
    if found then
      new.reopen_attempt_id := v_attempt.id;
    end if;
  else
    select * into v_attempt
    from public.order_reopen_attempts
    where organization_id = new.organization_id
      and id = new.reopen_attempt_id
      and unit_id = new.unit_id
      and order_id = new.order_id
      and base_revision_number = new.revision_number
    for update;
    if not found then
      raise exception 'reopen attempt does not match ledger link' using errcode = '23503';
    end if;
  end if;

  return new;
end;
$$;

create trigger order_ledger_links_attach_reopen_attempt
  before insert on public.order_ledger_links
  for each row execute function private.onda6_attach_reopen_attempt_to_ledger_link();

revoke all on function private.onda6_attach_reopen_attempt_to_ledger_link() from public, anon, authenticated, service_role;
