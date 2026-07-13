-- KortexOS technical MVP — greenfield baseline.
-- The SQL files supplied as references are intentionally not inherited.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'manager', 'reception', 'professional')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);
create index memberships_user_active_idx on public.memberships(user_id, organization_id) where active;

create or replace function private.touch_updated_at()
returns trigger language plpgsql set search_path = pg_catalog as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  insert into public.profiles(user_id, display_name)
  values (new.id, coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), split_part(coalesce(new.email, new.id::text), '@', 1)))
  on conflict (user_id) do nothing;
  return new;
end;
$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger auth_user_profile_created
after insert on auth.users
for each row execute function private.handle_new_user();

create or replace function private.is_member(p_organization_id uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.memberships m
    join public.organizations o on o.id = m.organization_id and o.active
    where m.organization_id = p_organization_id
      and m.user_id = (select auth.uid())
      and m.active
  );
$$;

create or replace function private.has_role(p_organization_id uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.memberships m
    join public.organizations o on o.id = m.organization_id and o.active
    where m.organization_id = p_organization_id
      and m.user_id = (select auth.uid())
      and m.active
      and m.role = any(p_roles)
  );
$$;
create or replace function private.has_membership_role(p_organization_id uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.memberships m
    where m.organization_id = p_organization_id
      and m.user_id = (select auth.uid())
      and m.active
      and m.role = any(p_roles)
  );
$$;
create or replace function private.actor_has_role(p_organization_id uuid, p_actor_user_id uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = pg_catalog, public as $$
  select exists (
    select 1 from public.memberships m
    join public.organizations o on o.id = m.organization_id and o.active
    where m.organization_id = p_organization_id
      and m.user_id = p_actor_user_id
      and m.active
      and m.role = any(p_roles)
  );
$$;
revoke all on function private.is_member(uuid) from public, anon;
revoke all on function private.has_role(uuid, text[]) from public, anon;
revoke all on function private.has_membership_role(uuid, text[]) from public, anon;
revoke all on function private.actor_has_role(uuid, uuid, text[]) from public, anon, authenticated;
grant execute on function private.is_member(uuid) to authenticated;
grant execute on function private.has_role(uuid, text[]) to authenticated;
grant execute on function private.has_membership_role(uuid, text[]) to authenticated;

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 160),
  phone text,
  email text,
  active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, created_by) references public.memberships(organization_id, user_id) on delete restrict
);

create table public.professionals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  user_id uuid,
  name text not null check (length(trim(name)) between 1 and 160),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, user_id),
  foreign key (organization_id, user_id) references public.memberships(organization_id, user_id) on delete restrict
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (length(trim(name)) between 1 and 160),
  price_cents bigint not null check (price_cents >= 0),
  duration_minutes integer not null check (duration_minutes between 5 and 1440),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  sku text not null,
  name text not null check (length(trim(name)) between 1 and 160),
  price_cents bigint not null check (price_cents >= 0),
  cost_cents bigint not null default 0 check (cost_cents >= 0),
  stock_on_hand integer not null default 0 check (stock_on_hand >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, sku)
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  client_id uuid not null,
  professional_id uuid not null,
  service_id uuid not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'scheduled' check (status in ('scheduled', 'confirmed', 'in_service', 'completed', 'cancelled', 'no_show')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at),
  unique (organization_id, id),
  foreign key (organization_id, client_id) references public.clients(organization_id, id),
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id),
  foreign key (organization_id, service_id) references public.services(organization_id, id),
  foreign key (organization_id, created_by) references public.memberships(organization_id, user_id) on delete restrict,
  exclude using gist (
    organization_id with =,
    professional_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status in ('scheduled', 'confirmed', 'in_service'))
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  client_id uuid,
  status text not null default 'closed' check (status in ('draft', 'closed', 'cancelled', 'refunded')),
  subtotal_cents bigint not null check (subtotal_cents >= 0),
  discount_cents bigint not null default 0 check (discount_cents >= 0),
  total_cents bigint not null check (total_cents >= 0 and total_cents = subtotal_cents - discount_cents),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  unique (organization_id, id),
  foreign key (organization_id, client_id) references public.clients(organization_id, id),
  foreign key (organization_id, created_by) references public.memberships(organization_id, user_id) on delete restrict
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  order_id uuid not null,
  kind text not null check (kind in ('service', 'product')),
  service_id uuid,
  product_id uuid,
  description text not null,
  quantity integer not null check (quantity > 0),
  unit_price_cents bigint not null check (unit_price_cents >= 0),
  total_cents bigint not null check (total_cents >= 0 and total_cents = unit_price_cents * quantity),
  check ((kind = 'service' and service_id is not null and product_id is null) or (kind = 'product' and product_id is not null and service_id is null)),
  foreign key (organization_id, order_id) references public.orders(organization_id, id) on delete restrict,
  foreign key (organization_id, service_id) references public.services(organization_id, id),
  foreign key (organization_id, product_id) references public.products(organization_id, id)
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  order_id uuid not null,
  method text not null check (method in ('cash', 'pix', 'debit_card', 'credit_card', 'other')),
  amount_cents bigint not null check (amount_cents > 0),
  created_at timestamptz not null default now(),
  foreign key (organization_id, order_id) references public.orders(organization_id, id) on delete restrict
);

