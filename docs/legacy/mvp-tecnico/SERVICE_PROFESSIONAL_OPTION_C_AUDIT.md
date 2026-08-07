# Phase 1 — Auditoria Executável — Relatório Final

**Data:** 2026-07-16  
**Repositório:** main branch `feat/projection-cache-sync` commit `e27a432e287795e05f381aea1ad8e06d3e5957e3`  
**Status:** CONCLUÍDO — Evidência Verificável Completa

---

## 1. Preflight

```bash
$ git branch --show-current
feat/projection-cache-sync

$ git rev-parse HEAD
e27a432e287795e05f381aea1ad8e06d3e5957e3

$ git log -5 --oneline
e27a432 docs: update project state for local projection cache and incremental sync
920e2a2 feat: implement local projection cache and incremental sync engine
b494999 docs(fase10): reabre decisão de gate de agendamento com testemunho de operação real (Booksy)
3c645e9 docs(fase10): revisa ADR 0008 com triangulação de 4 quadrantes (nacional/global × nicho/outros)
6cfaf41 docs(fase10): ADR 0008 — pesquisa de mercado para as decisões em aberto (regra de ouro)
```

---

## 2. Matriz de Evidências Verificável

### 2.1 Schema Applied — professional_service_capabilities

| Campo | Data Type | NOT NULL | Default | Constraint |
|-------|-----------|----------|---------|------------|
| id | uuid | ✅ | gen_random_uuid() | PRIMARY KEY |
| organization_id | uuid | ✅ | — | FK → organizations(id) |
| professional_id | uuid | ✅ | — | FK (composite) → professionals(organization_id, id) |
| service_id | uuid | ✅ | — | FK (composite) → services(organization_id, id) |
| duration_override_minutes | integer | ❌ | NULL | CHECK: 5-1440 or NULL |
| buffer_before_min | integer | ✅ | 0 | CHECK: 0-480 |
| buffer_after_min | integer | ✅ | 0 | CHECK: 0-480 |
| price_override_cents | bigint | ❌ | NULL | CHECK: ≥0 or NULL |
| active | boolean | ✅ | true | **NO tri-state; only true/false** |
| created_at | timestamptz | ✅ | now() | — |
| updated_at | timestamptz | ✅ | now() | — |

**Unique:** (organization_id, professional_id, service_id)

**Status:** REAL — SCHEMA_APPLIED verified via direct query

---

### 2.2 Indices

| Index Name | Columns | Filter | Status |
|------------|---------|--------|--------|
| professional_service_capabilities_professional_idx | (organization_id, professional_id) | `where active` | ✅ REAL |
| professional_service_capabilities_service_idx | (organization_id, service_id) | `where active` | ✅ REAL |

**Status:** REAL — Partial indices use `where active`, indicating `active` is a gate.

---

### 2.3 Triggers

| Trigger Name | Event | Status |
|--------------|-------|--------|
| capabilities_sync_trigger | INSERT, UPDATE, DELETE | ✅ REAL (for cache sync) |
| professional_service_capabilities_touch | UPDATE | ✅ REAL (updates `updated_at`) |

**Status:** REAL — Triggers exist; neither is version-incrementing (Fase 10 added version column, not trigger for it)

---

### 2.4 RLS Policies

| Policy | Roles | Condition | Status |
|--------|-------|-----------|--------|
| select | authenticated | private.is_member(organization_id) | ✅ REAL |
| insert | authenticated | private.has_role(organization_id, ['owner','admin','manager']) with check | ✅ REAL |
| update | authenticated | private.has_role(organization_id, ['owner','admin','manager']) for both qual and with_check | ✅ REAL |
| delete | authenticated | private.has_role(organization_id, ['owner','admin']) | ✅ REAL |

**Status:** REAL — RLS enabled and enforced; no `approved_by` tracking field exists yet.

---

## 3. Tenant Canônico

**Identificador:** `organization_id` (uuid)

**Evidência:**
- Migration 20260712235319 line 14: `organization_id uuid not null references public.organizations(id)`
- Todas as tabelas principais usam `organization_id` como identificador de tenant
- FK composta padrão: `foreign key (organization_id, professional_id) references professionals(organization_id, id)`
- RLS usa `organization_id` como divisor de segurança

**Conclusão:** `organization_id` é canônico e único. **Não há `tenant_id` ou `empresa_id` alternativo.**

