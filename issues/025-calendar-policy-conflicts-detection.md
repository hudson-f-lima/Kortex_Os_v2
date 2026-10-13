---
title: "Issue 025 - Calendar Policy Conflicts Detection"
status: "IMPLEMENTED_LOCAL"
stage: "ISSUE"
governance_ref: ["DEC-49"]
upstream_doc: "docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md"
last_updated: "2026-07-29"
---

## Parent Blueprint

`docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md` (APROVADO, DEC-49), §2, §3.2, §3.8, §4.

## What to build

`calendar_policy_conflicts` — fila de conflitos (Master §2.4, CRÍTICO: mudança de política não altera `appointments` confirmados, gera fila para resolução humana via Command). Populada exclusivamente por trigger `AFTER INSERT` (um por tabela, não uma função genérica única — cada tabela tem uma semântica diferente de "o que mudou") rodando em `calendar_policies`, `professional_shifts`, `calendar_holidays`, `calendar_exceptions` e `calendar_time_off` — nunca por `INSERT` direto.

**Correção de escopo herdada da fatia 023:** a tentativa intermediária de isentar `private.close_previous_professional_shift_version()` por `calendar_exceptions.exceptional_opening` foi removida. Turno recorrente fora do horário padrão continua rejeitado; abertura excepcional só vale para ocorrências pontuais avaliadas pelo Resolver.

## Acceptance criteria

- [x] Migration aditiva cria `calendar_policy_conflicts` (`id`, `organization_id`, `unit_id`, `source_type`, `source_id`, `appointment_id`, `status`, `detected_at`, `resolved_by`/`resolved_at`/`resolution_note`) com FK composta de 3 colunas `(organization_id, appointment_id, unit_id) references appointments(organization_id, id, unit_id) on delete restrict` (usa `appointments_org_id_unit_unique`, não FK simples — achado do Red Team de desenho). `supabase/migrations/20260729030000_onda4_calendar_policy_conflicts_detection.sql`
- [x] Pre-flight check (DEC-44): confere que as 5 tabelas de política (fatias 023/024) e `appointments_org_id_unit_unique` existem antes de criar os triggers
- [x] Trigger `AFTER INSERT` em cada uma das 5 tabelas de política grava 1 linha por `appointment` confirmado/agendado/em atendimento que ficou fora da janela resolvida pela nova versão — `calendar_policies`/`professional_shifts` comparam bloco a bloco (`HH:MM` local via `units.timezone`); `calendar_holidays` só quando `unit_opens = false`; `calendar_exceptions` só quando `is_open = false`; `calendar_time_off` sempre (toda folga reduz disponibilidade)
- [x] Nenhum grant de `INSERT` a `authenticated` em `calendar_policy_conflicts` — só os triggers (`security definer`, via `private.record_calendar_policy_conflict`) escrevem
- [x] RLS: SELECT via `private.can_access_fact_unit(org: owner/admin/manager; unit: nenhum)` — fila é Command-facing, nenhum papel unit-scoped enxerga; UPDATE (`status`, `resolved_by`, `resolved_at`, `resolution_note`) restrito a `owner`/`admin`/`manager`
- [x] pgTAP: estreitar `calendar_policies`/`professional_shifts` gera conflito para o appointment que ficou fora; feriado `unit_opens=false` no dia do appointment gera conflito, `unit_opens=true` não gera; `exceptional_closure` cobrindo o appointment gera conflito, `exceptional_opening` não gera; folga do profissional cobrindo o appointment gera conflito; `reception1` (papel unit-scoped) não enxerga a fila; `owner1` resolve um conflito (`status='resolved'` persistido); turno fora do horário padrão continua rejeitado mesmo quando existe `exceptional_opening` na data. `supabase/tests/rls_calendar_policy_conflicts_test.sql` — 20/20 assertions, suíte completa 764/764 (`supabase test db`, evidência bruta: `Result: PASS`), sem regressão

## Blocked by

023 (calendar_policies/professional_shifts), 024 (calendar_holidays/calendar_exceptions/calendar_time_off) — concluídas

## Seções do Blueprint endereçadas

- §2 (escopo de dados)
- §3.2 (trigger automático, custo aceito)
- §3.8 (matriz RLS)
- §4 (contrato físico, FK composta de 3 colunas)

## Correção pós-implementação (2026-07-29, Red Team de implementação)

O item "fecha a pendência da fatia 023" (isenção por `exceptional_opening`) foi **removido** desta fatia, não mantido: era um erro conceitual, não um bug de detalhe — comparava só `HH:MI` da exceção contra o turno, ignorando que a exceção é de uma data única e o turno é um padrão recorrente semanal. `supabase/migrations/20260729030000_...sql` seção 8 hoje só registra a remoção, não redefine mais `close_previous_professional_shift_version()`. Teste correspondente em `rls_calendar_policy_conflicts_test.sql` invertido de `lives_ok` para `throws_ok`. Também corrigido no mesmo achado: timezone de feriado org-wide (usava a unidade default para todas as unidades — agora usa o timezone de cada unidade via join). Auditoria final de fix trocou `private.record_calendar_policy_conflict` para argumentos explícitos em vez de `record`, limpando `supabase db lint`. Evidência atualizada: **20/20** assertions (2 novas cobrindo o timezone), suíte completa **764/764**.
