---
title: "Onda 5 — Group Booking pai e filhos"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-51", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 032 — `appointment_groups` e appointments filhos

Criar o agregado-pai e o vínculo `appointments.group_id`. Criar grupos de 2–10 participantes com o mesmo serviço/unidade/início e profissionais independentes, de modo atômico. Implementar edição individual, edição do conjunto, filhos futuros, adição e cancelamento auditável; respeitar permissões atuais de agenda e escopo de unidade.

Aceite: rollback integral em falha de qualquer filho, nenhuma consolidação de checkout, cardinalidade 2–10, requester/participante com visibilidade correta e grupo agregado consistente.