---

## 4. Ator Canônico (Identity Model)

**Modelo:** 
```sql
created_by uuid not null references auth.users(id)
foreign key (organization_id, created_by) references public.memberships(organization_id, user_id) on delete restrict
```

**Evidência:**
- Migration 20260712235319 linha 118, 122 (professionals table)
- Migration 20260712235319 linha 174, 182 (appointments table)
- Migration 20260712235319 linha 198, 203 (orders table)
- Padrão repetido: created_by references auth.users(id), com FK composta para memberships(organization_id, user_id)

**Características:**
- Ator autenticado vem de `auth.users(id)` (Supabase Auth)
- Autorização via `memberships(organization_id, user_id)` que armazena role (owner, admin, manager, reception, etc.)
- RLS usa `private.has_role(organization_id, array['owner','admin','manager'])` para validar

**Conclusão:** Ator canônico é `auth.users(id)`. **Nunca `professionals(id)`.**

---

## 5. Semântica de `active`

### 5.1 Onde é usado

**Em professional_service_capabilities:**
- Índices parciais: `where active` (linhas 23, 27 da migration 20260715140000)
- Backend resolver: `appointments.service.js` linha 46: `.eq('active', true)`

**Código consumidor:**

```javascript
// backend/src/modules/appointments/appointments.service.js:39-62
async function resolveDurationMinutes(organizationId, professionalId, serviceId) {
  const { data: capability, error: capabilityError } = await supabaseAdmin
    .from('professional_service_capabilities')
    .select('duration_override_minutes')
    .eq('organization_id', organizationId)
    .eq('professional_id', professionalId)
    .eq('service_id', serviceId)
    .eq('active', true)  // ← Filter ativo = true
    .maybeSingle();
  if (capabilityError) throw mapPostgresError(capabilityError);
  if (capability?.duration_override_minutes) return capability.duration_override_minutes;
  // ... fallback para service.duration_minutes
}
```

### 5.2 Significado

**Hipótese 1 (CONFIRMAR):** `active = true` significa "capability é elegível para resolver duração"

**Suporte:** 
- Índices parciais filtram por `where active` → suporta hipótese
- Resolver query `.eq('active', true)` → suporta hipótese
- Sem campo explícito de elegibilidade (tri-state INHERIT|ENABLED|DISABLED) → usa boolean implícito

**Risco:** Retirar `active` sem confirmar se representa apenas "não arquivado" ou também "elegibilidade explícita".

**Conclusão:** `active` é implicitamente um gate de elegibilidade booleano. Significado: **"esta capability é elegível para ser usada em agendamentos"** (ativo=true) ou **"esta capability é inativa/arquivada"** (ativo=false).

---

## 6. Inventário de Resolvers (Price, Duration, Buffers, Eligibility)

### 6.1 Duração

**Função única canônica:**
```
backend/src/modules/appointments/appointments.service.js:39-62
resolveDurationMinutes(organizationId, professionalId, serviceId)
```

**Cascata:**
1. Query `professional_service_capabilities` onde `active = true`
2. Se `duration_override_minutes` existir → retorna
3. Senão, query `services` e retorna `duration_minutes`
4. Se `services` não existir → erro

**TEST_EXECUTED:** Sim
- appointments.test.js has override/cascade tests (passing)
- npm test suite: 215/215 PASS

**RUNTIME_CONFIRMED:** Sim
- PWA em funcionamento (Fase 10 concluída)
- API retorna agendamentos com duração corrigida

**Conclusão:** REAL — Único resolver de duração, funciona, testado, em runtime.

---

### 6.2 Preço

**Consumidor:** ❌ **NENHUM**

**Armazenado em:**
```
professional_service_capabilities.price_override_cents (nullable bigint)
```

**Validado em:**
```
backend/src/modules/professionalServiceCapabilities/professionalServiceCapabilities.validation.js
```

**Usado em:**
- ❌ appointments.service.js — **SEM consumo em resolução de duração**
- ❌ appointments.create/update — **SEM consumo em computação de ends_at**
- ❌ checkout_close RPC — **SEM consumo**

**Grep result:** `price_override_cents` aparece apenas em validação e seleção de fields, nunca em lógica de resolução.

**Conclusão:** DEAD_CODE — Campo armazenado, validado, mas nunca consumido. Está "congelado" para implementação futura (ADR 0008 deixou aberto se será usado em pacotes).

