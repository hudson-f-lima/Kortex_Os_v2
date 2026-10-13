-- KortexOS 5.1.2 — Onda 0 (units): schema aditivo + backfill inline.
-- Implementa docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_DRAFT.md (DEC-31/DEC-32).
-- Escopo desta migration: tabelas novas, extensão de memberships, unit_id
-- nullable nos 6 fatos MVP, create_organization atualizada, backfill da(s)
-- organização(ões) existente(s) para sua unidade default (timezone fixa
-- America/Sao_Paulo — único tenant real hoje é o Salão Esperança), triggers
-- de default-fill. NOT NULL final, imutabilidade e VALIDATE CONSTRAINT ficam
-- para a migration de hardening seguinte — nenhum dado real ainda existe
-- para travar, e travar aqui tornaria qualquer correção forward-only.
-- Fora de escopo desta onda (ver Blueprint §1/§7): RPCs de gestão de unidade
-- (set_default_unit, deactivate_unit, assign/revoke), UI de seleção de
-- unidade, e reescrita de checkout_close/create_appointment/inventory_adjust
-- — o preenchimento de unit_id nos fatos é feito por trigger, não pelas RPCs.

-- ============================================================================
-- 1. units
-- ============================================================================

create table public.units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (length(trim(name)) between 2 and 120),
  timezone text not null,
  active boolean not null default true,
  is_default boolean not null default false,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_by uuid,
  updated_at timestamptz not null default now(),
  unique (organization_id, id)
);

create unique index units_one_default_active_idx on public.units(organization_id) where is_default and active;
create unique index units_name_unique_idx on public.units(organization_id, lower(trim(name)));
create index units_org_active_idx on public.units(organization_id, active);

create trigger units_touch before update on public.units for each row execute function private.touch_updated_at();

alter table public.units enable row level security;

create policy units_select on public.units for select to authenticated using (private.is_member(organization_id));
create policy units_insert on public.units for insert to authenticated with check (private.has_role(organization_id, array['owner', 'admin']));
create policy units_update on public.units for update to authenticated using (private.has_role(organization_id, array['owner', 'admin'])) with check (private.has_role(organization_id, array['owner', 'admin']));

-- ============================================================================
-- 2. professional_units (vínculo N:N profissional<->unidade)
-- ============================================================================

create table public.professional_units (
  organization_id uuid not null,
  professional_id uuid not null,
  unit_id uuid not null,
  active boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_by uuid,
  updated_at timestamptz not null default now(),
  primary key (organization_id, professional_id, unit_id),
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  foreign key (organization_id, unit_id) references public.units(organization_id, id) on delete restrict
);

create index professional_units_unit_idx on public.professional_units(organization_id, unit_id, active);
create index professional_units_professional_idx on public.professional_units(organization_id, professional_id, active);

create trigger professional_units_touch before update on public.professional_units for each row execute function private.touch_updated_at();

alter table public.professional_units enable row level security;

create policy professional_units_select on public.professional_units for select to authenticated using (private.is_member(organization_id));
create policy professional_units_insert on public.professional_units for insert to authenticated with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));
create policy professional_units_update on public.professional_units for update to authenticated using (private.has_role(organization_id, array['owner', 'admin', 'manager'])) with check (private.has_role(organization_id, array['owner', 'admin', 'manager']));

-- ============================================================================
-- 3. membership_permissions (allowlist tenant-safe, dormant até existir RPC
--    de concessão/revogação — schema aprovado nesta onda, uso em onda futura)
-- ============================================================================

create table public.membership_permissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  user_id uuid not null,
  permission_code text not null check (permission_code in ('schedule:view_all', 'clients:view_all')),
  granted_by uuid not null,
  granted_at timestamptz not null default now(),
  revoked_by uuid,
  revoked_at timestamptz,
  foreign key (organization_id, user_id) references public.memberships(organization_id, user_id) on delete restrict,
  check ((revoked_at is null) = (revoked_by is null))
);

create unique index membership_permissions_active_unique_idx on public.membership_permissions(organization_id, user_id, permission_code) where revoked_at is null;
create index membership_permissions_lookup_idx on public.membership_permissions(organization_id, user_id, permission_code) where revoked_at is null;

alter table public.membership_permissions enable row level security;

create policy membership_permissions_select on public.membership_permissions for select to authenticated using (private.has_role(organization_id, array['owner', 'admin']));
create policy membership_permissions_insert on public.membership_permissions for insert to authenticated with check (private.has_role(organization_id, array['owner', 'admin']));
create policy membership_permissions_update on public.membership_permissions for update to authenticated using (private.has_role(organization_id, array['owner', 'admin'])) with check (private.has_role(organization_id, array['owner', 'admin']));

-- ============================================================================
-- 4. unit_access_audit_events (append-only, sem grant de escrita direta —
--    só via funções security definer; leitura restrita a owner/admin)
-- ============================================================================

