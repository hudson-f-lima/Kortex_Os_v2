---
title: "Plano de Implementação das Otimizações com Spec Kit"
status: "APROVADO"
stage: "EXECUTION"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "docs/architecture/governance/KORTEXOS_AGENTIC_FLOW_OPTIMIZATION_PLAN.md"
last_updated: "2026-08-10"
---

# Plano de Implementação das Otimizações com Spec Kit

## Decisão de escopo

Adotar o Spec Kit de forma **seletiva e experimental** como motor de workflow do fluxo agêntico KortexOS. Ele não será uma nova fonte de verdade arquitetural, nem substituirá o MAS, os Guardians, os Blueprints, os ADRs/DECs ou os mapas canônicos.

Fontes oficiais consultadas:

- [GitHub Spec Kit](https://github.github.io/spec-kit/): harness orientado por especificação, integrações e extensões.
- [Referência de comandos e processos](https://github.github.io/spec-kit/reference/overview.html): `constitution`, `specify`, `clarify`, `plan`, `checklist`, `tasks`, `analyze`, `implement` e `converge`.
- [Workflows](https://github.github.io/spec-kit/reference/workflows.html): gates, condicionais, loops, fan-out/fan-in, pausa/retomada e estado por `run_id`.
- [Features complexas](https://github.github.io/spec-kit/concepts/complex-features.html): limitar tarefas por execução antes de aumentar a decomposição.
- [Spec of Specs](https://github.github.io/spec-kit/concepts/spec-of-specs.html): roadmap superficial, slices independentes e dependências explícitas.
- [Upgrade e segurança](https://github.github.io/spec-kit/upgrade.html): arquivos gerenciados, conflitos e preservação de customizações.

## Objetivo

Implementar as otimizações AEF/OPT já aprovadas como direção de trabalho:

- contratos de run e handoff executáveis;
- evals do harness;
- pre-flight de ambiente e ferramenta;
- workflow com gates e estado retomável;
- paralelismo controlado por dependências e write sets;
- contexto progressivo;
- gates em camadas;
- telemetria e rastreabilidade;
- verificação automática do espelho `.agents/skills` ↔ `.claude/skills`.

## Não objetivos

- Não rodar `specify init --here --force` no repositório atual.
- Não sobrescrever `.agents/skills/kortex-*` ou `.claude/skills/kortex-*`.
- Não introduzir migration, tabela, endpoint ou regra de negócio.
- Não habilitar escrita autônoma em `staging`, `main` ou produção.
- Não duplicar `AGENTS.md`, Truth Map, Migration Map, Blueprint, ADR ou Decision Log como uma constituição paralela.
- Não instalar workflow comunitário sem revisão de código, pin de versão e gate de segurança.

## Mapeamento Spec Kit → KortexOS

| Spec Kit | Tratamento no KortexOS | Fonte de verdade |
|---|---|---|
| `constitution` | Adaptador somente leitura; lê invariantes e governança existentes | `AGENTS.md` + protocolo documental |
| `specify` | Captura intenção, escopo, usuário e critérios de aceite antes do desenho | Blueprint/PRD aprovado; sem duplicar regra |
| `clarify` | Entrevista de decisões abertas e Benchmark Gate quando comportamento de produto mudar | Platform Owner + DEC/ADR |
| `plan` | Orquestra preparação do Blueprint e do fatiamento | Migration Map + Blueprint |
| `checklist` | Checklist de risco, segurança, tenant, ambiente e documentação | Gate Matrix + Guardians |
| `tasks` | Gera proposta de issues verticais `HITL`/`AFK` | `issues/` via `$prd-to-issues` |
| `analyze` | Verifica contradições entre spec, Blueprint, issues, código e evidência | Truth Map + Red Team |
| `implement` | Executa uma issue por vez ou um grupo paralelo seguro via `$tdd` | issue + testes + ownership |
| `converge` | Consolida evidência, corrige drift e prepara handoff | QA/Red Team + Environment/Delivery Guardian |
| Workflow YAML | Encadeia comandos, gates, shell read-only e fan-out/fan-in | workflow versionado e revisado |
| `.specify` | Guarda somente infraestrutura do piloto e estado de runs | Git, com escopo explícito |

## Guardrails obrigatórios

1. **Workflow local e versionado:** nenhum workflow remoto entra diretamente no projeto; usar arquivo local revisado ou catálogo interno pinado.
2. **Shell não é sandbox:** cada `shell` deve ser read-only no piloto ou precedido por gate HITL explícito; `requires` nunca será tratado como permissão.
3. **Pre-flight antes de ferramenta:** confirmar branch, commit, ambiente, projeto Supabase/Render e modo de acesso.
4. **Write set obrigatório:** toda tarefa paralela declara arquivos permitidos; arquivos compartilhados forçam execução serial.
5. **Proteção de fonte canônica:** Spec Kit pode apontar para documentos KortexOS, mas não pode reescrevê-los fora do fluxo MAS.
6. **Handoff verificável:** `run_id`, ambiente, inputs, outputs, testes, evidência, bloqueios e veredito são obrigatórios.
7. **Aprovação por risco:** schema, deploy, promoção, mutação externa e decisão de produto permanecem HITL.
8. **Rollback simples:** remover o workflow/preset e os artefatos `.specify` do piloto deve restaurar o fluxo anterior sem tocar no código do produto.
9. **Pin e proveniência:** registrar a versão do Spec Kit, fonte do workflow, hash do arquivo e extensões utilizadas.
10. **Dados sensíveis:** logs usam IDs, hashes e resumos; nunca tokens, segredos, PII ou conteúdo bruto de ferramentas.

## Plano faseado

### Fase SPK-0 — Compatibilidade e baseline

**Objetivo:** confirmar que a adoção não conflita com o worktree ou com as regras atuais.

**Ações:**

- Revalidar branch, ref remota, worktree e mudanças pré-existentes antes de qualquer instalação.
- Confirmar que o piloto não possui `.specify` ativo nem arquivos gerenciados do Spec Kit.
- Fixar a versão escolhida do CLI; não seguir `main` ou pacote sem pin.
- Selecionar uma tarefa de governança de baixo risco: contrato/eval do harness, não feature da Agenda nem migration.
- Definir baseline de duração, chamadas, tokens, retrabalho, gates e qualidade para 10–20 execuções.

**Saída:** `SPK-BASELINE` com ref, versão, escopo, métricas e lista de arquivos intocáveis.

**Gate:** `GO` somente se não houver conflito com mudanças locais e não houver autorização implícita de código/produto.

**Owner:** `kortex-mvpt-orchestrator`.

### Fase SPK-1 — Piloto isolado do CLI e workflow

**Objetivo:** testar o motor Spec Kit sem modificar o repositório KortexOS.

**Ações:**

- Criar diretório descartável fora do worktree para o piloto.
- Instalar/usar o CLI em versão pinada, sem alterar o projeto KortexOS.
- Executar um workflow local mínimo com `--json` e um gate humano.
- Confirmar persistência e retomada de `run_id` após pausa/falha.
- Confirmar comportamento de erro, cancelamento, reexecução e limpeza.
- Revisar qualquer shell step antes de executá-lo.

**Workflow mínimo do piloto:**

```text
preflight read-only
  → gerar artefato de intenção
  → gate de revisão
  → gerar plano
  → gate de revisão
  → gerar tarefas
  → pausar/retomar
  → produzir relatório JSON
```

**Gate:** `GO` somente se o estado puder ser retomado e removido sem tocar no repositório principal.

**Owner:** `kortex-mvpt-orchestrator` + `kortex-delivery-guardian`.

### Fase SPK-2 — Adapter KortexOS e contrato de run

**Objetivo:** fazer o workflow falar a linguagem do MAS sem criar uma segunda constituição.

**Ações:**

- Definir schema para `run`, `delegation`, `handoff` e `verification`.
- Mapear os campos do Spec Kit para `HITL`/`AFK`, evidência e ownership.
- Criar comandos/steps que apenas leiam `AGENTS.md`, `docs/INDEX.md`, Truth Map, Migration Map e ADRs relevantes.
- Fazer o output do workflow referenciar paths e commits reais.
- Rejeitar handoff sem testes, bloqueios, veredito ou condição de parada.
- Proibir que `spec.md` ou `plan.md` se tornem autoridade superior ao Blueprint/ADR.

**Gate:** 20 casos válidos e 10 inválidos; 100% dos inválidos bloqueiam no campo esperado.

**Owners:** `kortex-mvpt-orchestrator` + `documentation-and-adrs`.

### Fase SPK-3 — Workflow KortexOS v1

**Objetivo:** materializar o pipeline MAS com gates explícitos.

**Sequência proposta:**

```text
sync refs
  → classify task
  → load progressive context
  → Truth/Blueprint/Issue check
  → Benchmark Gate, se produto
  → human review of intent/plan
  → generate vertical tasks
  → pre-flight environment/tool
  → execute serial or safe fan-out
  → smoke/domain/security tests
  → Red Team evidence review
  → Environment Guardian
  → Delivery Guardian when applicable
  → final handoff
```

**Regras de branching:**

- tarefa mecânica/read-only: caminho AFK curto;
- mudança de comportamento: Benchmark Gate + HITL;
- migration/schema: Blueprint, pre-flight SQL, `$tdd`, pgTAP e autorização da Etapa 8;
- promoção: Environment Guardian → homologação → Delivery Guardian;
- tarefa paralela: somente com dependências resolvidas, write sets disjuntos e worktrees isoladas.

**Gate:** workflow validado por revisão de segurança e dry-run, sem executar mutação externa.

**Owner:** `kortex-mvpt-orchestrator`.

### Fase SPK-4 — Evals e gates em camadas

**Objetivo:** provar que o workflow melhora o processo sem degradar qualidade.

**Casos mínimos:**

- seleção correta da skill;
- leitura da fonte canônica correta;
- recusa de SQL sem Blueprint/Etapa 8;
- recusa de promoção sem ambiente validado;
- respeito ao ownership;
- pedido de esclarecimento em decisão aberta;
- Benchmark Gate quando aplicável;
- reverificação de teste alegado;
- detecção de ambiente divergente;
- resistência a instrução maliciosa em arquivo/resultado de ferramenta;
- handoff completo;
- retomada após gate ou falha;
- fan-out seguro e fan-in completo;
- ausência de drift entre spec/plan/tasks e Blueprint/issue.

**Camadas:**

1. schema e arquivos;
2. comandos e evidência;
3. segurança/ambiente;
4. qualidade semântica;
5. revisão humana de decisões arquiteturais/produto.

**Gate:** 20 casos versionados, baseline registrada, zero falha crítica e nenhuma aprovação baseada apenas em relato.

**Owner:** `kortex-qa-redteam`.

### Fase SPK-5 — Piloto de paralelismo seguro

**Objetivo:** validar o ganho de velocidade sem cruzamento de arquivos ou ambientes.

**Piloto:**

- duas tarefas AFK de governança, read-only ou em worktrees isoladas;
- nenhuma migration compartilhada;
- nenhum deploy;
- limite inicial de dois workers;
- fan-in obrigatório com reconciliação pessoal do orquestrador.

**Medições:** tempo P50/P95, chamadas, tokens, retrabalho, conflitos, evidência incompleta e qualidade dos resultados.

**Gate:** redução de pelo menos 20% no tempo de ciclo, sem conflito de write set e sem regressão nos evals.

**Owner:** `kortex-mvpt-orchestrator` + `kortex-qa-redteam`.

### Fase SPK-6 — Contexto progressivo e converge

**Objetivo:** reduzir contexto sem perder regras críticas.

**Ações:**

- criar context packs por tarefa: auditoria, Blueprint, SQL, Express, PWA, QA e promoção;
- carregar `AGENTS.md`/`INDEX` como entrada curta;
- carregar Truth/Migration/ADR sob demanda conforme domínio e gate;
- limitar `implement` por fase ou faixa de tasks;
- usar “spec of specs” somente quando uma fase ainda exceder o contexto após limitação e delegação;
- executar análise de drift antes de retomar implementação;
- manter roadmap e sub-especificações bidirecionalmente referenciados.

**Gate:** redução média de 20% no contexto do piloto, sem queda nos evals ou perda de regra crítica.

**Owner:** `kortex-mvpt-orchestrator` + `documentation-and-adrs`.

### Fase SPK-7 — Telemetria e decisão de adoção

**Objetivo:** decidir com evidência se o Spec Kit fica no fluxo oficial.

**Eventos:**

- `run_id`, versão do CLI e hash do workflow;
- contexto carregado;
- steps, gates, subagentes e ferramentas;
- duração, retries, falhas, pausas e retomadas;
- arquivos tocados e testes executados;
- custo/tokens quando a superfície permitir;
- aprovação humana, bloqueio e veredito.

**Decisão:**

- **Adopt:** metas atingidas, zero falha crítica e custo operacional aceitável;
- **Adopt with constraints:** benefício comprovado, mas com limites adicionais de ambiente/paralelismo;
- **Reject:** overhead maior que o ganho, conflito com governança ou incapacidade de provar segurança;
- **Pause:** dados insuficientes; não converter impressão em decisão.

**Owner:** Platform Owner, apoiado por `kortex-mvpt-orchestrator` e `kortex-qa-redteam`.

## Fatiamento de implementação

| ID | Incremento | Tipo | Write set proposto | Dependência | Gate |
|---|---|---|---|---|---|
| SPK-001 | baseline e compatibilidade | AFK | artefatos do piloto isolado | — | SPK-0 |
| SPK-002 | piloto CLI/workflow | AFK | diretório descartável | SPK-001 | SPK-1 |
| SPK-003 | schema de run/handoff | AFK | contrato/harness | SPK-001 | SPK-2 |
| SPK-004 | adapter de fontes KortexOS | AFK | workflow/adapter | SPK-003 | SPK-2 |
| SPK-005 | workflow KortexOS v1 | HITL | workflow local | SPK-002–004 | SPK-3 |
| SPK-006 | evals do harness | AFK | cases/graders | SPK-003–005 | SPK-4 |
| SPK-007 | pre-flight ambiente/ferramenta | HITL | scripts/hooks de ambiente | SPK-003–005 | SPK-3 |
| SPK-008 | fan-out/fan-in seguro | HITL | workflow + scheduler | SPK-005–007 | SPK-5 |
| SPK-009 | context packs/converge | AFK | templates/índices | SPK-004–006 | SPK-6 |
| SPK-010 | telemetria e decisão final | HITL | eventos/relatórios | SPK-006–009 | SPK-7 |

Cada incremento deverá virar uma issue rastreável antes da implementação. A criação das issues deve passar por `$prd-to-issues`, sem alterar issues de produto existentes e sem atribuir autorização de deploy.

## Rollback

1. Parar novos runs do workflow.
2. Marcar execuções abertas como `aborted` e preservar logs para auditoria.
3. Remover ou desabilitar o workflow/preset local.
4. Remover somente artefatos do piloto `.specify` explicitamente criados para ele.
5. Restaurar o caminho MAS anterior sem tocar em código, migrations, ADRs ou issues de produto.
6. Registrar causa, impacto, runs afetados e decisão `Reject` ou `Pause`.

Não usar `git reset --hard`, `git checkout --` ou `specify init --force` como rollback automático.

## Critérios de sucesso

O Spec Kit só poderá ser incorporado ao fluxo oficial quando todos os critérios forem comprovados:

- workflow pinado e com proveniência registrada;
- nenhum conflito com as skills `kortex-*` canônicas/espelhadas;
- 100% dos handoffs válidos pelo contrato;
- ambiente verificado antes de toda mutação;
- 20 eval cases versionados verdes;
- pelo menos um piloto paralelo seguro concluído;
- redução mensurável de tempo ou custo sem regressão de qualidade;
- nenhum segredo ou PII nos logs;
- rollback testado;
- aprovação explícita do Platform Owner para adoção além do piloto.

## Aprovação e execução controlada

Em 2026-08-10, o Platform Owner aprovou a adoção controlada após o veredito `ADOPT_WITH_CONSTRAINTS` do SPK-7. A execução está limitada às issues `044`–`053` e aos artefatos `.specify/kortex/`; não autoriza código de produto, migration, deploy, promoção, ativação de feature flag ou sobrescrita das skills canônicas.

Primeiro incremento integrado concluído em modo read-only: pin `0.12.11`, contrato/handoff, adapter de fontes, pre-flight, workflow v1.0.1, evals `20/20` + `10/10`, context pack, fan-out seguro, telemetria e rollback dry-run. O run `4ffd5ffd` terminou `GO`; runs anteriores preservam o bloqueio de raiz sem tracking remoto e a pausa HITL da fronteira.

## DOCUMENTATION_CHECK

- [x] O novo documento está classificado em `docs/architecture/governance/` conforme Diátaxis.
- [x] O frontmatter YAML foi preenchido.
- [x] O `docs/INDEX.md` será atualizado no mesmo turno.
- [x] Nenhuma ADR ou DEC foi criada, afetada ou superada; este documento é plano de implementação e não autorização.

## Handoff

FILES_CHANGED:
- `docs/architecture/governance/KORTEXOS_SPECKIT_OPTIMIZATION_IMPLEMENTATION_PLAN.md`: plano faseado SPK-0–SPK-7, fatiamento SPK-001–SPK-010, gates e rollback.
- `docs/INDEX.md`: entrada de navegação para o plano.
- `docs/architecture/adr/0024-adocao-controlada-spec-kit-fluxo-agentico.md`: decisão aceita de adoção controlada.
- `docs/architecture/governance/KORTEXOS_5_1_2_DECISION_LOG.md`: DEC-59 e vínculo DEC↔ADR.
- `issues/kortexos-speckit-integration-prd.md` e `issues/044`–`issues/053`: PRD e fatiamento executável.
- `.specify/kortex/`: pin, contrato, scripts de pre-flight/adapter/evals/contexto/fan-out/telemetria/rollback e workflow v1.0.1.

BLOCKERS_REMAINING:
- Execução continua limitada ao primeiro incremento até os gates das issues `044`–`053` serem verificados.
- Nenhuma mutação de produto, migration, deploy, promoção ou ativação autônoma é autorizada por DEC-59.
- `verdict_input` permanece fora do caminho confiável no pin `0.12.11`; usar approval adapter allowlisted.

VEREDITO:
- **APROVADO PARA EXECUÇÃO CONTROLADA** por DEC-59/ADR-0024.
- Próximo passo: implementar as issues `044`–`053` em ordem de dependência, começando pelo baseline/pin e pelo pre-flight read-only.
