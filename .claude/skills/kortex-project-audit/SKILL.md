---
name: kortex-project-audit
description: Audita o estado real do KortexOS, sincroniza evidências entre código, testes e governança e define o próximo incremento seguro.
---

# Auditoria e continuidade do KortexOS

## Quando usar

Use ao retomar o KortexOS após troca de sessão, receber snapshot/ZIP, revisar estado global ou planejar a conclusão do produto. Esta habilidade não substitui `kortex-mvpt-orchestrator`, `kortex-truth-mapper`, `kortex-qa-redteam`, `kortex-environment-guardian` nem `kortex-delivery-guardian`.

## Princípio

Trate código/testes executados como evidência técnica, documentação como contrato e autorização, e relato humano como pista a verificar. Classifique cada achado como `REAL`, `PARCIAL`, `MOCKADO`, `HARDCODED`, `CRÍTICO`, `BLOQUEADO`, `DESCONHECIDO`, `OBSOLETO` ou `CONTRADITÓRIO`.

## Sequência obrigatória

1. Leia `AGENTS.md`, `docs/INDEX.md`, Master Briefing, Truth Map, Migration Map e os handoffs da onda ativa.
2. Se houver Git: `git status`, `git fetch`, branch atual, divergência com upstream e commits recentes. Nunca inferir o remoto a partir de um ZIP sem `.git`. Se só houver snapshot, registrar explicitamente que comparação remota não foi feita.
3. Identifique a onda ativa e sua etapa; confronte Decision Log, issues, migrations, frontend/backend e estado dos ambientes. Não converta documentação de plano em prova de implementação.
4. Rode os gates reproduzíveis disponíveis: instalação limpa por lockfile, lint/testes/build de backend/frontend; para banco, `supabase db reset`, pgTAP e `supabase db lint --local`, respeitando a ordem ambiental prescrita nos docs. Não use produção como ambiente de teste.
5. Para cada conclusão, registrar caminho/linha ou comando e resultado. Distinguir `confirmado no snapshot`, `confirmado no remoto`, `não verificado` e `bloqueado por acesso/infraestrutura`.
6. Produza um mapa de bloqueios ordenado por dependência: requisito, evidência faltante, responsável/credencial/ambiente necessário, gate de saída e próximo passo reversível.
7. Escolha um incremento pequeno e autorizado. Mudança de produto/schema exige Blueprint e autorização de Etapa 8 conforme `AGENTS.md`; não deduza autorização ampla de uma solicitação genérica para “terminar o projeto”.
8. Mudanças em `.agents/skills/kortex-*` devem ser copiadas para `.claude/skills/kortex-*` no mesmo turno. Alteração documental segue o protocolo de automação documental e atualiza índices/rastreabilidade.
9. Handoff final deve conter: escopo auditado, evidências/gates, achados por severidade, decisões pendentes, bloqueios externos, arquivos alterados, testes e próximo passo exato. Nunca afirmar merge, deploy, homologação ou aprovação sem prova observável.

## Limites de segurança operacional

- Nunca imprimir ou commitar segredos; use `.env.example` como lista de variáveis e reporte nomes ausentes, não valores secretos.
- Não aplicar migrations, mudar feature flags em ambiente compartilhado, promover branches, fazer deploy, apagar dados ou alterar billing sem gate/documentação e autorização específica para aquele ambiente/ação.
- A autorização para trabalhar no projeto permite análise e mudanças locais reversíveis; não supre acesso a GitHub, Supabase, Render, credenciais ou aprovação formal registrada exigida pela governança.
- Se o ambiente remoto estiver indisponível, entregar uma conclusão local reproduzível e explicitar a pendência sem inventar sucesso.

## Formato de achado

`[SEVERIDADE] [ESTADO] afirmação — evidência (arquivo/comando) — impacto — ação/gate para fechar.`
