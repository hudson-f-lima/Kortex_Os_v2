---
title: "SPK-BASELINE — Baseline de Compatibilidade do Spec Kit"
status: "APROVADO"
stage: "EXECUTION"
governance_ref: ["DEC-59", "ADR-0024"]
upstream_doc: "docs/architecture/governance/KORTEXOS_SPECKIT_OPTIMIZATION_IMPLEMENTATION_PLAN.md"
last_updated: "2026-08-10"
---

# SPK-BASELINE — Baseline de Compatibilidade do Spec Kit

## Escopo

Snapshot read-only que autoriza a transição do plano para o piloto isolado, sem instalar o Spec Kit, sem inicializar `.specify` no KortexOS e sem alterar código de produto, migration, skill ou hook.

## Ref e estado do worktree

| Item | Evidência | Resultado |
|---|---|---|
| Branch local | `feat/agenda-drag-reschedule` | preservada |
| `HEAD` | `24df1a6b2b109d70bf2b1b9f04fe735686986424` | coincide com `origin/staging` |
| `origin/main` | `c7b63c6ac98d6b54a6b833ca67a05638db926ddf` | distinto; não utilizado |
| Remote homônimo da branch | inexistente | não fazer pull/merge implícito |
| Worktree | 23 itens modificados/não rastreados antes do piloto | intocável e preservado |

O worktree já contém alterações de Agenda/PWA e artefatos documentais. O piloto não assume autoria dessas mudanças, não as limpa e não executa comandos sobre elas.

## Compatibilidade e isolamento

- `.specify/`: ausente.
- Arquivos identificáveis de Spec Kit no projeto: ausentes.
- CLI `specify`: não instalado.
- `uv` e Python no `PATH`: indisponíveis.
- Node.js: disponível (`v24.18.0`), mas não substitui o runtime recomendado para o CLI.
- Produto, migrations, `.agents/skills/kortex-*`, `.claude/skills/kortex-*`, `.claude/hooks/`, `.claude/settings.json`, Truth Map, Migration Map e ambientes remotos ficam fora do escopo de escrita.

## Pin proposto para o piloto

O piloto usou `Spec Kit v0.12.11`, instalado por pin explícito somente no ambiente descartável. A release oficial existe e documenta a instalação por tag; nenhuma instalação foi feita no KortexOS:

