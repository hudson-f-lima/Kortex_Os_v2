---
name: kortex-supabase-guard
description: Projeta, implementa e audita o Supabase/Postgres do KortexOS.
---

# Guardar o Supabase greenfield

## 1. Quando ativar
- Em qualquer alteração de banco de dados, criação de tabelas, modificação de políticas RLS, escrita de RPCs ou novas migrations.

## 2. Quando não ativar
- Durante desenvolvimento de UI frontend puro ou lógica de rotas Express que não afetem a estrutura ou políticas do banco de dados.

## 3. Objetivo
- Projetar e auditar um banco de dados relacional multi-tenant seguro e performático usando o ecossistema Supabase/Postgres.

## 4. Entradas necessárias
- Especificações do schema, regras de acesso e migrations locais existentes.

## 5. Fluxo mínimo
1. Carregar as regras de schema de [references/greenfield-schema.md](references/greenfield-schema.md).
2. Criar novas migrations via Supabase CLI (`supabase migration new`).
3. Aplicar localmente (`supabase db reset`) e verificar advisors (`supabase db advisors`).
4. Desenvolver testes unitários de banco de dados (pgTAP) cobrindo caminhos felizes e ataques (RLS bypass).

## 6. Restrições críticas
- Toda tabela de negócio deve possuir a coluna `organization_id` e RLS ativado.
- Proibir chaves compostas que permitam vazamento cross-tenant (usar FK compostas `(organization_id, id)`).
- Não expor dados ou conceder grants à roles anônimas ou autenticadas padrão no backend API-only; usar `service_role` exclusivamente no servidor.
- Fixar `search_path` e validar membership de forma rígida em funções `SECURITY DEFINER`.

## 7. Arquivos que podem ser carregados
- [references/greenfield-schema.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-supabase-guard/references/greenfield-schema.md)

## 8. Condição de parada
- Migrations aplicadas localmente com sucesso, pgTAP passando (100% PASS), e advisors sem avisos de segurança ou performance.

## 9. Formato de saída
- SQL da migration gerada e relatório pgTAP de testes executados:
```text
MIGRATION: <nome_da_migration>
TESTS: <resumo pgTAP de acertos/erros>
RLS_AUDIT: <tabelas alteradas e RLS habilitado: SIM/NÃO>
```
