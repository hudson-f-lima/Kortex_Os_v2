---
title: "Onda 5 — conflitos e retry de recorrência"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-51", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-04"
---

# 031 — conflitos explícitos de recorrência

Criar `appointment_series_conflicts`, registrar cada ocorrência conflitante sem abortar as válidas e implementar retry somente para conflitos `OPEN`. O retry deve revalidar política/Resolver e resolver o conflito apenas após criar a ocorrência real.

Aceite: nenhum conflito é silencioso, reexecução não duplica ocorrência, retry de conflito resolvido falha fechado e a janela futura não reescreve histórico.
