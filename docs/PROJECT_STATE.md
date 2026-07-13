# PROJECT STATE — KortexOS MVP técnico

**Atualizado:** 2026-07-13 (módulo profissionais)

## Estado

| Área | Estado | Evidência |
|---|---|---|
| Arquitetura greenfield | `REAL` como especificação | `KORTEX_MVP_TECNICO.md` |
| Suite MAS | `REAL` | `.agents/skills/*` |
| Docker Desktop + WSL 2 | `REAL` | Docker Engine 29.6.1; contêiner de teste aprovado |
| Supabase local | `REAL` | Auth e Studio HTTP 200; contêineres principais saudáveis |
| Baseline Supabase | `REAL` local | migration aplicada por `supabase db reset` |
| Auth/tenant/RLS | `REAL` no schema local | 13/13 tabelas públicas com RLS; 69 testes pgTAP (grants, RLS, cross-tenant, invariante de owner) em `supabase/tests/`, todos `PASS` |
| Checkout atômico | `REAL` no schema local | `rpc_checkout_close_test.sql` (14 testes): idempotência, replay divergente, estoque insuficiente, reconciliação de pagamento, cross-tenant, atomicidade em falha |
| Backend Express | `PARCIAL` | `backend/` materializado: `/health`, middleware JWT (JWKS, ES256), contexto de organização (`X-Organization-Id` + membership real) e módulos `clients`/`professionals` completos (CRUD + roles); 46 testes (unit/integration/contract), incluindo fluxos reais contra Supabase Auth/DB local. Catálogo/agenda/checkout/caixa ainda não têm rota |
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
- Suíte pgTAP criada em `supabase/tests/` (6 arquivos, 69 testes): `rls_baseline_test.sql`, `rls_business_tables_test.sql`, `rpc_create_organization_test.sql`, `rpc_membership_set_test.sql`, `rpc_checkout_close_test.sql`, `rpc_inventory_adjust_test.sql`. `supabase test db --local` retorna `PASS` de forma reprodutível após `db reset --local --no-seed` limpo.
- **Gap real encontrado e corrigido pelos testes de integração do backend:** a migration baseline nunca concedeu `SELECT/INSERT/UPDATE/DELETE` em tabelas públicas para `service_role` (só `EXECUTE` nas 4 RPCs); `service_role` tem `BYPASS RLS` mas isso é inócuo sem grants. O backend recebia `permission denied for table memberships` ao listar organizações. Corrigido pela migration `20260713034222_grant_service_role_tables.sql`; `db advisors` seguiu limpo e a suíte pgTAP (69 testes) segue `PASS` após o reset.
- `backend/` materializado (`src/config`, `middleware`, `shared`, `modules/{health,organizations}`, `tests/{unit,integration,contract}`). Testado com `npm test` (Node test runner + supertest): 12/12 `PASS`, incluindo um fluxo real contra o Supabase Auth local (signup real, JWT ES256 validado via JWKS, `X-Organization-Id` sem membership rejeitado com 403, contrato de erro estável sem stack/segredo). Servidor real também subido via `node src/server.js` e `/health` respondeu 200 por HTTP.
- Módulo `clients` materializado (`src/modules/clients/{clients.validation,clients.service,clients.route}.js`): CRUD completo (`GET/POST/PATCH/DELETE /api/v1/clients`) via `service_role`, espelhando os mesmos roles das policies RLS (`owner/admin/manager/reception` para leitura/escrita, `owner/admin/manager` para exclusão) como segunda camada de defesa. `shared/postgresError.js` mapeia violação de FK (`23503`) para `409 referenced_by_other_records` em vez de vazar erro cru do Postgres. 19 testes novos (8 unit de validação + 6 integração real: CRUD completo, role gating por papel, isolamento cross-tenant por id direto, conflito de FK ao deletar cliente com agendamento).
- Módulo `professionals` materializado no mesmo padrão (`GET/POST/PATCH/DELETE /api/v1/professionals`): leitura liberada a qualquer membro ativo (`professionals_select` não restringe por role), escrita restrita a `owner/admin/manager`, exclusão a `owner/admin`. `user_id` (vínculo opcional a uma membership) é validado antes do insert/update com uma pré-checagem explícita (`invalid_user_id`) em vez de depender só da FK; violação de unicidade `(organization_id, user_id)` mapeada para `409 already_exists` (novo caso `23505` em `shared/postgresError.js`). Helper `setUpOrgWithRole` de testes foi extraído para `tests/helpers/localSupabase.js` e reaproveitado por `clients.test.js` e `professionals.test.js`. 15 testes novos (10 unit + 5 integração real: CRUD, gating por role incluindo leitura irrestrita, vínculo/unicidade de `user_id`, cross-tenant, conflito de FK ao deletar profissional com agendamento). Suíte completa do backend: 46/46 `PASS`.

## Decisão vigente

Os SQL enviados pelo usuário são exemplos. A arquitetura foi redefinida sem compatibilidade obrigatória. `API_ACCESS_TOKEN` e `DEFAULT_EMPRESA_ID` foram removidos do contrato.

## Próxima ação

Materializar os módulos de negócio restantes no backend Express (catálogo, agenda, checkout, caixa) seguindo o mesmo padrão (validação pura + serviço + rota fina, roles espelhando RLS, RPCs para mutações transacionais); depois iniciar a PWA modular.
