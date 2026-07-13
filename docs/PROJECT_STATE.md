# PROJECT STATE — KortexOS MVP técnico

**Atualizado:** 2026-07-13

## Estado

| Área | Estado | Evidência |
|---|---|---|
| Arquitetura greenfield | `REAL` como especificação | `KORTEX_MVP_TECNICO.md` |
| Suite MAS | `REAL` | `.agents/skills/*` |
| Docker Desktop + WSL 2 | `REAL` | Docker Engine 29.6.1; contêiner de teste aprovado |
| Supabase local | `REAL` | Auth e Studio HTTP 200; contêineres principais saudáveis |
| Baseline Supabase | `REAL` local | migration aplicada por `supabase db reset` |
| Auth/tenant/RLS | `REAL` no schema local | 13/13 tabelas públicas com RLS |
| Checkout atômico | `PARCIAL` | RPC criada e migration aplicada; teste funcional de comando ainda pendente |
| Backend Express | `BLOQUEADO` | não materializado |
| PWA | `BLOQUEADO` | não materializada |
| CI/Render | `PARCIAL` | `render.yaml` real criado (URL e publishable key preenchidos, secrets como `sync: false`); `rootDir: backend`/`rootDir: frontend` ainda não existem, deploy falharia até materializar o código |

## Validação executada

- Supabase CLI `2.109.0` criou a migration baseline.
- Parser PostgreSQL (`pglast`) aprovou a sintaxe das 639 linhas.
- Red Team inicial encontrou grants financeiros, update direto de estoque e invariantes de tenant/owner; a migration foi endurecida com allowlist determinística, RPC `inventory_adjust`, organização ativa, ownership e autoria tenant-safe.
- A segunda revisão fechou a fronteira API-only: `anon/authenticated` não recebem acesso de negócio; RPCs são exclusivas de `service_role`, recebem ator validado e membership management é serializado por organização.
- Docker Desktop 4.81.0 e WSL 2.7.10 foram instalados; Docker Engine 29.6.1 está ativo.
- Analytics local foi desabilitado por ser opcional ao MVP e incompatível com o coletor de logs nesta instalação Windows.
- `supabase db reset --local --no-seed` concluiu duas vezes; a segunda execução ficou limpa.
- `supabase db advisors --local --type all --level warn --fail-on warn` retornou `No issues found`.
- Auth e Studio respondem HTTP 200; schema contém 13 tabelas públicas, todas com RLS, e 4 RPCs de negócio.
- `render.yaml` (raiz do repo) foi verificado: nenhum segredo real exposto (`SUPABASE_SERVICE_ROLE_KEY`/`SUPABASE_SECRET_KEY` como `sync: false`); porém `rootDir: backend`/`rootDir: frontend` apontam para diretórios ainda inexistentes.

## Decisão vigente

Os SQL enviados pelo usuário são exemplos. A arquitetura foi redefinida sem compatibilidade obrigatória. `API_ACCESS_TOKEN` e `DEFAULT_EMPRESA_ID` foram removidos do contrato.

## Próxima ação

Adicionar testes funcionais de Auth/RLS/cross-tenant e das RPCs; depois materializar o backend Express com middleware JWT e contexto de organização.
