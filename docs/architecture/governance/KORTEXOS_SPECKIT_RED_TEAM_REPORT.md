---
title: "Red Team — Integração controlada do Spec Kit"
status: "EM_REMEDIACAO"
stage: "EXECUTION"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "docs/architecture/governance/KORTEXOS_SPECKIT_OPTIMIZATION_IMPLEMENTATION_PLAN.md"
last_updated: "2026-08-10"
---

# Red Team — Integração controlada do Spec Kit

## Escopo e evidência

Revisão adversarial executada pessoalmente no worktree limpo `C:\tmp\kortexos-speckit-adoption`, branch `codex/speckit-adoption-validation`, commit `4f04148`, acompanhando `origin/staging`. O workflow foi executado com `specify-cli 0.12.11`; os runs e os comandos permanecem no worktree temporário.

## GATES_EVALUATION

| Gate | Resultado | Evidência |
|---|---|---|
| Escopo/cânone | PASS | `git diff --stat origin/staging..HEAD`; somente `.specify/kortex`, governança e issues; nenhum backend/frontend/supabase/migration no commit. |
| Contrato/evals | PASS | `contract-eval.mjs`: `20/20` válidos e `10/10` inválidos bloqueados no campo esperado. |
| Pre-flight/root | PASS | Worktree limpo: `GO`, `origin_ref=origin/staging`, `ahead 1`; raiz falsa bloqueou com exit `2`. |
| Promotion gate | PASS | `task_class=promotion` bloqueou com exit `2`. |
| Benchmark Gate | PASS | `task_class=product-behavior` sem aprovação abortou no step `benchmark-gate` (`da245704`). |
| Fan-out/rollback | PASS | `fanout-eval.mjs`: 2 workers, worktrees isoladas, write sets disjuntos; rollback somente dry-run. |
| Segredos | PASS | scan dos artefatos e documentação: `SECRET_SCAN=clean`; handoff com conteúdo secret-like bloqueou com exit `2`. |
| Migration/Blueprint | FAIL | `task_class=migration` com `approval=approve` completou (`8c830a44`) sem exigir Blueprint, Etapa 8 ou evidência SQL. |
| Worktree sujo | FAIL | Pre-flight com `clean=false` e `task_class=mechanical` retornou `GO` (`PREFLIGHT_DIRTY_EXIT=0`). |
| Adapter de saída | PASS COM RISCO ACEITO | O workflow usa `--output -`, mas o adapter também aceita e grava em qualquer caminho explícito (`ADAPTER_WRITE_EXIT=0`). |

Gates de dinheiro, estoque, agenda, Supabase, PWA e Render foram classificados como `BLOQUEADO — não aplicável`: o commit não contém código de produto, schema, deploy ou ambiente externo.

## VULNERABILITIES_FOUND

1. **P1 — ausência de gate de Migration/Blueprint.** A classificação `migration` chega ao handoff `GO` quando `approval=approve`, sem verificar Blueprint aprovado, Etapa 8, pre-flight SQL ou `$tdd`. Embora o workflow atual não tenha step de mutação, o veredito pode ser interpretado como autorização indevida por uma etapa futura.
2. **P2 — pre-flight aceita worktree sujo para tarefa mecânica.** O resultado expõe `clean=false`, mas não bloqueia. Alterações não relacionadas podem contaminar comandos shell ou a evidência de um run.
3. **P2 — adapter possui escrita arbitrária quando recebe `--output`.** O caminho integrado usa stdout, mas o script não restringe o destino a stdout ou a um diretório de run allowlisted; sob shell não sandboxed, isso amplia a superfície de sobrescrita.

## VEREDITO

**NO-GO para tarefas sensíveis, migration, implementação ou qualquer fluxo que possa interpretar `GO` como autorização de mutação.**

**GO limitado a read-only/dry-run**, com a condição de que o fluxo não avance para código, schema, deploy ou promoção até a [issue 054](../../../issues/054-speckit-redteam-remediation.md) ser implementada e revalidada.

## DOCUMENTATION_CHECK

- [x] Relatório classificado em `docs/architecture/governance/`.
- [x] Frontmatter YAML preenchido.
- [x] `docs/INDEX.md` e issue corretiva atualizados no mesmo turno.
- [x] Nenhuma correção foi aplicada silenciosamente durante o Red Team.
