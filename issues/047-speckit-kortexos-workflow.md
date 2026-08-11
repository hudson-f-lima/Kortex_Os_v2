---
title: "SPK-004 — Workflow KortexOS v1 com gates"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 047 — Workflow KortexOS v1 com gates

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Versionar o workflow local que encadeia sincronização de refs, classificação, contexto progressivo, Truth/Blueprint/Issue check, Benchmark Gate quando aplicável, revisão HITL, pre-flight, verificação e handoff. A primeira execução integrada permanece dry-run.

## Acceptance criteria

- [ ] Tarefas read-only e mecânicas seguem o caminho AFK curto sem mutação.
- [ ] Tarefas de produto pausam no Benchmark Gate sem aprovação explícita.
- [ ] Migration e promoção permanecem bloqueadas sem seus Guardians/gates próprios.
- [ ] O run interrompe antes de qualquer mutação externa e produz handoff verificável.

## Blocked by

- Blocked by [`issues/046-speckit-source-adapter.md`](046-speckit-source-adapter.md)

## User stories addressed

- User story 2
- User story 3
- User story 7