- [Release v0.12.11](https://github.com/github/spec-kit/releases/tag/v0.12.11)
- [Guia oficial de instalação](https://github.github.io/spec-kit/installation.html)

O pin não autoriza `specify init` no repositório KortexOS nem autoriza seguir `main`/pacote sem versão.

## Baseline de medição

Antes da primeira execução do piloto:

| Métrica | Baseline atual | Coleta no piloto |
|---|---:|---|
| Execuções Spec Kit | 0 | 10–20 runs isolados |
| Duração | não aplicável | início/fim por `run_id` |
| Chamadas de ferramenta | não aplicável | contagem por run e etapa |
| Retrabalho | não aplicável | reexecuções, falhas e correções |
| Gates | não aplicável | `GO`, `NO-GO`, `BLOCKED`, motivo |
| Handoff completo | não aplicável | contrato válido/inválido |
| Segredos/PII observados | 0 no piloto | scan por run e artefato |
| Alterações no KortexOS | 0 pelo SPK | `git status` antes/depois |

Cada run deve conservar `run_id`, versão do CLI, ref do workflow, timestamp, resultado dos gates, erro bruto e artefatos produzidos. Nenhum prompt/artefato deve conter segredo, token, JWT, dado financeiro ou PII real.

## Lista de arquivos e superfícies intocáveis

- Todo o código de produto em `backend/`, `frontend/` e `supabase/`.
- Todas as migrations, testes de banco e fixtures existentes.
- `.agents/skills/kortex-*` e suas cópias em `.claude/skills/kortex-*`.
- `.claude/hooks/` e `.claude/settings.json`.
- `docs/waves/`, ADRs, DEC logs, Truth Map e Migration Map.
- Branches remotas, staging, produção, integrações externas e credenciais.
- Todo arquivo que já aparecia no `git status` antes da criação do piloto.

## Evidência do primeiro piloto SPK-1

Executado em 2026-08-10 no diretório descartável `C:\tmp\kortex-spk-pilot-20260810`:

- `specify-cli 0.12.11` instalado em venv isolado e verificado com Python `3.12.13`.
- `kortex-spk-pilot`, run `f0a47b3a`: `paused` no gate `review-preflight`, com preflight concluído e saída `--json` válida.
- `kortex-spk-resume-pilot`, run `55dd54f9`: falhou com exit code controlado e foi retomado até `completed` com input numérico allowlisted.
- `kortex-spk-artifact-pilot`, run `54f375d3`: `completed`, gerou artefatos determinísticos e relatório JSON.
- A execução direta sem decisão humana (`76858d1f`, `e884bb2e`, `7c86dae7`) abortou como `reject` por EOF no terminal automatizado; isso confirma que o gate não deve ser tratado como autoaprovado.
- O campo `verdict_input` descrito na documentação corrente não produziu auto-decisão no pacote `0.12.11` observado; fica classificado como `DESCONHECIDO` até uma reprodução em terminal interativo ou versão posterior. O workflow KortexOS não deve depender desse campo para liberar etapa sensível.
- O repositório KortexOS permaneceu sem `.specify` e sem arquivos identificáveis de Spec Kit após todos os runs.

O piloto, portanto, validou JSON, gates, persistência de estado, artefatos determinísticos e resume após falha. A aprovação humana interativa real permanece pendente; não houve implementação de produto.

## Evidência do SPK-2 e SPK-3

- `run-contract.schema.json` e `contract-harness.mjs` foram criados somente no piloto.
- Harness SPK-2: `20/20` casos válidos passaram e `10/10` inválidos bloquearam no campo esperado (`spk2-contract-report.json`).
- `kortex-source-adapter.mjs` leu seis fontes canônicas em modo read-only, registrando apenas paths, tamanho, SHA-256, branch, commit e snapshot de status.
- Dry-run do workflow KortexOS v1: run `270a9a4d`, `completed`, handoff `GO`, `externalWrites=false`.
- Caminho de produto sem Benchmark Gate: run `df2b2b47`, `paused` exatamente em `benchmark-gate`.
- Adapter v0.12.11: run `fd70bc11`, `completed` com aprovações allowlisted; sem aprovação, run `9801809e` pausou no gate humano.
- Input de aprovação fora da allowlist foi rejeitado antes da execução.

O dry-run continua restrito a `C:\tmp\kortex-spk-pilot-20260810`; não é workflow habilitado no KortexOS. O uso de `KORTEX_REPO` ainda precisa de pre-flight que valide a raiz autorizada antes de qualquer integração real.

## Evidência do SPK-4

- `spk4-eval-harness.mjs`: `11/11` checks passaram, sem falhas (`spk4-eval-report.json`).
- A suíte reconfirmou contrato, allowlist, proveniência de commit, context pack sem conteúdo, isolamento do repositório, handoff sem escrita externa, ordem do Benchmark Gate e preservação do gate humano.
- O resultado é `GO` somente para o piloto isolado; não autoriza instalar workflow no KortexOS nem executar fan-out em worktrees reais.

## Evidência do SPK-5

- Dois worktrees detached foram criados no commit `24df1a6b2b109d70bf2b1b9f04fe735686986424` e removidos após a execução.
- Worker A auditou governança versionada; Worker B auditou Truth Map, Migration Map e ADR 0023.
- Fan-in confirmou HEADs iguais, worktrees limpos, três arquivos presentes por worker e write sets vazios/disjuntos.
- Harness SPK-5: `392,271 ms` paralelo contra `672,862 ms` sequencial, redução medida de `41,7%`, acima do gate de `20%` (`spk5-fanout-report.json`).
- Nenhuma migration, deploy, branch compartilhada ou alteração no worktree principal foi executada.

## Evidência do SPK-6

- Sete context packs foram gerados por domínio: auditoria, Blueprint, SQL, Express, PWA, QA e promoção.
- Contexto completo: `207.843` caracteres; média dos packs: `100.552` caracteres; redução média: `51,62%`.
- Nenhum marcador crítico foi perdido (`service_role`, `organization_id`, RLS, Benchmark, `git fetch` e Handoff).
- Hashes das fontes permaneceram estáveis (`source_drift=false`) e os evals anteriores continuaram `GO`.
- Os packs e o relatório ficaram somente em `C:\tmp\kortex-spk-pilot-20260810`; nenhuma fonte do KortexOS foi alterada.

## Evidência e decisão do SPK-7

- Telemetria consolidada em `spk7-telemetry.json`: 11 runs com `4 completed`, `3 paused`, `3 aborted`, `1 failed` e 1 run retomado após falha.
- Hashes dos cinco workflows, gates, duração, retries, contexto, handoffs e write sets foram registrados; tokens/custo permanecem `UNKNOWN`.
- Benefício comprovado: fan-out `+41,7%` e context packs `-51,62%`; contrato `20/20` + `10/10` e evals em camadas `11/11` continuam verdes.
- Decisão calculada em `spk7-adoption-decision.json`: `ADOPT_WITH_CONSTRAINTS`, com aprovação obrigatória do Platform Owner antes de qualquer integração no KortexOS.

## Aprovação do Platform Owner

Em 2026-08-10, o Platform Owner aprovou a adoção controlada recomendada pelo SPK-7 (`ADOPT_WITH_CONSTRAINTS`). A autorização cobre a integração local e versionada do fluxo, não cobre execução autônoma de produto, migrations, deploy, promoção, alteração de segredos ou ativação de feature flag.

## Primeiro dry-run integrado

Executado em 2026-08-10 com `specify-cli 0.12.11` e o workflow versionado em `.specify/kortex/workflows/kortexos-v1.yml`:

- `f8c3fc25`: `failed` no pre-flight porque o runtime não propagou a variável de raiz autorizada; o bloqueio foi correto e levou ao uso explícito de `--repo . --authorized-root .` no workflow.
- `7d7a1aac`: `paused` no gate `stop-before-mutation`; a retomada por input de gate não funcionou, confirmando a limitação de `verdict_input`/resume do pin atual.
- `6615f641`: `completed`, com pre-flight `GO`, adapter read-only de seis fontes, caminho de Benchmark não aplicável, aprovação allowlisted, fronteira sem mutação e handoff validado `GO`.
- `7749ccf3`: `failed` no pre-flight de uma tarefa `product-behavior` porque a branch local não possui ref `origin/<branch>`; o fluxo bloqueou antes do Benchmark Gate, como exige a precedência do pre-flight.
- `4ffd5ffd`: `completed` com o workflow v1.0.1, eval de contrato `20/20` + `10/10`, context pack progressivo, fan-out seguro, rollback dry-run e handoff `GO`.

O workflow não possui step de código de produto, migration, escrita externa, promoção ou ativação de feature flag. Os runs ficam preservados em `.specify/workflows/runs/` como evidência local e não autorizam promoção.

Telemetria integrada no momento: 5 runs, 2 completos, 1 pausado e 2 falhos (ambos bloqueios de pre-flight/integração), zero runs órfãos; tokens/custo continuam `UNKNOWN`.

## Validação em worktree limpo

O commit `4f04148` foi validado em `C:\tmp\kortexos-speckit-adoption`, branch `codex/speckit-adoption-validation`, acompanhando `origin/staging` (`ahead 1`) e sem alterações locais. O run `72576c42` completou o workflow v1.0.1 com pre-flight `GO`, todas as verificações read-only, handoff `GO`, zero falhas e zero runs órfãos. O estado de runs permanece no worktree temporário para auditoria local; não foi incluído no commit de integração.

## Gate SPK-0

**GO para SPK-0:** não há conflito de arquivos do Spec Kit nem autorização implícita para código/produto; a ref de comparação foi sincronizada e o snapshot foi registrado.

**SPK-1 = GO condicionado:** o adapter allowlisted preserva o gate humano quando não há aprovação; `verdict_input` permanece fora do caminho confiável no pin `0.12.11`.

**SPK-2 = GO:** contrato, adapter read-only e gate de 20 casos válidos/10 inválidos passaram.

**SPK-3 = GO limitado ao dry-run:** workflow KortexOS v1 validado sem mutação externa; ainda não autorizado para uso no worktree ou em qualquer ambiente.

**SPK-4 = GO limitado ao piloto:** evals em camadas passaram `11/11`; o próximo estágio deve testar paralelismo somente com write sets disjuntos e worktrees descartáveis.

**SPK-5 = GO limitado ao piloto:** fan-out/fan-in passou com dois workers, write sets disjuntos e redução medida de `41,7%`; os worktrees foram removidos.

**SPK-6 = GO limitado ao piloto:** context packs progressivos passaram com redução média de `51,62%`, sem perda de regras críticas ou drift.

**SPK-7 = ADOPT_WITH_CONSTRAINTS aprovado:** adoção iniciada somente com pre-flight de raiz, adapter allowlisted, revisão de shell, paralelismo limitado, telemetria de custo futura e rollback explícito, sob DEC-59/ADR-0024.

## DOCUMENTATION_CHECK

- [x] O documento está classificado em `docs/architecture/governance/`.
- [x] O frontmatter contém `title`, `status`, `stage`, `governance_ref`, `upstream_doc` e `last_updated`.
- [x] `docs/INDEX.md` será atualizado no mesmo turno.
- [x] Nenhuma ADR ou DEC foi criada; não houve decisão de produto.
- [x] Links locais e formatação devem ser validados antes do handoff.

FILES_CHANGED:
- `docs/architecture/governance/KORTEXOS_SPECKIT_BASELINE.md`: baseline read-only, pin proposto, métricas, superfícies intocáveis e gate SPK-0.
- `docs/INDEX.md`: entrada de navegação do baseline.

BLOCKERS_REMAINING:
- O pre-flight do `KORTEX_REPO` precisa validar a raiz autorizada antes de qualquer execução integrada.
- `verdict_input` não deve ser usado como controle de segurança no pin `0.12.11`.
- A integração só pode avançar pelas issues `044`–`053`, com revisão de segurança e sem mutação externa autônoma.

VEREDITO:
- `SPK-0 = GO`; `SPK-1 = GO condicionado`; `SPK-2 = GO`; `SPK-3 = GO limitado ao dry-run`; `SPK-4 = GO limitado ao piloto`; `SPK-5 = GO limitado ao piloto`; `SPK-6 = GO limitado ao piloto`; `SPK-7 = ADOPT_WITH_CONSTRAINTS aprovado por DEC-59`. Próximo passo: executar as issues `044`–`053` em ordem de dependência, preservando a condição de parada.
