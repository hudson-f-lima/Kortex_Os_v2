-- Onda 0 forward-only correction.
-- The original backfill covered professionals that existed when Migration 1
-- ran, but did not cover professionals created afterwards.

-- professional_units is an association owned by the professional lifecycle.
-- The original RESTRICT action made every otherwise-valid professional delete
-- fail as soon as the automatic default-unit link was introduced.
alter table public.professional_units
  drop constraint professional_units_organization_id_professional_id_fkey;

alter table public.professional_units
  add constraint professional_units_professional_fk
  foreign key (organization_id, professional_id)
  references public.professionals(organization_id, id)
  on delete cascade;

create or replace function private.link_new_professional_to_default_unit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_unit_id uuid;
begin
  select u.id
    into v_unit_id
  from public.units u
  where u.organization_id = new.organization_id
    and u.is_default
    and u.active
  for key share;

  if v_unit_id is null then
    raise exception 'organization must have an active default unit before creating a professional'
      using errcode = '23514';
  end if;

  insert into public.professional_units (
    organization_id,
    professional_id,
    unit_id,
    active
  )
  values (
    new.organization_id,
    new.id,
    v_unit_id,
    true
  );

  insert into public.unit_access_audit_events (
    organization_id,
    unit_id,
    event_type,
    actor_kind,
    professional_id,
    after_state
  )
  values (
    new.organization_id,
    v_unit_id,
    'professional_unit_changed',
    'system',
    new.id,
    jsonb_build_object(
      'professional_id', new.id,
      'unit_id', v_unit_id,
      'active', true,
      'source', 'professional_insert'
    )
  );

  return new;
end;
$$;

revoke all on function private.link_new_professional_to_default_unit()
  from public, anon, authenticated;

create trigger professionals_link_default_unit
after insert on public.professionals
for each row execute function private.link_new_professional_to_default_unit();

create or replace function private.audit_professional_unit_delete()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_setting text := nullif(
    current_setting('kortex.actor_user_id', true),
    ''
  );
  v_actor_user_id uuid;
begin
  if v_actor_setting is not null then
    v_actor_user_id := v_actor_setting::uuid;
  end if;

  insert into public.unit_access_audit_events (
    organization_id,
    unit_id,
    event_type,
    actor_kind,
    actor_user_id,
    professional_id,
    before_state,
    after_state
  )
  values (
    old.organization_id,
    old.unit_id,
    'professional_unit_changed',
    case when v_actor_user_id is null then 'system' else 'user' end,
    v_actor_user_id,
    old.professional_id,
    jsonb_build_object(
      'professional_id', old.professional_id,
      'unit_id', old.unit_id,
      'active', old.active
    ),
    jsonb_build_object(
      'professional_id', old.professional_id,
      'unit_id', old.unit_id,
      'active', false,
      'action', 'deleted'
    )
  );

  return old;
end;
$$;

revoke all on function private.audit_professional_unit_delete()
  from public, anon, authenticated;

create trigger professional_units_audit_delete
before delete on public.professional_units
for each row execute function private.audit_professional_unit_delete();

alter table public.membership_permissions
  drop constraint membership_permissions_check;
alter table public.membership_permissions
  add constraint membership_permissions_revocation_actor_check
  check (revoked_at is not null or revoked_by is null);

create or replace function private.invalidate_professional_access()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_setting text := nullif(
    current_setting('kortex.actor_user_id', true),
    ''
  );
  v_actor_user_id uuid;
  v_actor_kind text := 'system';
  v_membership public.memberships;
  v_revoked_permission record;
begin
  if tg_op = 'UPDATE'
    and old.user_id is not distinct from new.user_id
    and not (old.active and not new.active)
  then
    return new;
  end if;

  if old.user_id is null then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if v_actor_setting is not null then
    v_actor_user_id := v_actor_setting::uuid;
    v_actor_kind := 'user';
  end if;

  select *
    into v_membership
  from public.memberships m
  where m.organization_id = old.organization_id
    and m.user_id = old.user_id
  for update;

  if found and v_membership.role = 'professional' and v_membership.active then
    update public.memberships
    set active = false
    where organization_id = old.organization_id
      and user_id = old.user_id;

    insert into public.unit_access_audit_events (
      organization_id,
      unit_id,
      event_type,
      actor_kind,
      actor_user_id,
      target_user_id,
      before_state,
      after_state
    )
    values (
      old.organization_id,
      v_membership.unit_id,
      'membership_scope_changed',
      v_actor_kind,
      v_actor_user_id,
      old.user_id,
      jsonb_build_object(
        'role', v_membership.role,
        'unit_id', v_membership.unit_id,
        'active', true
      ),
      jsonb_build_object(
        'role', v_membership.role,
        'unit_id', v_membership.unit_id,
        'active', false,
        'source', 'professional_lifecycle'
      )
    );
  end if;

  for v_revoked_permission in
    update public.membership_permissions
    set revoked_by = v_actor_user_id,
        revoked_at = now()
    where organization_id = old.organization_id
      and user_id = old.user_id
      and revoked_at is null
    returning permission_code
  loop
    insert into public.unit_access_audit_events (
      organization_id,
      unit_id,
      event_type,
      actor_kind,
      actor_user_id,
      target_user_id,
      before_state,
      after_state
    )
    values (
      old.organization_id,
      v_membership.unit_id,
      'permission_revoked',
      v_actor_kind,
      v_actor_user_id,
      old.user_id,
      jsonb_build_object(
        'permission_code', v_revoked_permission.permission_code,
        'active', true
      ),
      jsonb_build_object(
        'permission_code', v_revoked_permission.permission_code,
        'active', false,
        'source', 'professional_lifecycle'
      )
    );
  end loop;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function private.invalidate_professional_access()
  from public, anon, authenticated;

