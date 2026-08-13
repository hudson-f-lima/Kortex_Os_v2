---
title: "ADR 0025 - Onda 6: reabertura versionada de pedidos"
status: "ACCEPTED"
stage: "DECISION"
governance_ref: ["DEC-03", "DEC-11", "DEC-44", "DEC-53", "DEC-62", "DEC-66"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-13"
---

# ADR 0025: Onda 6 — Reabertura versionada de pedidos

## Status

**Accepted (DEC-62, 2026-08-11); Etapa 8 local autorizada por DEC-66.** A implementação das fatias 055–061 fechou localmente em 2026-08-13 após Red Team de código. O hardening final tornou uniforme o `FOR UPDATE` da linha de `orders` para produtor de financial lock e comissão de venda. Isto não autoriza ativação, `staging`, `main` ou produção.

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
- A Etapa 8 foi executada localmente sob DEC-66; qualquer promoção continua a exigir DEC pós-Red-Team, Environment Guardian, homologação e Delivery Guardian.
