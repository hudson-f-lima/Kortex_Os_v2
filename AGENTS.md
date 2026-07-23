# KortexOS — regras de arquitetura e governança

## Ordem de leitura

1. `AGENTS.md`
2. `docs/INDEX.md`
3. `docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` (visão vigente)
4. `docs/KORTEXOS_5_1_2_TRUTH_MAP.md` + `docs/KORTEXOS_5_1_2_MIGRATION_MAP.md` (realidade técnica atual + próximos objetos)
5. habilidade aplicável em `.agents/skills/`

A construção do MVP técnico (Fases 1–11, Trilhas A–E) foi encerrada formalmente em 2026-07-20 (DEC-29). `docs/legacy/mvp-tecnico/PROJECT_STATE.md` e `docs/legacy/mvp-tecnico/KORTEX_MVP_TECNICO.md` continuam corretos sobre o que está em produção hoje, mas não são mais lidos como fonte ativa de escopo — consulte-os só para contexto histórico.

## Premissa

O produto é greenfield. SQL, blueprints e código externos são referências não autoritativas. Não preservar numeração, nomes, tabelas, RPCs ou limitações desses exemplos sem justificativa técnica atual.

## Fundação em produção (MVP, encerrado)

O MVP entregue e em produção — ERP vertical multi-tenant mínimo para beleza e bem-estar: organizações, usuários/memberships, clientes, profissionais, catálogo, agenda, estoque, checkout, pagamentos e caixa — é a fundação real sobre a qual a Trilha 5.1.2 constrói (ver Truth Map). Não é redesenhada do zero; é estendida.

## Invariantes

- Backend Express é dono das regras e valida o JWT do Supabase Auth.
- Tenant deriva de membership autenticada; nunca de body/query isoladamente.
- PWA não recebe `service_role` e não escreve diretamente verdade financeira.
- Toda tabela de negócio possui `organization_id`, RLS e FK tenant-safe.
- Dinheiro usa centavos inteiros; checkout é atômico e idempotente.
- Migrations são criadas pela Supabase CLI e testadas em ambiente local/descartável antes de produção.
- Exemplos antigos podem inspirar testes, nunca definir a arquitetura.
- A interface (PWA) DEVE usar exclusivamente os componentes primitivos do Kortex Design System (`<Button>`, `<Input>`, `<Badge>`, etc.) localizados em `ui/primitives`, nunca tags HTML nativas. A tela principal (Agenda) usa obrigatoriamente layout em Timeline Vertical.

## Processo MAS

Usar `$kortex-mvpt-orchestrator`. Delegar por domínio com ownership exclusivo de arquivos. Classificar evidência como `REAL`, `PARCIAL`, `MOCKADO`, `HARDCODED`, `CRÍTICO`, `BLOQUEADO`, `DESCONHECIDO`, `OBSOLETO` ou `CONTRADITÓRIO`.

Toda promoção entre branches/ambientes (feature → `staging`, `staging` → `main`) passa por `$kortex-environment-guardian`, que confirma a origem/destino corretos e a ausência de cruzamento entre os valores de staging e produção. Ele aciona `$kortex-delivery-guardian` como gate final antes de qualquer merge em `main` — cujo veredito passa a significar "seguro para promover a produção", não apenas "seguro para publicar".

## Trilha ativa: KortexOS 5.1.2

`docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` é a visão de produto final vigente **e**, desde o encerramento do MVP, a única trilha ativa de execução (Trilha F do `docs/INDEX.md`). Ela não substitui as Invariantes acima nem autoriza domínio, tabela ou endpoint novo por si só — `docs/KORTEXOS_5_1_2_TRUTH_MAP.md` audita a lacuna entre a fundação em produção e aquela visão, e a promoção segue etapas gated (Migration Map → Blueprint → SQL) que exigem aprovação explícita do Platform Owner em cada uma. Estado em 2026-07-20: Migration Map aprovado (v1.2); Blueprint (etapa 7) desbloqueado, ainda não iniciado — é o próximo passo.

## Handoff

```text
FILES_CHANGED:
- <paths e natureza>
BLOCKERS_REMAINING:
- <pendências>
VEREDITO:
- <estado e próximo passo>
```
