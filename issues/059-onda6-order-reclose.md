---
title: "Onda 6 — order_reclose, pagamentos versionados e delta de caixa"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-62", "DEC-66", "DEC-68", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-13"
---

# 059 — order_reclose, pagamentos versionados e delta de caixa

Quinta fatia (Blueprint §6, item 5; contrato físico §4.5; invariante §3.7). `order_reclose` recebe o payload completo e validado da versão editada; só aceita pedido `reopened` do mesmo tenant/unidade com a tentativa ativa; revalida catálogo, profissional, quantidade, preço autorizado, pagamento e todas as somas; restaura/aplica estoque, consumo de benefício, comissão e gorjeta; cria pagamentos append-only para a nova revisão (`revision_number` incrementado); posta novo lançamento balanceado via `private.checkout_ledger_post`; grava `order_ledger_links.closure` e snapshot v2 no mesmo commit; acrescenta evento `reclosed`; muda status para `closed`; incrementa `orders.current_revision`. O Command calcula o delta contra v1 e grava no caixa só esse delta: `new_total_cents − v1_total_cents`. Diferença positiva cria `cash_entries.kind='sale'`; negativa cria `cash_entries.kind='refund'` mais `order_payment_adjustments` distribuídas pelas formas de pagamento de v1 com arredondamento determinístico e soma exata em centavos; delta zero não gera lançamento. Inclui contratos Express/Jest e a casca de UI no Design System — edição em memória, nenhuma tabela financeira recebe DML direto do cliente.

Aceite: ciclo reabrir→editar→refechar preserva histórico v1/v2 e os links de ledger reversíveis; delta de caixa e alocações de `order_payment_adjustments` batem em centavos exatos, com arredondamento determinístico; total maior gera `sale`, menor gera `refund` proporcional às formas de v1 (cada alocação não supera o saldo daquele pagamento após ajustes anteriores), delta igual a zero não gera lançamento; UI não grava nenhuma tabela financeira diretamente — só via `order_reclose`.

Type: AFK — contrato de delta/alocação já fechado no Blueprint (§3.7, §4.5); risco tratado pela fatia de hardening (061).
Blocked by: `issues/058-onda6-order-reopen-discard.md`.

## Implementação local — 2026-08-13

Entregue por migration forward-only `20260813140851_onda6_order_reclose.sql`: `order_reclose` com escopo tenant/unidade, tentativa ativa e idempotência; nova revisão append-only de pagamentos, snapshot v2, fechamento de ledger, evento `reclosed` e delta de caixa com rateio proporcional determinístico de refund. O backend expõe somente `POST /orders/:id/reclose`, protegido por papel, feature flag e `Idempotency-Key`; a PWA mostra a ação apenas sob `checkout_reopen_enabled` e persiste exclusivamente por esse Command. Não houve ativação de flag, promoção ou deploy.

Evidência em reset limpo: 1.036/1.036 pgTAP (63 arquivos, repetido após backend), 327/327 backend e 117/117 PWA; `supabase db lint --local` sem achados. Red Team de implementação local: `GO` para a fatia; a hardening transversal permanece na 061.

## Correção operacional de homologação — 2026-08-13

A casca da PWA passa a oferecer, sob a mesma flag escura, o fluxo completo de operador: solicitar e abrir uma reabertura de comanda fechada, refinalizar uma comanda reaberta ou descartar a reabertura. A tela usa somente primitives do Design System e Commands HTTP server-owned; não calcula nem grava fatos financeiros no navegador. Os testes da Comanda cobrem solicitação/abertura, descarte e o fluxo de refinalização existente.
