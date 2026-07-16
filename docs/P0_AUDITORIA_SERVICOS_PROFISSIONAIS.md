# P0 — Auditoria real: serviços × profissionais

**Data:** 2026-07-16  
**Escopo:** schema, migrations, banco local executado, backend, PWA e testes.  
**Regra:** código e banco executado prevalecem sobre documentação.

## Veredito

`professional_service_capabilities` é `REAL` como tabela e CRUD de overrides de duração, buffers, preço e `active`. Não é, porém, a autoridade canônica solicitada no plano anexado. O gate de elegibilidade, competência, modos `LEGACY_ALLOW/OBSERVE/STRICT`, origem por campo, vigência, resolução de preço temporal e snapshot auditável ainda estão `AUSENTES`.

O estado da documentação que declara a Fase 10 concluída é `CONTRADITÓRIO` com o contrato corrigido: há uma implementação, mas ela materializa outro contrato.

## Schema real

| Tabela | Campos relevantes | Constraints/FKs | RLS |
|---|---|---|---|
| `services` | `organization_id`, `price_cents bigint`, `duration_minutes integer`, `active`, `service_group_id`, comissão opcional | preço ≥ 0; duração 5–1440; FK tenant-safe para organização/grupo; unique `(organization_id,id)` | `SELECT` para membro; escrita por roles operacionais |
| `professionals` | `organization_id`, `active`, `user_id` opcional | FK tenant-safe para organização/membership; unique `(organization_id,id)` | `SELECT` para membro; escrita por roles operacionais |
| `professional_service_capabilities` | `organization_id`, `professional_id`, `service_id`, `duration_override_minutes`, `buffer_before_min`, `buffer_after_min`, `price_override_cents`, `active` | unique `(organization_id,professional_id,service_id)`; duração 5–1440; buffers 0–480; preço ≥ 0; FKs compostas tenant-safe | `SELECT` membro; `INSERT/UPDATE` owner/admin/manager; `DELETE` owner/admin |
| `professional_service_commissions` | `organization_id`, profissional, serviço, `commission_type`, `commission_value` | unique N:N; FKs compostas; percentual ≤ 10000 | CRUD separado; dados financeiros |
| `appointments` | `organization_id`, cliente, profissional, serviço, `starts_at`, `ends_at`, `status`, `version` | `ends_at > starts_at`; FKs compostas; exclusão GiST contra sobreposição por profissional; FSM para `completed`; trigger incrementa `version` | `SELECT` membro; `INSERT/UPDATE/DELETE` owner/admin/manager/reception |

**Evidência do banco local:** `supabase_db_kortex-os-v2` foi consultado em `information_schema`, `pg_policies` e triggers. A tabela de capability não contém `enabled_override`, `competency_level`, `version`, `updated_by` ou campos de vigência.

## Call sites

| Arquivo | Operação | Regra calculada | Autoridade atual | Risco |
|---|---|---|---|---|
| `backend/src/modules/appointments/appointments.service.js` | POST appointment | Calcula `ends_at` com `capability.duration_override_minutes` ou `services.duration_minutes` | Backend Express | `PARCIAL`: não resolve elegibilidade, preço, buffers, competência ou origem; usa truthiness e ignora override `0` se futuramente permitido |
| `backend/src/modules/appointments/appointments.service.js` | PATCH appointment | Recalcula término quando muda profissional/serviço/início | Backend Express + trigger/constraint | `CRÍTICO`: várias leituras e uma escrita; sem transação, snapshot ou lock otimista por `version` |
| `backend/src/modules/appointments/appointments.route.js` | POST/PATCH/DELETE | RBAC e tenant via middleware | Express + RLS | `REAL` como autorização; não força resolver canônico em outros caminhos |
| `frontend/src/modules/agenda/AppointmentModal.jsx` | POST/PATCH appointment | Calcula duração com `service.duration_minutes` e envia `ends_at` | Frontend, embora o backend seja a autoridade | `CONTRADITÓRIO`: o backend rejeita `ends_at` como `unknown_fields`; a PWA não está alinhada ao contrato server-side |
| `backend/src/modules/professionalServiceCapabilities/*` | CRUD capability | Valida limites e referências cross-tenant | Backend CRUD | `PARCIAL`: `active` é tratado como elegibilidade binária; não há tri-state nem `expected_version` |
| `supabase/migrations/20260713060000_professional_commissions_checkout.sql` | checkout | profissional × serviço → serviço → grupo | RPC `checkout_close` / `private.resolve_commission` | `REAL` para settlement; não é resolver de booking |
| `frontend/src/modules/comanda/ComandaPage.jsx` | checkout/status | Envia intenção à API e marca appointment completed | API/RPC checkout | `REAL` como fluxo financeiro; não congela configuração de agenda |

