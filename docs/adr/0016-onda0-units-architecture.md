# ADR 0016: Onda 0 — Arquitetura de Unidades (Units)

## Status
Accepted (DEC-31, 2026-07-22)

## Date
2026-07-22

## Context

KortexOS suporta multi-tenant a nível de organização desde o MVP (Fases 1–11). A Onda 0 (conforme Migration Map v1.2, DEC-24) introduz um **segundo nível de tenant hierárquico**: unidades dentro de uma organização.

### Motivações

1. **Realidade operacional:** salões de beleza reais (ex. Salão Esperança) operam múltiplas unidades (filiais, equipes separadas por local/horário)
2. **Isolamento de dados:** agendamentos, pedidos, caixa devem ser associados a unidade (não apenas organização)
3. **Autorização granular:** profissionais podem ter acesso a algumas unidades, não todas
4. **Auditoria:** rastreabilidade de qual unidade executou cada transação

### Constraints

- **Backward-compatibility:** codebase existente não deve quebrar. RPCs como `create_organization`, `checkout_close`, `inventory_adjust` não podem mudar assinatura
- **Timezone:** fixo por unidade (não por usuário). Onda 0 assume timezone única global `America/Sao_Paulo` (simplificação; flexibilidade vem em onda futura se necessário)
- **Auditoria obrigatória:** toda mudança de unit_id deve ser auditada (append-only, sem deleção)
- **RLS:** deve-se bloquear acesso cross-unit, cross-tenant no nível de banco de dados
- **Verificabilidade:** schema, triggers, testes devem ser provados por pgTAP antes de produção

## Decision

Implementar unidades como **tenant secundário estruturado em duas migrações**:

### Estrutura de dados

```sql
units
├── id (PK)
├── organization_id (FK)
├── name
├── timezone (fixo em Onda 0)
├── active
├── is_default (cada org tem exatamente 1)
├── created_by, timestamps

professional_units (N:N vinculo)
├── organization_id, professional_id, unit_id (PK composta)

membership_permissions (allowlist)
├── membership_id, permission_type (schedule:view_all, clients:view_all)

unit_access_audit_events (append-only)
├── organization_id, unit_id
├── event_type (unit_created, ...)
├── actor_kind (user, system), actor_user_id
├── timestamps (immutable)
```

### 6 fatos transacionais ganham unit_id

`appointments`, `orders`, `order_items`, `payments`, `inventory_movements`, `cash_entries` recebem:
- `unit_id uuid nullable` (Migration 1)
- Foreign key composta `(organization_id, unit_id) → units`
- Default-fill via trigger `BEFORE INSERT` para null → org default (nunca reescrita de RPC)
- `unit_id SET NOT NULL` (Migration 2 — hardening)
- Immutability trigger (UPDATE bloqueado após inserção)

### Decisão crítica: triggers vs RPC rewriting

**Alternativa considerada:** reescrever `create_organization`, `checkout_close`, `inventory_adjust` para aceitar `unit_id` como parâmetro.

**Rejeitada porque:**
- `checkout_close` é uma função de 150+ linhas coberta por pgTAP — risco alto de regressão financeira
- Replicar lógica de default-fill em múltiplas RPCs é propenso a inconsistência
- Novos chamadores não precisam conhecer unit_id; o banco resolve automaticamente

**Decisão:** default-fill via `BEFORE INSERT` trigger + `AFTER INSERT` trigger em organizations para criar unit padrão. Estratégia:
- Trigger `BEFORE INSERT` em memberships, appointments, orders, etc. — se `unit_id` é null, preenche com unit padrão da organização
- Trigger `AFTER INSERT` em organizations — cria automaticamente uma unit padrão com timezone fixo
- RPC `membership_set` continua sem parâmetro `unit_id` — trigger faz o resto
- RPCs de fato (agenda, checkout, estoque) continuam inalteradas — trigger preenche antes da inserção

### Backfill

Migração 1 faz backfill inline (não script separado):
- Insere unit padrão para cada organização existente
- Backfill de `professional_units` (vínculo profissional ↔ unidade)
- Backfill de `memberships` (professional/reception roles → unit padrão; owner/admin/manager → unit null, org-wide)
- Backfill de 6 fatos (tudo aponta para unit padrão da organização)

Idempotente: roda OK mesmo se executada múltiplas vezes (usa `INSERT ... ON CONFLICT`).

### Duas migrações: aditiva + hardening

**Migration 1** (`20260723025006_onda0_units_schema_backfill.sql`):
- CREATE TABLE, FK, RLS policies (select)
- Backfill de dados existentes
- Triggers de default-fill
- NOT VALID constraint (fará validação na M2)

**Migration 2** (`20260723025439_onda0_units_hardening.sql`):
- VALIDATE CONSTRAINT (confirma que NOT VALID de M1 não violou dados)
- SET NOT NULL nos 6 fatos
- Imutability triggers (UPDATE bloqueado)

