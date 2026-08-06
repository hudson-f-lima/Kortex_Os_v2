---
name: kortex-mvpt-orchestrator
description: Orquestra agentes especialistas para planejar, desenhar, fatiar em incrementos testáveis e revisar o KortexOS, onda por onda.
---

# Orquestrar o MVPT KortexOS

## 1. Quando ativar
- Solicitações de planejamento de macro-tarefas, fatiamento de funcionalidades do MVP ou coordenação de múltiplos agentes especialistas.

## 2. Quando não ativar
- Tarefas focadas em um único domínio específico (ex: escrever queries SQL, criar rotas Express, ajustar UI).

## 3. Objetivo
- Fatiar metas em incrementos curtos e seguros, coordenando especialistas e garantindo integridade arquitetural sem expandir escopo.

## 4. Entradas necessárias
- [AGENTS.md](AGENTS.md) (regras e invariantes)
- [docs/KORTEXOS_5_1_2_TRUTH_MAP.md](docs/KORTEXOS_5_1_2_TRUTH_MAP.md) e [docs/KORTEXOS_5_1_2_MIGRATION_MAP.md](docs/KORTEXOS_5_1_2_MIGRATION_MAP.md) (realidade técnica e mapeamento vigentes; `PROJECT_STATE.md` em `docs/legacy/mvp-tecnico/` é só histórico do MVP encerrado em 2026-07-20, DEC-29)
- Definição do incremento/Onda solicitado pelo usuário.

## 5. Fluxo mínimo
1. Carregar Truth Map e Migration Map vigentes para basear decisões na realidade física do código, não em otimismo.
2. **Benchmark Gate:** antes de delegar decisão de comportamento de produto, exigir benchmark na ordem Booksy → principais players → cross-industry quando aplicável. O handoff deve conter links e distinguir `FATO`, `INFERÊNCIA` e `DECISÃO`; ausência de precedente Booksy é registrada, não ignorada.
3. **Desenho:** delegar a `$kortex-blueprint-architect`, que fecha decisões abertas via `$grill-me` e Benchmark Gate antes de redigir o Blueprint.
4. **Fatiamento:** delegar a `$prd-to-issues` para quebrar o Blueprint aprovado em fatias verticais pequenas (`issues/NNN-titulo.md`), marcadas `HITL`/`AFK` — nunca uma migration monolítica para a Onda inteira.
5. **Implementação:** cada fatia é implementada via `$tdd` (teste antes do código, uma fatia por vez).
6. **Validação:** `$kortex-qa-redteam` ataca cada fatia relevante e o conjunto final, sempre com evidência bruta reverificada, nunca relato resumido de subagente.
7. **Integração:** consolidar mudanças conflitantes entre fatias, registrar DEC/ADR de cada aprovação formal (ver `references/mas-contracts.md`, "Registro automático de decisão") e produzir o relatório final.

Ver [references/mas-contracts.md](references/mas-contracts.md) para o contrato completo de ondas/gates e [references/incorporated-skills.md](references/incorporated-skills.md) para qual skill do ecossistema aberto cobre qual onda.

## 6. Restrições críticas
- Proibir edição simultânea do mesmo arquivo por múltiplos agentes.
- Garantir que o tenant seja derivado de membership autenticada, rejeitando parâmetros isolados.
- Impedir exposição de chaves privilegiadas (`service_role`) e cálculos financeiros no frontend.
- Validar migrations novas localmente via Supabase CLI antes do deploy.
- Proibir migration de Onda inteira em um único incremento não fatiado — toda Onda passa pela etapa de Fatiamento antes de qualquer SQL.
- Não delegar ou aprovar decisão de produto sem o Benchmark Gate; se faltar evidência, o domínio fica `BLOQUEADO` até a comparação ser registrada.
- Nunca consolidar o relatório final de uma Onda/fatia com base só no relato de um subagente delegado (`$kortex-blueprint-architect`, `$prd-to-issues`, `$tdd`, `$kortex-qa-redteam`) sobre arquivos alterados, testes executados ou gate aprovado — reexecutar pessoalmente `git status`/`git diff` para confirmar os arquivos realmente alterados, e reexecutar o comando de teste que o subagente alega ter passado, antes de registrar o `VEREDITO` final.

## 7. Arquivos que podem ser carregados
- [docs/INDEX.md](docs/INDEX.md)
- [references/mas-contracts.md](references/mas-contracts.md)
- [references/incorporated-skills.md](references/incorporated-skills.md)

## 8. Condição de parada
- Incremento fatiado, implementado fatia por fatia com teste antes do código, validado por QA/Red Team com evidência bruta, aprovado pelo usuário e com DEC/ADR já registrados — não pendente de lembrete.

## 9. Formato de saída
```text
FILES_CHANGED:
- <caminho: natureza da mudança>
BLOCKERS_REMAINING:
- <pendências ou "nenhum">
VEREDITO:
- <classificação, decisão e próximo passo único>
```
