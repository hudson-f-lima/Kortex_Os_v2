---
title: "Onda 6 — checkout_close sob flag, dark launch"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-62", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-12"
---

# 057 — checkout_close sob flag, dark launch

Terceira fatia (Blueprint §6, item 3; contrato físico §4.8, segunda metade). `checkout_close` mantém assinatura e validações atuais; ganha guard inline pela flag `checkout_reopen_enabled`. Com `false`/ausente: comportamento bit a bit idêntico ao atual, pedido nasce implicitamente legado (sem `order_ledger_links`, portanto inelegível a reabertura). Com `true`: depois de validar pagamentos, rateios de desconto/gorjeta e comissões já existentes, deriva o journal da fatia 056, chama `private.checkout_ledger_post`, grava `order_ledger_links.closure` e o snapshot v1 no mesmo commit. Falha do journal reverte integralmente o checkout — itens, pagamentos, caixa e estoque.

Aceite: pre-flight e pgTAP provam os dois ramos da flag byte a byte contra o comportamento atual; checkout por `reception` continua funcionando com a flag ligada, sem grant direto à primitive privada; pedido fechado com flag ligada recebe `order_ledger_links.closure` e snapshot v1 no mesmo commit; falha simulada no journal não deixa checkout parcialmente aplicado (itens/pagamentos/caixa/estoque revertem juntos); `rpc_checkout_close_test.sql` existente passa sem regressão.

Type: AFK — os dois ramos já estão inteiramente especificados no Blueprint; nenhuma decisão de negócio em aberto.
Blocked by: `issues/056-onda6-private-ledger-primitive-journal.md`.
