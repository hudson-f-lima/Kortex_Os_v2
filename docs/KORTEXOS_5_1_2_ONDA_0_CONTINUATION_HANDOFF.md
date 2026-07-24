# Handoff de continuidade — Onda 0 (`units`)

**Audience:** outra inteligência ou pessoa responsável por revisar, promover ou iniciar a Onda 1.
**Objetivo:** retomar o trabalho a partir de uma base verificável, sem reabrir decisões já aprovadas nem cruzar ambientes.

## Estado atual

- Branch de trabalho: `codex/fix-onda0-local-gates`.
- Base histórica: `staging` local.
- Onda 0: **GO local** após correção forward-only e revisão adversarial.
- Promoção remota: depende de PR para `staging`, revisão humana e gates de ambiente/entrega.
- Produção: fora do escopo; nenhum deploy deve ser inferido deste documento.
- Arquivo local excluído do escopo: `.claude/settings.local.json`.

## Ordem canônica de leitura

Leia nesta ordem antes de alterar código, SQL ou documentação:

1. [`AGENTS.md`](../AGENTS.md) — invariantes, governança MAS e formato de handoff.
2. [`docs/INDEX.md`](INDEX.md) — mapa da fonte única de verdade.
3. [`KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md`](KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md) — visão vigente do produto.
4. [`KORTEXOS_5_1_2_TRUTH_MAP.md`](KORTEXOS_5_1_2_TRUTH_MAP.md) e [`KORTEXOS_5_1_2_MIGRATION_MAP.md`](KORTEXOS_5_1_2_MIGRATION_MAP.md) — realidade técnica e lacunas aprovadas.
5. [`KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_DRAFT.md`](KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_DRAFT.md) e [`KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_REDTEAM.md`](KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_REDTEAM.md) — desenho aprovado.
6. [`KORTEXOS_5_1_2_ONDA_0_IMPLEMENTATION.md`](KORTEXOS_5_1_2_ONDA_0_IMPLEMENTATION.md), [`KORTEXOS_5_1_2_ONDA_0_IMPLEMENTATION_REDTEAM.md`](KORTEXOS_5_1_2_ONDA_0_IMPLEMENTATION_REDTEAM.md) e [`adr/0016-onda0-units-architecture.md`](adr/0016-onda0-units-architecture.md) — materialização, evidência e decisões.
7. `docs/legacy/mvp-tecnico/` somente para contexto histórico; não é fonte ativa de escopo.

## O que esta branch entrega

### Banco e segurança

- Migration forward-only [`20260724115722_onda0_units_security_forward_fix.sql`](../supabase/migrations/20260724115722_onda0_units_security_forward_fix.sql).
- RLS unit-aware para fatos transacionais, unidades e vínculos.
- Comandos canônicos tenant-safe, `SECURITY DEFINER`, `search_path` fixo e `EXECUTE` somente para `service_role`.
- `membership_set` legado sem execução pelo backend.
- Lifecycle profissional fail-closed: delete, inativação e unlink desativam membership e revogam permissões.
- `professional_update` e `professional_delete` propagam o ator humano para auditoria.
- Unidade default única, timezone fixo `America/Sao_Paulo` e auditoria append-only sem eventos de no-op.

### Backend e testes

- Contexto de organização deriva tenant da membership autenticada.
- Agenda, clientes, checkout, pedidos e sync REST/SSE respeitam unidade, perfil e permissões.
- Testes de integração usam fixtures diretas somente para preparar dados; comandos de produção continuam canônicos.
- O teste HTTP de lifecycle confirma `actor_kind = user`, `actor_user_id` do owner e bloqueio da requisição seguinte.

## Gates locais reproduzíveis

Execute no diretório raiz, com o Supabase local descartável ativo:

```powershell
supabase db reset --local
supabase test db
Set-Location backend
npm.cmd test
npm.cmd run lint
Set-Location ..
supabase db lint --local
supabase db advisors --local --type all --level warn --fail-on error
git diff --check
```

Resultado esperado da validação desta branch:

| Gate | Resultado esperado |
|---|---:|
| Migrations | 15 aplicadas do zero |
| pgTAP integral | 346/346 |
| `supabase/tests/rls_units_test.sql` | 99/99 |
| Backend | 255/255 |
| Backend lint | 0 erros; 1 warning preexistente em `fase9.test.js` |
| SQL lint/advisors | nenhum achado |
| Frontend | 106/106 e build aprovado; não alterado nesta correção |

Não execute pgTAP e backend simultaneamente no mesmo banco: os testes HTTP escrevem dados e podem contaminar contagens de testes que exigem banco limpo.

## Protocolo de continuidade

1. Confirme `git status -sb`, branch atual e remote antes de qualquer ação.
2. Não inclua `.claude/settings.local.json`, `.env*`, chaves, artefatos de build ou arquivos fora do escopo.
3. Se alterar SQL, rode `supabase db reset --local` antes de interpretar qualquer teste.
4. Se alterar API, atualize teste de integração e documentação do contrato na mesma mudança.
5. Preserve as invariantes: tenant da membership, dinheiro em centavos, checkout atômico/idempotente, PWA sem `service_role` e migrations testadas localmente.
6. Toda promoção deve ser `feature/fix → staging → main`; branch de correção não deve abrir PR direto para `main`.
7. Antes de merge em `main`, acione `kortex-environment-guardian` e `kortex-delivery-guardian`; confirme Supabase/Render de staging sem cruzamento com produção.
8. A próxima execução de produto é o Blueprint da Onda 1 (Payment Core, Etapa 7). Não crie SQL da Onda 1 antes do Blueprint e aprovação explícita do Platform Owner.

## Veredito e bloqueadores

```text
FILES_CHANGED:
- Onda 0: migration forward-only, backend unit-aware, testes e documentação.

BLOCKERS_REMAINING:
- Revisão/merge do PR em staging.
- Validação de ambiente staging e gate de entrega antes de main.
- Aprovação própria do Blueprint da Onda 1 antes de novo SQL.

VEREDITO:
- Onda 0: GO local.
- Promoção remota/produção: BLOQUEADA até os gates próprios.
```

## Fontes de autoridade

- Código e migrations atuais são a verdade operacional.
- `docs/INDEX.md`, Master Briefing, Truth Map, Migration Map e ADRs são a verdade documental ativa.
- Blueprints antigos, exemplos externos e `docs/legacy/` não autorizam novos domínios, tabelas, RPCs ou limitações.