create table public.unit_access_audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  unit_id uuid,
  event_type text not null check (event_type in (
    'unit_created', 'unit_updated', 'unit_deactivated', 'default_changed',
    'professional_unit_changed', 'membership_scope_changed',
    'permission_granted', 'permission_revoked'
  )),
  actor_kind text not null check (actor_kind in ('user', 'system')),
  actor_user_id uuid,
  target_user_id uuid,
  professional_id uuid,
  before_state jsonb,
  after_state jsonb,
  created_at timestamptz not null default now(),
  check (actor_kind = 'system' or actor_user_id is not null),
  foreign key (organization_id, unit_id) references public.units(organization_id, id)
);

create index unit_access_audit_events_org_idx on public.unit_access_audit_events(organization_id, created_at desc);
create index unit_access_audit_events_unit_idx on public.unit_access_audit_events(organization_id, unit_id, created_at desc);

alter table public.unit_access_audit_events enable row level security;

create policy unit_access_audit_events_select on public.unit_access_audit_events for select to authenticated using (private.has_role(organization_id, array['owner', 'admin']));

-- ============================================================================
-- 5. memberships.unit_id — escopo híbrido
-- ============================================================================

alter table public.memberships add column unit_id uuid;
alter table public.memberships add constraint memberships_org_unit_fk foreign key (organization_id, unit_id) references public.units(organization_id, id);
create index memberships_unit_scope_idx on public.memberships(organization_id, unit_id, user_id) where active and unit_id is not null;

-- ============================================================================
-- 6. unit_id (nullable) nos 6 fatos MVP transacionais
-- ============================================================================

alter table public.appointments add column unit_id uuid;
alter table public.appointments add constraint appointments_org_unit_fk foreign key (organization_id, unit_id) references public.units(organization_id, id);

alter table public.orders add column unit_id uuid;
alter table public.orders add constraint orders_org_unit_fk foreign key (organization_id, unit_id) references public.units(organization_id, id);

alter table public.order_items add column unit_id uuid;
alter table public.order_items add constraint order_items_org_unit_fk foreign key (organization_id, unit_id) references public.units(organization_id, id);

alter table public.payments add column unit_id uuid;
alter table public.payments add constraint payments_org_unit_fk foreign key (organization_id, unit_id) references public.units(organization_id, id);

alter table public.inventory_movements add column unit_id uuid;
alter table public.inventory_movements add constraint inventory_movements_org_unit_fk foreign key (organization_id, unit_id) references public.units(organization_id, id);

alter table public.cash_entries add column unit_id uuid;
alter table public.cash_entries add constraint cash_entries_org_unit_fk foreign key (organization_id, unit_id) references public.units(organization_id, id);

-- ============================================================================
-- 7. Unidade default é um invariante de `organizations`, não de uma RPC
--    específica: um trigger AFTER INSERT garante que TODA organização nova
--    ganha sua unidade default, não importa o caminho de criação (RPC
--    create_organization, fixture de teste com insert direto, script futuro
--    de import). create_organization não precisa de nenhuma mudança —
--    assinatura e corpo permanecem exatamente como antes desta onda.
-- ============================================================================

create or replace function private.create_default_unit_for_organization()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_unit_id uuid;
begin
  insert into public.units(organization_id, name, timezone, active, is_default)
    values (new.id, new.name, 'America/Sao_Paulo', true, true)
    returning id into v_unit_id;
  insert into public.unit_access_audit_events(organization_id, unit_id, event_type, actor_kind, after_state)
    values (new.id, v_unit_id, 'unit_created', 'system', jsonb_build_object('is_default', true, 'active', true, 'source', 'organization_insert'));
  return new;
end;
$$;
revoke all on function private.create_default_unit_for_organization() from public, anon, authenticated;

create trigger organizations_create_default_unit
after insert on public.organizations
for each row execute function private.create_default_unit_for_organization();

-- ============================================================================
-- 8. Backfill — determinístico: hoje existe uma única organização real em
--    produção (Salão Esperança, DEC-26 item 7). Roda por organização para
--    ser correto também se mais de uma já existir localmente/em staging.
-- ============================================================================

do $$
declare
  v_org record;
  v_unit_id uuid;
begin
  for v_org in select id, name from public.organizations loop
    -- 8.1 unidade default da organização (idempotente)
    select id into v_unit_id from public.units where organization_id = v_org.id and is_default and active limit 1;
    if v_unit_id is null then
      insert into public.units(organization_id, name, timezone, active, is_default)
        values (v_org.id, v_org.name, 'America/Sao_Paulo', true, true)
        returning id into v_unit_id;
      insert into public.unit_access_audit_events(organization_id, unit_id, event_type, actor_kind, after_state)
        values (v_org.id, v_unit_id, 'unit_created', 'system', jsonb_build_object('is_default', true, 'active', true, 'source', 'onda0_backfill'));
    end if;

    -- 8.2 vincula todos os profissionais existentes (ativos ou não) à default
    insert into public.professional_units(organization_id, professional_id, unit_id, active)
    select v_org.id, p.id, v_unit_id, true
    from public.professionals p
    where p.organization_id = v_org.id
    on conflict (organization_id, professional_id, unit_id) do nothing;

    -- 8.3 memberships professional/reception herdam a unidade default
    update public.memberships
    set unit_id = v_unit_id
    where organization_id = v_org.id
      and role in ('professional', 'reception')
      and unit_id is null;

    -- 8.4 backfill dos 6 fatos transacionais
    update public.appointments set unit_id = v_unit_id where organization_id = v_org.id and unit_id is null;
    update public.orders set unit_id = v_unit_id where organization_id = v_org.id and unit_id is null;
    update public.order_items set unit_id = v_unit_id where organization_id = v_org.id and unit_id is null;
    update public.payments set unit_id = v_unit_id where organization_id = v_org.id and unit_id is null;
    update public.inventory_movements set unit_id = v_unit_id where organization_id = v_org.id and unit_id is null;
    update public.cash_entries set unit_id = v_unit_id where organization_id = v_org.id and unit_id is null;
  end loop;
