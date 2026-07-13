---
name: kortex-mvpt-orchestrator
description: Orquestrar um sistema de múltiplos agentes para planejar, revisar e fatiar o MVPT do KortexOS, um ERP vertical de beleza e bem-estar com Supabase, Node.js/Express, PWA, Render e GitHub. Usar para transformar objetivos amplos em incrementos autorizados, coordenar especialistas, consolidar evidências e impedir expansão para V1.5, multi-tenant não comprovado ou migrations não autorizadas.
---

# Orquestrar o MVPT KortexOS

## Iniciar pelo estado real

1. Ler `AGENTS.md`, `docs/INDEX.md` e `docs/PROJECT_STATE.md` do repositório-alvo.
2. Tratar `PROJECT_STATE.md` como autoridade operacional e exemplos externos como referências não vinculantes.
3. Classificar cada afirmação como `REAL`, `PARCIAL`, `MOCKADO`, `HARDCODED`, `CRÍTICO`, `BLOQUEADO`, `DESCONHECIDO`, `OBSOLETO` ou `CONTRADITÓRIO`.
4. Manter o recorte MVP técnico: identidade, organizações/memberships, pessoas, catálogo, agenda, estoque, checkout, caixa e PWA modular.

## Coordenar especialistas

Delegar apenas subtarefas independentes e passar a cada agente arquivos, escopo, autoridade de escrita e formato de saída. Usar:

- `$kortex-truth-mapper` para confrontar documentos, código e evidências.
- `$kortex-supabase-guard` para schema, RPCs, grants, RLS e fronteiras de tenant.
- `$kortex-express-architect` para APIs, serviços e fonte de verdade no servidor.
- `$kortex-pwa-architect` para shell, módulos, cache e offline seguro.
- `$kortex-delivery-guardian` para JSON, segredos, GitHub e Render.
- `$kortex-qa-redteam` para gates, cenários adversariais e veto de release.

Executar em ondas: verdade e riscos; arquitetura por camada; QA e Red Team; integração final. Não permitir que dois agentes editem o mesmo arquivo simultaneamente.

## Produzir o plano

Entregar escopo, fora de escopo, árvore de repositório, contratos entre camadas, backlog fatiado, dependências, riscos, gates e decisão `GO`, `GO COM RESTRIÇÕES` ou `NO-GO`. Distinguir rigorosamente plano, draft e implementação.

Ler [references/mas-contracts.md](references/mas-contracts.md) para contratos de handoff e gates.

## Aplicar bloqueios

- Não copiar schema, numeração ou RPC de exemplos sem decisão técnica explícita.
- Criar migrations novas pela Supabase CLI e validar em ambiente local/descartável.
- Não declarar auth, RBAC ou multi-tenant seguros sem testes negativos.
- Não aceitar organization/tenant de body, query ou header sem validar membership autenticada.
- Não expor `service_role` ao frontend.
- Não permitir que frontend, fixture ou IA calculem verdade crítica.

## Encerrar

Reportar:

```text
FILES_CHANGED:
- <arquivo: natureza da mudança>
BLOCKERS_REMAINING:
- <bloqueio ou nenhum>
VEREDITO:
- <classificação, decisão e próximo passo único>
```