create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  product_id uuid not null,
  order_id uuid,
  reason text not null check (reason in ('purchase', 'sale', 'adjustment', 'return')),
  quantity_delta integer not null check (quantity_delta <> 0),
  balance_after integer not null check (balance_after >= 0),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key (organization_id, product_id) references public.products(organization_id, id),
  foreign key (organization_id, order_id) references public.orders(organization_id, id),
  foreign key (organization_id, created_by) references public.memberships(organization_id, user_id) on delete restrict
);

create table public.cash_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  order_id uuid,
  kind text not null check (kind in ('sale', 'income', 'expense', 'refund')),
  amount_cents bigint not null check (amount_cents > 0),
  description text not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  foreign key (organization_id, order_id) references public.orders(organization_id, id),
  foreign key (organization_id, created_by) references public.memberships(organization_id, user_id) on delete restrict
);

create table private.idempotency_keys (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  key text not null check (length(key) between 8 and 200),
  request_hash text not null,
  response jsonb,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  primary key (organization_id, key)
);

create or replace function private.enforce_created_by()
returns trigger language plpgsql set search_path = pg_catalog as $$
declare v_user_id uuid := (select auth.uid());
begin
  if tg_op = 'INSERT' and v_user_id is not null then new.created_by := v_user_id;
  elsif tg_op = 'INSERT' and new.created_by is null then raise exception 'created_by is required' using errcode = '23502';
  elsif new.created_by <> old.created_by then raise exception 'created_by is immutable' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_created_by() from public, anon, authenticated;
create trigger clients_enforce_created_by before insert or update on public.clients for each row execute function private.enforce_created_by();
create trigger appointments_enforce_created_by before insert or update on public.appointments for each row execute function private.enforce_created_by();

create or replace function private.require_active_owner()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_organization_id uuid := old.organization_id;
begin
  perform 1 from public.organizations where id = v_organization_id for update;
  if (tg_op = 'DELETE' and old.role = 'owner' and old.active)
     or (tg_op = 'UPDATE' and old.role = 'owner' and old.active and (new.role <> 'owner' or not new.active)) then
    if not exists (
      select 1 from public.memberships m
      where m.organization_id = v_organization_id
        and m.role = 'owner' and m.active
        and m.user_id <> old.user_id
    ) then
      raise exception 'organization must retain an active owner' using errcode = '23514';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
revoke all on function private.require_active_owner() from public, anon, authenticated;
create trigger memberships_require_owner
before update or delete on public.memberships
for each row execute function private.require_active_owner();

