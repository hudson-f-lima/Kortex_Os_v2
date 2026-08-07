# Skills do ecossistema aberto incorporadas ao processo

Registro de decisão de 2026-07-24: quais skills do grupo `mattpocock/ai-engineer-workshop-2026-project` (e correlatas) entram no fluxo de onda do `kortex-mvpt-orchestrator`, onde, e quais ficam de fora — para não depender de alguém lembrar da conversa que originou a escolha.

## Incorporadas

| Skill | Onda | Como |
|---|---|---|
| `$grill-me` | Desenho | Usada *dentro* de `$kortex-blueprint-architect` para fechar toda decisão de design aberta (uma pergunta por vez, com recomendação) antes de redigir qualquer seção do Blueprint. Não é uma onda própria — é o método de trabalho da onda de Desenho. |
| `$prd-to-issues` | Fatiamento | Onda nova, inserida entre Desenho e Implementação. Quebra o Blueprint aprovado em fatias verticais (`issues/NNN-titulo.md`, tracer bullet — schema→API→teste de ponta a ponta), marcadas `HITL`/`AFK`. Existe porque a Onda 0 provou o risco de fazer uma Onda inteira como um incremento só: a lacuna de RLS/FK só foi achada em auditoria pós-hoc, depois de já declarada "concluída". |
| `$tdd` | Implementação | Cada fatia do Fatiamento é implementada com um teste por comportamento, RED→GREEN, nunca escrevendo todos os testes primeiro e depois todo o código (slicing horizontal produz teste que não pega regressão real). |
| `$improve-codebase-architecture` | Integração (opcional, não bloqueia) | Ao fechar uma Onda, pode ser usada para sinalizar candidatos a refactor nos módulos que mais cresceram (ex.: `organizationContext.js`, que a Onda 0 reescreveu pesado). Produz RFC em `issues/`, não é gate — a Onda fecha sem depender dela. |

## Fora do fluxo de onda (uso pontual, fora do pipeline de Onda)

| Skill | Por que fica fora |
|---|---|
| `$write-a-prd` | O Blueprint de Onda (via `$kortex-blueprint-architect`) já cobre o mesmo papel — interview + esboço de módulos — mas com o rigor de schema/RLS que uma Onda exige. Um PRD genérico seria redundante dentro do pipeline de Onda. Uso legítimo: features pequenas fora do escopo de qualquer Onda do Migration Map (ex.: uma tela nova, um ajuste de UX) que não justificam abrir Blueprint. |
| `$find-skills` | Meta-ferramenta de descoberta de skills, não uma etapa de execução. Relevante só se uma Onda futura precisar de uma capacidade que nenhuma skill `kortex-*` cobre hoje. |
| `$better-sqlite3-rebuild` | Corrige mismatch de versão do Node para o módulo nativo `better-sqlite3`. **Não se aplica** — o projeto não tem nenhuma dependência de SQLite (persistência é 100% Supabase/Postgres). Fica instalada só porque veio junto no grupo do workshop; inofensiva, nunca vai disparar aqui. |

## Regra de ouro

Fatiar (`AFK`) reduz o tamanho de cada decisão do Platform Owner, nunca remove onde o julgamento dele é necessário: aprovar Blueprint, autorizar SQL (Etapa 8) e promover ambiente continuam exigindo aprovação explícita, fatia ou não.
