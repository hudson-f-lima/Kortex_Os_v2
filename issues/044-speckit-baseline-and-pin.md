---
title: "SPK-001 — Baseline, pin e proveniência do Spec Kit"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 044 — Baseline, pin e proveniência do Spec Kit

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Versionar a configuração mínima de integração em `.specify/kortex/`, fixando `specify-cli 0.12.11`, o hash do workflow aprovado, o modo `constrained` e as superfícies proibidas. O artefato deve apontar para a baseline SPK sem copiar seu conteúdo.

## Acceptance criteria

- [ ] A versão, fonte, hash e data do workflow estão registradas.
- [ ] O modo inicial é `read-only`/`dry-run` e a lista de ações proibidas é explícita.
- [ ] O pre-flight falha se a raiz autorizada ou a referência do Git não puder ser comprovada.
- [ ] Nenhum arquivo de produto, migration ou skill canônica é alterado.

## Blocked by

None - can start immediately.

## User stories addressed

- User story 1
- User story 7
