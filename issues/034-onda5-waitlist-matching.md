---
title: "Onda 5 — waitlist matching Booksy"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-51", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-04"
---

# 034 — entradas, preferências e ondas de oferta

Criar `waitlist_entries`, `waitlist_entry_professionals` e `waitlist_offers`. Implementar matcher idempotente que consulta Availability Resolver, cria ofertas simultâneas para candidatos elegíveis, aponta para slot exato, grava token hash, TTL de 30 minutos e cooldown de 6 horas.

Aceite: reexecução não duplica oferta nem notificação, entradas fora de unidade/serviço são rejeitadas, profissional inexistente ou inelegível não é aceito e a ausência de preferência significa qualquer profissional elegível.
