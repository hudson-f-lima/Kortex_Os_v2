-- Fase 3.1 do roteiro de comissão (docs/PLANEJAMENTO_COMISSOES.md): fundação
-- de catálogo para a cascata de comissão (profissional > serviço > grupo).
-- Não toca checkout_close, order_items nem overrides por profissional —
-- isso é Fase 5.1, deliberadamente separada por mexer na RPC atômica.
--
-- Percentual é armazenado em pontos-base (10000 = 100,00%) e valor fixo em
-- centavos, na mesma coluna bigint `commission_value`/`default_commission_value`
-- — mesma disciplina de "nunca float para dinheiro" já usada em price_cents.

create table public.service_groups (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 160),
  default_commission_type text not null check (default_commission_type in ('percentage', 'fixed')),
  default_commission_value bigint not null check (default_commission_value >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, name),
  check (default_commission_type is distinct from 'percentage' or default_commission_value <= 10000)
);

-- service_group_id is NOT NULL: the commission cascade in
-- docs/PLANEJAMENTO_COMISSOES.md §4.1 only terminates correctly if every
-- service belongs to a group. Safe to add directly (no default needed)
-- because `supabase db reset` always replays this against an empty table.
alter table public.services
  add column service_group_id uuid not null,
  add column commission_type text check (commission_type in ('percentage', 'fixed')),
  add column commission_value bigint check (commission_value >= 0),
  add constraint services_commission_pair check (
    (commission_type is null and commission_value is null)
    or (commission_type is not null and commission_value is not null)
  ),
  add constraint services_commission_percentage_range check (
    commission_type is distinct from 'percentage' or commission_value <= 10000
  ),
  add constraint services_group_fk foreign key (organization_id, service_group_id)
    references public.service_groups(organization_id, id);

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 160),
  price_cents bigint not null check (price_cents >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id)
);

-- Composition rows: meaningless without their package (cascade), but a
-- service that is part of a package composition cannot be deleted out from
-- under it (restrict) — same rule already used for services referenced by
-- appointments/order_items.
create table public.package_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  package_id uuid not null,
  service_id uuid not null,
  quantity integer not null default 1 check (quantity > 0),
  unique (organization_id, package_id, service_id),
  foreign key (organization_id, package_id) references public.packages(organization_id, id) on delete cascade,
  foreign key (organization_id, service_id) references public.services(organization_id, id) on delete restrict
);

alter table public.service_groups enable row level security;
alter table public.packages enable row level security;
alter table public.package_items enable row level security;

-- Same shape as services/products: any active member reads, owner/admin/
-- manager writes, owner/admin deletes. Defense in depth only — the actual
-- API path runs as service_role (BYPASSRLS) and checks role explicitly in
-- Express/RPCs, same as every other business table.
create policy service_groups_select on public.service_groups for select to authenticated using (private.is_member(organization_id));
create policy service_groups_insert on public.service_groups for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy service_groups_update on public.service_groups for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy service_groups_delete on public.service_groups for delete to authenticated using (private.has_role(organization_id, array['owner','admin']));

create policy packages_select on public.packages for select to authenticated using (private.is_member(organization_id));
create policy packages_insert on public.packages for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy packages_update on public.packages for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy packages_delete on public.packages for delete to authenticated using (private.has_role(organization_id, array['owner','admin']));

create policy package_items_select on public.package_items for select to authenticated using (private.is_member(organization_id));
create policy package_items_insert on public.package_items for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy package_items_update on public.package_items for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy package_items_delete on public.package_items for delete to authenticated using (private.has_role(organization_id, array['owner','admin','manager']));

create trigger service_groups_touch before update on public.service_groups for each row execute function private.touch_updated_at();
create trigger packages_touch before update on public.packages for each row execute function private.touch_updated_at();

grant select, insert, update, delete on public.service_groups, public.packages, public.package_items to service_role;

