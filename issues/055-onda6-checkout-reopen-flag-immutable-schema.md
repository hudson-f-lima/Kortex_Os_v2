---
title: "Onda 6 — flag e schema imutável de reabertura de comanda"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-62", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-12"
---

# 055 — Flag e schema imutável de reabertura de comanda

Primeira fatia da Onda 6 (Blueprint §6, item 1; contrato físico §4.1-4.3). Cria só a fundação: `organizations.settings.checkout_reopen_enabled` (ausente/`false` por padrão), `orders.current_revision integer not null default 1 check (current_revision > 0)` com backfill dos pedidos existentes, `order_revisions` (snapshot `jsonb` imutável, `unique (organization_id, order_id, revision_number)`, trigger que rejeita `UPDATE`/`DELETE`), `order_reopen_attempts` + `order_reopen_attempt_events` (append-only, índice parcial único para no máximo uma tentativa `requested|approved|opened` ativa por pedido), `order_ledger_links` (`kind` `closure|reversal|restore`), `order_financial_locks` (`source_type` `cash_close|staff_payout|psp_settlement|fiscal_emission|captured_payment_intent`, `enforcement` `action_request_required|terminal`, `unique (organization_id, order_id, revision_number, source_type, source_id)`), `order_payment_adjustments`, e `payments.revision_number integer not null default 1 check (revision_number > 0)`. RLS conforme §5 (leitura `owner`/`admin`/`manager` com tenant/unidade validados; escrita reservada a Command futuro, nenhum grant direto a `authenticated`). Nenhuma RPC nova nesta fatia — só schema, RLS e grants.

Aceite: pgTAP cobre defaults, `unique (organization_id, order_id, revision_number)`, trigger de imutabilidade rejeitando `UPDATE`/`DELETE` em `order_revisions`, índice parcial de tentativa única por pedido, isolamento de tenant/unidade em todas as tabelas novas, e RLS negando escrita direta por `authenticated` fora de Command. Nenhuma rota ou comportamento de `checkout_close`/`order_refund` muda nesta fatia.

Type: AFK — Blueprint §4.1-4.3 já fecha coluna, tipo, constraint e RLS; nenhuma decisão de negócio aberta.
Blocked by: nenhuma — primeira fatia da Onda 6.
