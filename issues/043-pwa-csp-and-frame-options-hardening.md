---
title: "Hardening — CSP e X-Frame-Options no PWA (produção e staging)"
status: "IMPLEMENTADA (config); PENDENTE (verificação pós-deploy)"
stage: "ISSUE"
governance_ref: []
upstream_doc: null
last_updated: "2026-08-06"
---

# 043 — CSP e X-Frame-Options no PWA (Render)

Hardening decorrente de verificação pessoal de um relatório de segurança externo colado pelo usuário (2026-08-06): a maior parte dos achados do relatório foi refutada contra a staging real (`curl -sI` mostrou `Strict-Transport-Security` e `X-Content-Type-Options` já presentes e corretos, contradizendo o relatório) ou contra o código real (`organization_id` client-side não é IDOR — `backend/src/middleware/organizationContext.js` já revalida toda operação contra uma membership real do `user_id` autenticado, nunca confia no header do cliente). Dois achados sobreviveram à verificação: **ausência de `Content-Security-Policy`** e **ausência de `X-Frame-Options`**, confirmados diretamente na resposta HTTP real de `https://kortex-pwa-staging.onrender.com/`.

Escopo: os dois serviços PWA estáticos do `render.yaml` — `kortex-pwa` (produção) e `kortex-pwa-staging` (homologação). Não inclui `kortex-api`/`kortex-api-staging` (Express), nem qualquer mudança de arquitetura de autenticação (o achado relacionado a token em `localStorage` não é escopo desta issue — é comportamento padrão do `@supabase/supabase-js`, mitigado, não eliminado, por este hardening).

Investigar o mecanismo de headers customizados para site estático do Render (arquivo `_headers` no `staticPublishPath`, ou chave de rotas/headers no `render.yaml`) e aplicar sem regredir os headers já corretos (`Strict-Transport-Security`, `X-Content-Type-Options: nosniff`). CSP inicial deve ser estrita o suficiente para bloquear scripts/estilos de origem não confiável sem quebrar o build Vite/PWA existente (Service Worker, manifest, assets com hash) — validar em staging antes de produção.

Aceite: `curl -sI` contra `kortex-pwa-staging.onrender.com` e, depois de validado, contra `kortex-pwa.onrender.com`, mostra `Content-Security-Policy` e `X-Frame-Options` presentes; a PWA carrega e funciona normalmente (Service Worker registra, login funciona, chamadas à API de `VITE_API_BASE_URL` não são bloqueadas pela CSP); `Strict-Transport-Security` e `X-Content-Type-Options` continuam presentes e inalterados; nenhuma outra rota/comportamento é alterado.

## Implementação (via `$tdd`, 2026-08-06)

Branch `hardening/043-pwa-csp-frame-options`, a partir de `staging` pós-merge da PR #37.

**Schema real confirmado antes de implementar** (a documentação resumida do Render sugeria um formato incorreto — `key`/lista aninhada; o formato real, confirmado contra `render.yaml` de terceiros publicados no GitHub, usa `path`/`name`/`value` plano, uma entrada por header): `- path: /*` seguido de `name:` e `value:`, um item de lista por header.

**RED:** `tests/render-headers.test.js` — 6 asserções (por serviço: CSP presente com `default-src 'self'`, `connect-src` inclui a origem própria de API e de Supabase daquele ambiente, `X-Frame-Options: DENY`). Rodado antes da mudança em `render.yaml`: 6/6 falhando, mensagens de erro corretas ("is missing a Content-Security-Policy header entry", `null !== 'DENY'`).

**GREEN:** adicionado bloco `headers:` em `kortex-pwa` e `kortex-pwa-staging` no `render.yaml`. CSP verificada linha a linha contra o código real antes de escrever a política — `frontend/index.html` não tem script inline (só `<script type="module" src="/src/main.jsx">`, então `script-src 'self'` sem `unsafe-inline`); `frontend/src/shared/syncEngine.js` usa `fetch()` contra a própria API para o stream de sync, não WebSocket, então `connect-src` não precisa de entrada `wss://` separada; `VITE_SUPABASE_URL` é chamado diretamente pelo client `@supabase/supabase-js` (login/sessão), por isso a origem do Supabase de cada ambiente entra em `connect-src` junto da origem da própria API. `Strict-Transport-Security`/`X-Content-Type-Options` não foram redeclarados — já chegam por default do Render/Cloudflare (confirmado por `curl -sI` antes desta fatia) e `render.yaml` preserva headers não declarados no Blueprint. Rodado depois da mudança: 6/6 verde.

**Validação extra:** sintaxe YAML confirmada por um parser real (`js-yaml`, já presente como dependência transitiva em `frontend/node_modules`), não só pelo teste baseado em regex — `render.yaml` carrega sem erro e ambos os serviços expõem exatamente os 2 headers esperados.

**Pendente, fora do alcance de um teste local:** o Aceite completo (curl contra a URL real pós-deploy) só pode ser verificado depois do merge + deploy automático do Render. `tests/render-headers.test.js` é o gate mecânico que roda antes disso; não substitui a verificação ao vivo.
