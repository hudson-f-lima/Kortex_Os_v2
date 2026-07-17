# PROJECT STATE — KortexOS MVP técnico

**Atualizado:** 2026-07-17 | Opção C Phase 3 concluída (banco + backend + wiring do frontend) e bug de `organization_id` (appointments + clients) corrigido. PWA verificada no browser real: criar/editar/reconfigurar/cancelar agendamento, fechar comanda a partir de agendamento, criar cliente inline e ver refletido em Agenda/Clientes na hora — tudo funcionando.

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
- **pgTAP (Banco):** 236 / 236 testes passando (`supabase test db --local`) — +6 do hardening de RLS (`idempotency_keys`/`sync_events`, 2026-07-17).
- **Backend (Express):** 231 / 231 testes passando (`npm run test`).
- **Frontend (PWA):** 91 / 91 testes passando (`npm run test`) — +7 desde a Fase Opção C (`AppointmentModal.test.jsx` novo, `ComandaPage.test.jsx` estendido).

---

## Histórico de Fases Concluídas
- **Fases 1 a 5:** Infraestrutura local, migrations, checkout atômico, comissionamento e pacotes.
- **Fase 6:** PWA Modular (Subfases 6.1 a 6.6: app shell, Agenda, Comanda/Checkout, cadastros e caixas).
- **Fases 7 a 10:** CI/CD, deploys Render/GitHub Pages, fundação financeira e capacidades profissional × serviço.
- **Fase Extra:** Projection Cache local e sincronização incremental via REST + SSE (ADR 0009).

---

## Gaps e Pendências Conhecidos
1. **Gestão de Equipe:** Sem convite por e-mail no frontend (Fase 11).
2. **Price Override:** Campo `price_override_cents` é dead code (reservado para o futuro — ver ADR 0008 Decisão 1 e ADR 0013).
3. **Sessões de Caixa:** Correção operacional de checkout fechado por erro (Fase 12, ADR 0007).
4. **UI de gestão de elegibilidade (Opção C):** não existe tela para configurar `professional_service_group_eligibility` nem `organizations.default_service_eligibility` — só a API/RPC. `CapabilityModal.jsx`/`CapabilitiesTab.jsx` (Equipe) seguem cobrindo só duração/buffer/preço, sem campo para `eligibility` (têm `default 'ENABLED'`, então não quebraram, mas o tri-state fica inacessível pela PWA por ora).

### Resolvido em 2026-07-17: `organization_id` ausente na resposta de `appointments`/`clients`
O fix de isolamento de tenant no IndexedDB (`useCachedQuery`, commit `f3ea95e`) filtra registros por `record.organization_id === organizationId`. Achado inicial apontava ~9 módulos potencialmente afetados por `COLUMNS` sem `organization_id`, mas **investigação confirmou que só `appointments` e `clients` participam do caminho que causa o bug de fato** (escrita instantânea no IndexedDB via `putRecord` após uma mutação, usado só por `AgendaPage.jsx`/`ClientesPage.jsx` — os demais módulos, ex. Equipe/Catálogo, gerenciam a própria lista via `apiClient` + estado local, não passam pelo cache). `professionals`/`services`/`products`/`serviceGroups`/`professionalCommissions`/`professionalServiceCapabilities`/`cashEntries`/`memberships` **não têm esse bug** — ficam desatualizados no cache só até o próximo ciclo normal de sync (SSE/REST catch-up), comportamento esperado, não uma falha. Ambos os módulos afetados corrigidos (`appointments.service.js`, `clients.service.js`, `jsonb_build_object` das RPCs) e verificados no browser real.

