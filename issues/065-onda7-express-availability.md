---
title: "Onda 7 — HTTP de edição e disponibilidade por recursos"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-69"]
upstream_doc: "docs/waves/onda-7-agenda-drag-resize/BLUEPRINT_ONDA_7_RESIZE.md"
last_updated: "2026-10-18"
---

# 065 — Contratos Express e slots reais

Validar/allowlist `duration_minutes` no PATCH, sem aceitar `ends_at`; mapear conflito tipado para HTTP sem revelar outros tenants. Expor configuração de requisitos somente a owner/admin/manager e com unidade autorizada. Disponibilidade por serviço/unidade/profissional só oferece slot se houver `required_count` recursos distintos livres por tipo, incluindo locks de manutenção e appointments; a RPC continua a autoridade final. Proteger UI/HTTP novo com `agenda_full_validation_enabled` desligada por padrão sem desativar integridade do banco. Substituir DELETE direto por RPC autorizada; triggers universais preservam a integridade também para outros escritores.

**Aceite:** testes Node de auth, unit scope, entrada inválida, idempotência, diff, 2 recursos exigidos e 1 livre, concorrência informativa, flag off/on e remoção; lint backend sem erros. Não expor `service_role` ao navegador.

Blocked by: [063](063-onda7-resource-allocation.md), [064](064-onda7-resize-calendar-conflicts.md).
Blocks: [066](066-onda7-agenda-resize-ui.md).
