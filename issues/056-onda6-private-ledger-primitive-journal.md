---
title: "Onda 6 — primitive de ledger privada e journal por conta"
status: "DRAFT"
stage: "ISSUE"
governance_ref: ["DEC-62", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-12"
---

# 056 — Primitive de ledger privada e journal por conta

Segunda fatia (Blueprint §6, item 2; contrato físico §4.8; invariante §3.11-3.12). Extrai `private.kortex_ledger_post_entries(...)` do write-path comum, sem ampliar grant nenhum. `REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon, authenticated, service_role` explícito nela e em `private.checkout_ledger_post(...)` — obrigatório porque função Postgres nasce com `EXECUTE` para `PUBLIC` e `private` concede `USAGE` a `authenticated`. `private.checkout_ledger_post(...)` aceita só o contexto interno dos três Commands que existirão nas fatias seguintes (`checkout_close`/`order_reclose`/`order_refund`), revalida o ator segundo a alçada do Command chamador. Chave filha determinística `sha256(parent_key + order_id + revision + operation)`, prefixada, menor que 200 caracteres, nunca reutiliza a chave/hash do Command pai. Journal por conta conforme regra 11 do §3: débito `cash` pela soma dos pagamentos; crédito `revenue_service`/`revenue_product` líquidos do desconto rateado (mesmo rateio de maior resto de `checkout_close`); crédito `tip_liability` pela gorjeta (não reduz receita nem comissão); débito `commission_expense`/crédito `staff_current_account` por profissional. `public.kortex_ledger_post` (RPC administrativa existente) não ganha grant para `reception`.

Aceite: pgTAP prova que `authenticated` e `service_role` não conseguem chamar as duas primitives privadas diretamente; a chave filha é determinística e nunca colide com a chave pai nem entre suboperações; o journal fecha (débitos = créditos) para um caso com desconto rateado, gorjeta e comissão de múltiplos profissionais; replay com mesma chave/payload retorna a mesma resposta, payload divergente falha.

Type: AFK — contrato de grants/journal já fechado pela 3ª e 4ª rodadas de Red Team de desenho (§8 do Blueprint).
Blocked by: `issues/055-onda6-checkout-reopen-flag-immutable-schema.md`.
