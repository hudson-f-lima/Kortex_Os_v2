---
title: "Issue 027 - Availability Resolver Functions"
status: "IMPLEMENTED_LOCAL"
stage: "ISSUE"
governance_ref: ["DEC-49"]
upstream_doc: "docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md"
last_updated: "2026-07-29"
---

## Parent Blueprint

`docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md` (APROVADO, DEC-49), §2, §3.4, §3.7, §4.

## What to build

As funções SQL pequenas do Availability Resolver (Rota A, decisão fechada por interview — Postgres resolve política, Express orquestra o loop de slots na fatia 028): `private.resolve_professional_shift`, `private.resolve_calendar_overrides`. Todas `stable security definer`, respeitando o timezone da unidade (`units.timezone` — achado do Red Team de desenho: a formulação original não descrevia conversão de timezone nenhuma).

**Ajuste feito na fatia 023:** `private.resolve_calendar_policy(p_organization_id, p_unit_id, p_date)` já nasceu na fatia 023 (`supabase/migrations/20260729010000_onda4_calendar_policies_professional_shifts.sql`) — o trigger de turno ⊆ horário daquela fatia já precisava dela. Esta fatia não a recria.

**Nota sobre feature flags (§3.7):** as 2 chaves (`availability_resolver_enabled`, `resource_orchestration_enabled`) não exigem migration própria — `organizations.settings` já existe (Onda 3) e não é um enum/schema fechado. Nesta Onda, só `availability_resolver_enabled` é lida por rota Express real; `resource_orchestration_enabled` fica reservada até existir um call site Express para `resource_lock_create`.

## Acceptance criteria

- [x] `private.resolve_professional_shift(p_organization_id, p_professional_id, p_unit_id, p_date) returns table(blocks jsonb)` — análoga a `private.resolve_calendar_policy` (fatia 023), mas para `professional_shifts`. `supabase/migrations/20260729050000_onda4_availability_resolver_functions.sql`
- [x] `private.resolve_calendar_overrides(p_organization_id, p_unit_id, p_professional_id, p_date) returns table(is_open boolean, reason text)` — aplica os tiers 1-4 da precedência canônica (Master §2.3: exceção pontual → fechamento/feriado → abertura excepcional → folga), retorna o primeiro que bater ou nenhuma linha. `p_professional_id` aceita `null` (consulta unit-wide, tier 4 nunca aplica nesse caso)
- [x] Toda conversão de bloco `HH:MM` para instante absoluto usa `units.timezone` explicitamente (`AT TIME ZONE`), nunca comparação ingênua contra `timestamptz`
- [x] `revoke all on function ... from public, anon, authenticated` nas 2 funções, mesmo padrão de `resolve_commission`/`resolve_service_pricing`
- [x] Pre-flight check (DEC-44): confere que `calendar_policies`/`professional_shifts` (fatia 023), `calendar_holidays`/`calendar_exceptions`/`calendar_time_off` (fatia 024) e `private.resolve_calendar_policy` (fatia 023) já existem
- [x] pgTAP: `resolve_professional_shift` retorna os blocos corretos para uma data dentro da vigência e vazio fora dela; `resolve_calendar_overrides` respeita a precedência (tier 1 vence tier 2 no mesmo dia; tier 2 via feriado E via `calendar_exceptions.exceptional_closure`; tier 3 sem concorrência de tier 1/2; tier 4 só quando `p_professional_id` é informado); feriado org-wide (`unit_id` nulo) se aplica a qualquer unidade da organização; nenhuma linha retornada quando nada se aplica; conversão de timezone testada explicitamente com uma unidade em `America/New_York` (fuso diferente de UTC e de `America/Sao_Paulo`), comparando o resultado contra o bloco esperado, não contra uma string `HH:MM` ingênua; `authenticated` não tem `EXECUTE` direto em nenhuma das 2 funções. `supabase/tests/availability_resolver_functions_test.sql` — 16/16 assertions, suíte completa 759/759 (`supabase test db --local supabase/tests`, evidência bruta: `Result: PASS`), sem regressão

## Blocked by

023 (calendar_policies/professional_shifts), 024 (calendar_holidays/calendar_exceptions/calendar_time_off) — concluídas

## Seções do Blueprint endereçadas

- §2 (escopo de dados — Availability Resolver)
- §3.4 (Rota A, timezone)
- §3.7 (Feature Flag)
- §4 (contrato das funções, nota de timezone)