## Escritas de appointments

1. API Express: `POST /api/v1/appointments` e `PATCH /api/v1/appointments/:id`, em `appointments.route.js`/`appointments.service.js`.
2. PWA: `AppointmentModal` cria/edita e `ComandaPage` atualiza status para `completed`.
3. Testes e helpers inserem diretamente no Supabase para fixtures/integração.
4. Não foi localizado RPC/Command `create_appointment_with_resolution`, nem revisão de configuração.

O banco aceita DML para `authenticated` conforme RLS e concede acesso operacional a `service_role`; portanto, a resolução não é uma fronteira única de escrita. O backend é o caminho normal, mas não existe enforcement estrutural que obrigue todo escritor privilegiado a passar pelo resolver.

## Preço, duração, buffers e competência

- **Preço de booking:** `services.price_cents` existe; `price_override_cents` existe apenas na capability CRUD. Não é consumido pelo appointment nem por um resolver de oferta.
- **Duração:** `capability.duration_override_minutes → services.duration_minutes` é consumida somente pelo serviço de appointments.
- **Buffers:** armazenados como `buffer_before_min`/`buffer_after_min`, mas não consumidos no cálculo de `ends_at`, no conflito ou em snapshot.
- **Elegibilidade:** `active` da linha de capability não implementa `enabled_override = NULL/TRUE/FALSE`; ausência e presença têm comportamento legado implícito. Não há `OBSERVE`/`STRICT`.
- **Competência:** inexistente; não há `competency_level` nem inferência legítima.
- **Origem/versões/hash:** inexistentes para a decisão de agenda.

## Commission flow

- **Cascata:** `professional_service_commissions` → `services` → `service_groups`.
- **Momento de resolução:** dentro de `checkout_close`, via `private.resolve_commission`.
- **Momento de congelamento:** inserção dos campos `commission_type`, `commission_value` e `commission_cents` em `order_items` no checkout.
- **Fonte definitiva:** settlement/checkout; isso está correto e não deve ser movido para appointment.
- **Classificação:** `REAL` para checkout; `AUSENTE` para estimativa de booking e distinção explícita entre estimativa e comissão final.

## Contradições e bypasses

### Contradições

- `PROJECT_STATE.md` afirma capacidade implementada/concluída, mas o contrato corrigido exige campos e semântica que não existem.
- O comentário do backend diz que `ends_at` é server-side, porém `AppointmentModal.jsx` ainda o calcula e envia.
- A implementação usa `active` obrigatório e buffers default `0`; o contrato exige tri-state, ausência distinta de zero e overrides nullable.
- `version` existe no appointment, mas a API não exige nem compara `expected_version`; o trigger apenas incrementa a versão.

### Bypasses e duplicações

- PWA calcula duração/término independentemente.
- Fixtures/testes fazem INSERT direto em `appointments`, fora de um command de resolução.
- `professional_service_capabilities` e `professional_service_commissions` são resolvidos por caminhos separados; não há oferta única.
- `service_role` bypassa RLS e tem grants DML; não há trigger/deny que force snapshot ou append-only.
- Não há revisão, hash, auditoria de decisão ou atomicidade entre appointment e configuração resolvida.

## P0.5 bloqueado

Não é seguro aprovar o contrato anexado como compatível com o schema atual sem decidir se a implementação da Fase 10 será substituída ou migrada. Em particular, ainda precisam ser definidos antes de qualquer migration nova:

- nomes canônicos (`enabled_override`, `competency_level`, buffers e `version`);
- política temporal e `pricingPolicy`;
- hash canônico e representação de `null`/zero;
- semântica de `LEGACY_ALLOW`, `OBSERVE` e `STRICT`;
- ownership da transação de criação e do snapshot.

## Testes e evidência

Os testes existentes comprovam `REAL` apenas para limites/RLS/CRUD da tabela, conflitos GiST, FSM e checkout. Não comprovam o resolver canônico, elegibilidade, buffers, preço no booking, snapshot, atomicidade ou concorrência por `expected_version`. A suíte declarada em `PROJECT_STATE.md` não altera essa classificação.

## Próxima ação única

Concluir P0.5 como contrato canônico compatível com o schema realmente escolhido; só depois desenhar a migration P1. Nenhuma migration foi criada nesta auditoria.

## Handoff

```text
FILES_CHANGED:
- docs/P0_AUDITORIA_SERVICOS_PROFISSIONAIS.md — auditoria P0 baseada em código, migrations, banco local e testes
BLOCKERS_REMAINING:
- Contrato P0.5 ainda não aprovado
- Divergência PWA/backend em ends_at
- Resolver único, snapshot e enforcement transacional ausentes
VEREDITO:
- NO-GO para migration P1 agora; a capability existente é REAL como CRUD parcial, não como autoridade canônica
```
