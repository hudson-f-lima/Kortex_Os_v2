---
title: "Onda 5 — feature flag e pre-flight"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-51", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 029 — Feature flag e pre-flight da Onda 5

Implementar somente a fundação de dark launch em `organizations.settings` para `recurring_group_waitlist_enabled`, `waitlist_offer_ttl_minutes` e `waitlist_offer_cooldown_hours`, com defaults seguros e pre-flight SQL. Validar organizações, unidades, memberships e vínculos profissional↔unidade antes de qualquer RPC nova.

Aceite: pgTAP cobre defaults, tenant, valores inválidos e flag desligada; nenhuma rota ou RPC nova fica ativa por padrão; migration referencia o Blueprint e fecha esta issue.
