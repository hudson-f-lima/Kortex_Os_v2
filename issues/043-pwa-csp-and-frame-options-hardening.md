---
title: "Hardening — CSP e X-Frame-Options no PWA (produção e staging)"
status: "IMPLEMENTADA em staging (verificado ao vivo); configurada em produção (serviço suspenso, sem verificação ao vivo possível)"
stage: "ISSUE"
governance_ref: []
upstream_doc: null
last_updated: "2026-08-07"
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

## Verificação pós-deploy e achado de infraestrutura (2026-08-07)

PR #38 mergeada em `staging` (`3cbd8b3`). Deploy automático do Render não disparou — investigado via API do Render (`RENDER_API_KEY` disponível no `.env`): **não existe Blueprint ativo ligando este repositório a `render.yaml`** (`GET /v1/blueprints` só lista um blueprint de um projeto não relacionado). Isso significa que `render.yaml` neste repositório é hoje só documentação/intenção — os serviços reais no Render foram criados avulsos e não resincronizam automaticamente com o arquivo. Consequência prática: qualquer edição futura em `render.yaml` (headers, env vars, o que for) precisa ser aplicada manualmente no serviço real (dashboard ou API), não só commitada.

Disparado deploy manual (`POST /v1/services/{id}/deploys`) para captar o commit da PR — completou (`live`), mas os headers continuaram ausentes na resposta real (confirmado com bypass de cache, `cf-cache-status: MISS`), confirmando que o deploy não lê `headers:` do `render.yaml` sem Blueprint sync. Aplicado diretamente via `POST /v1/services/{id}/headers` (endpoint dedicado de header rules do Render, existe independente de Blueprint) para `kortex-pwa-staging` — os mesmos 2 headers, mesmo valor do `render.yaml`.

**Verificado ao vivo, com bypass de cache (`cf-cache-status: MISS`):** `content-security-policy` e `x-frame-options: DENY` presentes na resposta real; `strict-transport-security`/`x-content-type-options` inalterados. App testado no browser: tela de login renderiza normalmente, JS/CSS carregam (200), console sem erro/violação de CSP.

## Produção (2026-08-07, autorizado pelo Platform Owner)

Confirmado antes de aplicar: `VITE_API_BASE_URL`/`VITE_SUPABASE_URL` reais do serviço `kortex-pwa` de produção (`srv-d9goto37uimc738pcsjg`, URL real `https://kortex-os-v2-1.onrender.com` — diferente de `kortex-pwa.onrender.com`, o valor assumido no comentário do `render.yaml`) batem exatamente com as origens já usadas em `connect-src`; a mesma CSP/`X-Frame-Options` da staging foi aplicada via `POST /v1/services/srv-d9goto37uimc738pcsjg/headers`, confirmada salva por `GET` no mesmo endpoint.

**Não verificável ao vivo:** `curl -sI` contra `https://kortex-os-v2-1.onrender.com/` retorna `503`, `x-render-routing: suspend-by-user` — o serviço está suspenso por usuário (não por esta sessão), assim como `kortex-api` (produção, `srv-d9air667r5hc73fukuqg`, também `suspended: ["user"]`). Os headers ficam salvos na configuração do serviço e valem assim que ele for reativado; não há como confirmar a resposta HTTP real enquanto estiver suspenso.

**Achado à parte, fora do escopo desta issue, não corrigido:** com produção suspensa no Render, o front-end de produção realmente servido hoje é provavelmente o GitHub Pages (`https://hudson-f-lima.github.io/Kortex_Os_v2/`, `200 OK` confirmado), não o `kortex-pwa` do Render. Isso é consistente com a suspensão ser deliberada. Um teste de CORS contra `kortex-api` (produção) com origin `https://kortex-os-v2-1.onrender.com` não recebeu `access-control-allow-origin` — o `CORS_ORIGINS` real do serviço é só `https://hudson-f-lima.github.io`, sem o `kortex-pwa`/`kortex-os-v2-1` que o `render.yaml` lista. Como a API de produção também está suspensa, isso não tem efeito prático agora; registrado aqui para o caso de alguém reativar o Render `kortex-pwa` no futuro esperando que ele funcione.

**Decisão em aberto, fora do escopo desta issue:** este repositório não tem Blueprint Render sincronizado com `render.yaml` (`GET /v1/blueprints` só lista um projeto não relacionado) — mudanças de infraestrutura no arquivo não se propagam sozinhas, e a URL real de alguns serviços diverge do que o arquivo assume. Registrar como issue própria se o Platform Owner quiser corrigir isso.
