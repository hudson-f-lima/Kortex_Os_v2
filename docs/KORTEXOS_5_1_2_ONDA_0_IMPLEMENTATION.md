# Onda 0 — Implementação: Units (Unidades)

**Implementação original:** 2026-07-23 (commits locais de `staging` `b389a86`–`4adf8ea`)

**Correção e validação local:** 2026-07-24 (`codex/fix-onda0-local-gates`, pronta para PR em `staging`)

**Decisões gateadas:** DEC-31 (Blueprint aprovado), DEC-32 (Etapa 8 SQL autorizada)  
**Referência técnica:** [ADR 0016 — Arquitetura de Unidades](adr/0016-onda0-units-architecture.md) · [Blueprint Onda 0 (Draft)](KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_DRAFT.md) · [Red Team de desenho](KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_REDTEAM.md) · [Red Team de implementação](KORTEXOS_5_1_2_ONDA_0_IMPLEMENTATION_REDTEAM.md)

---

## Retificação de estado — 2026-07-24

A declaração anterior de “100% implementada” foi auditada e estava **CONTRADITÓRIA** com o repositório local: o teste focado de unidades falhava, profissionais criados após o backfill não recebiam vínculo em `professional_units`, as políticas dos fatos continuavam org-wide e o backend/sync não aplicava o escopo de unidade. O commit `4adf8ea` permanece como registro histórico; esta seção o substitui como verdade operacional.

A correção é forward-only e adiciona enforcement em três camadas:

1. migration corretiva para vínculo automático/auditado de profissionais, integridade `appointment × professional × unit`, ciclo de exclusão e RLS unit-aware;
2. contexto e filtros fail-closed no Express para agenda, pedidos, checkout, clientes e sync REST/SSE;
3. testes adversariais de cross-tenant, cross-unit, permissões profissionais e escrita não-default.

O estado corrigido está **REAL e verde no ambiente local**. A publicação deve seguir o PR desta branch para `staging`; isso não autoriza merge, deploy ou promoção para produção.

## WHAT — Esquema e Estrutura

### Tabelas novas

```
units
├── id (uuid PK)
├── organization_id (uuid FK)
├── name (text)
├── timezone (text, fixo em Onda 0 = 'America/Sao_Paulo')
├── active (boolean)
├── is_default (boolean, apenas 1 por organização)
├── created_by (uuid, pode ser null se criada por trigger)
├── created_at, updated_at (timestamps)

professional_units  -- N:N vínculo profissional ↔ unidade
├── organization_id, professional_id, unit_id (PK composta)
├── active (boolean)
├── created_by, updated_by (uuid)
├── created_at, updated_at (timestamps)

membership_permissions  -- allowlist de permissões per-membership
├── id (uuid PK)
├── organization_id, user_id (FK tenant-safe para memberships)
├── permission_code ('schedule:view_all' | 'clients:view_all')
├── granted_by, granted_at
├── revoked_by, revoked_at

unit_access_audit_events  -- append-only log
├── id (uuid PK, ordenado por created_at desc)
├── organization_id, unit_id (FK)
├── event_type (text: 'unit_created', ...)
├── actor_kind (enum: 'user' | 'system')
├── actor_user_id, target_user_id, professional_id (uuid nullable)
├── before_state, after_state (jsonb)
├── created_at (timestamp, imutável)
```

### Alterações a tabelas existentes

**6 fatos transacionais** ganham coluna `unit_id`:

| Tabela | Coluna | Tipo | Constraint | Default-fill |
|---|---|---|---|---|
| appointments | unit_id | uuid | FK (org_id, unit_id) | BEFORE INSERT trigger |
| orders | unit_id | uuid | FK (org_id, unit_id) + PK composta | BEFORE INSERT trigger |
| order_items | unit_id | uuid | FK via order_id+unit_id | Herda de order (FK) |
| payments | unit_id | uuid | FK via order_id+unit_id | Herda de order (FK) |
| inventory_movements | unit_id | uuid | FK (org_id, unit_id) | BEFORE INSERT trigger |
| cash_entries | unit_id | uuid | FK (org_id, unit_id) | BEFORE INSERT trigger |

**memberships** ganha escopo condicional:

| Campo | Aplicável a | Valor |
|---|---|---|
| unit_id | professional, reception | unit default da organização (BEFORE INSERT trigger) |
| unit_id | owner, admin, manager | NULL (org-wide, sem escopo de unit) |

---

## WHY — Decisões e Trade-offs

### Por que unidades?

1. **Realidade operacional:** Salão Esperança e salões similares operam múltiplas unidades (filiais, equipes)
2. **Isolamento de dados:** agendamentos, pedidos, caixa devem estar isolados por unidade (não apenas organização)
3. **Autorização:** profissionais podem ter acesso a algumas unidades, não todas (vínculo N:N via `professional_units`)
4. **Auditoria:** rastreabilidade de qual unidade executou cada transação (via `unit_access_audit_events`)

