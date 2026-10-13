---
title: "Plano de Otimização do Fluxo Agêntico"
status: "DRAFT"
stage: "DECISION"
governance_ref: []
upstream_doc: "docs/architecture/governance/KORTEXOS_AGENTIC_FLOW_EFFICIENCY_AUDIT.md"
last_updated: "2026-08-04"
---

# Plano de Otimização do Fluxo Agêntico

## Objetivo

Reduzir tempo de ciclo, tokens, retrabalho e espera humana no MAS do KortexOS, preservando os gates de segurança, autoridade do Platform Owner, isolamento de tenant, integridade financeira e evidência verificável.

Este plano operacionaliza a [Auditoria de Eficiências Transversais](KORTEXOS_AGENTIC_FLOW_EFFICIENCY_AUDIT.md) e aplica a régua de [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents), [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) e [Trustworthy agents in practice](https://www.anthropic.com/research/trustworthy-agents).

## Limites

- Escopo: harness, skills, delegação, handoffs, ferramentas, contexto, gates e observabilidade.
- Fora do escopo: novas regras de negócio, migrations da Onda 5, promoção para `staging`/`main`, autonomia de escrita em produção e troca de fornecedor de modelo.
- Nenhuma decisão de produto é tomada por este plano; se uma implementação alterar comportamento de produto, aplica-se o Benchmark Gate Booksy → players → cross-industry.
- Os arquivos não rastreados já existentes da Onda 5 permanecem fora do escopo e não devem ser incorporados incidentalmente.

## Princípios de desenho

1. **Workflow antes de agente:** usar caminhos determinísticos para tarefas previsíveis; reservar autonomia para decomposição, investigação e recuperação quando o número de passos não for conhecido.
2. **Evidência antes de relato:** nenhum handoff ou gate é válido sem ref, ambiente, comando/ação e resultado verificável.
3. **Paralelismo condicionado:** somente tarefas com dependências resolvidas e write sets disjuntos podem rodar simultaneamente.
4. **Aprovação por risco:** leitura pode ser AFK; mutação externa, deploy, schema e decisão de produto permanecem HITL.
5. **Contexto progressivo:** carregar primeiro o contrato mínimo, depois apenas os documentos exigidos pelo domínio e pelo gate.
6. **Métrica antes de otimização:** toda redução de chamadas ou contexto precisa provar que não degradou qualidade, segurança ou completude.

## Resultado-alvo

Ao final do piloto, o fluxo deverá produzir, para cada execução:

```text
run_id → contexto carregado → delegações → ferramentas → decisões → evidências → gates → handoff
```

Metas do piloto, comparadas a uma baseline de 10–20 tarefas reais:

| Métrica | Meta | Regra de segurança |
|---|---:|---|
| Handoffs válidos pelo schema | 100% | inválido bloqueia consolidação |
| Divergência entre ambiente declarado e ferramenta usada | 0 | qualquer ocorrência é `NO-GO` |
| Custo/token por tarefa AFK | -20% | sem queda nos evals |
| Tempo de ciclo P50 em tarefas AFK | -25% | sem aumento de retrabalho |
| Retrabalho por handoff incompleto | -50% | medir contra baseline |
| Tarefas AFK independentes executadas em paralelo | pelo menos 1 piloto | somente write sets disjuntos |
| Falhas críticas de tenant, segredo, ambiente ou finanças | 0 | veto absoluto |
| Casos de eval versionados | 20 inicialmente | baseline reproduzível |

## Plano por fases

### Fase 0 — Baseline e congelamento de segurança

**Objetivo:** medir o fluxo atual antes de alterá-lo.

**Entregas:**

- Selecionar 10–20 tarefas representativas: leitura, auditoria, documentação, fatia AFK, fatia HITL e gate de promoção.
- Registrar manualmente duração, chamadas, retrabalho, contexto carregado, testes, bloqueios e aprovações.
- Definir o vocabulário de `run_id`, `parent_run_id`, ambiente, autoridade e resultado.
- Registrar os invariantes que não podem regredir: tenant, segredos, branch, Blueprint, SQL, testes e aprovação humana.

**Gate F0:** baseline armazenada; nenhuma meta de eficiência aprovada sem denominador; worktree e refs remotas preservados.

**Dependências:** nenhuma.

### Fase 1 — Agent Run Contract e handoff executável

**Objetivo:** transformar o contrato textual do MAS em estrutura validável.

**Entregas:**

- Schema versionado para `task`, `delegation`, `handoff` e `verification`.
- Campos obrigatórios: objetivo, arquivos permitidos/proibidos, autoridade, entradas canônicas, ferramentas autorizadas, formato de saída, testes, condição de parada, riscos, bloqueios, evidência e decisão pendente.
- Validador executado antes de delegar e antes de consolidar.
- Handoff inválido não pode ser promovido a `PASS`, `GO` ou `COMPLETE`.
- Compatibilidade explícita com `HITL`/`AFK` e com os formatos de saída atuais das skills.

**Gate F1:** 20 casos positivos e 10 negativos do schema; 100% dos casos negativos bloqueiam no campo correto; nenhum gate depende só de texto livre.

**Owner:** `kortex-mvpt-orchestrator`.

**Dependências:** F0.

### Fase 2 — Eval smoke do harness

**Objetivo:** detectar regressões de comportamento do agente antes de mudar skills ou hooks.

**Suite inicial:**

- escolher a skill correta;
- respeitar a ordem de leitura;
- recusar implementação sem Blueprint/Etapa 8;
- manter ownership exclusivo;
- pedir esclarecimento em decisão de produto aberta;
- aplicar Benchmark Gate quando aplicável;
- reexecutar teste alegado por subagente;
- recusar ferramenta apontada para ambiente divergente;
- resistir a instrução maliciosa em arquivo/resultado externo;
- produzir handoff completo e rastreável.

**Graders:**

- code-based para schema, arquivos, branch, comandos, testes e invariantes;
- model-based apenas para qualidade semântica, com critérios explícitos;
- human grader para decisões de produto, risco e adequação arquitetural.

**Gate F2:** baseline versionada; relatório por caso; regressão de skill não pode ser aceita por impressão subjetiva.

**Owner:** `kortex-qa-redteam`, com contribuição do `kortex-mvpt-orchestrator`.

**Dependências:** F1.

### Fase 3 — Pre-flight de ambiente e ferramenta

**Objetivo:** tornar branch, projeto, ambiente e permissões parte verificável do run.

**Entregas:**

- Perfis explícitos para local, staging e produção; nenhum ambiente inferido apenas por URL ou memória do agente.
- Pre-flight que confirma `branch`, `commit`, projeto Supabase/Render, modo de acesso e destino da operação.
- MCP e ferramentas externas iniciam em read-only quando possível.
- Mutação, deploy, alteração de schema e acesso a produção exigem aprovação HITL explícita.
- `environment_id` e `tool_scope` entram no Agent Run Contract e no handoff.
- Falha de identidade de ambiente encerra o run como `NO-GO`.

**Gate F3:** testes positivos e negativos para local/staging/produção; 0 mutações aceitas com ambiente divergente; nenhum segredo aparece no evento de telemetria.

**Owner:** `kortex-environment-guardian` e `kortex-delivery-guardian`.

**Dependências:** F1; pode avançar em paralelo com F2.

### Fase 4 — DAG seguro e paralelismo controlado

**Objetivo:** reduzir tempo sem violar ownership ou dependências.

**Entregas:**

- Derivar dependências das issues e marcar cada unidade com write set, read set, autoridade e gate.
- Classificar automaticamente: `parallel-safe`, `serial-required`, `HITL-blocked` ou `environment-blocked`.
- Limite inicial conservador de dois workers simultâneos.
- Proibir concorrência quando houver arquivo compartilhado, migration dependente, decisão HITL ou estado externo mutável.
- Agregador central coleta resultados; o orquestrador reexecuta evidências antes do veredito.
- Evaluator-optimizer final avalia completude, contradições, testes e riscos; não substitui a reverificação pessoal.

**Piloto:** duas tarefas AFK independentes, read-only ou em worktrees isoladas, sem envolver produção nem migrations compartilhadas.

**Gate F4:** piloto concluído com write sets disjuntos, sem conflito, com redução mensurável do tempo e sem regressão nos evals F2.

**Owner:** `kortex-mvpt-orchestrator`.

**Dependências:** F1, F2 e F3.

### Fase 5 — Contexto progressivo e gates em camadas

**Objetivo:** reduzir carga cognitiva e chamadas repetidas sem remover autoridade documental.

**Entregas:**

- Context packs por tipo de tarefa: auditoria, Blueprint, SQL, Express, PWA, QA, promoção e documentação.
- Entrada curta com `AGENTS.md`, `docs/INDEX.md` e o contrato; Truth/Migration/ADR carregados por roteamento.
- Gate em camadas: smoke da mudança → domínio afetado → segurança → regressão completa da Onda.
- Evidência assinada por `commit`, ambiente, comando, timestamp, resultado e responsável pela execução.
- Reutilização de evidência somente quando ref, ambiente e inputs forem idênticos.
- Hooks de risco passam de aviso para bloqueio quando o comportamento representar risco de segurança; exceções ficam registradas.

**Gate F5:** redução mínima de 20% no contexto médio das tarefas do piloto, sem queda nos evals; nenhuma regressão completa é omitida no gate final da Onda.

**Owner:** `kortex-qa-redteam`, `documentation-and-adrs` e `kortex-mvpt-orchestrator`.

**Dependências:** F2; F3 recomendado.

### Fase 6 — Telemetria e melhoria contínua

**Objetivo:** transformar otimização em ciclo mensurável.

**Eventos mínimos por `run_id`:**

- início/fim e duração;
- contexto carregado e estimativa de tokens;
- chamadas de modelo, subagentes e ferramentas;
- retries, falhas e bloqueios;
- arquivos tocados e testes executados;
- aprovações, interrupções e pedidos de esclarecimento;
- custo/latência quando disponibilizados pela superfície de execução;
- veredito e motivo de parada.

**Proteções:** não registrar segredos, tokens, dados pessoais ou conteúdo bruto de ferramenta; preferir hashes, IDs e resumos estruturados.

**Ritual:** revisão semanal dos 10 runs mais caros/lentos e dos casos de regressão; atualização de evals após cada falha real; revisão mensal dos limites de paralelismo.

**Gate F6:** dashboard ou relatório reproduzível com custo, latência, retries, bloqueios, qualidade e segurança por tarefa; segunda rodada de baseline confirma tendência, não apenas um caso isolado.

**Owner:** `kortex-mvpt-orchestrator` e `kortex-qa-redteam`.

**Dependências:** F0–F5.

## Sequenciamento e paralelismo do próprio plano

```text
F0 Baseline
 ├── F1 Contract ──┬── F2 Evals ──────┐
 │                 └── F3 Ambiente ────┤
 │                                    ├── F4 DAG seguro
 └── F5 Contexto + gates ─────────────┘
                                      └── F6 Telemetria contínua
```

F2 e F3 podem ser executadas em paralelo após F1. F5 pode começar com F2, mas o gate de redução de contexto só fecha depois de existir baseline. F4 nunca precede a validação de ambiente e contrato.

## Backlog de incrementos

| Incremento | Escopo | Tipo | Critério de saída |
|---|---|---|---|
| OPT-001 | Baseline e vocabulário de run | AFK | F0 aprovado |
| OPT-002 | Schema/validador de task, delegation e handoff | AFK | F1 aprovado |
| OPT-003 | 20 evals smoke + graders | AFK | F2 aprovado |
| OPT-004 | Pre-flight de ambiente/MCP | HITL | F3 aprovado pelo Environment/Delivery Guardian |
| OPT-005 | DAG, write sets e piloto de dois workers | HITL | F4 aprovado com evidência |
| OPT-006 | Context packs e gates em camadas | AFK | F5 aprovado |
| OPT-007 | Telemetria, relatório e revisão recorrente | AFK | F6 aprovado |
| OPT-008 | Check CI do espelho `.agents` ↔ `.claude` | AFK | divergência falha o CI |

Cada incremento deverá virar issue rastreável antes da implementação, com ownership exclusivo de arquivos e sem migration de produto. O fatiamento deve seguir `$prd-to-issues`; a implementação deve seguir `$tdd`; segurança e ambiente devem passar por Red Team e Guardians.

## Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Instrumentação registrar segredo ou PII | schema de eventos com allowlist; redaction test; revisão do Delivery Guardian |
| Paralelismo causar conflito ou contaminar ambiente | worktree isolada, write set obrigatório, limite de dois workers e pre-flight |
| Evals virarem burocracia sem valor | suite pequena, casos derivados de falhas reais e remoção de casos redundantes |
| Context pack omitir regra crítica | mapa de cobertura por domínio e gate de integridade contra `AGENTS.md`/INDEX |
| Métrica de custo reduzir qualidade | metas sempre subordinadas a segurança, completude e score dos evals |
| Plano ser confundido com autorização de implementação | cada fase possui gate; este documento não autoriza código, SQL, deploy ou promoção |

## Critério de sucesso do plano

O plano será considerado concluído somente quando F0–F6 estiverem aprovadas com evidência reproduzível, 20 eval cases versionados, 100% de handoffs válidos, ambiente verificado em cada mutação, um piloto paralelo seguro e uma segunda medição demonstrando redução de custo/tempo sem regressão crítica.

## DOCUMENTATION_CHECK

- [x] O novo documento está classificado em `docs/architecture/governance/` conforme Diátaxis.
- [x] O frontmatter YAML foi preenchido.
- [x] O `docs/INDEX.md` será atualizado no mesmo turno.
- [x] Nenhuma ADR ou DEC foi criada, afetada ou superada; este documento é plano, não aprovação de implementação.

## Handoff

FILES_CHANGED:
- `docs/architecture/governance/KORTEXOS_AGENTIC_FLOW_OPTIMIZATION_PLAN.md`: plano faseado, gates, métricas, dependências e backlog OPT-001–008.
- `docs/INDEX.md`: entrada de navegação para o plano.

BLOCKERS_REMAINING:
- Aprovação do Platform Owner para iniciar implementação dos incrementos OPT-001–008.
- Nenhum bloqueio para continuar o desenvolvimento local já autorizado da Onda 5, desde que este plano não seja tratado como autorização de promoção.

VEREDITO:
- **PLANO PRONTO PARA REVISÃO**.
- Próximo passo único: aprovar ou ajustar F0–F3 antes de criar as issues executáveis.
