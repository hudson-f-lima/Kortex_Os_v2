---
title: "SPK-005 — Pre-flight de ambiente e ferramenta"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 048 — Pre-flight de ambiente e ferramenta

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Implementar o pre-flight determinístico que valida raiz autorizada, branch, commit, origem remota, CLI pinado, ausência de credenciais no contexto e modo de execução antes de qualquer step sensível.

## Acceptance criteria

- [ ] Raiz correta, branch, commit e `origin` são registrados.
- [ ] `main`/`staging`, divergência remota e CLI fora do pin bloqueiam o run sensível.
- [ ] O pre-flight não imprime segredos, tokens, PII ou conteúdo bruto.
- [ ] O resultado é consumível pelo contrato de run e pelo handoff.

## Blocked by

- Blocked by [`issues/047-speckit-kortexos-workflow.md`](047-speckit-kortexos-workflow.md)

## User stories addressed

- User story 1
- User story 3
- User story 7
