---
title: "SPK-002 — Contrato de run e handoff"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 045 — Contrato de run e handoff

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Adicionar o schema e o validador do contrato que representa `run`, `verification` e `handoff`, incluindo owner, classificação, gates, artefatos, bloqueios, veredito e condição de parada.

## Acceptance criteria

- [ ] 20 casos válidos passam no schema.
- [ ] 10 casos inválidos são rejeitados no campo esperado.
- [ ] Handoff sem testes, bloqueios, veredito ou condição de parada é bloqueado.
- [ ] O validador não lê nem replica conteúdo bruto das fontes canônicas.

## Blocked by

- Blocked by [`issues/044-speckit-baseline-and-pin.md`](044-speckit-baseline-and-pin.md)

## User stories addressed

- User story 2
- User story 6
