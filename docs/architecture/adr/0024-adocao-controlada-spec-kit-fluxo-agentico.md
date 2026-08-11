---
title: "ADR 0024 — Adoção controlada do Spec Kit no fluxo agêntico"
status: "ACCEPTED"
stage: "ADR"
governance_ref: ["DEC-59"]
upstream_doc: "docs/architecture/governance/KORTEXOS_SPECKIT_OPTIMIZATION_IMPLEMENTATION_PLAN.md"
last_updated: "2026-08-10"
---

# ADR 0024: Adoção controlada do Spec Kit no fluxo agêntico

## Status

**Accepted (DEC-59, 2026-08-10).** O Platform Owner aprovou a integração controlada após o piloto SPK-0–SPK-7. A aprovação não autoriza execução autônoma de produto, migrations, deploy, promoção ou ativação de feature flag.

## Contexto

O piloto isolado com `specify-cli 0.12.11` comprovou redução de 41,7% no tempo do fan-out e redução média de 51,62% no contexto, mantendo contrato, evals, gates e ausência de escritas externas. Também revelou limites: `verdict_input` não é confiável como controle de segurança nessa versão, shell steps não possuem sandbox de capabilities, e custo/tokens ainda não são observáveis.

O KortexOS já possui MAS, skills `kortex-*`, Guardians, Truth Map, Migration Map, Blueprints, ADRs e DECs. Duplicar essas fontes ou permitir que um `spec.md` assuma autoridade criaria drift e risco operacional.

## Decisão

Adotar o Spec Kit seletivamente como motor de workflow e estado, por meio de uma integração local e versionada sob `.specify/kortex/`, com estas regras:

- `specify-cli` permanece pinado em `0.12.11` até nova avaliação.
- `AGENTS.md`, fontes canônicas, MAS, Guardians, Blueprints, ADRs e DECs permanecem autoridade superior.
- O modo padrão é read-only/dry-run; escrita sensível exige gate HITL allowlisted.
- `verdict_input` não libera etapa sensível; o adapter de aprovação explícita é o único caminho aceito até nova evidência.
- Shell steps são tratados como não sandboxed e passam por revisão de comandos.
- Paralelismo é limitado inicialmente a dois workers, worktrees isoladas e write sets disjuntos.
- Logs guardam IDs, hashes, paths, resumos e evidência; não guardam segredos, PII, tokens ou conteúdo bruto.
- Cada run exige pre-flight, contrato de handoff, verificação, telemetria e condição de parada.
- Rollback remove apenas a infraestrutura `.specify/kortex/` e seus artefatos explicitamente criados.

## Alternativas consideradas

### `specify init --here --force`

Rejeitada. Pode instalar arquivos gerenciados, skills e templates sobre superfícies canônicas, além de criar uma segunda constituição.

### Permanecer somente no piloto descartável

Rejeitada após o ganho mensurável, mas a decisão preserva as restrições do piloto no primeiro ciclo integrado.

### Substituir o MAS por workflows do Spec Kit

Rejeitada. O Spec Kit orquestra execução e estado; não decide domínio, arquitetura, tenant, schema, ambiente ou promoção.

## Consequências

- O fluxo ganha pre-flight, contrato, gates, fan-out seguro, contexto progressivo, converge e telemetria versionados.
- A integração terá overhead de revisão de shell, allowlist de aprovação e manutenção do pin.
- A adoção não será considerada plena até os evals, rollback e métricas de custo permanecerem verdes em runs reais controlados.
- Qualquer mudança de comportamento de produto continua sujeita ao Benchmark Gate e decisão do Platform Owner.

## DOCUMENTATION_CHECK

- [x] ADR classificada em `docs/architecture/adr/`.
- [x] Frontmatter YAML preenchido.
- [x] `docs/INDEX.md` e matriz DEC↔ADR serão atualizados no mesmo turno.
- [x] Nenhuma decisão anterior é supersedida; esta ADR limita e operacionaliza o plano SPK.
