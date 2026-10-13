---
title: "Onda 5 — conflitos e retry de recorrência"
status: "ABSORVIDA"
stage: "ISSUE"
governance_ref: ["DEC-51", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 031 — conflitos explícitos de recorrência

**Status: ABSORVIDA pela remediação forward-only da fatia 030 (2026-08-05).** A auditoria que apontou `NO-GO` para a fatia 030 (materialização tudo-ou-nada, desvio do Blueprint §3.1.4) foi corrigida na mesma remediação que já entrega integralmente o escopo desta issue — não há trabalho remanescente que justifique abrir esta issue como fatia própria. Ver `supabase/migrations/20260805010000_onda5_fatia030_partial_materialization.sql` (commit `662356a`) e o reforço de teste do commit `38e0aba`.

Mapeamento de aceite (verificado pessoalmente, não por relato):

| Aceite | Evidência |
|---|---|
| Nenhum conflito é silencioso | `private.onda5_materialize_series_occurrence` grava `appointment_series_conflicts` em toda falha de ocorrência, nunca descarta |
| Reexecução não duplica ocorrência | Idempotência por ocorrência (`series_id`+`occurrence_date`) reaproveitada pelo retry; testado em `onda5_appointment_series_create_test.sql` |
| Retry de conflito resolvido falha fechado | `appointment_series_conflict_retry` rejeita com `P0020` se `status <> 'OPEN'`; testado |
| Retry revalida política/Resolver | Retry sempre chama `create_appointment` com `origin='series'`, que roda o Resolver obrigatoriamente para toda origem não-direta — nenhum atalho |
| Janela futura não reescreve histórico | `onda5_appointment_series_extend_window_test.sql` prova por snapshot (`version`/`updated_at`) que uma ocorrência já materializada não é tocada por uma chamada redundante de `extend_window` (reforço adicionado em `38e0aba`) |

Evidência bruta: 802/802 pgTAP, `supabase db lint --local`/`db advisors --local` sem achados, grants e isolamento de tenant confirmados por query direta.

---

Texto original da issue (preservado para rastreabilidade):

Criar `appointment_series_conflicts`, registrar cada ocorrência conflitante sem abortar as válidas e implementar retry somente para conflitos `OPEN`. O retry deve revalidar política/Resolver e resolver o conflito apenas após criar a ocorrência real.

Aceite: nenhum conflito é silencioso, reexecução não duplica ocorrência, retry de conflito resolvido falha fechado e a janela futura não reescreve histórico.
