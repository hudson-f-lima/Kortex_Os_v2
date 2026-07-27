# 7. Sessões de Caixa e Distinção Void (Correção Operacional) vs. Refund (Cliente)

Date: 2026-07-15

## Status

Accepted

## Context

O ADR 0006 decidiu que correção de erro operacional (ex.: recepção digitou serviço/profissional errado) é estruturalmente um **void** (cancelamento pré-liquidação, sem circulação de dinheiro externo), distinto de um **refund** (reversão pós-venda, com dinheiro já saído do caixa).

Porém, a implementação prática de "void" revelou uma dependência: concorrentes diretos do nicho (AppBarber, Trinks, Avec, Nex) tratam isso não como uma operação isolada sobre a comanda, mas como **uma ação condicionada ao estado da sessão de caixa que contém a comanda**.

Seguindo a regra de pesquisar o mercado antes de decidir (`PLANEJAMENTO_EXECUCAO_UNIFICADO.md §1`):

## Pesquisa

### AppBarber (Brasil, segmento-alvo)
- Documentação: "Estou tentando reabrir uma comanda de um caixa fechado, como proceder?"
- **Padrão:** Uma comanda só pode ser alterada/reaberta enquanto o **caixa em que está contenha ainda está aberto**.
- **Fluxo de correção:** `Financeiro > Histórico de Caixa` → localizar caixa por usuário/data → **reabrir o caixa** (ação auditable própria) → agora a comanda fica editável → corrigir → fechar comanda de volta → fechar caixa de novo.
- **Implicação:** Reabrir comanda não é uma ação isolada; é uma ação subsequente a reabrir a sessão de caixa.

### Trinks (Brasil, segmento-alvo)
- Documentação: "Fechamento Mensal"
- **Padrão:** Ao invés de sessão por turno/dia, usa período mensal. "Fechamento Mensal" trava os valores a pagar por profissional; existe um botão explícito **"reabrir mês"** para ajustes retroativos.
- **Implicação:** A granularidade muda (mensal vs. diária), mas o princípio é idêntico — existe uma fronteira explícita, e reabrir é uma ação privilegiada e auditada.

### Avec, Nex (Brasil, POS local)
- Ambos seguem o padrão AppBarber — reabrir comanda é acesso condicional a sessão aberta.

### Zenoti (Global, benchmark citado em ADRs anteriores)
- Conceito similar: "Reopen a Closed Invoice" — faz referência à reabertura de um **período** (invoice batch/session).
- Confirmação lateral: Vagaro e Boulevard também estruturam fechamento de caixa/período como uma ação separada.

## Consequência: Uma Peça Faltante na Arquitetura

A migration baseline (`20260713034222_grant_baseline.sql` até `20260715120000_fase9_order_refund_reason.sql`) **nunca criou uma tabela de sessão de caixa**. `cash_entries` existe como lista append-only, sem fronteira de sessão:

```sql
-- Hoje: nenhuma coluna de session_id em cash_entries
CREATE TABLE cash_entries (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL,
  kind ('sale'|'income'|'expense'|'refund'),
  amount_cents int,
  created_at timestamp,
  -- ... SEM session_id
);
```

Sem essa tabela, não é possível:
1. Travar edição de comanda quando "caixa ainda aberto" (requer checar `session.closed_at IS NULL`)
2. Auditar quem abriu/fechou e quando
3. Calcular totais/validações por período (ex.: comissão acumulada no mês)
4. Implementar o padrão local que os concorrentes diretos usam

## Decision

**Uma nova fase (Fase 12) é alocada para materializar `cash_sessions`.**

