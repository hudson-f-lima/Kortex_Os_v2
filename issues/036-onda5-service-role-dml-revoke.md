---
title: "Onda 5 — revoga DML direto de service_role"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-52", "DEC-54", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 036 — revoga DML direto de `service_role`

Corretiva (DEC-54). Revogar `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE` de `service_role` nas 7 tabelas novas da Onda 5 (`appointment_series`, `appointment_series_conflicts`, `appointment_groups`, `appointment_participants`, `waitlist_entries`, `waitlist_entry_professionals`, `waitlist_offers`), fechando um gap real entre a implementação das fatias 032-035 e o invariante já registrado na ADR 0023 ("DML direto é revogado"). RPCs `security definer` continuam o único caminho de escrita; nenhuma migration já aplicada é alterada, só um `REVOKE` forward-only.

Aceite: pgTAP com `SET LOCAL ROLE service_role` falha em `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE` diretos contra as 7 tabelas; toda RPC de série, grupo, participante e waitlist (criação, edição, cancelamento, matcher, aceite/recusa/expiração de oferta) continua funcionando sem regressão.
