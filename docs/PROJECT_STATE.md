# PROJECT STATE — KortexOS MVP técnico

**Atualizado:** 2026-07-16 | Local Projection Cache & Incremental Sync (ADR 0009) concluído.

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
| PWA Modular | `REAL` | Vite + React app shell, 8 módulos, service worker e cache offline. |
| Projection Cache | `REAL` | Tabela `sync_events`, triggers, endpoints SSE/REST e IndexedDB local. |
| CI/CD & Deploy | `REAL` | GitHub Actions (lint, testes, secrets scan), Render API (`kortex-api`). |

## Métricas da Suíte de Testes (PASS)
- **pgTAP (Banco):** 183 / 183 testes passando (`supabase test db --local`).
- **Backend (Express):** 217 / 217 testes passando (`npm run test`).
- **Frontend (PWA):** 84 / 84 testes passando (`npm run test`).

---

## Histórico de Fases Concluídas
- **Fases 1 a 5:** Infraestrutura local, migrations, checkout atômico, comissionamento e pacotes.
- **Fase 6:** PWA Modular (Subfases 6.1 a 6.6: app shell, Agenda, Comanda/Checkout, cadastros e caixas).
- **Fases 7 a 10:** CI/CD, deploys Render/GitHub Pages, fundação financeira e capacidades profissional × serviço.
- **Fase Extra:** Projection Cache local e sincronização incremental via REST + SSE (ADR 0009).

---

## Gaps e Pendências Conhecidos
1. **Gestão de Equipe:** Sem convite por e-mail no frontend (Fase 11).
2. **Capacidade Profissional (Opção C):**
   - *Elegibilidade:* Qualquer profissional pode ser agendado (sem gate fail-closed).
   - *Duração no Update (CRITICAL GAP):* PATCH `/appointments/:id` com apenas `starts_at` recomputa `ends_at` (quebra o congelamento).
   - *Price Override:* Campo `price_override_cents` é dead code (reservado para o futuro).
3. **Sessões de Caixa:** Correção operacional de checkout fechado por erro (Fase 12, ADR 0007).

---

## Achados da Auditoria Opção C (Fase 10.5)
- **professional_service_capabilities** está ativa no schema (11 colunas, FKs compostas, RLS e triggers de sync).
- **resolveDurationMinutes()** implementado em `appointments.service.js` (capability override -> default).
- Para evoluir para Opção C, são necessários:
  - Elegibilidade tri-state (INHERIT|ENABLED|DISABLED).
  - Competency tracking e grupo -> profissional assignment.
  - Snapshot imutável no agendamento e preservação de horários (MOVE_TIME_ONLY).
  - Fluxo de aprovação e diff ao alterar profissional/serviço.

---

## Próxima Ação Imediata

**Modelagem de Capacidades (Opção C) — Especificação Documental concluída: 4 de 4 ADRs aprovados. Phase 3 (migration estrutural) liberada.**
*[ADR 0010](adr/0010-elegibilidade-tri-state-fail-closed.md) (Accepted) resolve a Decisão 2 reaberta do ADR 0008 com um modelo tri-state (INHERIT/ENABLED/DISABLED) em dois níveis (grupo + individual) e default configurável por organização. [ADR 0011](adr/0011-snapshot-operacional-agendamento.md) (Accepted) congela duração/elegibilidade no agendamento, corrigindo o CRITICAL GAP de `ends_at` recalculando em updates. [ADR 0012](adr/0012-idempotencia-concorrencia-otimista-appointments.md) (Accepted) move `appointments` para RPCs transacionais (`create_appointment`/`update_appointment`, Rota B — mesma arquitetura de `checkout_close`), com `Idempotency-Key` e ativação da coluna `version` já existente. [ADR 0013](adr/0013-change-plan-booking-settlement.md) (Accepted) especifica confirmação two-step (diff) ao trocar profissional/serviço e formaliza a separação Booking × Settlement. Nenhuma migration foi criada ainda nesta sessão — a Phase 3 (reescrever `appointments.service.js` como RPC `plpgsql`, é o maior item de esforço da leva) é o próximo passo de engenharia.*
