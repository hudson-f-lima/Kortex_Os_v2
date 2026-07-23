# Legacy — MVP técnico (Trilhas A–E)

**Arquivado em:** 2026-07-20, por decisão do Platform Owner ([DEC-29](../../KORTEXOS_5_1_2_DECISION_LOG.md)).

## O que é esta pasta

Esta pasta reúne toda a documentação de planejamento e estado operacional da **construção do MVP técnico** do KortexOS — as Trilhas A a E descritas historicamente em `docs/INDEX.md` — agora formalmente **encerrada**. Nenhum arquivo aqui foi apagado ou reescrito em substância: cada um recebeu apenas um banner de arquivamento no topo (quando referenciado com frequência) e foi movido para cá, preservando o histórico do `git log`/`git blame`.

Nada disto significa que o MVP estava errado ou que deixou de existir — ele continua rodando em produção. Significa que **a fase de construção guiada por esses documentos terminou**, e todo trabalho novo passa a ser planejado e executado sob a visão de produto final (Trilha F, 5.1.2), não mais sob a numeração de "Fases 8+" definida em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md`.

## Conteúdo

| Arquivo | O que descrevia |
|---|---|
| `KORTEX_MVP_TECNICO.md` | Arquitetura greenfield, modelo multi-tenant e escopo rígido do MVP (Trilha A) |
| `PROJECT_STATE.md` | Estado operacional ao vivo do workspace até o encerramento — inclui o histórico completo de "Resolvido em ..." (bugs, migrations, incidentes) que continua sendo referência técnica válida sobre *como* certos problemas foram diagnosticados e corrigidos |
| `PLANEJAMENTO_EXECUCAO_UNIFICADO.md` | Fonte canônica de numeração de Fases 8–19 — **substituída** pelas Ondas de `../../KORTEXOS_5_1_2_MIGRATION_MAP.md` |
| `PLANEJAMENTO_FINANCEIRO.md` | Planejamento da Camada 1 financeira — executado como Fase 9 |
| `PLANEJAMENTO_COMISSOES.md` | Planejamento de comissionamento (cascata, escalonamento, pacotes) — parcialmente executado (Fase 9/10); o que ficou pendente (comissões escalonadas) agora é escopo do Migration Map (Onda 3, Compensation) |
| `PWA_PLANEJAMENTO.md` | Plano de produto/UX original da PWA — executado (Fase 6 + Ondas 1-7 do Design System) |
| `PLANEJAMENTO_ROADMAP_POS_MVP.md` | Mapeamento D00–D31 vs. MVP e pesquisa de retenção/rebooking/membership — já se autodeclarava superseded por este mesmo documento antes do encerramento; a pesquisa de mercado nele permanece um bom achado histórico |
| `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md` | Blueprint da Availability Engine (Fase 15) — tema agora coberto por `KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md` e pela Onda 4 do Migration Map |
| `PLANEJAMENTO_AGENDA_TRANSACIONAL.md` | Blueprint do motor de mutação de agendamentos (Fase 16) — tema agora coberto pelo Master Briefing 5.1.2 (D07-D09) |
| `FASE_10_PLANO.md` / `FASE_10_STATUS.md` | Plano e status da Fase 10 (capacidades N:N profissional×serviço) — concluída |
| `REDTEAM_FASE7.md` | Vereditos de segurança/CI da Fase 7 — concluída |
| `P0_AUDITORIA_SERVICOS_PROFISSIONAIS.md` | Auditoria real de schema/backend/PWA que motivou a Opção C — concluída, achados incorporados |
| `SERVICE_PROFESSIONAL_OPTION_C_AUDIT.md` | Relatório final da auditoria executável da Opção C (Phase 1) — concluída |
| `PROMPT_ONDA6_DESIGN_SYSTEM.md` | Prompt técnico de execução usado para implementar o Kortex Design System (Ondas 0-7) — já executado; renomeado de `instrução designer.md` (estava em `docs/kortex-5.1.2-design/`, pasta reservada a referências de design ativas, não a briefs de tarefas concluídas) |

## O que ficou ativo (não está aqui)

- `docs/adr/0001` a `0015` — Architecture Decision Records permanentes, nunca arquivados (convenção própria do projeto)
- `docs/KORTEXOS_5_1_2_*.md` — Trilha F, a visão de produto final vigente e a trilha de execução ativa a partir de agora
- `docs/kortex-5.1.2-design/` — assets de referência de design para o produto final (mockup + Design System docx)

Para a navegação completa e atualizada, ver [`docs/INDEX.md`](../../INDEX.md).
