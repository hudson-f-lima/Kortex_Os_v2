-- Onda 5, fatia 029 (issues/029-onda5-feature-flag-and-preflight.md,
-- DEC-51/DEC-52). Implementa
-- docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md
-- §2/§3 — fundação de Dark Launching por Feature Flag (DEC-44, otimização 1)
-- e Pre-flight Check (DEC-44, otimização 2) para a Onda 5. Nenhuma rota ou
-- RPC de escrita nasce nesta fatia — só leitura de configuração com
-- defaults seguros e validação de forma. `organizations.settings` já
-- existe desde a Onda 3
-- (20260728000000_onda3_organizations_settings_feature_flag.sql).

-- Pre-flight check (DEC-44, otimização 2): confere pré-condição antes do
-- DDL — as fatias 030-035 desta Onda dependem de organizations, units,
-- memberships e professional_units já existirem.
do $$
begin
  if to_regclass('public.organizations') is null then
    raise exception 'pre-flight check failed: public.organizations does not exist';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'organizations' and column_name = 'settings'
  ) then
    raise exception 'pre-flight check failed: public.organizations.settings does not exist';
  end if;
  if to_regclass('public.units') is null then
    raise exception 'pre-flight check failed: public.units does not exist';
  end if;
  if to_regclass('public.memberships') is null then
    raise exception 'pre-flight check failed: public.memberships does not exist';
  end if;
  if to_regclass('public.professional_units') is null then
    raise exception 'pre-flight check failed: public.professional_units does not exist';
  end if;
  if exists (
    select 1 from pg_constraint where conname = 'organizations_onda5_waitlist_settings_shape'
  ) then
    raise exception 'pre-flight check failed: organizations_onda5_waitlist_settings_shape already exists';
  end if;
end $$;

-- Forma das 3 chaves novas em organizations.settings (§2 do Blueprint) —
-- só valida quando a chave está presente; ausência é o estado normal de
-- dark launch (default resolvido em tempo de leitura, ver função abaixo).
-- Limites superiores (achado do Red Team de implementação, 2026-08-04):
-- sem bound, um TTL/cooldown absurdo (ex.: 999999999) chegaria intacto às
-- fatias 034/035, que usam este valor como janela real de hold da
-- waitlist — equivalente a um hold que nunca expira. 1440min (24h) e
-- 168h (7 dias) dão folga generosa acima dos defaults (30min/6h) sem
-- permitir um valor operacionalmente absurdo.
alter table public.organizations add constraint organizations_onda5_waitlist_settings_shape check (
  (not (settings ? 'recurring_group_waitlist_enabled')
    or jsonb_typeof(settings -> 'recurring_group_waitlist_enabled') = 'boolean')
  and (not (settings ? 'waitlist_offer_ttl_minutes')
    or (
      jsonb_typeof(settings -> 'waitlist_offer_ttl_minutes') = 'number'
      and (settings ->> 'waitlist_offer_ttl_minutes')::numeric > 0
      and (settings ->> 'waitlist_offer_ttl_minutes')::numeric <= 1440
      and (settings ->> 'waitlist_offer_ttl_minutes')::numeric = floor((settings ->> 'waitlist_offer_ttl_minutes')::numeric)
    ))
  and (not (settings ? 'waitlist_offer_cooldown_hours')
    or (
      jsonb_typeof(settings -> 'waitlist_offer_cooldown_hours') = 'number'
      and (settings ->> 'waitlist_offer_cooldown_hours')::numeric >= 0
      and (settings ->> 'waitlist_offer_cooldown_hours')::numeric <= 168
      and (settings ->> 'waitlist_offer_cooldown_hours')::numeric = floor((settings ->> 'waitlist_offer_cooldown_hours')::numeric)
    ))
);

-- Resolver de leitura com defaults seguros (flag desligada, TTL 30min,
-- cooldown 6h — DEC-52). security definer + private.is_member() embutido:
-- mesma disciplina de private.can_access_fact_unit (Onda 0/1) — a função
-- não confia em RLS de organizations para isolar tenant, ela mesma nega
-- fail-closed para quem não é membro ativo da organização consultada.
create or replace function private.onda5_waitlist_settings(p_organization_id uuid)
returns table (
  waitlist_enabled boolean,
  offer_ttl_minutes integer,
  offer_cooldown_hours integer
)
language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  if not private.is_member(p_organization_id) then
    raise exception 'insufficient organization permission' using errcode = '42501';
  end if;

  return query
  select
    coalesce((o.settings ->> 'recurring_group_waitlist_enabled')::boolean, false),
    coalesce((o.settings ->> 'waitlist_offer_ttl_minutes')::integer, 30),
    coalesce((o.settings ->> 'waitlist_offer_cooldown_hours')::integer, 6)
  from public.organizations o
  where o.id = p_organization_id;
end;
$$;

revoke all on function private.onda5_waitlist_settings(uuid) from public, anon;
grant execute on function private.onda5_waitlist_settings(uuid) to authenticated;
