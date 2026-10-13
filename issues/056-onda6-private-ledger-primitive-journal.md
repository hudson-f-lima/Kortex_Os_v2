---
title: "Onda 6 — primitive de ledger privada e journal por conta"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-62", "DEC-66", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-13"
---

# 056 — Primitive de ledger privada e journal por conta

Segunda fatia (Blueprint §6, item 2; contrato físico §4.8; invariante §3.11-3.12). Extrai `private.kortex_ledger_post_entries(...)` do write-path comum, sem ampliar grant nenhum. `REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon, authenticated, service_role` explícito nela e em `private.checkout_ledger_post(...)` — obrigatório porque função Postgres nasce com `EXECUTE` para `PUBLIC` e `private` concede `USAGE` a `authenticated`. `private.checkout_ledger_post(...)` aceita só o contexto interno dos três Commands que existirão nas fatias seguintes (`checkout_close`/`order_reclose`/`order_refund`), revalida o ator segundo a alçada do Command chamador. Chave filha determinística `sha256(parent_key + order_id + revision + operation)`, prefixada, menor que 200 caracteres, nunca reutiliza a chave/hash do Command pai. Journal por conta conforme regra 11 do §3: débito `cash` pela soma dos pagamentos; crédito `revenue_service`/`revenue_product` líquidos do desconto rateado (mesmo rateio de maior resto de `checkout_close`); crédito `tip_liability` pela gorjeta (não reduz receita nem comissão); débito `commission_expense`/crédito `staff_current_account` por profissional. `public.kortex_ledger_post` (RPC administrativa existente) não ganha grant para `reception`.

Aceite: pgTAP prova que `authenticated` e `service_role` não conseguem chamar as duas primitives privadas diretamente; a chave filha é determinística e nunca colide com a chave pai nem entre suboperações; o journal fecha (débitos = créditos) para um caso com desconto rateado, gorjeta e comissão de múltiplos profissionais; replay com mesma chave/payload retorna a mesma resposta, payload divergente falha.

Type: AFK — contrato de grants/journal já fechado pela 3ª e 4ª rodadas de Red Team de desenho (§8 do Blueprint).
Blocked by: `issues/055-onda6-checkout-reopen-flag-immutable-schema.md`.

## Implementacao local e evidencia

Implementada localmente em 2026-08-13 pela migration forward-only `20260813121110_onda6_private_ledger_journal.sql`, sem ativar flag, rota ou alterar `checkout_close`/`order_refund`. A RPC administrativa conserva a alçada de `owner`/`admin`/`manager`; o write-path comum agora está em `private.kortex_ledger_post_entries(...)` e as duas primitives privadas têm `EXECUTE` explicitamente revogado de `PUBLIC`, `anon`, `authenticated` e `service_role`.

O journal de closure deriva somente dos fatos persistidos da comanda e recalcula o maior resto por `frac DESC, id`; gorjeta permanece em `tip_liability` e comissão em contas correntes por profissional. O contexto interno de `order_refund` inverte a closure vinculada, com chave filha distinta. O Red Team de implementação encontrou e corrigiu, antes do fechamento, a ausência de escopo de unidade para `reception`; gestão continua organizacional e `reception` só alcança a unidade da membership. Evidência local: novo pgTAP com 27 casos (grants e chamadas diretas negadas, isolamento cross-unit, journal misto com desconto/gorjeta/dois profissionais, replay divergente e inversão de refund), regressão do ledger administrativo 33/33 e lint SQL sem achados. O gate final, após `supabase db reset --local`, confirmou 965/965 pgTAP (60 arquivos), 325/325 backend e lint limpo. Veredito local: `GO` para a fatia 057 autorizada, ainda `NO-GO` para ativação, `staging`, `main` e produção sob DEC-66.
