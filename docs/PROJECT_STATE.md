# PROJECT STATE — KortexOS MVP técnico

**Atualizado:** 2026-07-17 | Opção C Phase 3 concluída (banco + backend + wiring do frontend). PWA verificada no browser real: criar/editar/reconfigurar/cancelar agendamento e fechar comanda a partir de agendamento — tudo funcionando.

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
- **pgTAP (Banco):** 230 / 230 testes passando (`supabase test db --local`) — +47 desde a Fase Opção C (RPCs, tri-state, snapshot, idempotência).
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
2. **`organization_id` ausente na resposta de várias RPCs/rotas de escrita (CRITICAL, achado 2026-07-17):** o fix de isolamento de tenant no IndexedDB (`useCachedQuery`, commit `f3ea95e`) filtra registros por `record.organization_id === organizationId`. `create_appointment`/`update_appointment` foram corrigidas (agora retornam `organization_id`), mas o mesmo padrão (`COLUMNS` sem `organization_id`) existe em `clients`, `professionals`, `services`, `products`, `serviceGroups`, `professionalCommissions`, `professionalServiceCapabilities`, `cashEntries`, `memberships` — qualquer criação/edição nesses módulos fica **invisível na UI até o próximo full sync via SSE/REST catch-up** (sem crash, sem erro — só não aparece). Não corrigido nesta sessão fora de `appointments`; requer passar por cada módulo adicionando `organization_id` ao `COLUMNS`/`jsonb_build_object` de retorno.
3. **Price Override:** Campo `price_override_cents` é dead code (reservado para o futuro — ver ADR 0008 Decisão 1 e ADR 0013).
4. **Sessões de Caixa:** Correção operacional de checkout fechado por erro (Fase 12, ADR 0007).
5. **UI de gestão de elegibilidade (Opção C):** não existe tela para configurar `professional_service_group_eligibility` nem `organizations.default_service_eligibility` — só a API/RPC. `CapabilityModal.jsx`/`CapabilitiesTab.jsx` (Equipe) seguem cobrindo só duração/buffer/preço, sem campo para `eligibility` (têm `default 'ENABLED'`, então não quebraram, mas o tri-state fica inacessível pela PWA por ora).

---

## Achados da Auditoria Opção C (Fase 10.5) — resolvidos pela Phase 3
- **professional_service_capabilities.eligibility** (tri-state, substituiu `active` boolean) + **professional_service_group_eligibility** (nova tabela) + **organizations.default_service_eligibility**: cascata capability > grupo > default da org via `private.resolve_eligibility()` (ADR 0010).
- **appointments.resolved_duration_minutes/resolved_eligibility_source/resolved_at**: snapshot congelado na criação, preservado em MOVE_TIME_ONLY (ADR 0011) — fecha o CRITICAL GAP de `ends_at` recalculando em updates.
- **create_appointment/update_appointment** (RPCs `security definer`, mesma arquitetura de `checkout_close`): idempotência atômica via `Idempotency-Key`, concorrência otimista via `version` (coluna existia desde a Fase 10 mas nunca foi usada), gate de elegibilidade fail-closed configurável, confirmação two-step com diff ao reconfigurar profissional/serviço (ADR 0012/0013).
- Migration: `supabase/migrations/20260716150000_fase_opcao_c_elegibilidade_snapshot.sql`. 46 novos testes pgTAP (`rpc_appointments_test.sql`, `rls_professional_service_group_eligibility_test.sql`).

---

## Próxima Ação Imediata

**Opção C encerrada de ponta a ponta (banco, backend, frontend, verificado no browser real). Próximo passo: decidir entre o Gap #2 (organization_id sistêmico) e a Fase 11 (Equipe/convite).**
*O Gap #2 é uma falha silenciosa (sem erro, sem crash — o registro só não aparece até o próximo sync), então não bloqueia o dia a dia como o `appointments` quebrado bloqueava, mas gera confusão real de UX ("criei e sumiu") em qualquer módulo afetado. Corrigir é mecânico (adicionar `organization_id` a cada `COLUMNS`/resposta de RPC), mas precisa passar por ~9 módulos com verificação em cada um.*