-- Package composition is a multi-table mutation (package + package_items)
-- that must be atomic; per kortex-express-architect, that means a
-- transactional RPC, never sequential inserts compensated from Express.
-- Not idempotency-key protected: this is catalog management, not a
-- financial/stock command (same category as services/products, which have
-- no RPC at all — this only needs one because it spans two tables).
create or replace function public.create_package(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_package_id uuid := gen_random_uuid();
  v_name text;
  v_price_cents bigint;
  v_item jsonb;
  v_service_id uuid;
  v_quantity integer;
  v_seen_ids uuid[] := array[]::uuid[];
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;

  v_name := trim(p_payload ->> 'name');
  if v_name is null or length(v_name) not between 1 and 160 then
    raise exception 'invalid package name' using errcode = '22023';
  end if;
  v_price_cents := (p_payload ->> 'price_cents')::bigint;
  if v_price_cents is null or v_price_cents < 0 then
    raise exception 'invalid package price' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload -> 'items') <> 'array' or jsonb_array_length(p_payload -> 'items') = 0 then
    raise exception 'items must be a non-empty array' using errcode = '22023';
  end if;

  insert into public.packages(id, organization_id, name, price_cents)
  values (v_package_id, p_organization_id, v_name, v_price_cents);

  for v_item in select value from jsonb_array_elements(p_payload -> 'items') loop
    v_service_id := (v_item ->> 'service_id')::uuid;
    if v_service_id = any(v_seen_ids) then
      raise exception 'duplicate service in package items' using errcode = '22023';
    end if;
    v_seen_ids := array_append(v_seen_ids, v_service_id);
    v_quantity := coalesce((v_item ->> 'quantity')::integer, 1);
    if v_quantity <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;
    if not exists (
      select 1 from public.services s
      where s.organization_id = p_organization_id and s.id = v_service_id and s.active
    ) then
      raise exception 'active service not found' using errcode = 'P0002';
    end if;
    insert into public.package_items(organization_id, package_id, service_id, quantity)
    values (p_organization_id, v_package_id, v_service_id, v_quantity);
  end loop;

  return jsonb_build_object(
    'id', v_package_id,
    'organization_id', p_organization_id,
    'name', v_name,
    'price_cents', v_price_cents
  );
end;
$$;
revoke all on function public.create_package(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.create_package(uuid, uuid, jsonb) to service_role;

-- Partial patch, same semantics as the Express PATCH modules: only keys
-- present in the payload are touched. `items`, when present, replaces the
-- full composition (delete+reinsert in the same transaction) rather than
-- diffing — simplest correct semantics for "this is now the package".
create or replace function public.update_package(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_package_id uuid,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_name text;
  v_price_cents bigint;
  v_item jsonb;
  v_service_id uuid;
  v_quantity integer;
  v_seen_ids uuid[] := array[]::uuid[];
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if not exists (select 1 from public.packages where organization_id = p_organization_id and id = p_package_id) then
    raise exception 'package not found' using errcode = 'P0002';
  end if;

  if p_payload ? 'name' then
    v_name := trim(p_payload ->> 'name');
    if v_name is null or length(v_name) not between 1 and 160 then
      raise exception 'invalid package name' using errcode = '22023';
    end if;
    update public.packages set name = v_name where organization_id = p_organization_id and id = p_package_id;
  end if;

  if p_payload ? 'price_cents' then
    v_price_cents := (p_payload ->> 'price_cents')::bigint;
    if v_price_cents is null or v_price_cents < 0 then
      raise exception 'invalid package price' using errcode = '22023';
    end if;
    update public.packages set price_cents = v_price_cents where organization_id = p_organization_id and id = p_package_id;
  end if;

  if p_payload ? 'active' then
    update public.packages set active = (p_payload ->> 'active')::boolean
    where organization_id = p_organization_id and id = p_package_id;
  end if;

  if p_payload ? 'items' then
    if jsonb_typeof(p_payload -> 'items') <> 'array' or jsonb_array_length(p_payload -> 'items') = 0 then
      raise exception 'items must be a non-empty array' using errcode = '22023';
    end if;
    delete from public.package_items where organization_id = p_organization_id and package_id = p_package_id;
    for v_item in select value from jsonb_array_elements(p_payload -> 'items') loop
      v_service_id := (v_item ->> 'service_id')::uuid;
      if v_service_id = any(v_seen_ids) then
        raise exception 'duplicate service in package items' using errcode = '22023';
      end if;
      v_seen_ids := array_append(v_seen_ids, v_service_id);
      v_quantity := coalesce((v_item ->> 'quantity')::integer, 1);
      if v_quantity <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;
      if not exists (
        select 1 from public.services s
        where s.organization_id = p_organization_id and s.id = v_service_id and s.active
      ) then
        raise exception 'active service not found' using errcode = 'P0002';
      end if;
      insert into public.package_items(organization_id, package_id, service_id, quantity)
      values (p_organization_id, p_package_id, v_service_id, v_quantity);
    end loop;
  end if;

  select jsonb_build_object(
    'id', id, 'organization_id', organization_id, 'name', name,
    'price_cents', price_cents, 'active', active
  ) into v_response
  from public.packages where organization_id = p_organization_id and id = p_package_id;
  return v_response;
end;
$$;
revoke all on function public.update_package(uuid, uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.update_package(uuid, uuid, uuid, jsonb) to service_role;
