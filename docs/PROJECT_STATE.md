# PROJECT STATE — KortexOS MVP técnico

**Atualizado:** 2026-07-17 | Opção C Phase 3 (banco + backend) concluída — **PWA quebrada até a Fase de wiring do frontend** (ver Gaps).

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
| Elegibilidade Opção C | `REAL` (banco+API) | ADRs 0010-0013; `create_appointment`/`update_appointment` RPCs, tri-state, snapshot, idempotência, version, change plan. |
| PWA Modular | `QUEBRADO` (appointments) | Agenda/Comanda ainda chamam `POST/PATCH /appointments` no contrato antigo — ver Gaps. |
| Projection Cache | `REAL` | Tabela `sync_events`, triggers, endpoints SSE/REST e IndexedDB local. |
| CI/CD & Deploy | `REAL` | GitHub Actions (lint, testes, secrets scan), Render API (`kortex-api`). |

## Métricas da Suíte de Testes (PASS)
- **pgTAP (Banco):** 229 / 229 testes passando (`supabase test db --local`) — +46 desde a Fase Opção C (RPCs, tri-state, snapshot, idempotência).
- **Backend (Express):** 231 / 231 testes passando (`npm run test`).
- **Frontend (PWA):** 84 / 84 testes passando (`npm run test`) — **não cobre o novo contrato**, testes mockam `apiClient` e não pegam o 400/409 real (ver Gaps).

---

## Histórico de Fases Concluídas
- **Fases 1 a 5:** Infraestrutura local, migrations, checkout atômico, comissionamento e pacotes.
- **Fase 6:** PWA Modular (Subfases 6.1 a 6.6: app shell, Agenda, Comanda/Checkout, cadastros e caixas).
- **Fases 7 a 10:** CI/CD, deploys Render/GitHub Pages, fundação financeira e capacidades profissional × serviço.
- **Fase Extra:** Projection Cache local e sincronização incremental via REST + SSE (ADR 0009).

---

## Gaps e Pendências Conhecidos
1. **Gestão de Equipe:** Sem convite por e-mail no frontend (Fase 11).
2. **PWA × novo contrato de `appointments` (CRITICAL, bloqueia deploy):** `AppointmentModal.jsx` chama `POST/PATCH /appointments` sem `Idempotency-Key` (400 `missing_idempotency_key` em toda tentativa) e sem `version` no PATCH (400 `missing_version`). Além disso o modo "editar" sempre reenvia `professional_id`/`service_id` mesmo sem mudança, o que agora sempre aciona `confirmation_required` (409, ADR 0013) — falta a tela de diff/confirmação que não existe ainda. Achado adicional, não relacionado à Opção C: o payload também envia `ends_at` (nunca aceito pelo backend desde a Fase 10 — `unknown_fields`), bug pré-existente que passou despercebido porque os testes de frontend mockam `apiClient`. **Nenhum destes três pontos foi corrigido nesta sessão** — precisa de uma fase própria de wiring do frontend antes de merge/deploy.
3. **Price Override:** Campo `price_override_cents` é dead code (reservado para o futuro — ver ADR 0008 Decisão 1 e ADR 0013).
4. **Sessões de Caixa:** Correção operacional de checkout fechado por erro (Fase 12, ADR 0007).

---

## Achados da Auditoria Opção C (Fase 10.5) — resolvidos pela Phase 3
- **professional_service_capabilities.eligibility** (tri-state, substituiu `active` boolean) + **professional_service_group_eligibility** (nova tabela) + **organizations.default_service_eligibility**: cascata capability > grupo > default da org via `private.resolve_eligibility()` (ADR 0010).
- **appointments.resolved_duration_minutes/resolved_eligibility_source/resolved_at**: snapshot congelado na criação, preservado em MOVE_TIME_ONLY (ADR 0011) — fecha o CRITICAL GAP de `ends_at` recalculando em updates.
- **create_appointment/update_appointment** (RPCs `security definer`, mesma arquitetura de `checkout_close`): idempotência atômica via `Idempotency-Key`, concorrência otimista via `version` (coluna existia desde a Fase 10 mas nunca foi usada), gate de elegibilidade fail-closed configurável, confirmação two-step com diff ao reconfigurar profissional/serviço (ADR 0012/0013).
- Migration: `supabase/migrations/20260716150000_fase_opcao_c_elegibilidade_snapshot.sql`. 46 novos testes pgTAP (`rpc_appointments_test.sql`, `rls_professional_service_group_eligibility_test.sql`).

---

## Próxima Ação Imediata

**Wiring do frontend para o novo contrato de `appointments` — bloqueia deploy (ver Gap #2).**
*O backend da Opção C (ADRs 0010-0013) está completo e testado (banco + Express), mas a PWA (`AgendaPage.jsx`/`AppointmentModal.jsx`) ainda fala o contrato antigo. Falta: (1) gerar `Idempotency-Key` por tentativa de escrita, igual ao padrão já usado em `ComandaPage`/checkout; (2) rastrear e reenviar `version` a cada PATCH; (3) parar de reenviar `professional_id`/`service_id` quando não mudaram (ou implementar a tela de diff/confirmação do ADR 0013 para quando mudarem de fato — `confirmation_required`); (4) remover `ends_at` do payload (bug pré-existente, não relacionado à Opção C, nunca aceito pelo backend desde a Fase 10). Testes de frontend precisam de cobertura nova para os três fluxos (idempotência, version conflict, confirmação) — os 84 testes atuais mockam `apiClient` e não pegam a quebra.*
