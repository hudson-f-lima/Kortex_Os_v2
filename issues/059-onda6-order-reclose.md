---
title: "Onda 6 — order_reclose, pagamentos versionados e delta de caixa"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-62", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-12"
---

# 059 — order_reclose, pagamentos versionados e delta de caixa

Quinta fatia (Blueprint §6, item 5; contrato físico §4.5; invariante §3.7). `order_reclose` recebe o payload completo e validado da versão editada; só aceita pedido `reopened` do mesmo tenant/unidade com a tentativa ativa; revalida catálogo, profissional, quantidade, preço autorizado, pagamento e todas as somas; restaura/aplica estoque, consumo de benefício, comissão e gorjeta; cria pagamentos append-only para a nova revisão (`revision_number` incrementado); posta novo lançamento balanceado via `private.checkout_ledger_post`; grava `order_ledger_links.closure` e snapshot v2 no mesmo commit; acrescenta evento `reclosed`; muda status para `closed`; incrementa `orders.current_revision`. O Command calcula o delta contra v1 e grava no caixa só esse delta: `new_total_cents − v1_total_cents`. Diferença positiva cria `cash_entries.kind='sale'`; negativa cria `cash_entries.kind='refund'` mais `order_payment_adjustments` distribuídas pelas formas de pagamento de v1 com arredondamento determinístico e soma exata em centavos; delta zero não gera lançamento. Inclui contratos Express/Jest e a casca de UI no Design System — edição em memória, nenhuma tabela financeira recebe DML direto do cliente.

Aceite: ciclo reabrir→editar→refechar preserva histórico v1/v2 e os links de ledger reversíveis; delta de caixa e alocações de `order_payment_adjustments` batem em centavos exatos, com arredondamento determinístico; total maior gera `sale`, menor gera `refund` proporcional às formas de v1 (cada alocação não supera o saldo daquele pagamento após ajustes anteriores), delta igual a zero não gera lançamento; UI não grava nenhuma tabela financeira diretamente — só via `order_reclose`.

Type: AFK — contrato de delta/alocação já fechado no Blueprint (§3.7, §4.5); risco tratado pela fatia de hardening (061).
Blocked by: `issues/058-onda6-order-reopen-discard.md`.