**Rationale:** rollback mais seguro. Se M1 cai em produção durante backfill, banco fica num estado valido (colunas nullable, sem constraints não-validadas). M2 só roda se M1 passou, e é idempotente.

### RLS

Nenhuma nova política violaria as existentes:
- Queries de `units` filtram por `organization_id` (tenant primário)
- RLS de 6 fatos filtra por organization_id já — adicionar `AND unit_id = ...` é incremental
- Audit events: append-only, sem INSERT grant a anon/authenticated

### Auditoria

Tabela `unit_access_audit_events` (append-only):
- Ninguém pode deletar/atualizar
- INSERT apenas via função SECURITY DEFINER (triggers a dispõem)
- Rastreia: unit_created (via trigger AFTER INSERT em organizations)
- Extensível: futuros eventos (unit_activated, unit_timezone_changed, etc.) seguem mesmo padrão

## Alternatives Considered

### A: Reescrever todas as RPCs para aceitar unit_id como parâmetro
- **Pros:** Explícito; chamador escolhe a unit
- **Cons:** 150+ linhas de `checkout_close` + testes regressivos = risco alto; novos RPCs precisam replicar lógica; inconsistência entre RPCs que implementam default-fill e as que não implementam
- **Rejected:** Risco de regressão financeira, overhead de manutenção

### B: Usar coluna global `user_session.unit_id` (context-based)
- **Pros:** RPCs não mudam; default automático
- **Cons:** Falha se usuário tem acesso a múltiplas units (qual fica no contexto?); impossível de auditoria (qual unit executou se a query não a menciona?); quebra se usuário muda de unit durante transação
- **Rejected:** Ambigüidade de dados; impossível de auditoria

### C: Permitir unit_id nullable (soft-multitenant)
- **Pros:** Menos dados para backfill
- **Cons:** Consultas que esquecem de filtrar by unit vazam dados cross-unit; impossível garantir isolamento sem SET NOT NULL
- **Rejected:** NOT NULL é essencial para RLS fail-closed; soft-multitenant é falha de segurança

### D: Timezone por organização (input do usuário)
- **Pros:** Suporta multinacional
- **Cons:** Onda 0 é sobre units, não timezone. Timezone multinacional é escopo futuro (Onda 7 ou além). Simplicidade agora > flexibilidade que não precisa existir.
- **Rejected:** Scope creep; realidade atual = Salão Esperança (1 timezone). Regredir de timezone fixo para entrada do usuário é trivial quando necessário.

## Consequences

### Aplicação

- **Imediato:** 21 testes pgTAP validam schema, RLS, triggers, imutabilidade
- **Deployment:** M1 + M2 devem ser aplicadas juntas (M2 depende de M1 ter backfill completo)
- **Rollback:** reverter M2 deixa banco com unit_id nullable (degradado, mas funcional); reverter M1 não é possível (backfill irreversível — use restore de backup)

### Código

- **RPC signatures:** nenhuma muda (backward-compatible)
- **Frontend:** nenhuma UI nova para Onda 0 (timezone é fixo, não há seletor de unit nesta onda)
- **Backend:** nenhum endpoint novo; RPC de organização auto-cria unit padrão

### Futuro

- **Onda 1+:** RPCs podem aceitar `unit_id` como parâmetro *opcional* (default = org default)
- **UI:** quando necessário seletor de unit, RLS policy verifica `professional_units` (qual units o profissional tem acesso)
- **Timezone:** quando necessário timezone por unit, alterar coluna de NOT NULL DEFAULT → NOT NULL sem DEFAULT e aceitar input de usuário (migration adicional)

## Related Decisions

- **DEC-24:** Migration Map v1.2 define Onda 0 como "units"
- **DEC-26:** Pontos Cegos Pré-Blueprint: hierarquia Empresa→Unidade resolvida
- **DEC-31:** Blueprint Onda 0 aprovado (QA Red Team GO; nenhuma vulnerabilidade)
- **DEC-32:** Autorização de Etapa 8 (SQL) — restrição: local only, produção após Red Team implementação
- **ADR 0002, 0012:** Idempotência e concorrência otimista em appointments (Onda 0 herda essas garantias)

## Verification

✅ pgTAP: 17 testes RLS + 4 novos em create_organization (21 total, todos passando)  
✅ db reset + ambas migrations aplicadas localmente  
✅ Advisors rodados (sem alertas críticos)  
✅ Backend regression tests: nenhuma quebra  
✅ Frontend regression tests: nenhuma quebra  
✅ Cross-tenant/cross-unit attacks: bloqueados por RLS  

Próximas verificações (fora desta sessão): Red Team de implementação antes de promoção a staging.