create trigger professionals_invalidate_access
before update of user_id, active or delete
on public.professionals
for each row execute function private.invalidate_professional_access();

-- Repair the transition window after the original Migration 1. This is
-- forward-only and does not move or delete any existing link.
with inserted_links as (
  insert into public.professional_units (
    organization_id,
    professional_id,
    unit_id,
    active
  )
  select
    p.organization_id,
    p.id,
    u.id,
    true
  from public.professionals p
  join public.units u
    on u.organization_id = p.organization_id
   and u.is_default
   and u.active
  where not exists (
    select 1
    from public.professional_units pu
    where pu.organization_id = p.organization_id
      and pu.professional_id = p.id
      and pu.active
  )
  on conflict (organization_id, professional_id, unit_id)
  do update set active = true
  returning organization_id, professional_id, unit_id
)
insert into public.unit_access_audit_events (
  organization_id,
  unit_id,
  event_type,
  actor_kind,
  professional_id,
  after_state
)
select
  i.organization_id,
  i.unit_id,
  'professional_unit_changed',
  'system',
  i.professional_id,
  jsonb_build_object(
    'professional_id', i.professional_id,
    'unit_id', i.unit_id,
    'active', true,
    'source', 'onda0_forward_fix'
  )
from inserted_links i;

-- Appointments are the first operational fact that depends on
-- professional_units. Validate after the existing default-fill trigger has
-- resolved unit_id; the trigger name preserves that ordering.
create or replace function private.validate_appointment_professional_unit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not exists (
    select 1
    from public.units u
    join public.professional_units pu
      on pu.organization_id = u.organization_id
     and pu.unit_id = u.id
     and pu.professional_id = new.professional_id
     and pu.active
    where u.organization_id = new.organization_id
      and u.id = new.unit_id
      and u.active
  ) then
    raise exception 'professional must have an active link to the appointment unit'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_appointment_professional_unit()
  from public, anon, authenticated;

create trigger appointments_validate_professional_unit
before insert or update of organization_id, unit_id, professional_id
on public.appointments
for each row execute function private.validate_appointment_professional_unit();

-- RLS helpers keep the policy expressions small while resolving authorization
-- from the current authenticated membership on every statement. They expose
-- no data and are the only new EXECUTE privileges; fact tables remain without
-- grants to anon/authenticated in the persisted schema.
create or replace function private.can_access_fact_unit(
  p_organization_id uuid,
  p_unit_id uuid,
  p_organization_wide_roles text[],
  p_unit_scoped_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.memberships m
    join public.organizations o
      on o.id = m.organization_id
     and o.active
    where m.organization_id = p_organization_id
      and m.user_id = (select auth.uid())
      and m.active
      and (
        m.role = any(p_organization_wide_roles)
        or (
          m.role = any(p_unit_scoped_roles)
          and m.unit_id = p_unit_id
        )
      )
  );
$$;

create or replace function private.can_read_appointment(
  p_organization_id uuid,
  p_unit_id uuid,
  p_professional_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
    from public.memberships m
    join public.organizations o
      on o.id = m.organization_id
     and o.active
    where m.organization_id = p_organization_id
      and m.user_id = (select auth.uid())
      and m.active
      and (
        m.role in ('owner', 'admin', 'manager')
        or (m.role = 'reception' and m.unit_id = p_unit_id)
        or (
          m.role = 'professional'
          and m.unit_id = p_unit_id
          and exists (
            select 1
            from public.professionals self_professional
            join public.professional_units pu
              on pu.organization_id = self_professional.organization_id
             and pu.professional_id = self_professional.id
             and pu.unit_id = p_unit_id
             and pu.active
            where self_professional.organization_id = p_organization_id
              and self_professional.user_id = m.user_id
              and (
                self_professional.id = p_professional_id
                or exists (
                  select 1
                  from public.membership_permissions mp
                  where mp.organization_id = m.organization_id
                    and mp.user_id = m.user_id
                    and mp.permission_code = 'schedule:view_all'
                    and mp.revoked_at is null
                )
              )
          )
        )
      )
  );
