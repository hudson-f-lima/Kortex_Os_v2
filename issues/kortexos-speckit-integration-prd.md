---
title: "PRD — Integração controlada do Spec Kit no fluxo agêntico KortexOS"
status: "APROVADO"
stage: "ISSUE"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "docs/architecture/governance/KORTEXOS_SPECKIT_OPTIMIZATION_IMPLEMENTATION_PLAN.md"
last_updated: "2026-08-10"
---

# PRD — Integração controlada do Spec Kit no fluxo agêntico KortexOS

## Problem Statement

O piloto isolado do Spec Kit comprovou ganhos de paralelismo e redução de contexto, mas o repositório KortexOS ainda não possui uma camada versionada de execução, pre-flight, contrato, telemetria e rollback. A integração precisa preservar o MAS, as skills `kortex-*`, os Guardians e as fontes canônicas, sem transformar `spec.md` ou `plan.md` em autoridade arquitetural.

## Solution

Adicionar uma integração local, pinada em `specify-cli 0.12.11`, com workflows e adapters próprios sob `.specify/kortex/`. A integração começa em modo read-only/dry-run, exige gates HITL para produto, migration e promoção, registra contratos e evidências sem conteúdo bruto e limita o paralelismo a write sets disjuntos em worktrees isoladas.

## User Stories

1. Como orquestrador, quero validar branch, commit, raiz autorizada e fontes canônicas antes de iniciar um run.
2. Como agente, quero um contrato de run/handoff verificável, para que nenhum resultado incompleto seja aceito.
3. Como Platform Owner, quero gates explícitos para comportamento de produto, schema, ambiente e promoção.
4. Como equipe, quero carregar contexto progressivo por domínio, reduzindo custo sem perder invariantes críticas.
5. Como orquestrador, quero paralelizar somente tarefas com write sets disjuntos e fan-in verificável.
6. Como auditor, quero telemetria com `run_id`, versão, hashes, gates, retries, artefatos e veredito, sem segredos ou PII.
7. Como responsável de segurança, quero rollback que remova somente a infraestrutura do Spec Kit e restaure o MAS anterior.

## Invariants and boundaries

- `AGENTS.md`, Truth Map, Migration Map, Blueprint, ADRs/DECs e Guardians continuam superiores ao Spec Kit.
- A integração não cria tabela, migration, endpoint, regra de negócio ou feature flag de produto.
- Nenhum run integrado autoriza sozinho `staging`, `main`, produção ou ativação de feature flag.
- Shell steps são tratados como não sandboxed: ficam read-only ou atrás de gate HITL allowlisted.
- A versão do CLI fica pinada; `verdict_input` não é usado como controle de segurança no `0.12.11`.
- Logs registram referências, hashes e resumos; nunca tokens, JWTs, segredos, PII ou conteúdo bruto de ferramenta.

## Testing Decisions

- Validar schema com casos válidos e inválidos.
- Testar pre-flight em raiz correta, raiz errada, branch protegida e divergência remota.
- Testar gates sem aprovação, com aprovação válida e com input fora da allowlist.
- Testar contrato de handoff, ausência de drift e ausência de escrita externa no dry-run.
- Testar fan-out com dois workers, write sets disjuntos, conflito deliberado e fan-in incompleto.
- Testar rollback em diretório descartável, sem `git reset --hard` ou `git checkout --`.

## Out of Scope

- Execução autônoma de código de produto, migrations, deploy ou promoção.
- Instalação de skills `speckit-*` sobre `.agents/skills/` ou `.claude/skills/`.
- Uso de workflow remoto sem revisão e pin de proveniência.
- Medição de custo real de tokens enquanto a superfície não o expuser.

## Further Notes

O fatiamento executável está nas issues `044`–`053`. A aprovação do Platform Owner em 2026-08-10 libera somente a integração controlada descrita na ADR 0024; cada incremento mantém seu próprio gate e condição de parada.

## DOCUMENTATION_CHECK

- [x] Documento criado em `issues/` com frontmatter obrigatório.
- [x] Granularidade segue o plano aprovado SPK-001–SPK-010.
- [x] `docs/INDEX.md` e `issues/README.md` serão atualizados no mesmo turno.
- [x] Decisão registrada em DEC-59 e ADR 0024.
