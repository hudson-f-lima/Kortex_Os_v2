---
name: kortex-blueprint-architect
description: Desenha o Blueprint técnico (Etapa 7) de uma Onda do Migration Map — schema, RLS, triggers e comandos — fechando cada decisão de desenho por interview antes de redigir.
---

# Desenhar o Blueprint de uma Onda

## 1. Quando ativar
- Depois que o Migration Map vigente estiver aprovado (DEC registrado) e a Onda em questão tiver item(s) mapeado(s) — Etapa 7 da ordem de construção (Master Briefing §22.1).

## 2. Quando não ativar
- Antes do Migration Map da Onda estar aprovado (Etapa 6 pendente).
- Para escrever SQL, migration ou código executável — isso é Etapa 8 (SQL Master), bloqueada até este Blueprint ser aprovado.
- Para reabrir decisão de produto já fechada no Master Briefing — este skill materializa regra já decidida, não inventa regra nova.

## 3. Objetivo
- Produzir um contrato técnico completo e auditável (objetos, colunas, tipos, FKs, RLS, triggers, comandos) para os itens `CRÍTICO`/`AUSENTE` da Onda, com toda decisão de desenho não trivial fechada por interview — nunca assumida — antes da redação final.

## 4. Entradas necessárias
- [docs/KORTEXOS_5_1_2_MIGRATION_MAP.md](docs/KORTEXOS_5_1_2_MIGRATION_MAP.md) — aprovado, com o escopo da Onda em questão.
- [docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md](docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md) — regra de produto vigente por domínio.
- Schema real do banco (`list_tables`/`supabase/migrations/`) — nunca supor coluna ou tabela sem checar o schema atual.
- [references/blueprint-template.md](references/blueprint-template.md)

## 5. Fluxo mínimo
1. Confirmar que o Migration Map cobre a Onda e está aprovado (DEC correspondente existe) — sem isso, parar e reportar bloqueio.
2. Listar as decisões de desenho ainda abertas (não fechadas pelo Master Briefing/Migration Map): escopo de dado nullable vs. obrigatório, trigger vs. reescrita de RPC, split de migration, qualquer trade-off com mais de uma opção viável.
3. Para cada decisão que crie ou refine comportamento de produto, executar o **Benchmark Gate** antes da interview: consultar primeiro o Booksy, depois os principais players do mercado e, quando aplicável, referências cross-industry. Registrar links e separar `FATO`, `INFERÊNCIA` e `DECISÃO`; ausência de precedente Booksy também é evidência e não permite pular as comparações seguintes.
4. Para cada decisão aberta, usar `$grill-me` — uma pergunta por vez, com recomendação própria, explorando o código quando a resposta estiver nele — até fechar todas antes de redigir qualquer seção do Blueprint.
5. Redigir o Blueprint seguindo [references/blueprint-template.md](references/blueprint-template.md): autoridade e limites, escopo de dados, integridade/invariantes por tenant e por unidade, contrato físico de schema, compatibilidade e backfill, plano de execução e rollback, matriz RLS.
6. Encaminhar o Blueprint para `$kortex-qa-redteam` (gate de desenho) antes de pedir aprovação do Platform Owner.
7. Após aprovação explícita do Platform Owner, registrar o DEC correspondente no Decision Log (e ADR quando a decisão for arquitetural/técnica) como parte deste mesmo fluxo — nunca como tarefa separada pendente de lembrete (ver `references/mas-contracts.md` do `kortex-mvpt-orchestrator`, seção "Registro automático de decisão").

## 6. Restrições críticas
- Nunca escrever SQL, migration ou DDL executável — apenas contrato técnico (Etapa 8 é skill/etapa separada).
- Nunca redigir uma seção do Blueprint com uma decisão de desenho ainda aberta — sempre fechar via `$grill-me` primeiro.
- Nunca fechar decisão de comportamento de produto sem o Benchmark Gate documentado; se a evidência estiver ausente, marcar a decisão como aberta/bloqueada.
- Nunca alterar regra de produto do Master Briefing — só materializar em schema o que já foi decidido lá.
- Nunca declarar o Blueprint "aprovado" sem o DEC correspondente registrado no Decision Log.
- Preservar todos os invariantes do AGENTS.md — tenant derivado de membership, `_cents`, idempotência, RLS fail-closed.

## 7. Arquivos que podem ser carregados
- [docs/KORTEXOS_5_1_2_MIGRATION_MAP.md](docs/KORTEXOS_5_1_2_MIGRATION_MAP.md)
- [docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md](docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md)
- [references/blueprint-template.md](references/blueprint-template.md)
- [../kortex-mvpt-orchestrator/references/mas-contracts.md](../kortex-mvpt-orchestrator/references/mas-contracts.md)

## 8. Condição de parada
- Blueprint completo, sem decisão de desenho aberta, `$kortex-qa-redteam` emitiu `GO` de desenho, e DEC registrado no Decision Log.

## 9. Formato de saída
```text
BLUEPRINT_STATUS:
- Onda / item do Migration Map: <...>
- Decisões fechadas por $grill-me: <lista curta>
- Red Team de desenho: <GO/NO-GO, motivo>
- Benchmark Gate: <FATOS/INFERÊNCIAS/DECISÃO e fontes, ou BLOQUEADO>
- DEC registrado: <SIM (número) / NÃO>
PRÓXIMO_PASSO:
- <Etapa 8 liberada mediante aprovação explícita / bloqueado, motivo>
```
