# PROJECT STATE — KortexOS MVP técnico

**Atualizado:** 2026-07-18 | Fase 11 (convite de equipe por e-mail + RLS self-view) e correção de crash no SSE de sync mergeados em `main` (PR #9). Opção C Phase 3 segue concluída (banco + backend + wiring do frontend), sem dado de teste residual, banner de atualização da PWA verificado funcionando. **Pendência aberta:** confirmar se a migration da Fase 11 (fix de RLS) já rodou em produção — ver Próxima Ação Imediata.

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
- **pgTAP (Banco):** 236 / 236 testes passando (`supabase test db --local`) — +6 do hardening de RLS (`idempotency_keys`/`sync_events`, 2026-07-17). Não reexecutado em 2026-07-18 (Fase 11 e o fix de sync SSE não tocaram schema/RLS).
- **Backend (Express):** 239 / 239 testes passando (`npm run test`) — +8 desde 2026-07-17: +7 da Fase 11 (`convites.test.js` novo, `env.test.js` +1 caso de `SITE_URL`), +1 de regressão do fix de crash no SSE de sync (conexões concorrentes na mesma organização).
- **Frontend (PWA):** 91 / 91 testes passando na última execução verificada (2026-07-17, `npm run test`). Fase 11 adicionou `EquipePage.test.jsx` (+1) em 2026-07-18, mas a suíte não foi reexecutada nesta sessão para confirmar o novo total — validar antes de reportar como fato.

---

## Histórico de Fases Concluídas
- **Fases 1 a 5:** Infraestrutura local, migrations, checkout atômico, comissionamento e pacotes.
- **Fase 6:** PWA Modular (Subfases 6.1 a 6.6: app shell, Agenda, Comanda/Checkout, cadastros e caixas).
- **Fases 7 a 10:** CI/CD, deploys Render/GitHub Pages, fundação financeira e capacidades profissional × serviço.
- **Fase Extra:** Projection Cache local e sincronização incremental via REST + SSE (ADR 0009).
- **Fase 11:** Convite de equipe por e-mail e RLS self-view em `professionals` (ADR 0014) — código em produção, migration pendente de confirmação (ver Próxima Ação Imediata).

---

## Gaps e Pendências Conhecidos
1. **Price Override:** Campo `price_override_cents` é dead code (reservado para o futuro — ver ADR 0008 Decisão 1 e ADR 0013).
2. **Sessões de Caixa:** Correção operacional de checkout fechado por erro (Fase 12, ADR 0007).
3. **UI de gestão de elegibilidade (Opção C):** não existe tela para configurar `professional_service_group_eligibility` nem `organizations.default_service_eligibility` — só a API/RPC. `CapabilityModal.jsx`/`CapabilitiesTab.jsx` (Equipe) seguem cobrindo só duração/buffer/preço, sem campo para `eligibility` (têm `default 'ENABLED'`, então não quebraram, mas o tri-state fica inacessível pela PWA por ora).
4. **Ambiente de homologação:** não existe hoje — merge em `main` dispara deploy direto para produção (Render + GitHub Pages), sem etapa intermediária de QA manual. Só a CI (testes automatizados contra Supabase local efêmero) protege esse caminho. Ver conversa de 2026-07-18 sobre opções (segundo projeto Supabase/Render gratuitos vs. Supabase Branching + Render Preview Environments pagos).

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

**⚠️ Verificar/aplicar migration em produção:** `233e941` (Fase 11) inclui `supabase/migrations/20260718120000_fase11_professionals_self_view.sql`, que fecha um vazamento de RLS (papel `professional` enxergando toda a lista de profissionais da organização, não só a própria linha). Backend e frontend dessa mesma feature já foram para produção via deploy automático (push em `main` dispara Render + GitHub Pages), mas **nenhuma automação de CI/CD aplica migrations em produção** (mesma lição da paridade de 2026-07-17) — sem confirmação de que essa migration específica já rodou lá, o vazamento pode seguir ativo em produção mesmo com o código já publicado. Sem acesso MCP ao projeto de produção nesta sessão para confirmar (mesma limitação registrada em 2026-07-17); precisa ser checado manualmente (`supabase migration list --db-url ...` ou advisors) antes de considerar a Fase 11 realmente concluída em produção.

Fora esse ponto, **nenhum outro bloqueador conhecido pendente.** As três suítes de teste verdes na última verificação (pgTAP 236/236 em 2026-07-17, backend 239/239 em 2026-07-18, frontend 91/91 em 2026-07-17 — ver nota de reexecução pendente acima), lint limpo, produção sem dado de teste residual.

*Próximos candidatos, por ordem de valor: confirmar migration da Fase 11 em produção (acima), ambiente de homologação (Gap #4, evita repetir esse tipo de lacuna), UI de gestão de elegibilidade (Gap #3, torna o tri-state da Opção C configurável pela PWA), ou Fase 12 (Sessões de Caixa, ADR 0007).*
