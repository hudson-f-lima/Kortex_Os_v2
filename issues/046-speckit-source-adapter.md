---
title: "SPK-003 — Adapter read-only das fontes KortexOS"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "issues/kortexos-speckit-integration-prd.md"
last_updated: "2026-08-10"
---

# 046 — Adapter read-only das fontes KortexOS

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Criar o adapter que lê somente os paths canônicos autorizados e produz um context pack com branch, commit, tamanho e SHA-256, sem transportar o conteúdo dos documentos para o estado do workflow.

## Acceptance criteria

- [ ] A allowlist inclui `AGENTS.md`, `docs/INDEX.md`, Truth Map, Migration Map, protocolo documental e ADR relevante.
- [ ] O output contém hashes e referências reais do worktree.
- [ ] O processo falha em fonte ausente, raiz não autorizada ou Git inconsistente.
- [ ] Nenhuma escrita ocorre no repositório alvo.

## Blocked by

- Blocked by [`issues/045-speckit-run-contract.md`](045-speckit-run-contract.md)

## User stories addressed

- User story 1
- User story 4
- User story 6