### Escopo
- **Tabela nova:** `cash_sessions(id, organization_id, opened_by, opened_at, closed_by, closed_at, opening_balance_cents, closing_balance_cents, notes)`
- **Alteração em `cash_entries`:** adicionar coluna `session_id` (FK)
- **RPC nova `order_void`:** distinta de `order_refund`, precondição é `session.closed_at IS NULL`, efeito é reabrir + corrigir + refechará na mesma sessão
- **RPC de sessão:** `cash_session_open`, `cash_session_close`
- **Permissões:** apenas `owner`/`manager` (mesma allowlist que `membership_set`)
- **RLS:** por `organization_id`; policies que bloqueiam void se sessão já fechou
- **PWA:** novo fluxo "Reabertura de Comanda" dentro de Caixa/Histórico, visível só para `owner`/`manager`

### Sequência Ajustada
```
Fase 9:  Fundação Financeira [CONCLUÍDO]
Fase 10: N:N profissional×serviço + Hardening Agenda
Fase 11: Convite de Equipe + RLS self-view
Fase 12: Sessões de Caixa + Reabertura de Comanda (Void) ← NOVO
Fase 13: Comissões Escalonadas + Política de Absorção (era Fase 12)
Fase 14: No-show FSM + Sinal + Mensageria (era Fase 13)
Fase 15: Calendário Operacional & Availability Engine (era Fase 14)
Fase 16: Agenda Dinâmica Transacional (era Fase 15)
Fase 17: Waitlist (era Fase 16)
Fase 18: Portal do Cliente (era Fase 17)
Fase 19: Memberships (era Fase 18)
```

### Por que Fase 12, antes de Comissões?
1. **Fundação:** `cash_sessions` é o contêiner que toda comissão futura vai viver dentro (fronteira de acumulado, limite de mês)
2. **Simplicidade:** Fase 13 (Comissões Escalonadas) pode assumir que sessões já são um conceito estável, focando 100% em lógica de escalonamento
3. **Permissões:** Reabertura de sessão é uma ação auditável e privilegiada — conceito fora do escopo de Comissões
4. **Padrão local:** Alinha com AppBarber/Trinks (Brasil), que são o piso funcional

## Consequences

### Positivo
- **Alinhamento com padrão:** Replica o comportamento que recepcionistas já usam em AppBarber/Trinks (confortável)
- **Auditoria:** Quem abriu/fechou caixa, quando — rastreabilidade completa
- **Desbloqueador:** Fase 13 (Comissões) pode operar sobre fronteiras bem definidas; Fase 15+ (Agenda) pode usar sessão para cálculos de período
- **Sem mudança de lógica:** `order_refund` permanece igual — só `order_void` é novo, isolado

### Trade-off
- **Aumento de complexidade:** Uma tabela + RPC + RLS nova; renumeração de 7 fases subsequentes (10→12 viram 11→13, etc.)
- **Atraso de Comissões:** Fase 13 passa de Fase 12 (atrasamento de ~1-2 sprints típicas, dependendo do tamanho de Fase 10-11)
- **Reversão de comissão ainda adiada:** `order_void` também não reverterá comissão automaticamente — aguarda decisão de classificação do profissional (ADR 0005), mesma decisão que `order_refund` já tomou. Documenta-se que a estrutura está pronta, mas automação é Fase posterior.

## References
- [ADR 0006](0006-gorjeta-fora-da-comissao-e-motivo-do-estorno.md) — distinção void vs. refund
- [ADR 0005](0005-reversao-de-comissao-em-estornos.md) — por que comissão não reverte automaticamente hoje
- [AppBarber/AppBeleza Help](https://appbarber-appbeleza.zendesk.com/hc/pt-br/articles/360001571051) — fluxo de reabrir comanda de caixa fechado
- [Trinks Help](https://ajuda.trinks.com/fechamento-mensal) — fechamento mensal como fronteira
- [Avec Help](http://ajuda.avecbrasil.com.br/support/solutions/articles/17000092938-como-reabrir-um-caixa-) — reabrir caixa como ação prévia
- [Nex POS](https://nexposcorp.com) — padrão local convergente
- `docs/PLANEJAMENTO_EXECUCAO_UNIFICADO.md` — tabela de rastreabilidade e sequenciamento de fases
