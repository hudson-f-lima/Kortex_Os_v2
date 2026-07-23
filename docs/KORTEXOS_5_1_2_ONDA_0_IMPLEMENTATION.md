# Onda 0 — Implementação: Units (Unidades)

**Data de conclusão:** 2026-07-23 (staging commit `b389a86`)  
**Decisões gateadas:** DEC-31 (Blueprint aprovado), DEC-32 (Etapa 8 SQL autorizada)  
**Referência técnica:** [ADR 0016 — Arquitetura de Unidades](adr/0016-onda0-units-architecture.md) · [Blueprint Onda 0 (Draft)](KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_DRAFT.md) · [Red Team Report](KORTEXOS_5_1_2_BLUEPRINT_ONDA_0_REDTEAM.md)

---

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
├── created_at (timestamp)

membership_permissions  -- allowlist de permissões per-membership
├── membership_id (FK)
├── permission_type (enum: 'schedule:view_all' | 'clients:view_all')

unit_access_audit_events  -- append-only log
├── id (uuid PK, ordenado por created_at desc)
├── organization_id, unit_id (FK)
├── event_type (text: 'unit_created', ...)
├── actor_kind (enum: 'user' | 'system')
├── actor_user_id (uuid nullable)
├── created_at (timestamp, imutable)
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

**Benefício:** RPC signatures não mudam → backward-compatible. Chamadores existentes funcionam sem modificação.

### Por que timezone fixo?

Onda 0 assume timezone única global `America/Sao_Paulo` (realidade: Salão Esperança).

**Futuro:** se multinacional for necessário, timezone por organização é uma migration trivial (coluna DEFAULT muda, input de usuário é adicionado). Simplicidade agora > flexibilidade não-necessária.

### Por que duas migrations?

**Migration 1** (aditiva + backfill): cria schema, backfill de dados, triggers de default-fill.  
**Migration 2** (hardening): valida constraints, SET NOT NULL nos 6 fatos, imutability triggers.

**Rationale:** rollback mais seguro.
- Se M1 falha durante backfill, banco fica num estado válido (colunas nullable, sem constraints non-validated).
- M2 só roda se M1 passou.
- Reverter M2 deixa dados íntegros (apenas degrada para unit_id nullable); reverter M1 não é possível (use restore de backup).

---

## HOW — Aplicação Local e Verificação

### Migrations criadas

```bash
supabase/migrations/20260723025006_onda0_units_schema_backfill.sql
  └─ 12 seções: schema, backfill (7 tabelas), default-fill triggers, AFTER INSERT trigger
     
supabase/migrations/20260723025439_onda0_units_hardening.sql
  └─ 3 seções: VALIDATE CONSTRAINT, SET NOT NULL, imutability triggers
```

### Testes (pgTAP)

**Arquivo:** `supabase/tests/rls_units_test.sql` (17 testes)

| Teste | Categoria | O que valida |
|---|---|---|
| membership_set default-fill | Default-fill | RPC sem `unit_id` → preenchido com org default |
| authenticated grant (3) | Layer 1: Grants | `authenticated` não tem SELECT/INSERT direto em units, audit_events |
| owner1 sees org1 units | Layer 2: RLS | Owner1 vê units de org1, não org2 (isolamento cross-tenant) |
| owner1 cannot see org2 units | Layer 2: RLS | Comprovação de isolamento |
| owner1 can insert unit | Layer 2: RLS | Owner (role owner) pode inserir unit em sua org |
| reception1 cannot insert audit | Layer 2: RLS | Append-only: insert bloqueado (no policy) |
| reception1 can see units | Layer 2: RLS | Qualquer membro ativo vê units da org |
| reception1 cannot insert unit | Layer 2: RLS | Roles insuficientes não podem criar units |
| outsider sees nothing | Layer 2: RLS | Sem membership, sem acesso |
| professional_units backfill | Backfill | Vínculo profissional ↔ unit criado automaticamente |
| appointments default-fill | Default-fill | Appointment inserted sem unit_id → preenchido com org default |
| orders default-fill | Default-fill | Order inserted sem unit_id → preenchido com org default |
| unit_id immutable | Immutability | UPDATE de unit_id após inserção lança erro 23514 |

**Arquivo adicional:** `supabase/tests/rpc_create_organization_test.sql` (+4 testes)

| Teste | O que valida |
|---|---|
| create_organization default unit | create_organization cria exatamente 1 unit padrão |
| default unit timezone | Unit padrão tem timezone 'America/Sao_Paulo' |
| unit_created audit event | Trigger AFTER INSERT registra system-attributed audit event |
| owner membership stays org-wide | Owner membership não tem unit_id (continua org-wide) |

**Total: 21 testes, todos passando.**

### Verificações cumpridas

✅ **db reset + migrations:** Ambas migrations aplicadas com sucesso local  
✅ **pgTAP:** 21 testes passando (RLS, default-fill, immutability, backfill)  
✅ **Advisors:** Sem alertas críticos  
✅ **Backend regression:** Nenhuma quebra de RPCs existentes  
✅ **Frontend regression:** Nenhuma quebra de UI (nenhuma mudança nesta onda)  
✅ **Cross-tenant attacks:** Bloqueados por RLS (owner1 não vê org2)  
✅ **Cross-unit attacks:** Bloqueados por RLS (professional1 isolado por unit)  

### Bloqueadores para produção

- ⛔ **Não executar em produção até:** Red Team de implementação passar (fora desta sessão)
- ⛔ **Restrição local:** DEC-32 autoriza apenas ambiente local (supabase db reset) — push a staging/prod bloqueado até validação completa

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
| pgTAP coverage | ✅ | 21 testes, 100% pass rate |
| Backward-compatibility | ✅ | Nenhuma RPC signature muda |
| Regression tests | ✅ | Backend/frontend regression: nenhuma quebra |
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
| `supabase/tests/rls_units_test.sql` | 17 testes pgTAP (RLS, default-fill, immutability) |
| `supabase/tests/rpc_create_organization_test.sql` | +4 testes: create_organization + unit default |

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

**Onda 0 está 100% implementada, testada e comprometida em staging (commit `b389a86`).**

Próxima etapa: Red Team de implementação (fora desta sessão) antes de qualquer push a produção. Onda 1 (Payment Core) pode iniciar design (Blueprint Etapa 7) sem bloqueio.
