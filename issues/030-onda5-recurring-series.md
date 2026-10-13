---
title: "Onda 5 — recurring series e materialização"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-51", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 030 — `appointment_series`

Criar schema unit-safe, `appointments.series_id`, âncora local, duração snapshot, RPC de criação, extensão da janela de oito semanas, edição, pausa, retomada e cancelamento. Estender `create_appointment` com metadados server-owned e consulta obrigatória ao Availability Resolver para origens `series`.

Aceite: pgTAP cobre timezone da unidade, idempotência por ocorrência, CAS/version, titular imutável, janela rolante e ausência de inserção direta em `appointments`; Jest cobre contratos de RPC e erros de domínio.
