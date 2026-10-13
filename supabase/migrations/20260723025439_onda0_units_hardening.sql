-- KortexOS 5.1.2 — Onda 0 (units): hardening.
-- Segunda metade de docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_DRAFT.md (DEC-31/DEC-32).
-- Só roda depois que 20260723025006_onda0_units_schema_backfill.sql já deixou
-- toda linha existente consistente (contagem de unit_id nulo = zero nos 6
-- fatos, memberships professional/reception todos com unit_id). Travar aqui
-- é intencionalmente a última etapa: qualquer correção depois disso é
-- forward-only, conforme o plano de rollback do Blueprint (§5.1).

-- ============================================================================
-- 1. Valida o check de escopo papel x unidade (adicionado NOT VALID na
--    migration anterior) contra as linhas já existentes.
-- ============================================================================

alter table public.memberships validate constraint memberships_role_unit_scope_check;

-- ============================================================================
-- 2. unit_id passa a ser obrigatório nos 6 fatos transacionais. Não se aplica
--    a memberships.unit_id, que é condicional por papel (regra do check
--    acima, nunca um NOT NULL geral).
-- ============================================================================

alter table public.appointments alter column unit_id set not null;
alter table public.orders alter column unit_id set not null;
alter table public.order_items alter column unit_id set not null;
alter table public.payments alter column unit_id set not null;
alter table public.inventory_movements alter column unit_id set not null;
alter table public.cash_entries alter column unit_id set not null;

-- ============================================================================
-- 3. Imutabilidade: unit_id de um fato nunca muda depois de gravado. Mover
--    unidade de um appointment é reagendamento explícito (fora desta onda);
--    unidade financeira nunca muda, correção é sempre por fluxo reversível.
-- ============================================================================

create or replace function private.enforce_unit_id_immutable()
returns trigger language plpgsql set search_path = pg_catalog as $$
begin
  if new.unit_id is distinct from old.unit_id then
    raise exception 'unit_id is immutable once set' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_unit_id_immutable() from public, anon, authenticated;

create trigger appointments_enforce_unit_id_immutable before update on public.appointments for each row execute function private.enforce_unit_id_immutable();
create trigger orders_enforce_unit_id_immutable before update on public.orders for each row execute function private.enforce_unit_id_immutable();
create trigger order_items_enforce_unit_id_immutable before update on public.order_items for each row execute function private.enforce_unit_id_immutable();
create trigger payments_enforce_unit_id_immutable before update on public.payments for each row execute function private.enforce_unit_id_immutable();
create trigger inventory_movements_enforce_unit_id_immutable before update on public.inventory_movements for each row execute function private.enforce_unit_id_immutable();
create trigger cash_entries_enforce_unit_id_immutable before update on public.cash_entries for each row execute function private.enforce_unit_id_immutable();