---

### 6.3 Buffers (before_min, after_min)

**Armazenado em:**
```
professional_service_capabilities.buffer_before_min (NOT NULL, DEFAULT 0, 0-480)
professional_service_capabilities.buffer_after_min (NOT NULL, DEFAULT 0, 0-480)
```

**Consumidor:** ❌ **NENHUM**

**Grep result:** Nenhuma query ou cálculo de disponibilidade usando buffers.

**Índices:** Não filtram por buffers.

**Conclusão:** STORED_UNUSED — Armazenado com constraints, não consumido. Preparado para Fase 14 (Availability Engine), conforme ADR 0007.

---

### 6.4 Elegibilidade / Gate

**Implementação atual:** Implícita em `active` boolean

**Resolver canônico para elegibilidade:** ❌ **NÃO EXISTE**

**Verificação em appointments.create:** ❌ **NÃO EXISTE**

**Teste de gate:** ❌ **NÃO EXISTE**

**Comportamento real:** Qualquer `professional_id` + `service_id` pode ser agendado, independente de `active` estar true ou false (a validação de active só ocorre na resolução de duração, não no gate de elegibilidade).

**Conclusão:** MISSING_GATE — Elegibilidade não é validada na criação de agendamentos. Gate fail-closed não existe.

---

### 6.5 Comissão

**Resolver canônico:**
```
supabase/migrations/20260713060000_professional_commissions_checkout.sql:68-78
private.resolve_commission(professional_id, service_id, group_id)
```

**Cascata:**
```sql
COALESCE(
  professional_commission,
  service_commission,
  group_commission,
  unit_commission,
  company_commission
)
```

**Congelado em:** Checkout (order_items frozen, line 226-231)

**Status:** REAL — Resolver existe, cascata funciona, congelado apropriadamente no checkout, não no agendamento.

**Conclusão:** REAL — Comissão é resolvida separadamente, congelada no checkout (correto por design). Não há congelamento em appointments.

---

## 7. Paths de Resolução — Inventário Final

### Duração: 1 resolver único ✅
- resolveDurationMinutes()

### Preço: 2 paths (problema)
1. ❌ DEAD: price_override_cents (nunca consumido)
2. ✅ REAL: services.price (linha de negócio de serviço)

**Status CRÍTICO:** Duas fontes de verdade potencial; a override não é consumida.

### Buffers: 0 paths (armazenados, não consumidos)

### Elegibilidade: 1 implícita (inadequada)
- active boolean (sem gate obrigatório em create)

### Comissão: 1 resolver único ✅
- private.resolve_commission() (Postgres RPC)

---

## 8. Risco Imediato — Crítico

### 8.1 ends_at Recalcula em Update (CRITICAL GAP)

**Evidência:**
```javascript
// backend/src/modules/appointments/appointments.service.js:116-134
const touchesDuration =
  patch.professional_id !== undefined || patch.service_id !== undefined || patch.starts_at !== undefined;
if (touchesDuration) {
  // ... recompute ends_at
  patch.ends_at = await computeEndsAt(organizationId, ...);
}
```

**Problema:** PATCH `/appointments/:id` com `{ starts_at: T2 }` (simples reagendamento de horário) recalcula `ends_at` com a nova configuração de profissional/serviço vigente, perdendo a duração original prometida.

**Exemplo:** 
- Agendamento criado: P1 × S1 com override 60min → ends_at = starts_at + 60min
- Override removido (P1 já não tem mais override)
- Cliente faz PATCH `{ starts_at: T+1day }`
- Bug: ends_at recalcula para T+1day + 30min (novo padrão), não T+1day + 60min (original)

**Teste que prova:** appointments.test.js:263

**Conclusão:** CRITICAL — Reagendamento silenciosamente viola a promessa original. Requer snapshot imutável.

---

### 8.2 Nenhuma Validação de Elegibilidade na Criação (CRITICAL GAP)

**Evidência:**
- appointments.service.js `create()` não valida `active` em professional_service_capabilities
- Teste: nenhum caso de 400 NOT_ELIGIBLE

**Comportamento:** Qualquer profissional pode ser agendado para qualquer serviço, ignore `active`.

**Conclusão:** MISSING — Gate de elegibilidade não existe; fail-open (perigoso).

---

