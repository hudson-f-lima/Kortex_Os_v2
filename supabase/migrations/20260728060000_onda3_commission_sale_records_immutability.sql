-- Onda 3, fatia 022 (issues/022-commission-sale-records-immutability.md,
-- DEC-47, achados P2/P3): fecha os 2 gaps de robustez encontrados por uma
-- auditoria pós-merge que a fatia 020 não havia coberto.
--
-- P2 — commission_sale_records não tinha nenhuma proteção contra mutação:
-- RLS bloqueava authenticated, mas service_role herdava DML completo via
-- `alter default privileges` (20260713034222), e não havia guard de coluna.
-- O projeto tem 2 padrões estabelecidos, nunca aplicados juntos numa mesma
-- tabela: trigger guard (deposit_holds, 20260726200000) e revoke de
-- service_role (ledger, 20260727170000). Aplicamos os dois aqui — o guard
-- sozinho não cobre DELETE; o revoke sozinho não impede que a própria RPC
-- SECURITY DEFINER altere commission_cents junto com uma transição de
-- status legítima.
--
-- P3 — o pre-flight da fatia 020 (20260728030000) não conferia
-- `organizations`/`professionals`, inconsistente com o padrão das fatias
-- 018/019. Não editamos a migration já aplicada — o pre-flight completo
-- vive aqui, como parte do contrato desta fatia.

do $$
begin
  if to_regclass('public.commission_sale_records') is null then
    raise exception 'pre-flight check failed: public.commission_sale_records does not exist';
  end if;
  if to_regclass('public.organizations') is null then
    raise exception 'pre-flight check failed: public.organizations does not exist';
  end if;
  if to_regclass('public.professionals') is null then
    raise exception 'pre-flight check failed: public.professionals does not exist';
  end if;
end $$;

-- Guard de imutabilidade — mesmo padrão de
-- private.guard_deposit_hold_financial_identity (20260726200000:38-68):
-- allowlist invertida via `is distinct from` (trata NULL corretamente),
-- errcode 55000 (mesmo código de imutabilidade financeira do projeto),
-- libera só status/updated_at.
create or replace function private.guard_commission_sale_record_immutability()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if new.organization_id is distinct from old.organization_id
    or new.unit_id is distinct from old.unit_id
    or new.order_id is distinct from old.order_id
    or new.package_id is distinct from old.package_id
    or new.professional_id is distinct from old.professional_id
    or new.commission_type is distinct from old.commission_type
    or new.commission_value is distinct from old.commission_value
    or new.commission_cents is distinct from old.commission_cents
  then
    raise exception 'commission sale record financial identity is immutable' using errcode = '55000';
  end if;
  return new;
end;
$$;
revoke all on function private.guard_commission_sale_record_immutability() from public, anon, authenticated;

drop trigger if exists commission_sale_records_immutability_guard on public.commission_sale_records;
create trigger commission_sale_records_immutability_guard
before update on public.commission_sale_records
for each row execute function private.guard_commission_sale_record_immutability();

-- Lockdown de grant — mesmo padrão de 20260727170000 (ledger, DEC-42):
-- select não é revogado, só INSERT/UPDATE/DELETE. commission_sale_record_create
-- continua funcionando (security definer, roda com o privilégio do dono da
-- função, não do chamador — mesmo racional já documentado para o ledger).
revoke insert, update, delete on public.commission_sale_records from service_role;
