---
title: "ADR 0025 - Onda 6: reabertura versionada de pedidos"
status: "ACCEPTED"
stage: "DECISION"
governance_ref: ["DEC-03", "DEC-11", "DEC-44", "DEC-53", "DEC-62"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-10"
---

# ADR 0025: Onda 6 — Reabertura versionada de pedidos

## Status

**Accepted (DEC-62, 2026-08-11).** Blueprint aprovado após Benchmark Gate e quatro rodadas de Red Team de desenho (GO). Isto não autoriza Etapa 8, SQL, UI, ativação ou promoção.

## Contexto

O KortexOS permite reabrir e alterar o pedido original sem apagar a versão fechada nem criar dupla verdade de caixa, comissão, estoque ou KortexFlow. O checkout atual permite fechamento por reception, mas o ledger não pode ser exposto para esse papel.

## Decisão

Usar pedido vivo versionado: fechamento sob checkout_reopen_enabled cria snapshot imutável e order_ledger_links; reabrir reverte efeitos e refechar cria revisão nova, com somente o delta de caixa. Pedido legado sem closure link não reabre e segue por order_refund mais nova venda.

Captured payment intent, payout, PSP settlement e emissão fiscal são locks terminais. Cash close requer Action Request e aprovação de owner. FOR UPDATE em orders, tentativas append-only e idempotência composta impedem corrida e duplicação.

Primitives privadas de ledger não recebem execução externa, inclusive de service_role. Desligar a flag impede novos links, mas order_refund sempre reverte pedido já versionado.

## Alternativas rejeitadas

- Mutar a venda fechada sem versões: perde auditoria e reversibilidade.
- Reconstruir ledger para pedido legado: inventaria origem financeira histórica.
- Tratar cash close como lock terminal: contradiz a política vigente.
- Expor helper privada a reception ou service_role: permitiria lançamento arbitrário.

## Consequências

- checkout_close e order_refund mudam somente atrás de flag e com regressão do caminho legado.
- Implementação fatiada, TDD e forward-only; cada migration terá pre-flight.
- A Etapa 8 exige aprovação do fatiamento e autorização posterior.