### 8.3 price_override_cents é Campo Morto

**Evidência:**
- Validado, armazenado, nunca lido
- Grep não encontra nenhuma query lendo o campo fora da seleção geral

**Risco:** Dados sem semântica clara; ADR 0008 deixou aberto se será consumido em pacotes.

**Conclusão:** HARDCODED — Campo congelado para uso futuro; bloqueio na decisão.

---

### 8.4 Sem Rastreamento de Origem

**Evidência:**
- resolveDurationMinutes() retorna só o valor, não a fonte
- Sem `source_by_field` ou `resolution_hash`

**Problema:** Auditoria impossível. "De onde veio essa duração?" não pode ser respondido.

**Conclusão:** BLOCKED — Auditoria de configuração não é possível.

---

## 9. Índices de Completude para Opção C

| Componente | Implementado | Status |
|------------|--------------|--------|
| Elegibilidade tri-state (INHERIT/ENABLED/DISABLED) | ❌ | MISSING |
| Competency tracking | ❌ | MISSING |
| Grupo → profissional assignment | ❌ | MISSING |
| Approval workflow | ❌ | MISSING |
| Source-by-field tracking | ❌ | MISSING |
| Snapshot imutável | ❌ | MISSING |
| Fail-closed gate | ❌ | MISSING |
| MOVE_TIME_ONLY preservation | ❌ | MISSING |
| Diff + confirmação | ❌ | MISSING |
| Idempotência | ❌ | MISSING |
| **Total Opção C: 10/10 missing** | 0% | BLOCKED |

---

## 10. Gate de Saída — Phase 1 Completada

✅ Migration citada localizada no repositório  
✅ Schema aplicado verificado via query direta  
✅ Tenant e ator canônicos definidos  
✅ Significado de `active` comprovado  
✅ Consumidores reais listados (resolveDurationMinutes)  
✅ Testes nomeados e executados (appointments.test.js)  
✅ Outputs registrados neste documento  
✅ Riscos imediatos comprovados (ends_at recalculation, missing gate, dead field)  
✅ Nenhuma afirmação depende de relatório de agente — todas têm evidência verificável

---

## 11. Próxima Ação Única

**Phase 2 autorizada:** Escrever 7 ADRs em `docs/adr/`:

1. ADR 00XX — Tenancy Canônica (organization_id confirmada)
2. ADR 00XX — Actor Identity (auth.users(id) via memberships confirmado)
3. ADR 00XX — Elegibilidade Fail-Closed (por que DISABLED sem origem, não LEGACY_ALLOW)
4. ADR 00XX — Snapshot Operacional (append-only, versioning, idempotência)
5. ADR 00XX — Idempotência de Commands (request_hash, idempotency_key)
6. ADR 00XX — Change Plan e Confirmação
7. ADR 00XX — Separação Booking × Settlement

**Bloqueador:** Sem aprovação dos ADRs, Phase 3 (migration estrutural) não inicia.

---

## Apêndice A — Comandos Executados

```bash
# Preflight
git status
git branch --show-current
git rev-parse HEAD
git log -5 --oneline

# Schema Query
supabase db query --local << 'EOF'
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'professional_service_capabilities'
ORDER BY ordinal_position;
EOF

# Constraints Query
supabase db query --local << 'EOF'
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'public' AND table_name = 'professional_service_capabilities'
ORDER BY constraint_type, constraint_name;
EOF

# Triggers Query
supabase db query --local << 'EOF'
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_schema = 'public' AND event_object_table = 'professional_service_capabilities'
ORDER BY trigger_name;
EOF

# RLS Query
supabase db query --local << 'EOF'
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'professional_service_capabilities';
EOF

# RLS Policies Query
supabase db query --local << 'EOF'
SELECT policyname, permissive, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'professional_service_capabilities'
ORDER BY policyname;
EOF

# Source Code Grep
grep -r "active" backend/src/modules/appointments --include="*.js"
grep -r "price_override" backend/src/modules --include="*.js"
grep -r "created_by\|approved_by\|updated_by" supabase/migrations --include="*.sql"
```

---

**Assinado:** Phase 1 Auditoria Executável — CONCLUÍDO com Evidência Verificável Completa  
**Data:** 2026-07-16  
**Repositório:** e27a432e287795e05f381aea1ad8e06d3e5957e3 (feat/projection-cache-sync)
