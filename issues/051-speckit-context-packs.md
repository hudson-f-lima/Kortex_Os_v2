---
title: "SPK-008 — Context packs progressivos e converge"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 051 — Context packs progressivos e converge

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Materializar packs por domínio e uma etapa de converge que verifica drift antes de retomar ou implementar. O pack carrega regras mínimas sempre e documentos de domínio sob demanda.

## Acceptance criteria

- [ ] Existem packs para auditoria, Blueprint, SQL, Express, PWA, QA e promoção.
- [ ] Invariantes críticas permanecem presentes em todos os packs aplicáveis.
- [ ] Hashes detectam drift entre carregamento e converge.
- [ ] O relatório mede redução de contexto sem transformar pack em nova fonte de verdade.

## Blocked by

- Blocked by [`issues/046-speckit-source-adapter.md`](046-speckit-source-adapter.md)
- Blocked by [`issues/049-speckit-evals.md`](049-speckit-evals.md)

## User stories addressed

- User story 4
- User story 6
