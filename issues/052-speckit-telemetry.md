---
title: "SPK-009 — Telemetria e rastreabilidade"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 052 — Telemetria e rastreabilidade

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Registrar eventos estruturados por run: versão, hash do workflow, contexto, steps, gates, workers, duração, retries, pausas, retomadas, arquivos referenciados, testes, bloqueios e veredito.

## Acceptance criteria

- [ ] Cada run tem `run_id` e proveniência verificável.
- [ ] Retries, pausas, falhas e retomadas são distinguíveis.
- [ ] Logs não contêm segredos, PII, tokens ou conteúdo bruto.
- [ ] O relatório separa métricas medidas de métricas desconhecidas, incluindo tokens/custo.

## Blocked by

- Blocked by [`issues/050-speckit-safe-fanout.md`](050-speckit-safe-fanout.md)
- Blocked by [`issues/051-speckit-context-packs.md`](051-speckit-context-packs.md)

## User stories addressed

- User story 6
- User story 7
