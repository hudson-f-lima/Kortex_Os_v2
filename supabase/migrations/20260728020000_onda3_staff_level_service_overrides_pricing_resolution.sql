-- Onda 3, fatia 019 (issues/019-staff-level-service-overrides-pricing-resolution.md,
-- Blueprint §0/§2/§3.2/§3.3/§3.8/§4, DEC-46): staff_level_service_overrides
-- (override de preço/duração/comissão por nível×serviço, mesma forma de
-- professional_service_capabilities mas para o nível 2 da cascata) e
-- private.resolve_service_pricing() (equivalente de resolve_commission()
-- para os eixos preço/tempo). Sem call site nesta fatia — não é chamada
-- por checkout_close/create_appointment (achado §0: mesmo o override de
-- nível 1 de preço nunca foi ativado ali; decisão de sequenciamento, não
-- esquecimento). Comissão por nível fica gravada na tabela mas não é
-- consultada por private.resolve_commission(), que permanece intocada
-- (Migration Map §4 decisão 2, não reaberta aqui).

-- Pre-flight check (DEC-44, otimização 2).
do $$
begin
  if to_regclass('public.staff_levels') is null then
    raise exception 'pre-flight check failed: public.staff_levels does not exist';
  end if;
  if to_regclass('public.services') is null then
    raise exception 'pre-flight check failed: public.services does not exist';
  end if;
  if to_regclass('public.professional_service_capabilities') is null then
    raise exception 'pre-flight check failed: public.professional_service_capabilities does not exist';
  end if;
  if to_regclass('public.staff_level_service_overrides') is not null then
    raise exception 'pre-flight check failed: public.staff_level_service_overrides already exists';
  end if;
end $$;

create table public.staff_level_service_overrides (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  staff_level_id uuid not null,
  service_id uuid not null,
  duration_override_minutes integer check (duration_override_minutes is null or duration_override_minutes between 5 and 1440),
  price_override_cents bigint check (price_override_cents is null or price_override_cents >= 0),
  commission_type text check (commission_type in ('percentage', 'fixed')),
  commission_value bigint check (commission_value is null or commission_value >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, staff_level_id, service_id),
  check (
    (commission_type is null and commission_value is null) or (commission_type is not null and commission_value is not null)
  ),
  check (commission_type is distinct from 'percentage' or commission_value <= 10000),
  foreign key (organization_id, staff_level_id) references public.staff_levels(organization_id, id) on delete restrict,
  foreign key (organization_id, service_id) references public.services(organization_id, id) on delete restrict
);

-- Espelha professional_service_capabilities_service_idx (fase10_capabilities.sql)
-- em forma, não em predicado: esta tabela não tem coluna `active`, então o
-- índice é completo, sem `where active`.
create index staff_level_service_overrides_service_idx
on public.staff_level_service_overrides(organization_id, service_id);

create trigger staff_level_service_overrides_touch
before update on public.staff_level_service_overrides
for each row execute function private.touch_updated_at();

alter table public.staff_level_service_overrides enable row level security;

-- Trata a tabela inteira com a regra financeira mais estrita (owner/admin/
-- manager, sem reception) porque ela carrega comissão na mesma linha de
-- preço/duração (Blueprint §3.8) — mais estrito que
-- professional_service_capabilities (is_member), custo aceito e registrado.
create policy staff_level_service_overrides_select on public.staff_level_service_overrides for select to authenticated using (private.has_role(organization_id, array['owner','admin','manager']));
create policy staff_level_service_overrides_insert on public.staff_level_service_overrides for insert to authenticated with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy staff_level_service_overrides_update on public.staff_level_service_overrides for update to authenticated using (private.has_role(organization_id, array['owner','admin','manager'])) with check (private.has_role(organization_id, array['owner','admin','manager']));
create policy staff_level_service_overrides_delete on public.staff_level_service_overrides for delete to authenticated using (private.has_role(organization_id, array['owner','admin']));

-- Cascata de preço/tempo (§3.2): override profissional×serviço (nível 1,
-- já existente) > override nível×serviço (nível 2, novo) > base do serviço
-- (nível 3). coalesce() do mais específico pro mais genérico, nunca soma —
-- mesma forma de private.resolve_commission(). Sem call site: nenhuma RPC
-- desta fatia chama esta função.
create or replace function private.resolve_service_pricing(p_organization_id uuid, p_professional_id uuid, p_service_id uuid)
returns table (price_cents bigint, duration_minutes integer)
language sql stable security definer set search_path = pg_catalog, public, private as $$
  select coalesce(psc.price_override_cents, slso.price_override_cents, s.price_cents),
         coalesce(psc.duration_override_minutes, slso.duration_override_minutes, s.duration_minutes)
  from public.services s
  left join public.professionals prof
    on prof.organization_id = p_organization_id and prof.id = p_professional_id
  left join public.professional_service_capabilities psc
    on psc.organization_id = p_organization_id and psc.professional_id = p_professional_id and psc.service_id = p_service_id
  left join public.staff_level_service_overrides slso
    on slso.organization_id = p_organization_id and slso.staff_level_id = prof.staff_level_id and slso.service_id = p_service_id
  where s.organization_id = p_organization_id and s.id = p_service_id;
$$;
revoke all on function private.resolve_service_pricing(uuid, uuid, uuid) from public, anon, authenticated;