do $$
declare t text;
begin
  foreach t in array array['organizations','profiles','memberships','clients','professionals','services','products','appointments','orders','order_items','payments','inventory_movements','cash_entries'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

create policy organizations_select on public.organizations for select to authenticated using (private.is_member(id));
create policy organizations_update on public.organizations for update to authenticated using (private.has_membership_role(id, array['owner','admin'])) with check (private.has_membership_role(id, array['owner','admin']));
create policy profiles_select_self on public.profiles for select to authenticated using ((select auth.uid()) = user_id);
create policy profiles_update_self on public.profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy memberships_select on public.memberships for select to authenticated using (private.is_member(organization_id));
create policy memberships_insert on public.memberships for insert to authenticated with check (private.has_membership_role(organization_id, array['owner']));
create policy memberships_update on public.memberships for update to authenticated using (private.has_membership_role(organization_id, array['owner'])) with check (private.has_membership_role(organization_id, array['owner']));

create policy clients_select on public.clients for select to authenticated using (private.has_role(organization_id, array['owner','admin','manager','reception']));
create policy professionals_select on public.professionals for select to authenticated using (private.is_member(organization_id));
create policy services_select on public.services for select to authenticated using (private.is_member(organization_id));
create policy products_select on public.products for select to authenticated using (private.is_member(organization_id));
create policy appointments_select on public.appointments for select to authenticated using (private.is_member(organization_id));
create policy orders_select on public.orders for select to authenticated using (private.has_role(organization_id, array['owner','admin','manager','reception']));
create policy order_items_select on public.order_items for select to authenticated using (private.has_role(organization_id, array['owner','admin','manager','reception']));
create policy payments_select on public.payments for select to authenticated using (private.has_role(organization_id, array['owner','admin','manager','reception']));
create policy inventory_movements_select on public.inventory_movements for select to authenticated using (private.has_role(organization_id, array['owner','admin','manager']));
create policy cash_entries_select on public.cash_entries for select to authenticated using (private.has_role(organization_id, array['owner','admin','manager']));

create policy clients_insert on public.clients for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager','reception']));
create policy clients_update on public.clients for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager','reception'])) with check (private.has_role(organization_id, array['owner','admin','manager','reception']));
create policy clients_delete on public.clients for delete to authenticated using (private.has_role(organization_id, array['owner','admin','manager']));
create policy professionals_insert on public.professionals for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy professionals_update on public.professionals for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy professionals_delete on public.professionals for delete to authenticated using (private.has_role(organization_id, array['owner','admin']));
create policy services_insert on public.services for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy services_update on public.services for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy services_delete on public.services for delete to authenticated using (private.has_role(organization_id, array['owner','admin']));
create policy products_insert on public.products for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy products_update on public.products for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy products_delete on public.products for delete to authenticated using (private.has_role(organization_id, array['owner','admin']));
create policy appointments_insert on public.appointments for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager','reception']));
create policy appointments_update on public.appointments for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager','reception'])) with check (private.has_role(organization_id, array['owner','admin','manager','reception']));
create policy appointments_delete on public.appointments for delete to authenticated using (private.has_role(organization_id, array['owner','admin','manager','reception']));

create trigger organizations_touch before update on public.organizations for each row execute function private.touch_updated_at();
create trigger profiles_touch before update on public.profiles for each row execute function private.touch_updated_at();
create trigger clients_touch before update on public.clients for each row execute function private.touch_updated_at();
create trigger professionals_touch before update on public.professionals for each row execute function private.touch_updated_at();
create trigger services_touch before update on public.services for each row execute function private.touch_updated_at();
create trigger products_touch before update on public.products for each row execute function private.touch_updated_at();
create trigger appointments_touch before update on public.appointments for each row execute function private.touch_updated_at();

create or replace function public.create_organization(p_actor_user_id uuid, p_name text, p_slug text)
returns public.organizations language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_org public.organizations;
begin
  if p_actor_user_id is null or not exists (select 1 from auth.users u where u.id = p_actor_user_id) then
    raise exception 'valid actor required' using errcode = '28000';
  end if;
  insert into public.organizations(name, slug) values (trim(p_name), lower(trim(p_slug))) returning * into v_org;
  insert into public.memberships(organization_id, user_id, role) values (v_org.id, p_actor_user_id, 'owner');
  return v_org;
end;
$$;
revoke all on function public.create_organization(uuid, text, text) from public, anon, authenticated;

revoke all on all tables in schema public from anon, authenticated;

create or replace function public.checkout_close(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_hash text := encode(digest(p_payload::text, 'sha256'), 'hex');
  v_existing private.idempotency_keys%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_item jsonb;
  v_payment jsonb;
  v_kind text;
  v_ref_id uuid;
  v_quantity integer;
  v_unit_price bigint;
  v_description text;
  v_stock integer;
  v_subtotal bigint := 0;
  v_paid bigint := 0;
  v_amount bigint;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager','reception']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload -> 'items') <> 'array' or jsonb_array_length(p_payload -> 'items') = 0 then
    raise exception 'items must be a non-empty array' using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload -> 'payments') <> 'array' or jsonb_array_length(p_payload -> 'payments') = 0 then
    raise exception 'payments must be a non-empty array' using errcode = '22023';
  end if;

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, v_user_id)
  on conflict (organization_id, key) do nothing;

  select * into v_existing
  from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;

  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then
    return v_existing.response;
  end if;

  insert into public.orders(
    id, organization_id, client_id, status,
    subtotal_cents, discount_cents, total_cents,
    created_by, closed_at
  ) values (
    v_order_id,
    p_organization_id,
    nullif(p_payload ->> 'client_id', '')::uuid,
    'closed', 0, 0, 0, v_user_id, now()
  );

  for v_item in select value from jsonb_array_elements(p_payload -> 'items') loop
    v_kind := v_item ->> 'kind';
    v_ref_id := (v_item ->> 'id')::uuid;
    v_quantity := (v_item ->> 'quantity')::integer;
    if v_quantity <= 0 then raise exception 'quantity must be positive' using errcode = '22023'; end if;

    if v_kind = 'product' then
      select p.price_cents, p.name, p.stock_on_hand
      into v_unit_price, v_description, v_stock
      from public.products p
      where p.organization_id = p_organization_id and p.id = v_ref_id and p.active
      for update;
      if not found then raise exception 'active product not found' using errcode = 'P0002'; end if;
      if v_stock < v_quantity then raise exception 'insufficient stock' using errcode = 'P0001'; end if;

      update public.products
      set stock_on_hand = stock_on_hand - v_quantity
      where organization_id = p_organization_id and id = v_ref_id
      returning stock_on_hand into v_stock;

      insert into public.inventory_movements(
        organization_id, product_id, order_id, reason,
        quantity_delta, balance_after, created_by
      ) values (
        p_organization_id, v_ref_id, v_order_id, 'sale',
        -v_quantity, v_stock, v_user_id
      );
    elsif v_kind = 'service' then
      select s.price_cents, s.name
      into v_unit_price, v_description
      from public.services s
      where s.organization_id = p_organization_id and s.id = v_ref_id and s.active;
      if not found then raise exception 'active service not found' using errcode = 'P0002'; end if;
    else
      raise exception 'unsupported item kind' using errcode = '22023';
    end if;

    insert into public.order_items(
      organization_id, order_id, kind, service_id, product_id,
      description, quantity, unit_price_cents, total_cents
    ) values (
      p_organization_id, v_order_id, v_kind,
      case when v_kind = 'service' then v_ref_id end,
      case when v_kind = 'product' then v_ref_id end,
      v_description, v_quantity, v_unit_price, v_unit_price * v_quantity
    );
    v_subtotal := v_subtotal + (v_unit_price * v_quantity);
  end loop;

  for v_payment in select value from jsonb_array_elements(p_payload -> 'payments') loop
    v_amount := (v_payment ->> 'amount_cents')::bigint;
    if v_amount <= 0 then raise exception 'payment must be positive' using errcode = '22023'; end if;
    insert into public.payments(organization_id, order_id, method, amount_cents)
    values (p_organization_id, v_order_id, v_payment ->> 'method', v_amount);
    v_paid := v_paid + v_amount;
  end loop;

  if v_paid <> v_subtotal then
    raise exception 'payments do not reconcile with order total' using errcode = '22023';
  end if;

  update public.orders
  set subtotal_cents = v_subtotal, total_cents = v_subtotal
  where organization_id = p_organization_id and id = v_order_id;

  insert into public.cash_entries(
    organization_id, order_id, kind, amount_cents, description, created_by
  ) values (
    p_organization_id, v_order_id, 'sale', v_subtotal, 'Checkout', v_user_id
  );

  v_response := jsonb_build_object(
    'order_id', v_order_id,
    'organization_id', p_organization_id,
    'total_cents', v_subtotal,
    'status', 'closed'
  );
  update private.idempotency_keys
  set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;
