---
title: "Onda 6 — order_refund compatível com pedido versionado"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-62", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-12"
---

# 060 — order_refund compatível com pedido versionado

Sexta fatia (Blueprint §6, item 6; contrato físico §4.7). `order_refund` continua o fluxo de estorno por `customer_cancellation|customer_default`; só aceita `closed`; nunca reabre `refunded` nem substitui `order_reopen`. A escolha do caminho depende exclusivamente da existência de `order_ledger_links.kind='closure'` para a revisão corrente — nunca do valor atual da flag `checkout_reopen_enabled`. Pedido sem esse link (legado, ou criado com a flag desligada) mantém o comportamento legado exato. Pedido com o link: bloqueia pedido e revisão com `FOR UPDATE`, posta a reversão identificada pelo helper interno da fatia 056, persiste `order_ledger_links.reversal`, e só então muda o status, restaura estoque e cria o `cash_entries.refund` já existente. Assinatura pública, motivos e erros existentes não mudam.

Aceite: desligar a flag depois de um pedido já versionado não elimina a reversão de ledger daquele pedido no `order_refund` (comportamento depende do link, não da flag corrente); pedido legado (sem link) continua com contrato de `order_refund` idêntico ao atual, zero regressão em `rpc_checkout_close_deposit_reconciliation_test.sql`/testes de refund existentes; todo pedido versionado sempre reverte seu ledger ao ser reembolsado.

Type: AFK — regra de decisão pelo link (não pela flag) já fechada na 3ª rodada de Red Team de desenho (§8 do Blueprint).
Blocked by: `issues/059-onda6-order-reclose.md`.
