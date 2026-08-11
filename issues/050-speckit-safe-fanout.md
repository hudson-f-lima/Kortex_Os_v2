---
title: "SPK-007 — Fan-out/fan-in seguro"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 050 — Fan-out/fan-in seguro

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Adicionar o scheduler restrito a dois workers, com declaração de dependências, write sets obrigatórios, worktrees isoladas e fan-in que verifica HEAD, limpeza, artefatos e conflitos antes de consolidar.

## Acceptance criteria

- [ ] Tarefas com write sets sobrepostos são serializadas ou bloqueadas.
- [ ] Workers usam worktrees descartáveis e não escrevem na branch compartilhada.
- [ ] Fan-in rejeita worker ausente, worktree suja, HEAD divergente ou evidência incompleta.
- [ ] O piloto mede ganho de tempo sem regressão nos evals.

## Blocked by

- Blocked by [`issues/049-speckit-evals.md`](049-speckit-evals.md)

## User stories addressed

- User story 5
- User story 6
- User story 7
