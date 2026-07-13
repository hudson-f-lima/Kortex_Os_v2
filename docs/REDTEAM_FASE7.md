# Red Team — Fase 7 (CI, Render, Observabilidade)

Veredito adversarial da Fase 7, seguindo a matriz de `.agents/skills/kortex-qa-redteam/references/gate-matrix.md`. Evidência re-executada nesta sessão (2026-07-13), não reaproveitada de afirmações antigas do `PROJECT_STATE.md` sem confirmação nova.

## Contexto encontrado no início desta fase

O CI (`.github/workflows/ci.yml`, `.github/workflows/deploy-pages.yml`) já tinha sido materializado e commitado (`33727cb`..`65e307e`) fora desta sessão, antes de eu revisar o estado do repositório. Esta auditoria não assumiu que estava correto só por já existir — reexecutou tudo e encontrou 2 defeitos reais, corrigidos nesta sessão (ver `FILES_CHANGED`).

## Matriz de gates

| Gate | Evidência executada nesta sessão | Veredito |
|---|---|---|
| Escopo/cânone | Nenhuma migration nova; nenhum domínio fora de `KORTEX_MVP_TECNICO.md §4/§5` tocado nesta fase | `PASS` |
| Backend | `cd backend && npm test` → 195/195 `PASS` (193 baseline + 2 novos de `accessLog`) | `PASS` |
| Tenant | Suíte de integração cross-tenant (já incluída nos 195) e pgTAP RLS seguem verdes; `organizationContext.js` confirmado inalterado — tenant só vem de membership validada no banco, nunca de header/body isolado | `PASS` |
| Dinheiro | `rpc_checkout_close_test.sql` dentro da suíte pgTAP (123/123) — idempotência, replay, reconciliação de pagamento cobertos | `PASS` |
| Estoque | `rpc_inventory_adjust_test.sql` dentro da suíte pgTAP; `stock_on_hand` sem grant direto (confirmado em `KORTEX_MVP_TECNICO.md §8`, inalterado) | `PASS` |
| Agenda | Testes de `appointments` (exclusion constraint / 409 `professional_double_booked`) inclusos na suíte de 195 | `PASS` |
| Supabase | `supabase db reset --local --no-seed` limpo → `supabase test db --local`: **123/123 PASS** → `supabase db advisors --local --type all --level warn --fail-on warn`: **No issues found** (re-executado agora, não reaproveitado) | `PASS` |
| PWA | `frontend && npm test` → **69/69 PASS**; `vite.config.js` confirmado inalterado desde a Fase 6.6 (`navigateFallback: 'index.html'`, `/api/*` → `NetworkOnly`) | `PASS` |
| Segredos | CI run [`29271759711`](https://github.com/hudson-f-lima/Kortex_Os_v2/actions/runs/29271759711) (commit `c7d3eba`, sucesso) executou `gitleaks/gitleaks-action@v2` com `fetch-depth: 0` (histórico completo) — limpo. `.env`/`.env.local` confirmados no `.gitignore` | `PASS` |
| Histórico Git | Mesma execução do gitleaks acima cobre o histórico alcançável completo, não só o diff | `PASS` |
| Supply chain | `npm audit` — backend: **0 vulnerabilidades**. Frontend: **6 vulnerabilidades** (1 crítica, 1 alta, 4 moderadas), todas na cadeia `esbuild`→`vite`→`vitest`/`vite-plugin-pwa` (GHSA-67mh-4wv8-2f99, exposição do dev server do Vite a requisições de qualquer site — não afeta o build de produção nem o runtime, só `vite dev`/`vitest` local). Correção exige `npm audit fix --force` (upgrade quebrado para Vite 8). Risco aceito para o MVP: superfície é só a máquina de desenvolvimento, nunca o `dist/` publicado | `PASS COM RISCO ACEITO` |
| Render | **`kortex-api` (Render) não respondeu**: `curl https://kortex-os-v2.onrender.com/health` deu timeout de conexão (60s, sem resposta) e uma tentativa via fetch HTTP retornou `503 Service Unavailable`. Não há evidência de um backend real no ar — `render.yaml` só define o Blueprint, nunca foi confirmado como deploy ativo em nenhuma fase anterior. GitHub Pages (`https://hudson-f-lima.github.io/Kortex_Os_v2/`) carrega o shell da PWA, mas sem o backend no ar nenhuma chamada de API funciona | `BLOQUEADO` |

## Defeitos reais encontrados e corrigidos nesta sessão

1. **`deploy-pages.yml` publicava a PWA apontando para o projeto Supabase errado.** Nenhum secret do GitHub (`gh secret list`/`gh variable list`) está configurado neste repositório, então `${{ secrets.VITE_SUPABASE_URL || 'https://lzkxmqmpxwctnysfzjwv.supabase.co' }}` sempre resolvia para o fallback hardcoded — um projeto Supabase diferente do que `render.yaml`/`.env` reais usam (`kpedsuklnedlhjvadiyc.supabase.co`). Isso significa que **todo build já publicado no GitHub Pages tinha Auth apontando para o Supabase errado** (login/signup real nunca funcionaria em produção). Corrigido: valores públicos (URL + chave publicável) agora hardcoded iguais a `render.yaml`, comentário explicando o porquê.
2. **`ignores` mal posicionado nos dois `eslint.config.js`** (backend e frontend): combinado com `languageOptions`/`rules`/`files` no mesmo objeto de config, o que no formato flat do ESLint só ignora aqueles arquivos *para aquele bloco específico*, não globalmente. `js.configs.recommended` (sem `files` restringindo) continuava lintando qualquer `dist/**` que existisse localmente. Não quebrava a CI porque o job de lint roda antes do build, mas é frágil (quebra se alguém rodar lint depois de um build local, como aconteceu aqui: 785 problemas ao lintar bundles minificados). Corrigido: `ignores` isolado em seu próprio objeto de config, no topo do array (`[{ ignores: [...] }, js.configs.recommended, {...}]`).
3. **`no-unused-vars`/`no-undef` geravam 10 warnings falso-positivos reais** (não bugs de código): `URL`/`fetch` não declarados como globals do Node no backend; `URLSearchParams`/`crypto`/`global` faltando nos globals do frontend; e o maior: `react/jsx-uses-vars` nunca estava habilitado, então todo import usado só dentro de JSX (`<Navigate>`, `<Outlet>`, `<Suspense>`, `<NavLink>`, `<MemoryRouter>` etc.) era acusado como não-usado. Corrigido nos dois `eslint.config.js`; nenhum código-fonte precisou mudar — os imports já estavam corretos.

## Gaps não corrigidos, registrados como decisão em aberto

- **Backend Render não está comprovadamente no ar.** Sem acesso ao painel Render nem a uma API key/MCP do Render nesta sessão, não há como diagnosticar (serviço pausado por inatividade do free tier, nunca criado, ou removido) nem reativar. Requer o usuário verificar o dashboard do Render.
- **`kortex-pwa` (site estático no `render.yaml`) parece redundante** com o `deploy-pages.yml` já publicando a PWA no GitHub Pages — não está claro se o serviço estático do Render ainda deveria existir. Não removido sem confirmação do usuário (pode ser intencional, ex.: ambiente de staging).
- **Pin exato de Node** (`engines.node`) segue `>=20.0.0` (soft) em ambos `package.json`, enquanto a CI já roda em Node 22 explícito (`actions/setup-node` `node-version: 22`). Não é um defeito ativo (Render escolhe uma versão compatível por padrão), mas fica registrado como possível day-2 hardening, não bloqueador desta fase.

## Veredito final da Fase 7

**`PASS COM RISCO ACEITO`** — todos os gates verificáveis localmente/via CI (backend, tenant, dinheiro, estoque, agenda, Supabase, PWA, segredos, histórico git) estão `PASS` com evidência re-executada nesta sessão; supply chain tem um risco aceito documentado (vulnerabilidade de dev-server do Vite, não afeta produção). O gate Render fica `BLOQUEADO` — não por falha de código, mas porque o backend hospedado não respondeu a `/health` nesta verificação e não há como este agente investigar ou corrigir o lado operacional do Render sem acesso ao painel. **A Fase 7 não pode ser declarada 100% `REAL` até o usuário confirmar/reativar o deploy do Render** e uma nova checagem de `/health` responder 200.
