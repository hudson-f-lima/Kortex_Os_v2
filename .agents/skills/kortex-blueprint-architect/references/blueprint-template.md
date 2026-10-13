# Template do Blueprint de Onda

Estrutura mínima, extraída do primeiro Blueprint materializado (Onda 0 — `docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_DRAFT.md`). Seções podem ganhar subitens, mas nenhuma pode faltar.

## 1. Autoridade e limites

O que este Blueprint materializa (Master Briefing, Truth Map, Migration Map — citar DEC de cada um) e o que ele explicitamente NÃO cria (domínios de onda futura, UI, SQL executável). Reafirmar a fronteira de tenant primária (`organization_id`) mesmo quando a Onda introduz fronteira subordinada.

## 2. Escopo de dados

Tabela por objeto novo/estendido: contrato técnico em prosa (não SQL) e estado (`Novo`/`Extensão`). Para cada objeto, citar explicitamente qualquer simplificação deliberada desta Onda (ex.: valor fixo em vez de configurável) e por quê.

## 3. Integridade e invariantes

Regras de concorrência, papéis, matriz de obrigatoriedade por papel/escopo quando aplicável. Toda regra "sempre"/"nunca" precisa estar aqui, não implícita no schema.

## 4. Contrato físico de schema

FKs, tipos, constraints, índices — em prosa técnica precisa o suficiente para virar SQL sem decisão adicional na Etapa 8. Se a decisão foi trigger vs. reescrita de RPC (ou equivalente), documentar a escolha e por que a alternativa foi rejeitada.

## 5. Compatibilidade e backfill

O que muda para chamadores existentes (idealmente: nada, via trigger de default-fill). Estratégia de backfill: inline na migration aditiva vs. script separado, e por quê.

## 6. Plano de execução e rollback

Quantas migrations, o que cada uma faz, e por que essa divisão (ex.: aditiva+backfill separada de hardening, para rollback seguro). Estado do banco em caso de falha parcial.

## 7. Matriz RLS e contratos afetados

Por objeto/tabela: quem pode ler/escrever, sob qual condição. Confirmar por leitura direta do código (rotas/RPCs existentes) que nenhum chamador quebra — citar arquivo e linha.

---

Depois de redigido, este documento vai para `$kortex-qa-redteam` (gate de desenho) antes de qualquer pedido de aprovação ao Platform Owner.