Veja [DEC-24 (Migration Map), DEC-26 (Pontos Cegos), DEC-27 (Reconsideração hierarquia)](#related-decisions) para a trajetória de decisão.

### Por que triggers de default-fill, não RPC rewriting?

**Alternativa:** reescrever `create_organization`, `checkout_close`, `inventory_adjust` para aceitar parâmetro `unit_id`.

**Rejeitada porque:**
- `checkout_close` tem 150+ linhas, coberta por pgTAP — risco alto de regressão financeira
- Duplicar lógica de default-fill em múltiplas RPCs = inconsistência, overhead
- Novos chamadores não precisam conhecer unit_id; banco resolve automaticamente

**Decisão:** BEFORE INSERT trigger em memberships, 6 fatos — se `unit_id` é null, preenche com unit padrão da organização.

**Benefício preservado:** as RPCs financeiras extensas não mudam. O fluxo de membership foi migrado deliberadamente para `membership_scope_set`, pois o comando legado não representava unidade nem auditoria.

### Por que timezone fixo?

Onda 0 assume timezone única global `America/Sao_Paulo` (realidade: Salão Esperança).

**Futuro:** se multinacional for necessário, timezone por organização é uma migration trivial (coluna DEFAULT muda, input de usuário é adicionado). Simplicidade agora > flexibilidade não-necessária.

### Por que o desenho original tinha duas migrations?

**Migration 1** (aditiva + backfill): cria schema, backfill de dados, triggers de default-fill.  
**Migration 2** (hardening): valida constraints, SET NOT NULL nos 6 fatos, imutability triggers.

**Rationale:** rollback mais seguro.
- Se M1 falha durante backfill, banco fica num estado válido (colunas nullable, sem constraints non-validated).
- M2 só roda se M1 passou.
- Reverter M2 deixa dados íntegros (apenas degrada para unit_id nullable); reverter M1 não é possível (use restore de backup).

Em 2026-07-24 foi necessária uma terceira migration forward-only para corrigir lacunas de segurança descobertas após a materialização original. Ela não altera o split aprovado M1/M2 nem reescreve migrations já registradas.

---

## HOW — Aplicação Local e Verificação

### Migrations criadas

```bash
supabase/migrations/20260723025006_onda0_units_schema_backfill.sql
  └─ 12 seções: schema, backfill (7 tabelas), default-fill triggers, AFTER INSERT trigger
     
supabase/migrations/20260723025439_onda0_units_hardening.sql
  └─ 3 seções: VALIDATE CONSTRAINT, SET NOT NULL, imutability triggers

supabase/migrations/20260724115722_onda0_units_security_forward_fix.sql
  └─ correção forward-only: lifecycle/auditoria, comandos canônicos, permissões, RLS unit-aware e gates de backend/sync
```

### Testes (pgTAP)

**Arquivo:** `supabase/tests/rls_units_test.sql` (99 testes)

| Categoria | O que valida |
|---|---|
| Grants e RLS | isolamento cross-tenant/cross-unit e ausência de acesso direto a superfícies sensíveis |
| Topologia | timezone fixo, exatamente uma unidade default, comandos serializados e escrita direta inválida bloqueada por trigger |
| Profissionais | vínculo automático, assign/revoke idempotentes e delete com cascade atribuído ao ator humano |
| Memberships e permissões | `membership_scope_set`, revogação sem ressurreição, lifecycle delete/inativação/unlink fail-closed e RPC legado sem `EXECUTE` |
| Fatos e sync | consistência de `unit_id`, imutabilidade e leitura unit-aware |

**Arquivo adicional:** `supabase/tests/rpc_create_organization_test.sql` (10 testes)

| Teste | O que valida |
|---|---|
| create_organization default unit | create_organization cria exatamente 1 unit padrão |
| default unit timezone | Unit padrão tem timezone 'America/Sao_Paulo' |
| unit_created audit event | Trigger AFTER INSERT registra system-attributed audit event |
| owner membership stays org-wide | Owner membership não tem unit_id (continua org-wide) |

**Cobertura específica da Onda 0: 109 testes, todos passando. Suíte pgTAP integral: 346/346.**

### Verificações cumpridas

✅ **db reset + migrations:** 15 migrations aplicadas com sucesso local

✅ **pgTAP:** 346/346 testes passando; 109 diretamente ligados à Onda 0

✅ **Advisors:** `No issues found`

✅ **Backend regression:** 255/255; lint com 0 erros e 1 warning preexistente

✅ **Frontend regression:** 106/106; build de produção passou; lint com 0 erros e 1 warning preexistente

✅ **Cross-tenant attacks:** Bloqueados por RLS (owner1 não vê org2)

✅ **Cross-unit attacks:** Bloqueados no banco e no Express (reception/professional isolados por unit)

### Bloqueadores para produção

- ✅ **Red Team de implementação local:** executado em 2026-07-24; ver relatório próprio
- ⛔ **Promoção remota:** não autorizada por esta correção. Exige fluxo `feature → staging → main`, gates do environment/delivery guardian e decisão explícita do Platform Owner

---

## NEXT — Ondas Subsequentes

### Onda 1: Payment Core
- Comissão sem cash sessions
- Métodos de pagamento sem dinheiro (cartão, PIX, etc.)
- Regressão (sem cash sessions/void nesta onda)
- Bloqueia: Onda 0 (pronto)

### Onda 2: KortexFlow Ledger/Wallet
- Double-entry ledger por unit
- Wallet (saldo profissional)
- Bloqueia: Onda 1

### Onda 3: Compensation/Sale Commission
- Split profissional multi-serviço (D02)
- Comissões escalonadas (era Fase 13)
- Cash sessions/Void (era Fase 12)
- Bloqueia: Onda 2

### Onda 4: Calendar Policy/Availability
- Calendário operacional por unit (Rodada 4)
- Motor de disponibilidade
- Bloqueia: Onda 1 (agenda precisa de unit_id confirmado)

### Onda 5: Recurring/Group/Waitlist
- Agendamentos recorrentes
- Group bookings
- Waitlist
- Bloqueia: Onda 4

### Onda 6: Versionamento de Comanda
- Snapshots de comanda (preço, comissão, gorjeta muda = nova versão)
- Bloqueia: Onda 3

---

## Integrity Checklist

| Item | Status | Evidência |
|---|---|---|
| Schema match Blueprint | ✅ | `20260723025006_onda0_units_schema_backfill.sql` §1–2 |
| Backfill completo | ✅ | `20260723025006_onda0_units_schema_backfill.sql` §8 (idempotente) |
| Default-fill triggers | ✅ | `20260723025006_onda0_units_schema_backfill.sql` §9–11 |
| AFTER INSERT org trigger | ✅ | `20260723025006_onda0_units_schema_backfill.sql` §7 |
| RLS policies | ✅ | Blueprint §6.1; tests layer 2 |
| Append-only audit | ✅ | `20260723025006_onda0_units_schema_backfill.sql` §4; no INSERT grant |
| Immutability | ✅ | `20260723025439_onda0_units_hardening.sql` §3; test 23514 |
| pgTAP coverage | ✅ | 109 testes específicos; suíte integral 346/346 |
| RPC migration | ✅ | APIs usam `membership_scope_set`; `membership_set` legado não é executável por `service_role` |
| Regression tests | ✅ | Backend 255/255; frontend 106/106; build passou |
| Cross-tenant isolation | ✅ | RLS test: owner1 ↔ org2 bloqueado |
| Cross-unit isolation | ✅ | RLS test: professional1 isolado por unit |

---

## Artefatos

| Arquivo | Propósito |
|---|---|
| [ADR 0016](adr/0016-onda0-units-architecture.md) | Decisões arquiteturais (contexto, alternativas, consequências) |
| [Blueprint Onda 0 Draft](KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_DRAFT.md) | Especificação técnica (schema, constraints, RLS, triggers) |
| [Blueprint Onda 0 Red Team Report](KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_REDTEAM.md) | Validação de design (gates, vulnerabilidades, evidências) |
| [Decision Log DEC-31/32](KORTEXOS_5_1_2_DECISION_LOG.md) | Registro de aprovações e autorizações |
| `supabase/migrations/20260723025006_*.sql` | Migration 1: schema + backfill + default-fill |
| `supabase/migrations/20260723025439_*.sql` | Migration 2: hardening + immutability |
| `supabase/migrations/20260724115722_*.sql` | Correção forward-only de segurança e contratos operacionais |
| `supabase/tests/rls_units_test.sql` | 99 testes pgTAP (RLS, topologia, lifecycle, permissões, auditoria, idempotência e cross-unit) |
| `supabase/tests/rpc_create_organization_test.sql` | 10 testes: create_organization + unit default |
| [Red Team de implementação](KORTEXOS_5_1_2_ONDA_0_IMPLEMENTATION_REDTEAM.md) | Evidência executável e veredito local de 2026-07-24 |
| [Handoff de continuidade](KORTEXOS_5_1_2_ONDA_0_CONTINUATION_HANDOFF.md) | Procedimento para outra inteligência retomar sem perder contexto ou violar gates |

---

## Referências de Decisão

- **DEC-24:** Migration Map v1.2 aprova Onda 0 como "units"
- **DEC-26:** Pontos Cegos Pré-Blueprint: hierarquia Empresa→Unidade resolvida
- **DEC-27:** Reconsideração da hierarquia (aprovado)
- **DEC-28:** Encerramento do MVP + aprovação do Truth Map
- **DEC-29:** Transição formal da Trilha A–E para Trilha F (Migration Map é fonte ativa)
- **DEC-31:** Blueprint Onda 0 aprovado pelo Platform Owner (QA Red Team GO)
- **DEC-32:** Autorização de Etapa 8 SQL (restrição: local only)

---

## Status Final

**Onda 0 está corrigida e validada localmente; 346/346 pgTAP, 255/255 backend e 106/106 frontend.**

Próxima etapa: concluir/publicar o PR da branch `codex/fix-onda0-local-gates` para `staging`, cumprir os gates de ambiente/entrega e só então iniciar o Blueprint da Onda 1 (Payment Core, Etapa 7). Produção continua fora do escopo desta branch.