$$;

revoke all on function private.can_access_fact_unit(uuid, uuid, text[], text[])
  from public, anon;
revoke all on function private.can_read_appointment(uuid, uuid, uuid)
  from public, anon;
grant execute on function private.can_access_fact_unit(uuid, uuid, text[], text[])
  to authenticated;
grant execute on function private.can_read_appointment(uuid, uuid, uuid)
  to authenticated;

drop policy units_select on public.units;
create policy units_select
on public.units
for select
to authenticated
using (
  private.can_access_fact_unit(
    organization_id,
    id,
    array['owner', 'admin', 'manager'],
    array['reception', 'professional']
  )
);

drop policy professional_units_select on public.professional_units;
create policy professional_units_select
on public.professional_units
for select
to authenticated
using (
  private.can_read_appointment(
    organization_id,
    unit_id,
    professional_id
  )
);

drop policy appointments_select on public.appointments;
create policy appointments_select
on public.appointments
for select
to authenticated
using (
  private.can_read_appointment(
    organization_id,
    unit_id,
    professional_id
  )
);

drop policy appointments_insert on public.appointments;
create policy appointments_insert
on public.appointments
for insert
to authenticated
with check (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception']
  )
);

drop policy appointments_update on public.appointments;
create policy appointments_update
on public.appointments
for update
to authenticated
using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception']
  )
)
with check (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception']
  )
);

drop policy appointments_delete on public.appointments;
create policy appointments_delete
on public.appointments
for delete
to authenticated
using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception']
  )
);

drop policy orders_select on public.orders;
create policy orders_select
on public.orders
for select
to authenticated
using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception']
  )
);

drop policy order_items_select on public.order_items;
create policy order_items_select
on public.order_items
for select
to authenticated
using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception']
  )
);

drop policy payments_select on public.payments;
create policy payments_select
on public.payments
for select
to authenticated
using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array['reception']
  )
);

drop policy inventory_movements_select on public.inventory_movements;
create policy inventory_movements_select
on public.inventory_movements
for select
to authenticated
using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array[]::text[]
  )
);

drop policy cash_entries_select on public.cash_entries;
create policy cash_entries_select
on public.cash_entries
for select
to authenticated
using (
  private.can_access_fact_unit(
    organization_id,
    unit_id,
    array['owner', 'admin', 'manager'],
    array[]::text[]
  )
);

-- ============================================================================
-- Server-side topology and permission commands.
-- Public signatures are backend APIs only: no anon/authenticated EXECUTE.
-- ============================================================================

create or replace function private.enforce_exactly_one_active_default_unit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_organization_id uuid := coalesce(new.organization_id, old.organization_id);
  v_default_count integer;
begin
  if current_setting('kortex.default_unit_transition', true) = 'on' then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  -- Cascading organization deletion has no surviving topology to protect.
  if not exists (
    select 1
    from public.organizations o
    where o.id = v_organization_id
  ) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  select count(*)::integer
    into v_default_count
  from public.units u
  where u.organization_id = v_organization_id
    and u.active
    and u.is_default;

  if v_default_count <> 1 then
    raise exception 'organization must have exactly one active default unit'
      using errcode = '23514';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists units_exactly_one_active_default
  on public.units;
create trigger units_exactly_one_active_default
after insert or update or delete
on public.units
for each row
execute function private.enforce_exactly_one_active_default_unit();

create or replace function public.unit_create(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_name text
)
returns public.units
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_unit public.units;
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin']
  ) then
    raise exception 'owner or admin permission required' using errcode = '42501';
  end if;

  if p_name is null or length(trim(p_name)) not between 2 and 120 then
    raise exception 'unit name must contain between 2 and 120 characters'
      using errcode = '22023';
  end if;

  insert into public.units (
    organization_id,
    name,
    timezone,
    active,
    is_default,
    created_by,
    updated_by
  )
  values (
    p_organization_id,
    trim(p_name),
    'America/Sao_Paulo',
    true,
    false,
    p_actor_user_id,
    p_actor_user_id
  )
  returning * into v_unit;

  insert into public.unit_access_audit_events (
    organization_id,
    unit_id,
    event_type,
    actor_kind,
    actor_user_id,
    after_state
  )
  values (
    p_organization_id,
    v_unit.id,
    'unit_created',
    'user',
    p_actor_user_id,
    jsonb_build_object(
      'unit_id', v_unit.id,
      'active', true,
      'is_default', false,
      'timezone', v_unit.timezone
    )
  );

  return v_unit;
