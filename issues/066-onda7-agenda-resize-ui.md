---
title: "Onda 7 — interface de resize e requisitos"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-69"]
upstream_doc: "docs/waves/onda-7-agenda-drag-resize/BLUEPRINT_ONDA_7_RESIZE.md"
last_updated: "2026-10-18"
---

# 066 — Agenda touch/pointer e editor de recursos

Adicionar editor de requisitos por serviço/unidade, duração no `AppointmentModal` e alça de resize no card da Timeline Vertical. Reaproveitar Pointer Events do arraste; preservar duração exata de 5–1440 sem arredondamento silencioso. Mostrar diff, conflito por tipo e ações Cancelar/Encaixar até HH:MM; encaixe envia nova proposta e exige confirmação. Reverter o preview em falha, versão obsoleta ou corrida. Usar Design System, modal compartilhado, flag off por padrão e acessibilidade touch/teclado.

**Aceite:** Vitest do fluxo puro/combinado, confirmação dupla de encaixe, falha de API e revert, flag off, responsividade e casos sem encaixe válido; lint/build frontend verdes.

Blocked by: [065](065-onda7-express-availability.md).
Blocks: [067](067-onda7-redteam-release-gates.md).