revoke all on function public.checkout_close(uuid, uuid, text, jsonb) from public, anon, authenticated;

create or replace function public.inventory_adjust(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_idempotency_key text,
  p_product_id uuid,
  p_quantity_delta integer,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_user_id uuid := p_actor_user_id;
  v_payload jsonb := jsonb_build_object('product_id', p_product_id, 'quantity_delta', p_quantity_delta, 'reason', p_reason);
  v_hash text;
  v_existing private.idempotency_keys%rowtype;
  v_balance integer;
  v_response jsonb;
begin
  if not private.actor_has_role(p_organization_id, v_user_id, array['owner','admin','manager']) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;
  if p_idempotency_key is null or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'invalid idempotency key' using errcode = '22023';
  end if;
  if p_quantity_delta = 0 or p_reason not in ('purchase','adjustment','return')
     or (p_reason in ('purchase','return') and p_quantity_delta < 0) then
    raise exception 'invalid inventory adjustment' using errcode = '22023';
  end if;
  v_hash := encode(digest(v_payload::text, 'sha256'), 'hex');

  insert into private.idempotency_keys(organization_id, key, request_hash, created_by)
  values (p_organization_id, p_idempotency_key, v_hash, v_user_id)
  on conflict (organization_id, key) do nothing;
  select * into v_existing from private.idempotency_keys
  where organization_id = p_organization_id and key = p_idempotency_key
  for update;
  if v_existing.request_hash <> v_hash then
    raise exception 'idempotency key reused with different payload' using errcode = '22023';
  end if;
  if v_existing.response is not null then return v_existing.response; end if;

  select stock_on_hand into v_balance from public.products
  where organization_id = p_organization_id and id = p_product_id and active
  for update;
  if not found then raise exception 'active product not found' using errcode = 'P0002'; end if;
  v_balance := v_balance + p_quantity_delta;
  if v_balance < 0 then raise exception 'insufficient stock' using errcode = 'P0001'; end if;

  update public.products set stock_on_hand = v_balance
  where organization_id = p_organization_id and id = p_product_id;
  insert into public.inventory_movements(
    organization_id, product_id, reason, quantity_delta, balance_after, created_by
  ) values (
    p_organization_id, p_product_id, p_reason, p_quantity_delta, v_balance, v_user_id
  );

  v_response := jsonb_build_object(
    'organization_id', p_organization_id,
    'product_id', p_product_id,
    'stock_on_hand', v_balance
  );
  update private.idempotency_keys set response = v_response
  where organization_id = p_organization_id and key = p_idempotency_key;
  return v_response;
end;
$$;

create or replace function public.membership_set(
  p_organization_id uuid,
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_role text,
  p_active boolean default true
) returns public.memberships
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare v_membership public.memberships;
begin
  perform 1 from public.organizations where id = p_organization_id for update;
  if not found then raise exception 'organization not found' using errcode = 'P0002'; end if;
  if not private.actor_has_role(p_organization_id, p_actor_user_id, array['owner']) then
    raise exception 'owner permission required' using errcode = '42501';
  end if;
  if p_role not in ('owner','admin','manager','reception','professional') then
    raise exception 'invalid membership role' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users u where u.id = p_target_user_id) then
    raise exception 'target user not found' using errcode = 'P0002';
  end if;

  insert into public.memberships(organization_id, user_id, role, active)
  values (p_organization_id, p_target_user_id, p_role, p_active)
  on conflict (organization_id, user_id)
  do update set role = excluded.role, active = excluded.active
  returning * into v_membership;
  return v_membership;
end;
$$;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.create_organization(uuid, text, text) to service_role;
grant execute on function public.checkout_close(uuid, uuid, text, jsonb) to service_role;
grant execute on function public.inventory_adjust(uuid, uuid, text, uuid, integer, text) to service_role;
grant execute on function public.membership_set(uuid, uuid, uuid, text, boolean) to service_role;

alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