end;
$$;

revoke all on function public.unit_create(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.unit_create(uuid, uuid, text)
  to service_role;

create or replace function public.set_default_unit(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_unit_id uuid
)
returns public.units
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_previous_default_id uuid;
  v_unit public.units;
  v_previous_transition_setting text := current_setting(
    'kortex.default_unit_transition',
    true
  );
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin']
  ) then
    raise exception 'owner or admin permission required' using errcode = '42501';
  end if;

  select *
    into v_unit
  from public.units u
  where u.organization_id = p_organization_id
    and u.id = p_unit_id
  for update;
  if not found then
    raise exception 'unit not found in organization' using errcode = 'P0002';
  end if;
  if not v_unit.active then
    raise exception 'default unit must be active' using errcode = '23514';
  end if;

  select u.id
    into v_previous_default_id
  from public.units u
  where u.organization_id = p_organization_id
    and u.active
    and u.is_default
  for update;

  if v_previous_default_id = p_unit_id then
    return v_unit;
  end if;

  perform set_config('kortex.default_unit_transition', 'on', true);

  if v_previous_default_id is not null then
    update public.units
    set is_default = false,
        updated_by = p_actor_user_id
    where organization_id = p_organization_id
      and id = v_previous_default_id;
  end if;

  update public.units
  set is_default = true,
      updated_by = p_actor_user_id
  where organization_id = p_organization_id
    and id = p_unit_id
  returning * into v_unit;

  perform set_config(
    'kortex.default_unit_transition',
    coalesce(v_previous_transition_setting, ''),
    true
  );

  if (
    select count(*) <> 1
    from public.units u
    where u.organization_id = p_organization_id
      and u.active
      and u.is_default
  ) then
    raise exception 'organization must have exactly one active default unit'
      using errcode = '23514';
  end if;

  insert into public.unit_access_audit_events (
    organization_id,
    unit_id,
    event_type,
    actor_kind,
    actor_user_id,
    before_state,
    after_state
  )
  values (
    p_organization_id,
    p_unit_id,
    'default_changed',
    'user',
    p_actor_user_id,
    jsonb_build_object('default_unit_id', v_previous_default_id),
    jsonb_build_object('default_unit_id', p_unit_id)
  );

  return v_unit;
end;
$$;

revoke all on function public.set_default_unit(uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.set_default_unit(uuid, uuid, uuid)
  to service_role;

create or replace function public.deactivate_unit(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_unit_id uuid
)
returns public.units
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_unit public.units;
  v_active_count integer;
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin']
  ) then
    raise exception 'owner or admin permission required' using errcode = '42501';
  end if;

  select *
    into v_unit
  from public.units u
  where u.organization_id = p_organization_id
    and u.id = p_unit_id
  for update;
  if not found then
    raise exception 'unit not found in organization' using errcode = 'P0002';
  end if;
  if not v_unit.active then
    raise exception 'unit is already inactive' using errcode = '23514';
  end if;
  if v_unit.is_default then
    raise exception 'default unit cannot be deactivated' using errcode = '23514';
  end if;

  select count(*)::integer
    into v_active_count
  from public.units u
  where u.organization_id = p_organization_id
    and u.active;
  if v_active_count <= 1 then
    raise exception 'organization must retain an active unit' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.memberships m
    where m.organization_id = p_organization_id
      and m.unit_id = p_unit_id
      and m.active
  ) then
    raise exception 'unit has active scoped memberships' using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.professional_units pu
    where pu.organization_id = p_organization_id
      and pu.unit_id = p_unit_id
      and pu.active
  ) then
    raise exception 'unit has active professional links' using errcode = '23514';
  end if;

  update public.units
  set active = false,
      updated_by = p_actor_user_id
  where organization_id = p_organization_id
    and id = p_unit_id
  returning * into v_unit;

  insert into public.unit_access_audit_events (
    organization_id,
    unit_id,
    event_type,
    actor_kind,
    actor_user_id,
    before_state,
    after_state
  )
  values (
    p_organization_id,
    p_unit_id,
    'unit_deactivated',
    'user',
    p_actor_user_id,
    jsonb_build_object('active', true, 'is_default', false),
    jsonb_build_object('active', false, 'is_default', false)
  );

  return v_unit;
end;
$$;