end $$;

-- ============================================================================
-- 9. Default-fill de memberships.unit_id — sem este trigger, membership_set
--    (RPC existente, sem parâmetro de unidade) passaria a violar o check da
--    seção 10 assim que criasse/alterasse uma membership 'professional' ou
--    'reception' sem unit_id explícito. Também zera unit_id ao promover para
--    papel org-wide (owner/admin/manager), por regra do Blueprint (§3.2).
-- ============================================================================

create or replace function private.default_fill_membership_unit_scope()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if new.role in ('owner', 'admin', 'manager') then
    new.unit_id := null;
  elsif new.unit_id is null then
    select id into new.unit_id from public.units where organization_id = new.organization_id and is_default and active limit 1;
  end if;
  return new;
end;
$$;
revoke all on function private.default_fill_membership_unit_scope() from public, anon, authenticated;

create trigger memberships_default_fill_unit_scope
before insert or update on public.memberships
for each row execute function private.default_fill_membership_unit_scope();

-- ============================================================================
-- 10. Check de escopo papel x unidade em memberships — NOT VALID: aplica a
--     partir de agora para linhas novas/alteradas, mas não falha por causa das
--     linhas já existentes (o backfill acima já as deixou consistentes; a
--     validação formal roda na migration de hardening).
-- ============================================================================

alter table public.memberships add constraint memberships_role_unit_scope_check check (
  (role in ('owner', 'admin', 'manager') and unit_id is null)
  or (role in ('professional', 'reception') and unit_id is not null)
) not valid;

-- ============================================================================
-- 11. Triggers de default-fill nos fatos — cobrem toda inserção nova feita
--     pelas RPCs existentes (checkout_close, create_appointment,
--     update_appointment, inventory_adjust) sem reescrever nenhuma delas.
-- ============================================================================

create or replace function private.default_fill_unit_id()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if new.unit_id is null then
    select id into new.unit_id from public.units where organization_id = new.organization_id and is_default and active limit 1;
  end if;
  return new;
end;
$$;
revoke all on function private.default_fill_unit_id() from public, anon, authenticated;

create or replace function private.default_fill_unit_id_from_order()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if new.unit_id is null then
    if new.order_id is not null then
      select unit_id into new.unit_id from public.orders where organization_id = new.organization_id and id = new.order_id;
    end if;
    if new.unit_id is null then
      select id into new.unit_id from public.units where organization_id = new.organization_id and is_default and active limit 1;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.default_fill_unit_id_from_order() from public, anon, authenticated;

create trigger appointments_default_fill_unit_id before insert on public.appointments for each row execute function private.default_fill_unit_id();
create trigger orders_default_fill_unit_id before insert on public.orders for each row execute function private.default_fill_unit_id();
create trigger order_items_default_fill_unit_id before insert on public.order_items for each row execute function private.default_fill_unit_id_from_order();
create trigger payments_default_fill_unit_id before insert on public.payments for each row execute function private.default_fill_unit_id_from_order();
create trigger inventory_movements_default_fill_unit_id before insert on public.inventory_movements for each row execute function private.default_fill_unit_id_from_order();
create trigger cash_entries_default_fill_unit_id before insert on public.cash_entries for each row execute function private.default_fill_unit_id_from_order();

-- ============================================================================
-- 12. Consistência pai-filho unidade<->pedido (já pode ser validada agora:
--     o backfill acima garante que não há divergência hoje).
-- ============================================================================

alter table public.orders add constraint orders_org_id_unit_unique unique (organization_id, id, unit_id);
alter table public.order_items add constraint order_items_org_order_unit_fk foreign key (organization_id, order_id, unit_id) references public.orders(organization_id, id, unit_id);
alter table public.payments add constraint payments_org_order_unit_fk foreign key (organization_id, order_id, unit_id) references public.orders(organization_id, id, unit_id);
-- order_id é nullable em inventory_movements/cash_entries (ajuste manual sem
-- pedido); FK composta com coluna nula é satisfeita trivialmente (MATCH
-- SIMPLE), só passa a valer quando o movimento/lançamento referencia um pedido.
alter table public.inventory_movements add constraint inventory_movements_org_order_unit_fk foreign key (organization_id, order_id, unit_id) references public.orders(organization_id, id, unit_id);
alter table public.cash_entries add constraint cash_entries_org_order_unit_fk foreign key (organization_id, order_id, unit_id) references public.orders(organization_id, id, unit_id);
