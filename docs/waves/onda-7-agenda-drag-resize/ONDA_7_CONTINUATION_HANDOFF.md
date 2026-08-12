# Handoff de continuidade — Onda 7 (Agenda: reagendamento por arraste e redimensionamento)

**Audience:** outra inteligência ou pessoa responsável por retomar o Blueprint (Etapa 7) e a implementação da Onda 7.
**Objetivo:** retomar o trabalho a partir de uma base verificável, sem reabrir decisões já aprovadas nem cruzar ambientes. Esta sessão terminou aqui por limite de contexto — não por bloqueio de produto.

## Estado atual

- **Migration Map v1.3 / Onda 7: APROVADO** (DEC-64). Etapa 7 (Blueprint) **desbloqueada**.
- **Reconciliação de numeração DEC-62: APROVADA e MESCLADA** (DEC-65, [PR #44](https://github.com/hudson-f-lima/Kortex_Os_v2/pull/44), merge commit `3c6327a`, em `staging`).
- **Blueprint da Onda 7 (Etapa 7): NÃO iniciado.** Esta é a próxima ação de produto.
- **Etapa 8 (SQL/migration): BLOQUEADA** até o Blueprint existir e ser aprovado.
- Produção/`main`: fora do escopo; nenhum deploy deve ser inferido deste documento.

### Branches relevantes (todas verificadas por comando, não por relato)

| Branch | Estado | Conteúdo |
|---|---|---|
| `staging` | Atual (`3c6327a`) | Tem DEC-62 a DEC-65, Migration Map v1.3/Onda 7, ADR 0025, Blueprint da Onda 6 |
| `feat/agenda-drag-and-resize-clean` | Empurrada (`origin/feat/agenda-drag-and-resize-clean`), **sem PR aberto** | Reagendamento por arraste — ver seção abaixo |
| `codex/onda6-checkout-reopen` | Publicada, intacta | DEC-62 original (Onda 6) — já bate com a numeração canônica, nada a corrigir |
| `codex/speckit-runner-telemetry` | Publicada, intacta | DEC-62 original (runner) — **ainda precisa renumerar para DEC-63** antes do próprio merge final; não reescrever, só alinhar numa branch nova quando for mesclar |

## Ordem canônica de leitura

1. [`AGENTS.md`](../../../AGENTS.md) — invariantes, governança MAS e formato de handoff.
2. [`docs/INDEX.md`](../../INDEX.md) — mapa da fonte única de verdade (linha da Onda 7 já atualizada).
3. [`KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md`](../../KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md) — visão vigente do produto.
4. [`KORTEXOS_5_1_2_MIGRATION_MAP.md`](../KORTEXOS_5_1_2_MIGRATION_MAP.md) §3, Onda 7 — escopo aprovado, objeto mapeado (`update_appointment` estendida), decisões de desenho já fechadas.
5. [`KORTEXOS_5_1_2_DECISION_LOG.md`](../../architecture/governance/KORTEXOS_5_1_2_DECISION_LOG.md) SEÇÕES 27-30 (DEC-62 a DEC-65) — histórico completo da colisão de numeração e sua reconciliação; leia antes de mexer em qualquer DEC novo.
6. Este documento.

## O que já foi entregue (não refazer)

### Sub-item 1 — reagendamento por arraste (frontend-only, completo)

Branch `feat/agenda-drag-and-resize-clean`, empurrada, sem PR ainda. 12 arquivos, 618 inserções.

- Arrastar um card na `TimelineView` (`frontend/src/modules/agenda/AgendaPage.jsx`) remaneja `starts_at` (mesma coluna) e/ou `professional_id` (coluna diferente) via Pointer Events (não HTML5 DnD — funciona em touch).
- Reaproveita o PATCH `/appointments/:id` existente: `version` (lock otimista) + fluxo `confirmation_required` (ADR 0013) quando troca de profissional.
- `ChangeDiff.jsx`, `appointmentErrorMessages.js` e `idempotencyKey.js` foram extraídos de `AppointmentModal.jsx` para serem compartilhados entre o modal e o drag.
- 4 testes novos de drag (mesma coluna, coluna diferente, clique simples não dispara PATCH, fluxo de confirmação) + suíte completa: **25/25 passando** em `frontend/src/modules/agenda/` e `frontend/src/ui/domain/`.
- **Próxima ação recomendada, se quiser mesclar isto independente do resto**: abrir PR desta branch para `staging` — não depende do Blueprint da Onda 7 (só usa contrato já existente). Rebase trivial, sem conflito (branch está 1 commit atrás de `staging`, arquivos não se sobrepõem com a reconciliação DEC-62/65).

### Reconciliação DEC-62 a DEC-65 (completa, mesclada)

Ver Decision Log SEÇÕES 27-30 para o histórico completo. Resumo: duas branches (Onda 6, runner de fan-out) registraram DEC-62 de forma independente; numeração canônica fixada (62=Onda 6, 63=runner, 64=Onda 7, 65=este registro), sem reescrever nenhum commit já publicado.

## O que falta (escopo do Blueprint a retomar)

**Sub-item 2 — redimensionamento de duração**, sem trocar profissional/serviço. Escopo já aprovado no Migration Map (DEC-64):

- Estender `update_appointment` (RPC existente, `supabase/migrations/20260805020000_onda5_fatia033_participants.sql`, última `create or replace`) pra aceitar `duration_minutes` opcional — mesmo padrão que `create_appointment` já usa desde a Onda 5. **Nenhuma tabela ou coluna nova.**
- Expor o campo no Express (`backend/src/modules/appointments/appointments.validation.js` — `CREATE_FIELDS`/`UPDATE_FIELDS` hoje bloqueiam `duration_minutes` com 400 `unknown_fields`).
- Frontend: campo de duração no `AppointmentModal` + resize por arrastar a borda do card (reaproveita a infra de pointer-events já construída no sub-item 1).

### Decisões de desenho já fechadas por interview com o Platform Owner (não reabrir, só materializar no Blueprint)

1. Mudança pura de duração **sempre exige confirmação explícita** antes de aplicar (reaproveita ADR 0013 change-plan) — diferente de mover só o horário, que aplica direto (`MOVE_TIME_ONLY`, ADR 0011).
2. Colisão com o próximo agendamento do mesmo profissional: a RPC deve devolver `max_fit_duration_minutes` (quanto cabe até o `starts_at` do próximo agendamento ativo) dentro do próprio diff de confirmação, pra UI oferecer "Encaixar até HH:MM" em vez de só um 409 seco. **A exclusion constraint GiST continua sendo a única barreira real de integridade** — a pré-checagem é só uma `SELECT` informativa, nunca a substitui.
3. Fora de escopo, explicitamente: `appointment_replan_with_hold` (comando separado, não mexer); nenhuma tabela de auditoria nova (não existe hoje pra nenhuma mutação de agendamento, não inaugurar nesta fatia); buffers (`professional_service_capabilities.buffer_before_min`/`buffer_after_min`) — colunas existem mas são dormentes hoje em `create_appointment`/`update_appointment`; esta fatia não os ativa, só mantém o comportamento atual.
4. Benchmark Gate já cumprido (registrado em DEC-64): FullCalendar (`eventOverlap`/`eventConstraint`/`revert`, sem auto-clamp nativo) e produtos de agenda de salão em geral — sem convenção de auto-clamp silencioso, a tensão "recusar vs. estender" é sempre resolvida por decisão humana explícita, nunca automática.
5. Comissão é 100% baseada em `commission_cents`, nunca em `resolved_duration_minutes` (grep zero confirmado no backend) — esta mudança é financeiramente inerte.

### Próxima ação única

Invocar `$kortex-blueprint-architect` com este handoff como contexto (Migration Map já aprovado, decisões de desenho já fechadas acima — não reabrir a interview, só redigir o Blueprint no template padrão: autoridade e limites, escopo de dados, integridade/invariantes, contrato físico de schema, compatibilidade/backfill, plano de execução/rollback, matriz RLS) e encaminhar pro `$kortex-qa-redteam` antes de pedir aprovação do Platform Owner.

## Protocolo de continuidade

1. Confirme `git status -sb`, branch atual e remote antes de qualquer ação — **este repositório teve concorrência real de outra sessão gravando no mesmo diretório de trabalho durante esta sessão** (ver DEC-65 e Decision Log SEÇÃO 30 para o incidente completo). Sempre reverifique o estado real (`git fetch`, comparar com `origin/*`) antes de assumir que nada mudou.
2. Não escreva SQL/migration sem Blueprint aprovado — o hook `check-blueprint-gate.js` bloqueia isso automaticamente, mas não contorne o hook criando uma referência falsa.
3. Toda promoção segue `feature/fix → staging → main`; nenhuma branch de correção abre PR direto para `main`.
4. Antes de qualquer PR de código (não só docs), rode a suíte completa do módulo tocado — o padrão desta sessão foi `npx vitest run` no frontend e `node --test` no backend, ambos localmente contra o Supabase local descartável.

## Veredito e bloqueadores

```text
FILES_CHANGED (esta sessão):
- Frontend: drag-to-reschedule completo (feat/agenda-drag-and-resize-clean, sem PR).
- Governança: Decision Log (DEC-62 a DEC-65), Migration Map v1.3, INDEX.md, ADR 0024 (mesclados em staging via PR #44).

BLOCKERS_REMAINING:
- Blueprint (Etapa 7) da Onda 7 — não iniciado.
- PR do sub-item 1 (drag-to-reschedule) — opcional, pode mesclar independente.
- codex/speckit-runner-telemetry precisa renumerar seu DEC-62 interno para DEC-63 antes do próprio merge final.

VEREDITO:
- Onda 7, sub-item 1 (arraste): GO local, pronto para PR.
- Onda 7, sub-item 2 (redimensionamento): Migration Map aprovado, Blueprint pendente.
- Promoção remota/produção: fora de escopo, não avaliada nesta sessão.
```

## Fontes de autoridade

- Código e migrations atuais são a verdade operacional.
- `docs/INDEX.md`, Master Briefing, Migration Map e Decision Log (SEÇÕES 27-30) são a verdade documental ativa desta Onda.
- Este handoff não autoriza SQL, migration, ativação ou promoção — só orienta a retomada do Blueprint.