revoke all on function public.deactivate_unit(uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.deactivate_unit(uuid, uuid, uuid)
  to service_role;

create or replace function public.professional_unit_assign(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_professional_id uuid,
  p_unit_id uuid
)
returns public.professional_units
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_link public.professional_units;
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin', 'manager']
  ) then
    raise exception 'unit assignment permission required' using errcode = '42501';
  end if;

  perform 1
  from public.professionals p
  where p.organization_id = p_organization_id
    and p.id = p_professional_id
    and p.active
  for update;
  if not found then
    raise exception 'active professional not found in organization'
      using errcode = 'P0002';
  end if;

  perform 1
  from public.units u
  where u.organization_id = p_organization_id
    and u.id = p_unit_id
    and u.active
  for update;
  if not found then
    if exists (
      select 1
      from public.units u
      where u.organization_id = p_organization_id
        and u.id = p_unit_id
    ) then
      raise exception 'unit is inactive' using errcode = '23514';
    end if;
    raise exception 'unit not found in organization' using errcode = 'P0002';
  end if;

  select *
    into v_link
  from public.professional_units pu
  where pu.organization_id = p_organization_id
    and pu.professional_id = p_professional_id
    and pu.unit_id = p_unit_id
    and pu.active
  for update;
  if found then
    return v_link;
  end if;

  insert into public.professional_units (
    organization_id,
    professional_id,
    unit_id,
    active,
    created_by,
    updated_by
  )
  values (
    p_organization_id,
    p_professional_id,
    p_unit_id,
    true,
    p_actor_user_id,
    p_actor_user_id
  )
  on conflict (organization_id, professional_id, unit_id)
  do update
  set active = true,
      updated_by = excluded.updated_by
  returning * into v_link;

  insert into public.unit_access_audit_events (
    organization_id,
    unit_id,
    event_type,
    actor_kind,
    actor_user_id,
    professional_id,
    after_state
  )
  values (
    p_organization_id,
    p_unit_id,
    'professional_unit_changed',
    'user',
    p_actor_user_id,
    p_professional_id,
    jsonb_build_object(
      'professional_id', p_professional_id,
      'unit_id', p_unit_id,
      'active', true,
      'action', 'assigned'
    )
  );

  return v_link;
end;
$$;

revoke all on function public.professional_unit_assign(uuid, uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.professional_unit_assign(uuid, uuid, uuid, uuid)
  to service_role;

create or replace function public.professional_unit_revoke(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_professional_id uuid,
  p_unit_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_previous_actor_setting text := current_setting(
    'kortex.actor_user_id',
    true
  );
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin', 'manager']
  ) then
    raise exception 'unit assignment permission required' using errcode = '42501';
  end if;

  perform 1
  from public.units u
  where u.organization_id = p_organization_id
    and u.id = p_unit_id
    and u.active
  for update;
  if not found then
    if exists (
      select 1
      from public.units u
      where u.organization_id = p_organization_id
        and u.id = p_unit_id
    ) then
      raise exception 'unit is inactive' using errcode = '23514';
    end if;
    raise exception 'unit not found in organization' using errcode = 'P0002';
  end if;

  perform 1
  from public.professional_units pu
  where pu.organization_id = p_organization_id
    and pu.professional_id = p_professional_id
    and pu.unit_id = p_unit_id
    and pu.active
  for update;
  if not found then
    raise exception 'active professional-unit link not found'
      using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.professionals p
    join public.memberships m
      on m.organization_id = p.organization_id
     and m.user_id = p.user_id
     and m.active
     and m.role = 'professional'
     and m.unit_id = p_unit_id
    where p.organization_id = p_organization_id
      and p.id = p_professional_id
  ) then
    raise exception 'link is required by an active professional membership'
      using errcode = '23514';
  end if;

  perform set_config(
    'kortex.actor_user_id',
    p_actor_user_id::text,
    true
  );

  delete from public.professional_units
  where organization_id = p_organization_id
    and professional_id = p_professional_id
    and unit_id = p_unit_id;

  perform set_config(
    'kortex.actor_user_id',
    coalesce(v_previous_actor_setting, ''),
    true
  );

  return true;
end;
$$;

