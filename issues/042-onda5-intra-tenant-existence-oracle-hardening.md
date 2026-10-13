---
title: "Onda 5 — hardening do oráculo de existência intra-tenant"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-57", "ADR-0023"]
upstream_doc: "docs/architecture/adr/0023-onda5-recurring-group-booking-waitlist.md"
last_updated: "2026-08-06"
---

# 042 — neutralizar oráculo de existência intra-tenant

Hardening decorrente do Red Team final (DEC-57). Em `private.onda5_write_target_unit` e `private.assert_actor_can_write_onda5_target`, uma reception autenticada no mesmo tenant pode distinguir um identificador inexistente (`P0002`, do corpo original) de um objeto existente em outra unidade (`42501`, do guard unit-aware). Não há leitura nem mutação indevida, mas a diferença de erro revela existência de objeto fora do escopo de unidade.

Objetivo: preservar o guard unit-aware e normalizar o resultado externo de identificador fora da unidade para o mesmo contrato `not found` usado por identificador inexistente, sem mascarar negação legítima no próprio escopo e sem alterar permissões de owner/admin/manager ou reception da unidade correta.

**Escopo refinado por decisão explícita do Platform Owner (2026-08-06):** o oráculo real só existe nas **10 operações de lookup** (série/conflito/grupo/oferta por ID já existente) — `appointment_series_extend_window/_update/_cancel/_conflict_retry`, `appointment_group_member_add/_update/_cancel`, `waitlist_offer_accept/_decline/_expire`. As 4 operações de **create** (`appointment_series_create`, `appointment_group_create`, `waitlist_entry_create`, `waitlist_matcher_run`) recebem `unit_id` direto do payload do próprio actor — não há objeto oculto a proteger, e normalizar para `P0002` ali só pioraria a clareza do erro sem ganho de segurança. Essas 4 continuam com `42501 'insufficient unit permission'`, comportamento inalterado.

Aceite: para as 10 operações de lookup, reception de outra unidade recebe `P0002` com a mesma mensagem que um identificador inexistente já produzia (`series not found`, `series conflict not found`, `group not found`, `waitlist offer not found`), sem distinguir objeto inexistente de objeto existente fora do seu escopo; as 4 de create seguem com `42501`; owner/admin/manager e reception da unidade correta continuam com o caminho positivo em todas as 14; nenhum DML direto é reaberto.

**Implementação (via `$tdd`, tracer bullet):** migration `supabase/migrations/20260806140000_onda5_fatia042_intra_tenant_not_found_normalization.sql`, forward-only sobre a 037 já aplicada (`CREATE OR REPLACE FUNCTION`, nenhuma migration anterior editada). Extraído `private.onda5_actor_can_write_unit` como fonte única da checagem de permissão de unidade, reusada tanto pelo caminho `42501` (`assert_actor_can_write_fact_unit`, inalterado para os 4 creates e para `waitlist_entry_create`) quanto pelo novo caminho `P0002` (`assert_actor_can_write_onda5_target`, via `private.onda5_write_target_not_found_message`, que mapeia operação → mensagem de not-found real, lida diretamente dos `_unsafe` da fatia 037; `NULL` para as 4 creates sinaliza "sem oráculo aqui, mantenha 42501").

Evidência: `supabase/tests/onda5_unit_aware_write_guard_test.sql` — RED confirmado (asserção do tracer bullet falhando contra o código da 037 antes da migration 042), GREEN após a migration, as outras 9 asserções de lookup atualizadas e verificadas verdes na mesma rodada (a implementação geral já as cobria). Reset limpo do zero: 908/908 pgTAP (57 arquivos, mesma contagem de antes — sem teste novo, só reescrita das 9 asserções de lookup), `supabase db lint --local` sem achados, `search_path` fixado nas 4 funções novas/alteradas. Backend não re-executado (nenhum arquivo JS tocado por esta fatia).
