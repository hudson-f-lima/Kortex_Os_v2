---
title: "Onda 7 — resize e conflitos de calendário"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-64", "DEC-69", "ADR-0013"]
upstream_doc: "docs/waves/onda-7-agenda-drag-resize/BLUEPRINT_ONDA_7_RESIZE.md"
last_updated: "2026-10-18"
---

# 064 — Duração explícita, confirmação e encaixe

Estender `update_appointment` para `duration_minutes` 5–1440, com `version`, idempotência e Change Plan. Resize puro e combinado exigem diff/confirm; duração explícita prevalece na troca de serviço/profissional. Adicionar verificador de intervalo completo (appointments, policy, turno, feriado, exceção/folga parcial e recursos) no timezone da unidade, com conflito tipado e `max_fit_duration_minutes` informativo. Criação direta deve usar unidade efetiva e validar calendário pelo mesmo contrato. `confirm=true` revalida e falha fechado sob corrida; `ends_at` permanece server-owned.

**Aceite:** pgTAP de propostas sem mutação, confirmação obsoleta, fronteiras de meia-noite/DST, exceção de minutos, folga parcial, conflito de appointment/recurso, encaixe >=5 min e corrida contra exclusion constraint. Testar regressão financeira/hold e fluxos série/grupo/waitlist. Reset/pgTAP/lint SQL verdes.

Blocked by: [063](063-onda7-resource-allocation.md).
Blocks: [065](065-onda7-express-availability.md).