revoke all on function public.professional_unit_revoke(uuid, uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.professional_unit_revoke(uuid, uuid, uuid, uuid)
  to service_role;

create or replace function public.professional_update(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_professional_id uuid,
  p_patch jsonb
)
returns public.professionals
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_professional public.professionals;
  v_name text;
  v_user_id uuid;
  v_active boolean;
  v_previous_actor_setting text := current_setting(
    'kortex.actor_user_id',
    true
  );
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin', 'manager']
  ) then
    raise exception 'professional update permission required'
      using errcode = '42501';
  end if;

  if p_patch is null
    or pg_catalog.jsonb_typeof(p_patch) <> 'object'
    or p_patch = '{}'::jsonb
    or exists (
      select 1
      from pg_catalog.jsonb_object_keys(p_patch) as keys(key)
      where keys.key not in ('name', 'user_id', 'active')
    )
  then
    raise exception 'invalid professional patch' using errcode = '22023';
  end if;

  select *
    into v_professional
  from public.professionals p
  where p.organization_id = p_organization_id
    and p.id = p_professional_id
  for update;
  if not found then
    raise exception 'professional not found in organization'
      using errcode = 'P0002';
  end if;

  v_name := v_professional.name;
  v_user_id := v_professional.user_id;
  v_active := v_professional.active;

  if p_patch ? 'name' then
    if pg_catalog.jsonb_typeof(p_patch -> 'name') <> 'string'
      or length(trim(p_patch ->> 'name')) not between 1 and 160
    then
      raise exception 'professional name must contain between 1 and 160 characters'
        using errcode = '22023';
    end if;
    v_name := trim(p_patch ->> 'name');
  end if;

  if p_patch ? 'active' then
    if pg_catalog.jsonb_typeof(p_patch -> 'active') <> 'boolean' then
      raise exception 'professional active flag must be boolean'
        using errcode = '22023';
    end if;
    v_active := (p_patch ->> 'active')::boolean;
  end if;

  if p_patch ? 'user_id' then
    if pg_catalog.jsonb_typeof(p_patch -> 'user_id') = 'null' then
      v_user_id := null;
    elsif pg_catalog.jsonb_typeof(p_patch -> 'user_id') = 'string' then
      begin
        v_user_id := (p_patch ->> 'user_id')::uuid;
      exception
        when invalid_text_representation then
          raise exception 'professional user_id must be a uuid or null'
            using errcode = '22023';
      end;
    else
      raise exception 'professional user_id must be a uuid or null'
        using errcode = '22023';
    end if;

    if v_user_id is not null and not exists (
      select 1
      from public.memberships m
      where m.organization_id = p_organization_id
        and m.user_id = v_user_id
    ) then
      raise exception 'professional user membership not found'
        using errcode = 'P0002';
    end if;
  end if;

  perform set_config(
    'kortex.actor_user_id',
    p_actor_user_id::text,
    true
  );

  update public.professionals
  set name = v_name,
      user_id = v_user_id,
      active = v_active
  where organization_id = p_organization_id
    and id = p_professional_id
  returning * into v_professional;

  perform set_config(
    'kortex.actor_user_id',
    coalesce(v_previous_actor_setting, ''),
    true
  );

  return v_professional;
end;
$$;

revoke all on function public.professional_update(uuid, uuid, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.professional_update(uuid, uuid, uuid, jsonb)
  to service_role;

create or replace function public.professional_delete(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_professional_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_previous_actor_setting text := current_setting(
    'kortex.actor_user_id',
    true
  );
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin']
  ) then
    raise exception 'owner or admin permission required' using errcode = '42501';
  end if;

  perform 1
  from public.professionals p
  where p.organization_id = p_organization_id
    and p.id = p_professional_id
  for update;
  if not found then
    raise exception 'professional not found in organization'
      using errcode = 'P0002';
  end if;

  perform set_config(
    'kortex.actor_user_id',
    p_actor_user_id::text,
    true
  );

  delete from public.professionals
  where organization_id = p_organization_id
    and id = p_professional_id;

  perform set_config(
    'kortex.actor_user_id',
    coalesce(v_previous_actor_setting, ''),
    true
  );

  return true;
end;
$$;

revoke all on function public.professional_delete(uuid, uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.professional_delete(uuid, uuid, uuid)
  to service_role;

create or replace function private.validate_active_membership_permission()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.revoked_at is null and not exists (
    select 1
    from public.memberships m
    join public.units u
      on u.organization_id = m.organization_id
     and u.id = m.unit_id
     and u.active
    join public.professionals p
      on p.organization_id = m.organization_id
     and p.user_id = m.user_id
     and p.active
    join public.professional_units pu
      on pu.organization_id = p.organization_id
     and pu.professional_id = p.id
     and pu.unit_id = m.unit_id
     and pu.active
    where m.organization_id = new.organization_id
      and m.user_id = new.user_id
      and m.active
      and m.role = 'professional'
  ) then
    raise exception 'active permission requires an active scoped professional membership'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_active_membership_permission()
  from public, anon, authenticated;

create trigger membership_permissions_validate_active_scope
before insert or update of organization_id, user_id, revoked_at
on public.membership_permissions
for each row execute function private.validate_active_membership_permission();

create or replace function public.membership_permission_grant(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_permission_code text
)
returns public.membership_permissions
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_membership public.memberships;
  v_permission public.membership_permissions;
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin']
  ) then
    raise exception 'owner or admin permission required' using errcode = '42501';
  end if;

  if p_permission_code not in ('schedule:view_all', 'clients:view_all') then
    raise exception 'invalid membership permission' using errcode = '22023';
  end if;

  select *
    into v_membership
  from public.memberships m
  where m.organization_id = p_organization_id
    and m.user_id = p_target_user_id
  for update;
  if not found then
    raise exception 'target membership not found' using errcode = 'P0002';
  end if;

  if not v_membership.active
     or v_membership.role <> 'professional'
     or v_membership.unit_id is null then
    raise exception 'permission requires an active scoped professional membership'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.units u
    join public.professionals p
      on p.organization_id = p_organization_id
     and p.user_id = p_target_user_id
     and p.active
    join public.professional_units pu
      on pu.organization_id = p.organization_id
     and pu.professional_id = p.id
     and pu.unit_id = u.id
     and pu.active
    where u.organization_id = p_organization_id
      and u.id = v_membership.unit_id
      and u.active
  ) then
    raise exception 'professional has no active link to membership unit'
      using errcode = '23514';
  end if;

  select *
    into v_permission
  from public.membership_permissions mp
  where mp.organization_id = p_organization_id
    and mp.user_id = p_target_user_id
    and mp.permission_code = p_permission_code
    and mp.revoked_at is null
  for update;

  if found then
    return v_permission;
  end if;

  insert into public.membership_permissions (
    organization_id,
    user_id,
    permission_code,
    granted_by
  )
  values (
    p_organization_id,
    p_target_user_id,
    p_permission_code,
    p_actor_user_id
  )
  returning * into v_permission;

  insert into public.unit_access_audit_events (
    organization_id,
    unit_id,
    event_type,
    actor_kind,
    actor_user_id,
    target_user_id,
    after_state
  )
  values (
    p_organization_id,
    v_membership.unit_id,
    'permission_granted',
    'user',
    p_actor_user_id,
    p_target_user_id,
    jsonb_build_object(
      'permission_code', p_permission_code,
      'active', true
    )
  );

  return v_permission;
