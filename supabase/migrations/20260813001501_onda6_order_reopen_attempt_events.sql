-- Onda 6, fatia 055: eventos são fatos separados da tentativa e carregam
-- somente o payload mínimo necessário para auditoria do ciclo de vida.
do $$
begin
  if to_regclass('public.order_reopen_attempts') is null then
    raise exception 'pre-flight check failed: public.order_reopen_attempts does not exist';
  end if;

  if to_regclass('public.order_reopen_attempt_events') is not null then
    raise exception 'pre-flight check failed: public.order_reopen_attempt_events already exists';
  end if;
end
$$;

create table public.order_reopen_attempt_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  reopen_attempt_id uuid not null,
  event_type text not null check (event_type in (
    'requested', 'approved', 'rejected', 'opened', 'discarded', 'reclosed'
  )),
  actor_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (organization_id, id, unit_id),
  foreign key (organization_id, unit_id)
    references public.units (organization_id, id) on delete restrict,
  foreign key (organization_id, reopen_attempt_id, unit_id)
    references public.order_reopen_attempts (organization_id, id, unit_id) on delete restrict,
  foreign key (organization_id, actor_id)
    references public.memberships (organization_id, user_id) on delete restrict
);
