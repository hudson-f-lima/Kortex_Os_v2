-- KortexOS 5.1.2 — Onda 4, fatia 028: wrappers públicos dos resolvers.
-- Implementa docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md
-- (APROVADO, DEC-49), §3.4.
--
-- Achado da implementação: PostgREST (e portanto supabaseAdmin.rpc(...) no
-- Express) só expõe funções do schema `public`, nunca `private` — mesmo com
-- grant explícito. As 3 funções de resolução (fatias 023/027) são `private.*`
-- de propósito (chamadas por triggers internos, nunca por usuário final
-- direto). Para o módulo Express desta fatia conseguir chamá-las, cada uma
-- ganha um wrapper fino em `public.*`, mesmo nome, `security definer`,
-- grant só para `service_role` (mesmo padrão de toda RPC já exposta ao
-- Express neste repositório) — a lógica em si continua inteiramente nas
-- funções `private.*` já testadas por pgTAP; o wrapper não adiciona
-- comportamento novo.

do $$
begin
  if to_regprocedure('private.resolve_calendar_policy(uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_calendar_policy does not exist';
  end if;
  if to_regprocedure('private.resolve_professional_shift(uuid,uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_professional_shift does not exist';
  end if;
  if to_regprocedure('private.resolve_calendar_overrides(uuid,uuid,uuid,date)') is null then
    raise exception 'pre-flight failed: private.resolve_calendar_overrides does not exist';
  end if;
  if to_regprocedure('private.resolve_eligibility(uuid,uuid,uuid)') is null then
    raise exception 'pre-flight failed: private.resolve_eligibility does not exist';
  end if;
end;
$$;

create or replace function public.resolve_calendar_policy(p_organization_id uuid, p_unit_id uuid, p_date date)
returns table(blocks jsonb)
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select * from private.resolve_calendar_policy(p_organization_id, p_unit_id, p_date);
$$;

revoke all on function public.resolve_calendar_policy(uuid, uuid, date) from public, anon, authenticated;
grant execute on function public.resolve_calendar_policy(uuid, uuid, date) to service_role;

create or replace function public.resolve_professional_shift(p_organization_id uuid, p_professional_id uuid, p_unit_id uuid, p_date date)
returns table(blocks jsonb)
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select * from private.resolve_professional_shift(p_organization_id, p_professional_id, p_unit_id, p_date);
$$;

revoke all on function public.resolve_professional_shift(uuid, uuid, uuid, date) from public, anon, authenticated;
grant execute on function public.resolve_professional_shift(uuid, uuid, uuid, date) to service_role;

create or replace function public.resolve_calendar_overrides(p_organization_id uuid, p_unit_id uuid, p_professional_id uuid, p_date date)
returns table(is_open boolean, reason text)
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select * from private.resolve_calendar_overrides(p_organization_id, p_unit_id, p_professional_id, p_date);
$$;

revoke all on function public.resolve_calendar_overrides(uuid, uuid, uuid, date) from public, anon, authenticated;
grant execute on function public.resolve_calendar_overrides(uuid, uuid, uuid, date) to service_role;

-- Utilitário puro de conversão de horário local (HH:MM, data civil, timezone
-- da unidade) para instante absoluto — reaproveitado pelo módulo Express
-- (fatia 028) para converter os blocos resolvidos em `starts_at`/`ends_at`
-- de resposta, sem reimplementar conversão de fuso horário em JS (não há
-- biblioteca de timezone no backend; Postgres já faz essa conversão
-- corretamente e já é a fonte usada por todo o Resolver).
create or replace function public.local_time_to_utc(p_timezone text, p_date date, p_local_time text)
returns timestamptz
language sql
stable
set search_path = pg_catalog
as $$
  select (p_date::text || ' ' || p_local_time)::timestamp at time zone p_timezone;
$$;

revoke all on function public.local_time_to_utc(text, date, text) from public, anon, authenticated;
grant execute on function public.local_time_to_utc(text, date, text) to service_role;

-- Wrapper público de private.resolve_eligibility (Fase Opção C,
-- 20260716150000) — achado de auditoria pós-implementação (2026-07-29): o
-- endpoint de disponibilidade nunca consultava elegibilidade tri-state
-- (ADR 0010) nem quando professional_id era passado explicitamente, então
-- um profissional com eligibility='DISABLED' para o serviço ainda aparecia
-- com slots. Mesmo racional dos outros wrappers desta migration — a função
-- já existe, testada, só não é chamável via PostgREST por estar em `private`.
create or replace function public.resolve_eligibility(p_organization_id uuid, p_professional_id uuid, p_service_id uuid)
returns table(eligible boolean, source text)
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select * from private.resolve_eligibility(p_organization_id, p_professional_id, p_service_id);
$$;

revoke all on function public.resolve_eligibility(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.resolve_eligibility(uuid, uuid, uuid) to service_role;
