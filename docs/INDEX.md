# KortexOS — Central SSoT de Documentação

Este é o ponto de entrada navegável da documentação ativa do KortexOS 5.1.2. A estrutura segue Diátaxis: arquitetura explica o porquê, referência descreve o contrato, ondas registram a execução e how-to reúne procedimentos operacionais.

## Autoridade e ordem de leitura

1. [`AGENTS.md`](../AGENTS.md) — invariantes, governança e formato de handoff.
2. [Master Briefing Canônico](KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md) — visão normativa de produto, agora composta por três módulos.
3. [Truth Map](waves/KORTEXOS_5_1_2_TRUTH_MAP.md) e [Migration Map](waves/KORTEXOS_5_1_2_MIGRATION_MAP.md) — verdade técnica e plano aprovado.
4. A documentação da onda em execução — blueprint, evidência e issues correspondentes.
5. A habilidade aplicável em `.agents/skills/`.

Documentação de visão não autoriza schema, endpoint, tela, deploy ou promoção. A promoção sempre segue os gates de `feature` → `staging` → `main` definidos em `AGENTS.md`.

## Estado atual da trilha 5.1.2

| Onda | Estado factual | Limite de promoção | Fonte primária |
|---|---|---|---|
| Onda 0 — Units | **REAL**; blueprint aprovado, implementação validada e em `staging` | Não autoriza produção por si só | [Onda 0](waves/onda-0-units/) |
| Onda 1 — Payment Core | **PARCIAL**; correção forward-only autorizada por DEC-38 | `NO-GO` para `main`/produção até homologação e decisão formal | [Onda 1](waves/onda-1-payment-core/) |
| Onda 2 — KortexFlow Ledger | **REAL local**; fatias 012–016 e hardening de ledger regularizados por DEC-42 | `NO-GO` para `staging`/`main` até Environment Guardian, Delivery Guardian e homologação | [Onda 2](waves/onda-2-kortexflow-ledger/) |

## Arquitetura e decisões

- [Parte I — Visão e Tese do Master Briefing](architecture/vision/KORTEXOS_5_1_2_MASTER_BRIEFING_VISAO_TESE.md)
- [Decision Log](architecture/governance/KORTEXOS_5_1_2_DECISION_LOG.md) — DEC/D append-only e [matriz DEC ↔ ADR](architecture/governance/KORTEXOS_5_1_2_DECISION_LOG.md#matriz-cruzada-dec--adr).
- [ADRs](architecture/adr/) — decisões técnicas e seus vínculos com ondas.
- [Global Benchmark Map](architecture/vision/KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md)
- [Comparative Proposal](architecture/vision/KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md)
- [Pontos Cegos Pré-Blueprint](architecture/vision/KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md)
- [Instrução histórica de Truth Map](architecture/governance/instructions/KORTEXOS_5_1_2_INSTRUCAO_CLAUDE_CODE_TRUTH_MAP.md)

## Referência

- [Parte II — Cadastros Canônicos](reference/data-dictionaries/KORTEXOS_5_1_2_CADASTROS_CANONICOS.md)
- [Parte III — Políticas de Negócio](reference/business-policies/KORTEXOS_5_1_2_POLITICAS_DE_NEGOCIO.md)
- [Assets do Design System](reference/design-system/assets/)

## Ondas, diagnóstico e evidência

- [Truth Map](waves/KORTEXOS_5_1_2_TRUTH_MAP.md) e [Adendo D02](waves/KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md)
- [Migration Map v1.2](waves/KORTEXOS_5_1_2_MIGRATION_MAP.md)
- [Onda 0 — Units](waves/onda-0-units/) — blueprint, Red Team, implementação e handoff.
- [Onda 1 — Payment Core](waves/onda-1-payment-core/) — blueprint e verificação corretiva.
- [Onda 2 — KortexFlow Ledger](waves/onda-2-kortexflow-ledger/) — blueprint da fundação sem ativação.

## Como fazer

- [Guia de procedimentos](how-to/README.md) — localização reservada para receitas operacionais que não sejam fontes de regra de negócio.

## Issues executáveis

- [Índice de issues](../issues/README.md) — rastreabilidade por onda, PRD e estado de execução. Os arquivos de issue permanecem no caminho estável `issues/` para não quebrar a cadeia DEC → Blueprint → Issue → código.

## Arquivo histórico

- [Legado do MVP técnico](legacy/mvp-tecnico/README.md) — contexto histórico, não fonte ativa de escopo desde DEC-29.
- [Snapshots arquivados](legacy/archive/) — preservação não normativa de documentos anteriores à reorganização.

## Regra de dupla verdade documental

O código e os testes executados prevalecem sobre texto de planejamento. O estado canônico de negócio vem do Master Briefing; o estado técnico vem do Truth Map; a autorização e o histórico vêm do Decision Log; e a execução de cada onda é demonstrada por seus artefatos e evidências. Quando houver conflito, registre-o como `CONTRADITÓRIO`; não o resolva por inferência.