end;
$$;

revoke all on function public.membership_permission_grant(uuid, uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.membership_permission_grant(uuid, uuid, uuid, text)
  to service_role;

create or replace function public.membership_permission_revoke(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_permission_code text
)
returns public.membership_permissions
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_permission public.membership_permissions;
  v_unit_id uuid;
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin']
  ) then
    raise exception 'owner or admin permission required' using errcode = '42501';
  end if;

  select m.unit_id
    into v_unit_id
  from public.memberships m
  where m.organization_id = p_organization_id
    and m.user_id = p_target_user_id
  for update;
  if not found then
    raise exception 'target membership not found' using errcode = 'P0002';
  end if;

  select *
    into v_permission
  from public.membership_permissions mp
  where mp.organization_id = p_organization_id
    and mp.user_id = p_target_user_id
    and mp.permission_code = p_permission_code
    and mp.revoked_at is null
  for update;
  if not found then
    raise exception 'active permission not found' using errcode = 'P0002';
  end if;

  update public.membership_permissions
  set revoked_by = p_actor_user_id,
      revoked_at = now()
  where id = v_permission.id
  returning * into v_permission;

  insert into public.unit_access_audit_events (
    organization_id,
    unit_id,
    event_type,
    actor_kind,
    actor_user_id,
    target_user_id,
    before_state,
    after_state
  )
  values (
    p_organization_id,
    v_unit_id,
    'permission_revoked',
    'user',
    p_actor_user_id,
    p_target_user_id,
    jsonb_build_object(
      'permission_code', p_permission_code,
      'active', true
    ),
    jsonb_build_object(
      'permission_code', p_permission_code,
      'active', false
    )
  );

  return v_permission;
end;
$$;

