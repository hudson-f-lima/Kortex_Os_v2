---
title: "Onda 6 — checkout_close sob flag, dark launch"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-62", "DEC-66", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-13"
---

# 057 — checkout_close sob flag, dark launch

Terceira fatia (Blueprint §6, item 3; contrato físico §4.8, segunda metade). `checkout_close` mantém assinatura e validações atuais; ganha guard inline pela flag `checkout_reopen_enabled`. Com `false`/ausente: comportamento bit a bit idêntico ao atual, pedido nasce implicitamente legado (sem `order_ledger_links`, portanto inelegível a reabertura). Com `true`: depois de validar pagamentos, rateios de desconto/gorjeta e comissões já existentes, deriva o journal da fatia 056, chama `private.checkout_ledger_post`, grava `order_ledger_links.closure` e o snapshot v1 no mesmo commit. Falha do journal reverte integralmente o checkout — itens, pagamentos, caixa e estoque.

Aceite: pre-flight e pgTAP provam os dois ramos da flag byte a byte contra o comportamento atual; checkout por `reception` continua funcionando com a flag ligada, sem grant direto à primitive privada; pedido fechado com flag ligada recebe `order_ledger_links.closure` e snapshot v1 no mesmo commit; falha simulada no journal não deixa checkout parcialmente aplicado (itens/pagamentos/caixa/estoque revertem juntos); `rpc_checkout_close_test.sql` existente passa sem regressão.

Type: AFK — os dois ramos já estão inteiramente especificados no Blueprint; nenhuma decisão de negócio em aberto.
Blocked by: `issues/056-onda6-private-ledger-primitive-journal.md`.

## Implementação local e evidência

Implementada localmente em 2026-08-13 pela migration forward-only `20260813125212_onda6_checkout_close_dark_launch.sql`. A função pública preserva assinatura, grants e resposta do checkout anterior; o corpo legado foi encapsulado em helper privado e continua sendo o único caminho quando `organizations.settings.checkout_reopen_enabled` está ausente ou é `false`. Somente o boolean JSON literal `true` alcança o bloco novo. Esse bloco chama a primitive privada com chave filha, persiste o journal balanceado, snapshot canônico v1 (pedido, itens, pagamentos, efeitos de estoque/caixa e referência do ledger) e o único `order_ledger_links.kind='closure'` na mesma transação.

O Red Team de implementação reatacou replay, escopo de `reception`, grants da primitive, conciliação e rollback. O achado preventivo foi coberto antes do fechamento: um checkout legado já concluído nunca ganha link/snapshot ao ser repetido depois de a flag ser ligada. A falha simulada de `private.checkout_ledger_post` aborta o statement e reverte pedido, pagamentos, caixa, movimentos e estoque juntos. Evidência reproduzida em reset limpo: pgTAP novo 25/25; suíte completa 990/990 (61 arquivos), repetida após os testes de backend; backend 325/325; PWA 116/116; `supabase db lint --local --fail-on error` sem achados. Veredito local: `GO` para a fatia 058 autorizada; a flag continua sem ativação e DEC-66 continua `NO-GO` para `staging`, `main` e produção.
