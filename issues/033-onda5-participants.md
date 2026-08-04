---
title: "Onda 5 — participantes e titular imutável"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-51", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-04"
---

# 033 — `appointment_participants`

Criar tabela unit-safe, trigger de titular, RPC de participante e backfill idempotente dos appointments existentes. Bloquear mutação de `appointments.client_id`; alterações de presença usam a tabela de participantes e os comandos aprovados.

Aceite: todo appointment possui titular, nenhum titular é duplicado, FKs não cruzam tenant/unidade, backfill é seguro em retry e `update_appointment` rejeita transferência implícita.
