# 11. Snapshot Operacional: Congelar Duração e Origem da Elegibilidade no Agendamento (Accepted)

Date: 2026-07-16

## Status

**Accepted (2026-07-16).** Item 4 do plano de 7 ADRs (`docs/audit_global/SERVICE_PROFESSIONAL_OPTION_C_AUDIT.md §11`). Depende do [ADR 0010](0010-elegibilidade-tri-state-fail-closed.md) (Accepted) existir, porque o snapshot inclui a origem (`source`) que o resolver de elegibilidade introduz. A pergunta de backfill (seção "Pergunta para aprovação") foi respondida pelo usuário.

## Context

A auditoria (§8.1) comprovou um bug real, com teste que o reproduz (`appointments.test.js:263`):

> `PATCH /appointments/:id` com apenas `{ starts_at: T2 }` recalcula `ends_at` usando a configuração **vigente no momento do PATCH**, não a que valia quando o agendamento foi criado.

Causa raiz em `backend/src/modules/appointments/appointments.service.js:116-134`: `touchesDuration` trata `professional_id`, `service_id` e `starts_at` como equivalentes — qualquer um dos três dispara `computeEndsAt` do zero. Mas são operações semanticamente diferentes:
- **Mover o horário** (só `starts_at` muda) deveria preservar a duração já prometida ao cliente.
- **Trocar profissional ou serviço** é uma reconfiguração real — faz sentido re-resolver.

A auditoria (§8.4) também comprovou que não há como responder "de onde veio essa duração?" hoje — `resolveDurationMinutes` retorna só o número, sem origem. O [ADR 0010](0010-elegibilidade-tri-state-fail-closed.md) já resolve isso para elegibilidade (retorna `{ eligible, source }`); este ADR estende o mesmo princípio para duração e propõe onde/quando congelar o resultado.

A auditoria também nomeia esse comportamento correto como **MOVE_TIME_ONLY** (item 8 da matriz de completude da Opção C) — preservar o snapshot quando só o horário muda.

## Decision (proposta)

### 1. Colunas de snapshot em `appointments`

```sql
alter table public.appointments
  add column resolved_duration_minutes integer not null,
  add column resolved_eligibility_source text not null
    check (resolved_eligibility_source in ('capability', 'group', 'org_default')),
  add column resolved_at timestamptz not null default now();
```

Preenchidas uma vez por `computeEndsAt` no `create()`, e recalculadas **só** quando `professional_id` ou `service_id` de fato mudam — nunca por causa de `starts_at` isolado.

### 2. `update()` passa a distinguir dois casos, não um

```
touchesConfig = patch.professional_id !== undefined || patch.service_id !== undefined
touchesTimeOnly = patch.starts_at !== undefined && !touchesConfig

se touchesConfig:
  re-resolve elegibilidade (ADR 0010) e duração a partir do zero
  grava novo resolved_duration_minutes / resolved_eligibility_source / resolved_at
  ends_at = starts_at (novo, se enviado, senão o existente) + resolved_duration_minutes novo

se touchesTimeOnly:
  NÃO re-resolve nada
  ends_at = novo starts_at + resolved_duration_minutes já gravado no agendamento (snapshot existente)
```

Isso fecha o bug do §8.1: mover só o horário nunca mais consulta `professional_service_capabilities` de novo — usa o número já congelado na criação (ou na última reconfiguração real).

### 3. Migração de dados para agendamentos já existentes

Agendamentos criados antes desta migration não têm `resolved_duration_minutes` gravado. Backfill: `resolved_duration_minutes = extract(epoch from (ends_at - starts_at)) / 60` (deriva do próprio intervalo já persistido — não precisa re-chamar o resolver, o valor efetivo já está implícito nas colunas existentes). `resolved_eligibility_source = 'org_default'` como valor conservador para todo backfill (não é possível reconstruir a origem real retroativamente; é só metadado de auditoria, não afeta comportamento).

### 4. Escopo explicitamente fora deste ADR

- **Log append-only de todas as resoluções** (uma linha por tentativa de resolução, não só o estado atual) — a auditoria lista isso como componente separado ("Source-by-field tracking"). As 3 colunas propostas aqui cobrem "qual é o snapshot vigente", não "histórico completo de todas as mudanças". Se auditoria completa (quem mudou o quê e quando, não só o valor atual) for necessária, é um ADR à parte — não represento isso como decidido.
- **Congelamento de `buffer_before_min`/`buffer_after_min`** — seguem `STORED_UNUSED` (aguardando Fase 14, Availability Engine); nada aqui muda isso.

## Decisão do usuário (2026-07-16)

- Backfill de `resolved_eligibility_source` para agendamentos pré-existentes usa **`'org_default'`** — reaproveita um dos 3 valores já aprovados no ADR 0010, sem exigir um 4º valor-sentinela no `check` constraint. É só metadado de auditoria; não muda `resolved_duration_minutes` nem qualquer comportamento em runtime.

## Consequences

### Positivo
- Fecha o CRITICAL GAP §8.1 da auditoria com teste já existente (`appointments.test.js:263`) como caso de regressão pronto para validar o fix.
- Implementa MOVE_TIME_ONLY (item 8 da matriz de completude da Opção C) sem exigir as outras 9 peças (approval workflow, competency tracking etc.).
- `resolved_eligibility_source` destrava a primeira camada de auditoria ("por que este profissional pôde ser agendado") sem exigir um log append-only completo.

### Trade-off
- 3 colunas novas em `appointments`, mais lógica condicional em `update()` — todo teste de reagendamento precisa cobrir os dois ramos (`touchesConfig` vs `touchesTimeOnly`).
- Não resolve auditoria histórica completa (quem mudou o quê, quando) — só o snapshot vigente. Se isso for necessário, é trabalho adicional.
- Depende do [ADR 0010](0010-elegibilidade-tri-state-fail-closed.md) estar implementado (o resolver de elegibilidade com `source` precisa existir) antes deste poder ser codificado — ordem de implementação importa.

## References
- `docs/audit_global/SERVICE_PROFESSIONAL_OPTION_C_AUDIT.md` §8.1, §8.4, §9 — bug comprovado, gap de auditoria, item MOVE_TIME_ONLY
- `backend/src/modules/appointments/appointments.service.js:39-67,110-134` — `resolveDurationMinutes`, `computeEndsAt`, `update()` (código a modificar)
- `backend/tests/**/appointments.test.js:263` — teste que já comprova o bug
- [ADR 0010 — Elegibilidade Tri-State](0010-elegibilidade-tri-state-fail-closed.md) — introduz o `source` que este ADR persiste
- `supabase/migrations/20260715140100_fase10_appointments_hardening.sql` — `version`/FSM guard já existentes, contexto de hardening anterior do mesmo módulo
