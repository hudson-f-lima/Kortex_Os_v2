---
title: "SPK-010 — Gate de adoção controlada e rollback"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 053 — Gate de adoção controlada e rollback

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Consolidar os resultados dos incrementos em um gate de adoção que só permita sair do dry-run com evidência dos evals, pre-flight, handoff, fan-out, contexto, telemetria e rollback. A decisão final permanece HITL.

## Acceptance criteria

- [ ] O gate emite `ADOPT_WITH_CONSTRAINTS`, `PAUSE` ou `REJECT` com evidência referenciada.
- [ ] A integração permanece limitada por dois workers, allowlist de aprovação e sem mutação externa autônoma.
- [ ] Rollback remove somente `.specify/kortex/` e seus registros explícitos, preservando o MAS e o produto.
- [ ] O handoff identifica blockers e a condição de parada para a próxima rodada.

## Blocked by

- Blocked by [`issues/052-speckit-telemetry.md`](052-speckit-telemetry.md)

## User stories addressed

- User story 3
- User story 6
- User story 7