revoke all on function public.membership_permission_revoke(uuid, uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.membership_permission_revoke(uuid, uuid, uuid, text)
  to service_role;

create or replace function public.membership_scope_set(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_role text,
  p_unit_id uuid,
  p_active boolean default true
)
returns public.memberships
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_previous_membership public.memberships;
  v_membership public.memberships;
  v_had_membership boolean := false;
  v_scope_changed boolean;
  v_has_professional_unit_link boolean := false;
  v_revoked_permission record;
begin
  perform 1
  from public.organizations o
  where o.id = p_organization_id
    and o.active
  for update;
  if not found then
    raise exception 'organization not found or inactive' using errcode = 'P0002';
  end if;

  if not private.actor_has_role(
    p_organization_id,
    p_actor_user_id,
    array['owner', 'admin']
  ) then
    raise exception 'owner or admin permission required' using errcode = '42501';
  end if;

  if p_role not in (
    'owner',
    'admin',
    'manager',
    'reception',
    'professional'
  ) then
    raise exception 'invalid membership role' using errcode = '22023';
  end if;
  if p_active is null then
    raise exception 'membership active flag is required' using errcode = '22023';
  end if;
  if not exists (
    select 1
    from auth.users u
    where u.id = p_target_user_id
  ) then
    raise exception 'target user not found' using errcode = 'P0002';
  end if;

  if p_role in ('owner', 'admin', 'manager') then
    if p_unit_id is not null then
      raise exception 'organization-wide role must not have unit scope'
        using errcode = '22023';
    end if;
  else
    if p_unit_id is null then
      raise exception 'unit-scoped role requires an explicit unit'
        using errcode = '22023';
    end if;

    perform 1
    from public.units u
    where u.organization_id = p_organization_id
      and u.id = p_unit_id
      and u.active
    for update;
    if not found then
      if exists (
        select 1
        from public.units u
        where u.organization_id = p_organization_id
          and u.id = p_unit_id
      ) then
        raise exception 'membership unit is inactive' using errcode = '23514';
      end if;
      raise exception 'membership unit not found in organization'
        using errcode = 'P0002';
    end if;
  end if;

  if p_role = 'professional' and p_active then
    select exists (
      select 1
      from public.professionals p
      join public.professional_units pu
        on pu.organization_id = p.organization_id
       and pu.professional_id = p.id
       and pu.unit_id = p_unit_id
       and pu.active
      where p.organization_id = p_organization_id
        and p.user_id = p_target_user_id
        and p.active
    )
      into v_has_professional_unit_link;
  end if;

  select *
    into v_previous_membership
  from public.memberships m
  where m.organization_id = p_organization_id
    and m.user_id = p_target_user_id
  for update;
  v_had_membership := found;
  v_scope_changed := not v_had_membership
    or row(
      v_previous_membership.role,
      v_previous_membership.unit_id,
      v_previous_membership.active
    ) is distinct from row(p_role, p_unit_id, p_active);

  insert into public.memberships (
    organization_id,
    user_id,
    role,
    active,
    unit_id
  )
  values (
    p_organization_id,
    p_target_user_id,
    p_role,
    p_active,
    p_unit_id
  )
  on conflict (organization_id, user_id)
  do update
  set role = excluded.role,
      active = excluded.active,
      unit_id = excluded.unit_id
  returning * into v_membership;

  if p_role <> 'professional'
    or not p_active
    or not v_has_professional_unit_link
  then
    for v_revoked_permission in
      update public.membership_permissions
      set revoked_by = p_actor_user_id,
          revoked_at = now()
      where organization_id = p_organization_id
        and user_id = p_target_user_id
        and revoked_at is null
      returning permission_code
    loop
      insert into public.unit_access_audit_events (
        organization_id,
        unit_id,
        event_type,
        actor_kind,
        actor_user_id,
        target_user_id,
        before_state,
        after_state
      )
      values (
        p_organization_id,
        case
          when v_had_membership then v_previous_membership.unit_id
          else null
        end,
        'permission_revoked',
        'user',
        p_actor_user_id,
        p_target_user_id,
        jsonb_build_object(
          'permission_code', v_revoked_permission.permission_code,
          'active', true
        ),
        jsonb_build_object(
          'permission_code', v_revoked_permission.permission_code,
          'active', false,
          'source', 'membership_scope_set'
        )
      );
    end loop;
  end if;

  if v_scope_changed then
    insert into public.unit_access_audit_events (
      organization_id,
      unit_id,
      event_type,
      actor_kind,
      actor_user_id,
      target_user_id,
      before_state,
      after_state
    )
    values (
      p_organization_id,
      p_unit_id,
      'membership_scope_changed',
      'user',
      p_actor_user_id,
      p_target_user_id,
      case
        when v_had_membership then jsonb_build_object(
          'role', v_previous_membership.role,
          'unit_id', v_previous_membership.unit_id,
          'active', v_previous_membership.active
        )
        else null
      end,
      jsonb_build_object(
        'role', v_membership.role,
        'unit_id', v_membership.unit_id,
        'active', v_membership.active
      )
    );
  end if;

  return v_membership;
end;
$$;

revoke all on function public.membership_scope_set(
  uuid,
  uuid,
  uuid,
  text,
  uuid,
  boolean
) from public, anon, authenticated;
grant execute on function public.membership_scope_set(
  uuid,
  uuid,
  uuid,
  text,
  uuid,
  boolean
) to service_role;

-- The legacy command cannot express an explicit unit and bypasses permission
-- revocation/auditing. Keep its definition only for migration history, but
-- remove every executable production path.
revoke all on function public.membership_set(
  uuid,
  uuid,
  uuid,
  text,
  boolean
) from public, anon, authenticated, service_role;