### Resolvido em 2026-07-17: produção estava 6 migrations atrasada (Fase 9 até Opção C nunca aplicadas)
Usuário reportou Agenda sem dados em produção, suspeitando de RLS. Investigação (sem MCP no projeto remoto — permissão negada, provavelmente conta/organização diferente) via SQL direto (`supabase db query --db-url`) revelou que `supabase_migrations.schema_migrations` em produção parava em `20260713060000` — **4 das 10 migrations do repositório**, faltando Fase 9, Fase 10, `sync_events` e a Opção C inteira. Nenhuma automação de CI/CD empurra migrations para produção; ficou represado desde 13/07. Confirmado zero risco de perda de dado (nenhuma das 6 migrations pendentes apaga dado existente) antes de aplicar. Usuário rodou `supabase db push --db-url ...` manualmente (bloqueado para mim pelo classificador de segurança do auto mode, mesmo em `--dry-run`). Após o push, foi necessário `NOTIFY pgrst, 'reload schema'` manual — aplicar via `--db-url` pula o hook automático do Supabase que recarregaria o cache do PostgREST. Verificado com dado real (2 agendamentos da organização do usuário, campos da Opção C corretamente preenchidos pelo backfill).

**Lição para sessões futuras:** sempre confirmar se existe um projeto Supabase de produção/hospedado (`render.yaml`/`.env` → `SUPABASE_URL`) e se as migrations locais realmente foram aplicadas lá antes de considerar uma feature "pronta" — testar só local não garante paridade com produção, e não há pipeline automática cobrindo esse gap hoje.

### Em andamento 2026-07-17: hardening de RLS (`idempotency_keys`, `sync_events`) — aplicado local, pendente produção
Advisor scan de produção (rodado pelo usuário via MCP oficial do Supabase, não por mim) encontrou `private.idempotency_keys` sem RLS habilitado (não era exposição ativa — sem grant a anon/authenticated, schema `private` não exposto via PostgREST — mas faltava a camada de defesa em profundidade) e `public.sync_events` com RLS habilitado mas sem nenhuma policy (mesmo raciocínio, grant já restrito a `service_role`). Migration `20260717060000_rls_hardening_idempotency_sync_events.sql` habilita RLS em `idempotency_keys` e documenta com `comment on table` que "zero policies" é o estado terminal correto para as duas tabelas (bookkeeping interno, nunca deve ser consultável direto por cliente) — não adiciona nenhuma policy permissiva. 6 testes pgTAP novos (`rls_baseline_test.sql` +4, `sync_events_test.sql` +2) travam essa postura. **Aplicado e testado local; ainda não aplicado em produção** — mesmo fluxo manual da correção anterior (`db push` + `NOTIFY pgrst`).

---

## Achados da Auditoria Opção C (Fase 10.5) — resolvidos pela Phase 3
- **professional_service_capabilities.eligibility** (tri-state, substituiu `active` boolean) + **professional_service_group_eligibility** (nova tabela) + **organizations.default_service_eligibility**: cascata capability > grupo > default da org via `private.resolve_eligibility()` (ADR 0010).
- **appointments.resolved_duration_minutes/resolved_eligibility_source/resolved_at**: snapshot congelado na criação, preservado em MOVE_TIME_ONLY (ADR 0011) — fecha o CRITICAL GAP de `ends_at` recalculando em updates.
- **create_appointment/update_appointment** (RPCs `security definer`, mesma arquitetura de `checkout_close`): idempotência atômica via `Idempotency-Key`, concorrência otimista via `version` (coluna existia desde a Fase 10 mas nunca foi usada), gate de elegibilidade fail-closed configurável, confirmação two-step com diff ao reconfigurar profissional/serviço (ADR 0012/0013).
- Migration: `supabase/migrations/20260716150000_fase_opcao_c_elegibilidade_snapshot.sql`. 46 novos testes pgTAP (`rpc_appointments_test.sql`, `rls_professional_service_group_eligibility_test.sql`).

---

## Próxima Ação Imediata

**Aplicar `20260717060000_rls_hardening_idempotency_sync_events.sql` em produção** (mesmo fluxo manual: `supabase db push --db-url ...` pelo usuário, seguido de `NOTIFY pgrst, 'reload schema'` — bloqueado para mim pelo classificador de segurança). Testado e validado local (236 pgTAP).

*Depois disso, sem bloqueador conhecido pendente. Próximos candidatos, por ordem de valor: Fase 11 (Equipe/convite por e-mail), UI de gestão de elegibilidade (Gap #4, torna o tri-state da Opção C configurável pela PWA), ou Fase 12 (Sessões de Caixa, ADR 0007).*
