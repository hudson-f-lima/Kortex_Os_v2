---
title: "Onda 6 — order_reopen e order_reopen_discard"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-62", "DEC-66", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-13"
---

# 058 — order_reopen e order_reopen_discard

Quarta fatia (Blueprint §6, item 4; contrato físico §4.4 e §4.6; invariantes §3.3, §3.5-3.6, §3.8-3.9). `order_reopen` deriva tenant/ator da membership autenticada, valida alçada (`owner`/`admin`/`manager` — nunca `reception`), flag, unidade e `status='closed'`; bloqueia o pedido com `FOR UPDATE`; exige `order_ledger_links.closure` da revisão corrente (recusa pedido legado); recusa lock terminal (`staff_payout`/`psp_settlement`/`fiscal_emission`/`captured_payment_intent`) sem bypass; quando existir `cash_close` pendente, exige evento `approved` de `owner` para aquela tentativa específica antes de abrir. Numa única transação: posta a reversão identificada do ledger via `order_ledger_links`, reverte efeitos de v1 (comissão, gorjeta, consumo de benefício, baixa de estoque, alocação de pagamento), acrescenta evento `opened`, muda status para `reopened`. Não escreve `cash_entries` — dinheiro só se move no delta do refechamento (fatia 059). `order_reopen_discard` só aceita `reopened`, restaura de maneira determinística os efeitos de v1 a partir do snapshot e da transação de reversão vinculada, posta a restauração no ledger, volta o pedido para `closed`, acrescenta evento `discarded`; é idempotente e atômico, não cria pagamento, venda, cancelamento ou estorno.

Aceite: reabertura de outro tenant/unidade, por `reception`, por payload manipulado, pedido legado, intent capturado, lock terminal ou replay divergente falha; `cash_close` sem evento `approved` de `owner` bloqueia a reabertura daquela tentativa; reabrir reverte exatamente comissão/gorjeta/estoque/benefício de v1 identificados por `order_ledger_links`, nunca ajusta campo isolado; descartar restaura v1 e a posição de ledger sem novo lançamento de caixa, estorno ou venda; duas tentativas simultâneas de reabrir o mesmo pedido resultam em uma única tentativa ativa (índice parcial + `FOR UPDATE`).

Type: AFK — contrato inteiro fechado pelas 4 rodadas de Red Team de desenho (achados 1-3 e 5 do §8 do Blueprint).
Blocked by: `issues/057-onda6-checkout-close-dark-launch.md`.

## Implementação — 2026-08-13

Implementados os Commands server-owned `order_reopen_request`, `order_reopen_approve`, `order_reopen` e `order_reopen_discard` na migration forward-only `20260813132439_onda6_order_reopen_discard.sql`. A solicitação cria a única tentativa ativa sob flag; aprovação é exclusiva de `owner` e só existe para lock `cash_close`; abrir exige o vínculo de fechamento v1, revalida flag/locks/intent capturado, restaura o estoque do snapshot e posta a reversão do journal por link. Descartar é o rollback atômico de uma tentativa aberta: consome novamente o estoque, posta a restauração do journal e fecha sem novo movimento de caixa.

O Red Team de implementação exercitou permissões, recepção, replay divergente, pedido legado, lock terminal, intent capturado, isolamento cross-tenant, aprovação de caixa e restauração determinística. As primitives privadas permanecem sem `EXECUTE` externo; os quatro Commands são exclusivos de `service_role` para o backend Express. Não houve nova decisão de produto, ativação de flag ou promoção de ambiente.
