---
name: kortex-migration-mapper
description: Mapeia nomes, domínios, prefixos e impacto de promoção do MVP para o produto final KortexOS 5.1.2, a partir de um Truth Map aprovado.
---

# Mapear a migração do KortexOS

## 1. Quando ativar
- Depois que um Truth Map (`docs/KORTEXOS_5_1_2_TRUTH_MAP.md` ou versão posterior) estiver aprovado pelo Platform Owner e registrado como DEC no Decision Log — Etapa 6 da ordem de construção (Master Briefing §22.1).

## 2. Quando não ativar
- Antes da aprovação explícita do Truth Map vigente (etapa 5 ainda pendente/rascunho).
- Para escrever SQL, migration ou código de fato — isso é Etapa 8 (SQL Master), bloqueada até o Blueprint (Etapa 7) ser aprovado.
- Para redesenhar regra de produto já decidida no Master Briefing — este skill mapeia nomes e impacto, não inventa arquitetura nova.

## 3. Objetivo
- Traduzir cada lacuna `CRÍTICO`/`AUSENTE` do Truth Map em: domínio canônico (D00–D31), nome de tabela/objeto seguindo a convenção `kortex_*` do Master §7.4, dependências de ordem (FK/migration order) e impacto sobre tabelas MVP existentes (rename, extensão ou coexistência).

## 4. Entradas necessárias
- [docs/KORTEXOS_5_1_2_TRUTH_MAP.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/docs/KORTEXOS_5_1_2_TRUTH_MAP.md) — aprovado, com DEC registrado.
- [docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md) — domínios D00–D31 (§5), objetos conceituais (§7.4), Gates (§21).
- Schema real do banco (`list_tables`/`supabase/migrations/`) — nunca supor nome de tabela sem checar o schema vigente.
- [references/mapping-conventions.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-migration-mapper/references/mapping-conventions.md)

## 5. Fluxo mínimo
1. Confirmar que o Truth Map de entrada está aprovado (DEC correspondente existe no Decision Log) — sem isso, parar e reportar bloqueio.
2. Para cada item `CRÍTICO`/`AUSENTE` do Truth Map, propor: domínio dono (D00–D31), nome de objeto conforme convenção, e se ele estende uma tabela MVP existente ou cria uma nova.
3. Mapear dependências: qual objeto precisa existir antes de outro (ex.: `kortex_accounts` antes de `kortex_ledger_entries`).
4. Marcar explicitamente qualquer rename ou alteração de tabela MVP existente como mudança de alto risco, citando o invariante do AGENTS.md que ela toca.
5. Produzir o Migration Map como artefato de mapeamento — nomes, domínios, ordem, impacto — nunca como SQL executável.

## 6. Restrições críticas
- Nunca escrever ou sugerir SQL/DDL executável — apenas nomes, domínios e ordem conceitual.
- Nunca renomear ou alterar tabela MVP existente sem marcar como decisão do Platform Owner, nunca silenciosa.
- Preservar todos os invariantes do MVP técnico (AGENTS.md) — tenant, RLS, `_cents`, idempotência, backend-only.
- Não avançar para Blueprint (Etapa 7) dentro deste skill — condição de parada é o Migration Map em si.

## 7. Arquivos que podem ser carregados
- [references/mapping-conventions.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-migration-mapper/references/mapping-conventions.md)
- [../kortex-truth-mapper/references/classification.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-truth-mapper/references/classification.md)

## 8. Condição de parada
- Migration Map completo: cada lacuna do Truth Map aprovado tem domínio, nome proposto, ordem de dependência e impacto sobre schema existente — revisado pelo Platform Owner, sem SQL escrito.

## 9. Formato de saída
```text
Migration Map:
- Domínio (D0X) | Objeto proposto | Estende/novo | Depende de | Impacto em tabela MVP existente | Risco
```
