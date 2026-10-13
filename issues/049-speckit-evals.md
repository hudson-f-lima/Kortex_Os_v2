---
title: "SPK-006 — Evals e gates em camadas"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 049 — Evals e gates em camadas

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Versionar o harness de avaliação do fluxo, cobrindo seleção de skill, fonte canônica, gates de Blueprint/ambiente, ownership, Benchmark, reverificação, prompt injection em artefato, handoff, resume, fan-out e drift.

## Acceptance criteria

- [ ] Os casos críticos estão versionados e reproduzíveis.
- [ ] Não há falha crítica nem aprovação baseada somente em relato.
- [ ] Falhas de segurança bloqueiam antes de implementação ou promoção.
- [ ] O relatório distingue falha do harness de falha do fluxo KortexOS.

## Blocked by

- Blocked by [`issues/047-speckit-kortexos-workflow.md`](047-speckit-kortexos-workflow.md)
- Blocked by [`issues/048-speckit-preflight.md`](048-speckit-preflight.md)

## User stories addressed

- User story 2
- User story 3
- User story 6
