# PROJECT STATE — KortexOS MVP técnico

> **ARQUIVADO em 2026-07-20 (DEC-29).** Construção do MVP técnico (Trilhas A–E) encerrada formalmente pelo Platform Owner. Este arquivo descreve o estado operacional do MVP até o encerramento e não é mais atualizado como fonte ativa — mantido como registro histórico. A execução segue em `docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` (visão), `docs/KORTEXOS_5_1_2_TRUTH_MAP.md` (realidade técnica atual) e `docs/KORTEXOS_5_1_2_MIGRATION_MAP.md` (próximos objetos). Ver `docs/INDEX.md`.

**Atualizado:** 2026-07-20 | Onda 6/7 (Fase 13) mergeada em `main` e em produção — [PR #11](https://github.com/hudson-f-lima/Kortex_Os_v2/pull/11), CI verde (3/3 checks), deploy automático no GitHub Pages confirmado rodando o commit do merge. Verificação rápida desta mesma data reexecutou as 3 suítes com banco local limpo: **106/106 (frontend)**, **239/239 (backend)**, **243/243 (pgTAP)** — todas passando, ver métricas abaixo. Migration da Fase 11 (fix de RLS em `professionals_select`) aplicada e verificada em produção — vazamento fechado, ver "Resolvido em 2026-07-20" abaixo. Opção C Phase 3 segue concluída (banco + backend + wiring do frontend), sem dado de teste residual.

## Estado do MVP

| Área | Estado | Evidência / Arquivos |
|---|---|---|
| Arquitetura greenfield | `REAL` | [KORTEX_MVP_TECNICO.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/docs/KORTEX_MVP_TECNICO.md) |
| Suite MAS | `REAL` | `.agents/skills/*` |
| Infraestrutura Local | `REAL` | Docker Desktop + Supabase local ativos; pgTAP executando. |
| Auth/tenant/RLS | `REAL` | 17 tabelas públicas com RLS; isolamento cross-tenant validado. |
| Checkout atômico | `REAL` | Transação transacional e idempotente via `checkout_close` RPC. |
| Comissão e Pacotes | `REAL` | Cascata de comissão (Profissional > Serviço > Grupo) e pacotes no checkout. |
| Backend Express | `REAL` | Rotas, middleware JWT, tratamento de erro 409/conflict em `backend/`. |
| Elegibilidade Opção C | `REAL` (banco+API+PWA) | ADRs 0010-0013; `create_appointment`/`update_appointment` RPCs, tri-state, snapshot, idempotência, version, change plan — Agenda/Comanda já falam o novo contrato. |
| PWA Modular | `REAL` | Vite + React app shell, 8 módulos, service worker e cache offline. |
| Projection Cache | `REAL` | Tabela `sync_events`, triggers, endpoints SSE/REST e IndexedDB local. |
| CI/CD & Deploy | `REAL` | GitHub Actions (lint, testes, secrets scan), Render API (`kortex-api`). |

## Métricas da Suíte de Testes (PASS)
- **pgTAP (Banco):** 243 / 243 testes passando (`supabase test db --local`), reexecutado em 2026-07-20 com `supabase db reset --local` antes (o `npm run test` do backend nesta mesma sessão tinha deixado resíduo de organizações no banco local, causando falhas espúrias tipo "more than one row returned by a subquery" — resetar limpou e a suíte passou 100%; nenhuma falha real de RLS/schema). +7 desde a última contagem confirmada (236, 2026-07-17), consistente com a migration da Fase 11 aplicada.
- **Backend (Express):** 239 / 239 testes passando (`npm run test`), reconfirmado em 2026-07-20 — mesma contagem de 2026-07-18 (Fase 11 + fix de crash no SSE), sem novos testes desde então.
- **Frontend (PWA):** 106 / 106 testes passando (`npm run test -- --run`), reconfirmado em 2026-07-20 após o merge da Onda 6/7 (+15 desde 2026-07-17: cobertura nova de PWA Installer, toasts, skeletons/empty states e `useCachedQuery`/Projection Cache).
- **Lint (frontend):** 0 erros, 1 warning pré-existente (`ToastContext.jsx`, `react-refresh/only-export-components`) — não bloqueante, mesmo estado desde a Onda 6.
- **Build de produção (frontend):** `npm run build` completo sem erros; aviso pré-existente de chunk >500kB (`index-*.js`, 571.85 kB) — conhecido, não endereçado nesta sessão.
- **Advisors de segurança (produção, Supabase MCP):** mesmo estado terminal de 2026-07-17 — 2 INFO esperados (`idempotency_keys`/`sync_events` sem policy, documentado como correto) + 1 WARN pré-existente (`auth_leaked_password_protection` desabilitado, não endereçado). Nenhum achado novo.

---

## Histórico de Fases Concluídas
- **Fases 1 a 5:** Infraestrutura local, migrations, checkout atômico, comissionamento e pacotes.
- **Fase 6:** PWA Modular (Subfases 6.1 a 6.6: app shell, Agenda, Comanda/Checkout, cadastros e caixas).
- **Fases 7 a 10:** CI/CD, deploys Render/GitHub Pages, fundação financeira e capacidades profissional × serviço.
- **Fase Extra:** Projection Cache local e sincronização incremental via REST + SSE (ADR 0009).
- **Fase 11:** Convite de equipe por e-mail e RLS self-view em `professionals` (ADR 0014) — código e migration em produção, paridade confirmada em 2026-07-20.
- **Fase 13 (MVP Refatorado):** Kortex Design System implementado globalmente (Ondas 1 a 5). PWA padronizada com primitives, Agenda reescrita para Timeline Vertical e AppShell consolidado. Métricas (LCP/INP) e NetworkStatus ativo na TopBar.
  - **Onda 6 (Polish UI/UX):** PWA Installer (antes do install prompt), Toasts globais, Skeletons de Transição (PageFadeIn animado) e Empty States amigáveis espalhados.
  - **Onda 7 (Carregamento Instantâneo):** Otimização massiva com o *Projection Cache* (IndexedDB local). Telas de Catálogo e Equipe agora abrem em 0ms (Offline First). Telas não cacheadas (Caixa e Comanda) não bloqueiam a renderização da AppShell e usam `<PageSkeleton />` em vez de texto cru. SWR implantado no carregamento de memberships da Equipe.
  - **Mergeada e em produção em 2026-07-20** ([PR #11](https://github.com/hudson-f-lima/Kortex_Os_v2/pull/11), branch `feature/ui-ux-polish-onda6` já deletada). Inclui fix complementar de warm start do cache local (`OrganizationContext.jsx`) e correções de regressão encontradas em análise global pré-merge (build quebrado + 12 testes falhando na branch, ver commit `a3c76d6`).

---

## Gaps e Pendências Conhecidos
1. **Price Override:** Campo `price_override_cents` é dead code (reservado para o futuro — ver ADR 0008 Decisão 1 e ADR 0013).
2. **Sessões de Caixa:** Correção operacional de checkout fechado por erro (Fase 12, ADR 0007).
3. **UI de gestão de elegibilidade (Opção C):** não existe tela para configurar `professional_service_group_eligibility` nem `organizations.default_service_eligibility` — só a API/RPC. `CapabilityModal.jsx`/`CapabilitiesTab.jsx` (Equipe) seguem cobrindo só duração/buffer/preço, sem campo para `eligibility` (têm `default 'ENABLED'`, então não quebraram, mas o tri-state fica inacessível pela PWA por ora).

### Resolvido em 2026-07-22: ambiente de homologação (staging) criado
Gap #4 anterior ("Ambiente de homologação: não existe hoje") fechado — ver DEC-30 (`docs/KORTEXOS_5_1_2_DECISION_LOG.md`) para o registro completo. Segundo projeto Supabase gratuito (`kortex-os-v2-staging`) com as 12 migrations aplicadas e verificadas por chamada própria; dois serviços novos no Render (`kortex-api-staging`, `kortex-pwa-staging`) na branch `staging`, validados live e com isolamento de ambiente confirmado por inspeção direta do bundle publicado (zero referência ao Supabase de produção). Branch `main` agora protegida via `gh api` (PR obrigatória, `enforce_admins: true`, sem force-push/delete); `staging` com proteção leve (só CI verde). Nova skill `kortex-environment-guardian` governa toda promoção entre branches daqui em diante.

### Resolvido em 2026-07-20: migration da Fase 11 aplicada em produção
Pendência aberta desde 2026-07-18 (sem acesso MCP ao projeto de produção naquela sessão). Confirmado nesta sessão que a MCP do Supabase disponível aqui está conectada exatamente ao projeto de produção (`kpedsuklnedlhjvadiyc`, mesmo do `render.yaml`, confirmado via `get_project_url`) — `supabase/migrations/20260718120000_fase11_professionals_self_view.sql` estava de fato ausente lá (`list_migrations` parava em `20260717060000`). Aplicada via `apply_migration` (registrada como `20260720223256_fase11_professionals_self_view`), seguida de `NOTIFY pgrst, 'reload schema'` manual (mesma lição de 2026-07-17: aplicar fora do `supabase db push` não recarrega o cache do PostgREST sozinho). **Verificado com a policy real do banco**, não só a presença da migration: `professionals_select` em produção agora é `owner/admin/manager/reception veem todos, professional só vê a própria linha (user_id = auth.uid())`, idêntico ao arquivo local. `get_advisors` (security) não aponta nada novo para `professionals`; os 2 avisos INFO de RLS sem policy (`idempotency_keys`, `sync_events`) continuam sendo o estado terminal esperado (2026-07-17). Achado à parte, de baixa prioridade: `auth_leaked_password_protection` está desabilitado no projeto Supabase — não relacionado a este fix, não endereçado nesta sessão.

### Resolvido em 2026-07-18: Fase 11 — convite de equipe por e-mail
Gap #1 anterior ("Gestão de Equipe: sem convite por e-mail no frontend") fechado. Endpoint `POST /convites` (`auth.admin.inviteUserByEmail` + `membership_set` + vínculo opcional a `professionals.user_id`), UI de envio no módulo Equipe e tela de aceite que define senha após o clique no link. Fecha também um vazamento de RLS: um membro com papel `professional` via `professionals_select` enxergava toda a lista da organização, não só o próprio registro. Decisão de SMTP (Resend) e expiração de 24h formalizadas em [ADR 0014](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/docs/adr/0014-fase11-convite-equipe-smtp.md). Mergeado em `main` (commit `233e941`).

### Resolvido em 2026-07-17: `organization_id` ausente na resposta de `appointments`/`clients`
O fix de isolamento de tenant no IndexedDB (`useCachedQuery`, commit `f3ea95e`) filtra registros por `record.organization_id === organizationId`. Achado inicial apontava ~9 módulos potencialmente afetados por `COLUMNS` sem `organization_id`, mas **investigação confirmou que só `appointments` e `clients` participam do caminho que causa o bug de fato** (escrita instantânea no IndexedDB via `putRecord` após uma mutação, usado só por `AgendaPage.jsx`/`ClientesPage.jsx` — os demais módulos, ex. Equipe/Catálogo, gerenciam a própria lista via `apiClient` + estado local, não passam pelo cache). `professionals`/`services`/`products`/`serviceGroups`/`professionalCommissions`/`professionalServiceCapabilities`/`cashEntries`/`memberships` **não têm esse bug** — ficam desatualizados no cache só até o próximo ciclo normal de sync (SSE/REST catch-up), comportamento esperado, não uma falha. Ambos os módulos afetados corrigidos (`appointments.service.js`, `clients.service.js`, `jsonb_build_object` das RPCs) e verificados no browser real.

### Resolvido em 2026-07-17: produção estava 6 migrations atrasada (Fase 9 até Opção C nunca aplicadas)
Usuário reportou Agenda sem dados em produção, suspeitando de RLS. Investigação (sem MCP no projeto remoto — permissão negada, provavelmente conta/organização diferente) via SQL direto (`supabase db query --db-url`) revelou que `supabase_migrations.schema_migrations` em produção parava em `20260713060000` — **4 das 10 migrations do repositório**, faltando Fase 9, Fase 10, `sync_events` e a Opção C inteira. Nenhuma automação de CI/CD empurra migrations para produção; ficou represado desde 13/07. Confirmado zero risco de perda de dado (nenhuma das 6 migrations pendentes apaga dado existente) antes de aplicar. Usuário rodou `supabase db push --db-url ...` manualmente (bloqueado para mim pelo classificador de segurança do auto mode, mesmo em `--dry-run`). Após o push, foi necessário `NOTIFY pgrst, 'reload schema'` manual — aplicar via `--db-url` pula o hook automático do Supabase que recarregaria o cache do PostgREST. Verificado com dado real (2 agendamentos da organização do usuário, campos da Opção C corretamente preenchidos pelo backfill).

**Lição para sessões futuras:** sempre confirmar se existe um projeto Supabase de produção/hospedado (`render.yaml`/`.env` → `SUPABASE_URL`) e se as migrations locais realmente foram aplicadas lá antes de considerar uma feature "pronta" — testar só local não garante paridade com produção, e não há pipeline automática cobrindo esse gap hoje.

### Resolvido em 2026-07-17: hardening de RLS (`idempotency_keys`, `sync_events`)
Advisor scan de produção (rodado pelo usuário via MCP oficial do Supabase, não por mim) encontrou `private.idempotency_keys` sem RLS habilitado (não era exposição ativa — sem grant a anon/authenticated, schema `private` não exposto via PostgREST — mas faltava a camada de defesa em profundidade) e `public.sync_events` com RLS habilitado mas sem nenhuma policy (mesmo raciocínio, grant já restrito a `service_role`). Migration `20260717060000_rls_hardening_idempotency_sync_events.sql` habilita RLS em `idempotency_keys` e documenta com `comment on table` que "zero policies" é o estado terminal correto para as duas tabelas (bookkeeping interno, nunca deve ser consultável direto por cliente) — não adiciona nenhuma policy permissiva. 6 testes pgTAP novos (`rls_baseline_test.sql` +4, `sync_events_test.sql` +2) travam essa postura. **Aplicado em produção e verificado** (`rls_enabled: true`, `policy_count: 0` nas duas tabelas, confirmado via SQL direto) — 11/11 migrations em paridade local×produção.

### Feito em 2026-07-17: dados de teste removidos de produção
Duas organizações de teste ("Hudson", "Hope"/slug `penha`) e todo dado associado (clientes, profissionais, agendamentos, pedidos, pagamentos, etc.) foram removidos de produção a pedido do usuário — confirmado zero linhas restantes em todas as tabelas de negócio. Contas de login (`auth.users`) não foram tocadas, só os dados de organização. Banco local também resetado (limpou 134 organizações de resíduo acumulado de rodar `npm test` repetidamente nesta sessão — nenhum teste do backend usa transação com rollback, diferente do pgTAP).

### Resolvido em 2026-07-18: crash do processo backend em conexões SSE concorrentes de sync
QA manual (`node --watch src/server.js`) reportou o processo Node inteiro morrendo com exceção não tratada ao recarregar a página logo após o login, disparando duas requisições quase simultâneas a `/api/v1/sync/stream` para a mesma organização. Causa raiz: `supabaseAdmin.channel(topic)` do `@supabase/realtime-js` **reaproveita** a instância de `RealtimeChannel` já existente quando o tópico (`sync_stream:<org_id>`) já está registrado — a segunda requisição chamava `.on('postgres_changes', ...)` num canal que a primeira já tinha subscrito, o que lança síncrono ("cannot add callbacks ... after subscribe()") e derruba o processo. Corrigido em [sync.route.js](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/backend/src/modules/sync/sync.route.js) com um registro por organização: o canal é criado/subscrito uma única vez por `organization_id` e compartilhado entre conexões SSE concorrentes via um `Set` de listeners, só sendo removido quando a última conexão daquela organização desconecta. Teste de regressão adicionado (`sync.test.js`) dispara duas conexões concorrentes para a mesma organização e confirma que o servidor sobrevive. Mergeado via [PR #9](https://github.com/hudson-f-lima/Kortex_Os_v2/pull/9), CI verde (lint, pgTAP advisors, backend, frontend).

### Achado em 2026-07-20: propagação do banner de atualização da PWA pode levar até 10 min no GitHub Pages
Usuário reportou "cliquei no botão, nova versão disponível, recarregar, e nada aconteceu" logo após o deploy do PR #11. Reproduzido ao vivo no site publicado: o clique **funcionou** (service worker em `waiting` passou para `active`, banner sumiu) quando testado minutos depois. Causa raiz do sintoma relatado: o GitHub Pages serve `sw.js` e `index.html` via CDN da Fastly com `Cache-Control: max-age=600` (10 min), header fixo que o GH Pages não permite customizar — diferentes nós de borda do CDN podem levar até 10 minutos após um deploy para propagar os arquivos novos, então um clique em "Atualizar" dentro dessa janela pode buscar um `sw.js` que aquele nó específico ainda serve como o antigo. Não é um bug de código (mecanismo do `useRegisterSW`/`updateServiceWorker(true)` em [UpdateBanner.jsx](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/frontend/src/shared/UpdateBanner.jsx) está correto) — é uma limitação inerente de hospedar PWA no GitHub Pages, sem controle sobre cache headers. Sem ação de código necessária; registrado aqui para não reabrir essa investigação à toa numa sessão futura caso o mesmo sintoma apareça logo após um deploy.

### Verificado em 2026-07-17: banner de atualização da PWA funciona corretamente
Usuário reportou que "não estava funcionando". Testado de ponta a ponta em build de produção real (`vite build` + `vite preview`): registrar SW → mudar código → rebuild → recarregar aba já aberta → banner "Nova versão disponível" aparece → clicar "Recarregar" → nova versão carrega, banner some. Sem bug — o service worker (e portanto todo o mecanismo de update) **fica desabilitado em `npm run dev`** por padrão no vite-plugin-pwa (sem `devOptions.enabled`), então testar em modo dev nunca mostraria o banner. Adicionado `frontend-preview` (porta 4173) ao `.claude/launch.json` para facilitar esse teste em sessões futuras.

---

## Achados da Auditoria Opção C (Fase 10.5) — resolvidos pela Phase 3
- **professional_service_capabilities.eligibility** (tri-state, substituiu `active` boolean) + **professional_service_group_eligibility** (nova tabela) + **organizations.default_service_eligibility**: cascata capability > grupo > default da org via `private.resolve_eligibility()` (ADR 0010).
- **appointments.resolved_duration_minutes/resolved_eligibility_source/resolved_at**: snapshot congelado na criação, preservado em MOVE_TIME_ONLY (ADR 0011) — fecha o CRITICAL GAP de `ends_at` recalculando em updates.
- **create_appointment/update_appointment** (RPCs `security definer`, mesma arquitetura de `checkout_close`): idempotência atômica via `Idempotency-Key`, concorrência otimista via `version` (coluna existia desde a Fase 10 mas nunca foi usada), gate de elegibilidade fail-closed configurável, confirmação two-step com diff ao reconfigurar profissional/serviço (ADR 0012/0013).
- Migration: `supabase/migrations/20260716150000_fase_opcao_c_elegibilidade_snapshot.sql`. 46 novos testes pgTAP (`rpc_appointments_test.sql`, `rls_professional_service_group_eligibility_test.sql`).

---

## Próxima Ação Imediata

**Nenhum bloqueador crítico de produção conhecido pendente.** A migration da Fase 11 segue aplicada e verificada em produção (2026-07-20), e a Onda 6/7 (Fase 13) está mergeada, deployada e com as 3 suítes de teste reexecutadas e passando 100% nesta mesma data (ver métricas acima).

Pendências conhecidas seguem as mesmas dos Gaps listados acima (UI de elegibilidade Opção C, Sessões de Caixa/Fase 12).

*Próximos candidatos, por ordem de valor: UI de gestão de elegibilidade (Gap #3, torna o tri-state da Opção C configurável pela PWA), ou Fase 12 (Sessões de Caixa, ADR 0007).*
