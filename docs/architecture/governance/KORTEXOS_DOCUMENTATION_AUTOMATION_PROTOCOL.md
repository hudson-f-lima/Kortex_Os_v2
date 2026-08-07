---
title: "Protocolo de Automação Documental para Agentes de IA"
status: "APROVADO"
stage: "DECISION"
governance_ref: ["DEC-43"]
upstream_doc: "AGENTS.md"
last_updated: "2026-07-27"
---

# Protocolo de Automação Documental para Agentes de IA

## Objetivo

Evitar *document drift* no KortexOS ao tornar a classificação Diátaxis, a rastreabilidade e a validação de documentação parte do trabalho de todo agente. Este protocolo é processual: não cria domínio, tabela, endpoint ou autorização de promoção.

## Cadeia obrigatória

`AGENTS.md` define as invariantes; as skills especializadas aplicam o fluxo; `docs/INDEX.md` expõe a navegação SSoT; código e testes fornecem a evidência de realidade. Em conflito, obedecer a `AGENTS.md`, à evidência executável e às DEC/ADRs vigentes.

## Classificação Diátaxis

Não criar Markdown novo na raiz de `docs/`. Classificar cada artefato novo em exatamente um destino:

| Destino | Uso |
|---|---|
| `docs/architecture/` | visão, tese, ADR, Decision Log e governança |
| `docs/waves/` | Truth Map, Migration Map, Blueprints, evidências e handoffs por onda |
| `docs/reference/` | dicionários de dados, especificações e políticas estáveis |
| `docs/how-to/` | procedimentos operacionais e guias de teste |

`docs/INDEX.md` e o entry point do Master na raiz de `docs/` são exceções de navegação. `docs/legacy/` permanece histórico. Só mover conteúdo existente por tarefa de migração explícita, atualizando todos os links de entrada no mesmo turno.

## Frontmatter obrigatório

Todo Markdown novo criado por agente em `docs/` fora de `legacy/`, ou em `issues/`, inicia com:

```yaml
---
title: "Nome do Artefato"
status: "DRAFT | PROPOSED | APROVADO | EM_REMEDIACAO"
stage: "VISION | DECISION | TRUTH_MAP | MIGRATION_MAP | BLUEPRINT | ISSUE"
governance_ref: ["DEC-xx", "ADR-xxxx"]
upstream_doc: "caminho/do/documento/pai.md"
last_updated: "YYYY-MM-DD"
---
```

Use `[]` em `governance_ref` e `null` em `upstream_doc` quando não houver referência real. Não invente IDs. `AGENTS.md` e `SKILL.md` são exceções técnicas: usam os formatos de instrução exigidos pela ferramenta.

## Atualização em cadeia

No mesmo turno em que alterar um artefato:

1. Blueprint alterado: atualizar a issue rastreável e qualquer evidência da onda afetada.
2. Decisão técnica registrada: criar/atualizar a ADR, registrar o DEC quando aplicável e atualizar a matriz DEC↔ADR no Decision Log.
3. Documento novo, estado alterado ou navegação afetada: atualizar `docs/INDEX.md`.
4. Issue concluída: mover para `issues/completed/` somente depois de atualizar todos os links de entrada e o índice. Não arquivar issue apenas por parecer concluída.

## Supersessão

Uma revogação integral exige, no cabeçalho do artefato anterior, `STATUS: SUPERSEDED BY [DEC/ADR]` com link. Uma alteração parcial deve identificar a regra e o escopo afetados, mantendo explícito o que continua vigente. Nunca reescrever ou apagar o histórico para esconder a decisão anterior.

## Validação e handoff

Antes de concluir, validar os links Markdown locais afetados e emitir:

```text
DOCUMENTATION_CHECK:
- [ ] O novo documento atende ao padrão Diátaxis (ou a exceção histórica foi registrada)?
- [ ] O frontmatter YAML foi preenchido quando aplicável?
- [ ] O docs/INDEX.md foi atualizado quando houve novo documento, estado ou navegação?
- [ ] Alguma ADR ou DEC foi criada, afetada ou superada?
```

## Limites

Este protocolo não substitui o Truth Map, não eleva evidência sem teste, não autoriza SQL, `staging`, `main` ou produção. Em qualquer divergência, registrar a contradição e pedir decisão ao Platform Owner.
