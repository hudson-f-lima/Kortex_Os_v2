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
| Onda 3 — Compensation | **REAL em `staging`** — as 6 fatias (017-022: Feature Flag, staff_levels, staff_level_service_overrides/resolve_service_pricing, comissão de venda, vínculo pacote↔pedido, imutabilidade) mescladas via PR #24 e PR #25, implementadas via `$tdd` (661/661 pgTAP, backend 301/301, PWA 108/108, todos verificados pessoalmente contra a aplicação real rodando localmente, não só pgTAP). Blueprint aprovado por DEC-46; Etapa 8 e a promoção a `staging` regularizadas por DEC-47; achados de auditoria pós-merge (P1/P2/P3) corrigidos pelas fatias 021-022 sob emenda DEC-48. Produção segue em Fase 11 — nenhuma migration da trilha 5.1.2 chegou lá | `NO-GO` para `main`/produção até os gates de ambiente/entrega/homologação (bloqueados por DEC-40, `kortex-api-staging` suspenso por billing) | [Onda 3](waves/onda-3-compensation/) |
| Onda 4 — Calendar Policy, Availability Resolver & Resource Orchestration | **REAL em `staging`** — Blueprint aprovado (DEC-49), fundação sem ativação (`create_appointment`/`checkout_close` intocados). As 6 fatias (023-028) implementadas e mescladas via PR #27 (`1f55d70`); Red Team de implementação pós-Etapa-8 e auditoria final de fix corrigiram os gaps reais conhecidos (unit scope, elegibilidade tri-state, isenção `exceptional_opening` removida, timezone, validação estrita de data, lint SQL, entre outros — ver ADR 0022). Evidência final: 764/764 pgTAP, 321/321 backend (`node --test`), `supabase db lint --local` sem erros, sem regressão | `NO-GO` para `main`/produção até os gates de ambiente/entrega/homologação | [Onda 4](waves/onda-4-calendar-availability/) |
| Onda 5 — Recurring, Group Booking & Waitlist | **REAL local, fechada (DEC-57)** — DEC-54 abriu as fatias corretivas 036-040; todas implementadas e verificadas em reset limpo local (908/908 pgTAP, 325/325 backend, lint sem achados). Red Team final de implementação sobre 029-040 classificou `GO`: nenhum gap crítico/alto, 4 achados de severidade baixa aceitos/backlog. O runtime AppCliente é backlog separado por DEC-56, não parte da ativação desta onda. | `NO-GO` para `staging`/`main`/produção sob DEC-52 (promoção é tarefa distinta) | [Onda 5](waves/onda-5-recurring-group-waitlist/) |
| Onda 6 — Checkout final: reabertura de comanda | **REAL em staging — homologada funcionalmente, dark launch preservado (DEC-68)**: schema e emenda forward-only aplicados; a PWA autenticada executou `requested` → `reopened` → `discarded` e confirmou duas tentativas auditáveis, links de ledger atribuídos, estoque restaurado e pedido final fechado. A flag `checkout_reopen_enabled` foi restaurada para desligada. Evidência: 1.068/1.068 pgTAP, 330/330 backend, lint limpo e CI verde nas PRs #50–#52. | `main`/produção e ativação permanecem bloqueados até o veredito final de Environment Guardian + Delivery Guardian | [Onda 6](waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md) |
| Onda 7 — Agenda: reagendamento por arraste e redimensionamento | **PARCIAL** — reagendamento por arraste (`starts_at`/`professional_id`) entregue, testado e **mesclado em `staging`** ([PR #46](https://github.com/hudson-f-lima/Kortex_Os_v2/pull/46), `ed21a2b`); redimensionamento de duração com Migration Map v1.3 **aprovado** (DEC-64), Blueprint ainda não iniciado | Etapa 7 (Blueprint) da Onda 7 **desbloqueada** — DEC-65 mesclado em `staging` ([PR #44](https://github.com/hudson-f-lima/Kortex_Os_v2/pull/44), `3c6327a`); Etapa 8 bloqueada em qualquer caso | [Handoff de continuidade](waves/onda-7-agenda-drag-resize/ONDA_7_CONTINUATION_HANDOFF.md) |

> **Atualização de promoção (DEC-58):** a Onda 5 está autorizada a seguir por PR de `feat/onda5-blueprint-and-fatia-029` para `staging` após CI verde. `main`/produção e a ativação da feature flag continuam bloqueados até homologação e Delivery Guardian.
> **Colisão de numeração (DEC-65, mesclada):** as branches `codex/onda6-checkout-reopen` e `codex/speckit-runner-telemetry` registraram DEC-62 de forma independente e não coordenada; a numeração canônica (DEC-62 Onda 6, DEC-63 runner, DEC-64 Onda 7) foi fixada em DEC-65, aprovada pelo Platform Owner e mesclada em `staging` via [PR #44](https://github.com/hudson-f-lima/Kortex_Os_v2/pull/44) (`3c6327a`, 2026-08-12). As duas branches originais ainda precisam alinhar sua numeração interna a este registro antes de seus próprios merges finais.

## Arquitetura e decisões

- [Parte I — Visão e Tese do Master Briefing](architecture/vision/KORTEXOS_5_1_2_MASTER_BRIEFING_VISAO_TESE.md)
- [Decision Log](architecture/governance/KORTEXOS_5_1_2_DECISION_LOG.md) — DEC/D append-only e [matriz DEC ↔ ADR](architecture/governance/KORTEXOS_5_1_2_DECISION_LOG.md#matriz-cruzada-dec--adr).
- Hardening dos agentes `kortex-*` (DEC-50): portabilidade de referências, guardrail de reverificação, subordinação dos vendor skills de UI ao Design System real, espelho em `.claude/skills/` e 5 hooks determinísticos em `.claude/hooks/` (`check-secret-commit.js`, `check-branch-protection.js`, `check-tenant-invariant.js`, `check-design-system.js`, `check-blueprint-gate.js`), registrados em `.claude/settings.json`.
- Benchmark Gate (DEC-53): Booksy → principais players → cross-industry, com evidência classificada em `FATO`/`INFERÊNCIA`/`DECISÃO`, exigido por `kortex-mvpt-orchestrator`, `kortex-blueprint-architect` e `kortex-qa-redteam`.
- [Protocolo de Automação Documental](architecture/governance/KORTEXOS_DOCUMENTATION_AUTOMATION_PROTOCOL.md) — regra prospectiva de Docs-as-Code para agentes (DEC-43).
- [ADRs](architecture/adr/) — decisões técnicas e seus vínculos com ondas (ver [ADR 0021](architecture/adr/0021-frontend-ux-responsiveness-and-adaptive-modals.md) para o Design System e Modais Adaptativos).
- [ADR 0023 — Onda 5](architecture/adr/0023-onda5-recurring-group-booking-waitlist.md) — recorrência, Group Booking pai/filhos e waitlist no modelo Booksy.
- [ADR 0024 — Adoção controlada do Spec Kit](architecture/adr/0024-adocao-controlada-spec-kit-fluxo-agentico.md) — motor de workflow subordinado ao MAS, com gates, pre-flight, runner read-only de fan-out, telemetria e rollback (DEC-59/DEC-63).
- [ADR 0025 — Onda 6](architecture/adr/0025-onda6-checkout-reopen-versioned-orders.md) — pedido vivo versionado e reabertura governada.
- [Programa de Convergência 6.x](architecture/governance/KORTEXOS_5_1_2_PROGRAMA_CONVERGENCIA_6X.md) — discovery read-only das correções e extensões pós-auditoria; não é Blueprint nem autoriza implementação (DEC-67).
- [Auditoria de Eficiências Transversais no Fluxo Agêntico](architecture/governance/KORTEXOS_AGENTIC_FLOW_EFFICIENCY_AUDIT.md) — maturidade do MAS contra práticas agentic da Anthropic; backlog AEF-01–12.
- [Plano de Otimização do Fluxo Agêntico](architecture/governance/KORTEXOS_AGENTIC_FLOW_OPTIMIZATION_PLAN.md) — fases F0–F6, gates, métricas e incrementos OPT-001–008.
- [Plano de Implementação das Otimizações com Spec Kit](architecture/governance/KORTEXOS_SPECKIT_OPTIMIZATION_IMPLEMENTATION_PLAN.md) — piloto seletivo, workflow, gates, evals, paralelismo e rollback.
- [SPK-BASELINE — Baseline de Compatibilidade do Spec Kit](architecture/governance/KORTEXOS_SPECKIT_BASELINE.md) — snapshot read-only, pin proposto, métricas e gate SPK-0.
- [Red Team — Integração controlada do Spec Kit](architecture/governance/KORTEXOS_SPECKIT_RED_TEAM_REPORT.md) — três gaps reproduzidos, remediados e revalidados; `GO COM RESTRIÇÕES` para dry-run controlado.
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
- [Onda 3 — Compensation](waves/onda-3-compensation/) — blueprint de Staff Levels & Comissão de Venda.
- [Onda 4 — Calendar Policy, Availability Resolver & Resource Orchestration](waves/onda-4-calendar-availability/) — blueprint aprovado, fundação sem ativação.
- [Onda 5 — Recurring, Group Booking & Waitlist](waves/onda-5-recurring-group-waitlist/) — Blueprint aprovado por DEC-51; fatias 029-040 implementadas e fechadas localmente (039: identidade AppCliente, inbox e outbox FCM; 040: gate de ambiente determinístico + correção de contaminação cross-tenant em 2 pgTAP legados; Red Team final `GO` por DEC-57); falta a infraestrutura externa de entrega de push (backlog DEC-56); promoção a `staging`/`main` segue não autorizada sob DEC-52.
- [Onda 6 — Checkout final: reabertura de comanda](waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md) — Blueprint aprovado por DEC-62; fatias 055–061 implementadas, Red Team local `GO`, schema aplicado e homologação autenticada concluída em staging sob DEC-68; dark launch, `main` e produção continuam bloqueados até os gates de promoção.
- [Onda 7 — Agenda: reagendamento por arraste e redimensionamento](waves/KORTEXOS_5_1_2_MIGRATION_MAP.md#onda-7--agenda-reagendamento-por-arraste-e-redimensionamento-d07-completa-m01--aprovada-dec-64-2026-08-11) — Migration Map v1.3 aprovado por DEC-64; Etapa 7 (Blueprint) desbloqueada (DEC-65 mesclado, PR #44), ainda não iniciada. Ver [handoff de continuidade](waves/onda-7-agenda-drag-resize/ONDA_7_CONTINUATION_HANDOFF.md).

> Atualização pós-fechamento: a fatia 042 eliminou o oráculo de existência intra-tenant, sem reabrir a Onda 5 nem autorizar promoção. Persistem somente os backlogs DEC-56, RLS self-service morta e o teste cross-tenant dedicado.

## Como fazer

- [Guia de procedimentos](how-to/README.md) — localização reservada para receitas operacionais que não sejam fontes de regra de negócio.

## Issues executáveis

- [Índice de issues](../issues/README.md) — rastreabilidade por onda, PRD e estado de execução. Issues concluídas passam por `issues/completed/` somente com atualização de todos os links de entrada; as demais permanecem no caminho estável `issues/`.

## Arquivo histórico

- [Legado do MVP técnico](legacy/mvp-tecnico/README.md) — contexto histórico, não fonte ativa de escopo desde DEC-29.
- [Snapshots arquivados](legacy/archive/) — preservação não normativa de documentos anteriores à reorganização.

## Regra de dupla verdade documental

O código e os testes executados prevalecem sobre texto de planejamento. O estado canônico de negócio vem do Master Briefing; o estado técnico vem do Truth Map; a autorização e o histórico vêm do Decision Log; e a execução de cada onda é demonstrada por seus artefatos e evidências. Quando houver conflito, registre-o como `CONTRADITÓRIO`; não o resolva por inferência.
