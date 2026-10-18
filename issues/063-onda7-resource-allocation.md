---
title: "Onda 7 — alocação e backfill transacionais"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-69"]
upstream_doc: "docs/waves/onda-7-agenda-drag-resize/BLUEPRINT_ONDA_7_RESIZE.md"
last_updated: "2026-10-18"
---

# 063 — Reserva obrigatória em todos os escritores

Adicionar primitiva de alocação por tipo/quantidade e triggers universais de integridade de `appointments` em INSERT/UPDATE/DELETE. Tratar criação direta, série, grupo, waitlist, replan, cancelamento, conclusão e exclusão física; não liberar lock manual. Usar a mesma serialização por organização/unidade/serviço na ativação do conjunto e nos escritores antes de ler a versão ativa, e serialização determinística por tipo/recurso na seleção. A ativação faz backfill de appointments ocupantes com `ends_at > transaction_timestamp()`, incluindo `in_service` já iniciado, com reserva apenas do intervalo remanescente; conflito mantém versão anterior e nenhum lock parcial. `resource_lock_release` externo rejeita lock automático obrigatório de appointment ocupante. Migrar o DELETE direto do Express para RPC autorizada e verificar grants DML reais; os triggers preservam a integridade também para DML direto e `service_role`.

**Aceite:** pgTAP cobre cada escritor, DML direto com papéis reais, ordem dos triggers inclusive preenchimento de unidade, corrida em duas sessões (ativação NOWAIT vs. writer que já travou appointment; ativação vs. criação; dois bookings pelo último recurso), release indevido por RPC e UPDATE/DELETE direto de `resource_locks`, rollback do grupo, série parcial, recurso manual concorrente, cancelamento e DELETE. Incluir backfill durante atendimento em andamento, ausência de reivindicação retroativa, transição de status não ocupante→ocupante sem mudança de horário com calendário revalidado e rollback de lock e appointment juntos. Teste de volume decide se ativação atômica é viável; se não, implementar estado pendente por lotes antes de ligar a configuração. `supabase db reset`/pgTAP/lint SQL verdes.

Blocked by: [062](062-onda7-resource-requirement-schema.md).
Blocks: [064](064-onda7-resize-calendar-conflicts.md), [065](065-onda7-express-availability.md).
