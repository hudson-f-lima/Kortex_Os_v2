# KortexOS — regras do MVP técnico

## Ordem de leitura

1. `AGENTS.md`
2. `docs/INDEX.md`
3. `docs/PROJECT_STATE.md`
4. `docs/KORTEX_MVP_TECNICO.md`
5. habilidade aplicável em `.agents/skills/`

## Premissa

O produto é greenfield. SQL, blueprints e código externos são referências não autoritativas. Não preservar numeração, nomes, tabelas, RPCs ou limitações desses exemplos sem justificativa técnica atual.

## Escopo do MVP

Entregar um ERP vertical multi-tenant mínimo para beleza e bem-estar: organizações, usuários/memberships, clientes, profissionais, catálogo, agenda, estoque, checkout, pagamentos e caixa.

## Invariantes

- Backend Express é dono das regras e valida o JWT do Supabase Auth.
- Tenant deriva de membership autenticada; nunca de body/query isoladamente.
- PWA não recebe `service_role` e não escreve diretamente verdade financeira.
- Toda tabela de negócio possui `organization_id`, RLS e FK tenant-safe.
- Dinheiro usa centavos inteiros; checkout é atômico e idempotente.
- Migrations são criadas pela Supabase CLI e testadas em ambiente local/descartável antes de produção.
- Exemplos antigos podem inspirar testes, nunca definir a arquitetura.

## Processo MAS

Usar `$kortex-mvpt-orchestrator`. Delegar por domínio com ownership exclusivo de arquivos. Classificar evidência como `REAL`, `PARCIAL`, `MOCKADO`, `HARDCODED`, `CRÍTICO`, `BLOQUEADO`, `DESCONHECIDO`, `OBSOLETO` ou `CONTRADITÓRIO`.

## Handoff

```text
FILES_CHANGED:
- <paths e natureza>
BLOCKERS_REMAINING:
- <pendências>
VEREDITO:
- <estado e próximo passo>
```
