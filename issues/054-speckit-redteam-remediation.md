---
title: "SPK-RT-001 — Remediar gates de migration, worktree e adapter"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "docs/architecture/governance/KORTEXOS_SPECKIT_RED_TEAM_REPORT.md"
last_updated: "2026-08-10"
---

# 054 — Remediar gaps do Red Team do Spec Kit

## Parent PRD

[`issues/kortexos-speckit-integration-prd.md`](kortexos-speckit-integration-prd.md)

## What to build

Endurecer a integração controlada conforme o Red Team: tarefas `migration` só podem sair bloqueadas quando não houver Blueprint/Etapa 8/evidência de pre-flight SQL; tarefas sensíveis devem exigir worktree limpo; e o source adapter deve emitir stdout por padrão e restringir qualquer arquivo de saída a um diretório de run explicitamente allowlisted.

## Acceptance criteria

- [ ] `task_class=migration` sem Blueprint, Etapa 8 e evidência válida termina `BLOCKED`, nunca `GO`.
- [ ] `task_class=mechanical`/`migration`/`promotion` com `clean=false` termina `BLOCKED`.
- [ ] `source-adapter.mjs` não grava em caminho arbitrário; stdout continua funcionando.
- [ ] Os casos negativos têm reprodução automatizada e o workflow read-only continua `GO`.
- [ ] Red Team reexecutado pessoalmente em worktree limpo, sem mudança de produto.

## Blocked by

- Blocked by [`docs/architecture/governance/KORTEXOS_SPECKIT_RED_TEAM_REPORT.md`](../docs/architecture/governance/KORTEXOS_SPECKIT_RED_TEAM_REPORT.md)

## User stories addressed

- User story 2
- User story 3
- User story 7
