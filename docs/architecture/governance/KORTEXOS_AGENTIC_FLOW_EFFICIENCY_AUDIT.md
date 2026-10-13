---
title: "Auditoria de Eficiências Transversais no Fluxo Agêntico"
status: "DRAFT"
stage: "DECISION"
governance_ref: []
upstream_doc: "AGENTS.md"
last_updated: "2026-08-04"
---

# Auditoria de Eficiências Transversais no Fluxo Agêntico

## Escopo e método

Esta auditoria avalia o fluxo agêntico do repositório KortexOS — skills, MAS, handoffs, hooks, gates, ferramentas e evidências — contra as práticas oficiais da Anthropic para sistemas agentic. Não avalia a corretude funcional das features da Onda 5.

Fontes externas usadas como régua:

- [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents): começar simples, escolher workflow/agente por necessidade, paralelizar trabalho independente, usar ground truth, impor condições de parada e testar a ACI.
- [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents): combinar graders code-based, model-based e human; medir regressões, latência, tokens, custo e erros.
- [Trustworthy agents in practice](https://www.anthropic.com/research/trustworthy-agents): manter controle humano, transparência, privacidade e segurança em todas as camadas do harness, ferramentas e ambiente.

Base local verificada em 2026-08-04:

- `git fetch` concluído; a branch local é `feat/onda5-blueprint-and-fatia-029`, três commits acima de `origin/staging`.
- A referência remota homônima não existe; não foi inferida uma comparação contra ela.
- Há migrations/testes não rastreados da Onda 5 no worktree; foram preservados e não fazem parte desta auditoria.
- O conjunto mínimo prescrito de contexto soma aproximadamente 212 KB antes de carregar referências adicionais: `AGENTS.md`, `INDEX`, Master modular, Truth Map, Migration Map e contratos da skill.

## Veredito executivo

**MATURIDADE: governança forte, eficiência operacional insuficientemente instrumentada.**

O fluxo já cobre bem separação de autoridade, ownership de arquivos, fatiamento vertical, TDD, Red Team, gates de ambiente, proteção de branch, referência de Blueprint em migrations e reverificação pessoal de relatos. Isso está alinhado com a parte de segurança e controle humano da régua.

O gap transversal é outro: não há um harness versionado que transforme o processo em algo mensurável e parcialmente executável. A organização não consegue provar, de forma repetível, qual fluxo foi usado, quanto custou, quanto demorou, quais ferramentas foram chamadas, quando o agente deveria ter pedido ajuda, nem se uma mudança de skill regrediu o comportamento do agente.

**Decisão operacional:** não bloquear a Onda 5 por este relatório; bloquear a declaração de “fluxo eficiente” até existir o primeiro pacote mínimo de telemetria/evals e controle de ambiente abaixo.

## Matriz de achados

| ID | Severidade | Achado | Evidência local | Impacto transversal |
|---|---|---|---|---|
| AEF-01 | P1 | **Não existe suíte de evals do agente/harness.** Há testes de produto e gates de Red Team, mas não um banco de tarefas que avalie seleção de skill, aderência ao envelope, qualidade de handoff, pedido de esclarecimento, uso de ferramentas ou regressão de comportamento. | [MAS contracts](../../../.agents/skills/kortex-mvpt-orchestrator/references/mas-contracts.md), [QA Red Team](../../../.agents/skills/kortex-qa-redteam/SKILL.md); busca por `eval`, `harness`, `grader`, `trace` e `telemetry` não encontrou harness versionado. | Cada alteração de prompt/skill é validada por inspeção humana ad hoc; custo, latência e regressões comportamentais ficam invisíveis. |
| AEF-02 | P1 | **A fronteira de ambiente/ferramenta não é least-privilege nem auto-verificada.** O `.mcp.json` aponta diretamente para um projeto Supabase específico, enquanto os hooks cobrem Bash/Edit/Write/MultiEdit, não a seleção de servidor MCP, escopo de operação ou confirmação de ambiente. | [.mcp.json](../../../.mcp.json), [settings.json](../../../.claude/settings.json), [environment guardian](../../../.agents/skills/kortex-environment-guardian/SKILL.md). | Um agente pode receber uma ferramenta válida para o ambiente errado; o controle depende de disciplina textual e não de pre-flight de identidade, modo read-only ou aprovação por mutação. |
| AEF-03 | P1 | **O contrato de delegação é normativo, mas não executável.** O MAS exige envelope com objetivo, arquivos permitidos/proibidos, autoridade, entradas, saída, testes e parada; também exige resposta com achados, evidências, decisões e bloqueios. Não há schema, parser, validador ou artefato obrigatório que rejeite um handoff incompleto. | [MAS contracts, §§ Envelope](../../../.agents/skills/kortex-mvpt-orchestrator/references/mas-contracts.md); [orchestrator skill](../../../.agents/skills/kortex-mvpt-orchestrator/SKILL.md). | A qualidade do handoff varia por agente/modelo; campos críticos podem desaparecer sem falhar um gate de máquina. |
| AEF-04 | P1 | **Não há plano de paralelismo baseado em dependências.** A implementação é descrita como “uma fatia por vez”, embora o próprio contrato classifique fatias como `HITL`/`AFK` e imponha ownership exclusivo. Não existe grafo de dependências, limite de concorrência ou agregador de resultados. | [orchestrator skill, fluxo](../../../.agents/skills/kortex-mvpt-orchestrator/SKILL.md); [prd-to-issues](../../../.agents/skills/prd-to-issues/SKILL.md). | Segurança é preservada, mas trabalho AFK independente é serializado; o custo de coordenação cresce com a Onda e não se aproveita o padrão de parallelization/orchestrator-workers recomendado pela Anthropic. |
| AEF-05 | P1 | **Não há telemetria de custo, latência, tokens, erros ou tempo de ciclo por tarefa.** O repositório registra contagens de testes de produto, não métricas do agente/harness. | [Master Briefing, invariantes de custo](../vision/KORTEXOS_5_1_2_MASTER_BRIEFING_VISAO_TESE.md); [CI](../../../.github/workflows/ci.yml); ausência de collector/schema/dashboard de execução agêntica. | “Eficiência” não pode ser comparada antes/depois; otimizações podem apenas deslocar custo para mais chamadas, mais releituras ou mais revisão humana. |
| AEF-06 | P2 | **Guardrails de hooks têm cobertura assimétrica e alguns apenas sinalizam depois da escrita.** Tenant e Design System são `PostToolUse` e explicitamente não bloqueantes; o hook de tenant cobre `tenant_id`, mas documenta que não cobre `organization_id`. Não há gate equivalente para conteúdo externo, prompt injection, chamada MCP ou escrita de artefato de handoff. | [settings.json](../../../.claude/settings.json); [check-tenant-invariant.js](../../../.claude/hooks/check-tenant-invariant.js); [check-design-system.js](../../../.claude/hooks/check-design-system.js). | O agente recebe feedback, mas a violação já ocorreu; falsos negativos e ações irreversíveis continuam possíveis. |
| AEF-07 | P2 | **Contexto inicial é amplo e obrigatório, sem roteamento progressivo.** A ordem canônica é correta para ondas, mas carrega documentos normativos longos antes de classificar a tarefa; não há resumo indexado por domínio nem mecanismo de “carregar só o contexto necessário”. | [AGENTS.md](../../../AGENTS.md), [docs/INDEX.md](../../INDEX.md); conjunto mínimo medido em ~212 KB. | Aumenta tokens, tempo de leitura e risco de instruções concorrentes; o custo é pago também por tarefas read-only pequenas. |
| AEF-08 | P2 | **Full regression é exigida em cada gate relevante, mas não há camadas de suíte.** O Red Team exige executar backend, frontend e pgTAP pessoalmente por fatia relevante; isso é seguro, porém não diferencia smoke, domínio afetado e regressão completa. | [QA Red Team, fluxo mínimo](../../../.agents/skills/kortex-qa-redteam/SKILL.md). | A segurança é boa, mas o caminho feliz fica caro e incentiva atalhos fora do processo; resultados repetidos não são reutilizados como evidência assinada. |
| AEF-09 | P2 | **Checkpoint humano existe, mas não há artefato de plano revisável.** Há `HITL`/`AFK`, entrevistas, aprovação do Platform Owner e limites de autoridade, porém não um plano estruturado com intenção, riscos, ferramentas autorizadas, pontos de pausa e critérios de retomada. | [MAS contracts](../../../.agents/skills/kortex-mvpt-orchestrator/references/mas-contracts.md); [AGENTS.md](../../../AGENTS.md). | O controle humano fica concentrado em aprovações de marco; é menos transparente e menos editável do que um plano upfront, especialmente em tarefas longas ou com subagentes. |
| AEF-10 | P2 | **Skills espelhadas dependem de sincronização manual.** Os dez `SKILL.md` de `kortex-*` foram comparados por SHA-256 e estão iguais hoje, mas a regra de cópia entre `.agents/skills` e `.claude/skills` não é validada por hook/CI. | [AGENTS.md](../../../AGENTS.md); comparação local dos diretórios `.agents/skills/kortex-*` e `.claude/skills/kortex-*`. | O estado atual está íntegro, mas o próximo ajuste pode criar divergência silenciosa e fazer agentes diferentes operarem com contratos distintos. |
| AEF-11 | P2 | **Não há suíte explícita de prompt-injection/tool-output red team.** O Red Team cobre tenant, RLS, dinheiro, concorrência e entrega; não há casos versionados para instruções maliciosas vindas de arquivos, resultados MCP, páginas web ou documentos de benchmark. | [QA Red Team](../../../.agents/skills/kortex-qa-redteam/SKILL.md); [settings.json](../../../.claude/settings.json). | A superfície de entrada do agente inclui conteúdo não confiável, mas a validação atual concentra-se no estado do produto, não na segurança do loop de ferramentas. |
| AEF-12 | P3 | **Benchmark Gate é forte, mas globalmente rígido.** A ordem Booksy → players → cross-industry é obrigatória para dúvidas de comportamento de produto, sem um classificador explícito que separe mudança de comportamento, correção mecânica, auditoria de processo e decisão técnica. | [AGENTS.md](../../../AGENTS.md); [orchestrator skill](../../../.agents/skills/kortex-mvpt-orchestrator/SKILL.md). | Evita decisões sem evidência, mas pode adicionar pesquisa e latência onde a pergunta não é de produto; a isenção depende de interpretação do agente. |

## O que está funcionando e deve ser preservado

- A separação entre workflow determinístico e autoridade humana é boa: planejar não autoriza implementar, draft não autoriza executar e credencial não autoriza deploy.
- Ownership exclusivo e fatiamento vertical reduzem conflitos e tornam a unidade de trabalho verificável.
- A regra de nunca aceitar relato de subagente sem reexecutar `git status`, diff e testes é uma aplicação forte de ground truth.
- Os cinco hooks cobrem riscos concretos e os dez `SKILL.md` espelhados estão iguais no snapshot auditado.
- A documentação distingue fato, decisão, evidência e bloqueio melhor do que a média de processos agentic não instrumentados.

## Backlog recomendado, em ordem de retorno

### 1. Criar o Agent Run Contract e o primeiro eval smoke — AEF-01/A03

Adicionar um schema versionado para `task`, `delegation`, `handoff` e `verification`, com `run_id`, `parent_run_id`, autoridade, arquivos permitidos/proibidos, ferramentas autorizadas, decisões pendentes, evidência, testes, bloqueios e condição de parada. Validar o envelope antes de delegar e antes de consolidar.

Criar um banco pequeno de tarefas canônicas, inicialmente 10–20 casos: seleção da skill correta, leitura na ordem, respeito a ownership, recusa de deploy sem gate, pedido de esclarecimento em decisão aberta, verificação de teste alegado, uso de ferramenta no ambiente correto e resistência a instrução maliciosa em artefato externo.

### 2. Instrumentar execução — AEF-05

Registrar por `run_id`: duração, número de chamadas, ferramenta, resultado, retries, tokens/custo quando disponível, arquivos tocados, testes executados, aprovação humana, bloqueio e resultado final. Emitir um resumo por tarefa e uma série temporal simples; não registrar segredos nem conteúdo sensível bruto.

### 3. Tornar ambiente e ferramenta explícitos — AEF-02

Separar configuração local/staging/produção; iniciar MCP em read-only quando possível; exigir pre-flight que confirme projeto, branch e ambiente; exigir aprovação explícita para mutações, deploy e qualquer ferramenta com efeito externo. O identificador do ambiente deve entrar no envelope e no handoff.

### 4. Paralelizar somente o DAG seguro — AEF-04

Derivar dependências das issues, agrupar fatias `AFK` com write sets disjuntos e rodar em paralelo com limite fixo. Manter serialização para decisões `HITL`, arquivos compartilhados, migrations dependentes e gates de integração. Agregar resultados em um evaluator-optimizer final, sem aceitar relato não verificado.

### 5. Fazer gates em camadas e assinar evidência — AEF-08/A06

Separar smoke por mudança, testes do domínio afetado, suíte de segurança e regressão completa da Onda. Cada resultado deve ter commit/ref, ambiente, comando, saída resumida e timestamp; o gate final apenas compõe evidências já verificadas. Promover tenant/design-system de aviso para bloqueio quando o risco for de segurança, ou explicitar uma exceção formal.

### 6. Reduzir contexto por roteamento — AEF-07

Manter `AGENTS.md` e `INDEX` como entrada curta; criar mapas de contexto por tarefa que apontem para Truth/Migration/ADR/skill relevantes. Carregar documentos completos apenas quando o domínio ou gate exigir. Medir tokens e tempo antes/depois para evitar otimização intuitiva.

### 7. Automatizar espelho de skills e classificar benchmark — AEF-10/A12

Adicionar um check CI que compare todos os arquivos sob `kortex-*`, não só `SKILL.md`, entre os dois espelhos. Adicionar uma classificação inicial da pergunta (`produto`, `técnica`, `mecânica`, `auditoria`) para exigir Benchmark Gate apenas quando aplicável, preservando a obrigação para mudanças de comportamento.

## Critério de sucesso da próxima revisão

Considerar a eficiência transversal demonstrada quando houver, no mínimo:

- 20 eval cases versionados com baseline e resultado reproduzível;
- 100% dos handoffs válidos pelo schema;
- 0 execução de ferramenta mutável em ambiente divergente do envelope;
- custo, latência, retries e taxa de bloqueio visíveis por run;
- pelo menos uma execução paralela de fatias independentes com write sets disjuntos;
- regressão completa mantida no gate da Onda, mas sem ser repetida cegamente em todo passo intermediário;
- check CI de espelho `.agents` ↔ `.claude` verde.

## DOCUMENTATION_CHECK

- [x] O novo documento está classificado em `docs/architecture/governance/` conforme Diátaxis.
- [x] O frontmatter YAML foi preenchido.
- [x] O `docs/INDEX.md` foi atualizado com a navegação deste artefato.
- [x] Nenhuma ADR ou DEC foi criada, afetada ou superada; este documento é diagnóstico e deixa decisões de implementação para follow-up explícito.

## Handoff

FILES_CHANGED:
- `docs/architecture/governance/KORTEXOS_AGENTIC_FLOW_EFFICIENCY_AUDIT.md`: auditoria transversal, evidências, priorização e backlog.
- `docs/INDEX.md`: entrada de navegação para a auditoria.

BLOCKERS_REMAINING:
- Não há bloqueio para continuar a Onda 5 localmente.
- A eficiência do fluxo permanece não demonstrada até AEF-01, AEF-02 e AEF-05 terem uma primeira implementação mensurável.

VEREDITO:
- **GO com remediação** para continuar o desenvolvimento local autorizado da Onda 5.
- **NO-GO para declarar o fluxo agêntico otimizado ou promover autonomia operacional adicional** até existir harness de eval/telemetria e pre-flight de ambiente.
