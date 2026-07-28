## Parent Blueprint

`docs/waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md` (APROVADO, DEC-46), emendado por **DEC-48** (Decision Log SEÇÃO 14) e pela seção "Emenda (DEC-47/DEC-48)" da [ADR 0020](../docs/architecture/adr/0020-onda3-compensation-staff-levels-sale-commission.md).

## What to build

Fecha o achado P1 de uma auditoria pós-merge (DEC-47): hoje é estruturalmente impossível saber, pelo banco, que pacote foi vendido em qual pedido — `order_items.kind` só aceita `service`/`product`, e `checkout_close` dissolve cada pacote em N linhas de serviço com preço rateado, descartando o `package_id` (`supabase/migrations/20260726190000_onda1_checkout_close_deposit_appointment_guard.sql:193,276-284`). Isso deixa `commission_sale_record_create` (fatia 020) aceitando qualquer pacote da organização contra qualquer pedido `closed`, sem provar que aquele pacote foi vendido naquele pedido, e calculando a comissão sobre `packages.price_cents` (preço de tabela) em vez do valor efetivamente cobrado.

**Escopo estritamente autorizado por DEC-48, nada além:** coluna `order_items.package_id` nullable + `checkout_close` redefinida só para gravar essa coluna no INSERT do ramo de pacote que já existe hoje. Nenhuma mudança em preço, rateio por maior-resto, totais ou reconciliação de depósito. `create_appointment` e `resolve_commission()` não são tocados.

## Acceptance criteria

- [x] Migration aditiva adiciona `order_items.package_id` nullable + FK composta `(organization_id, package_id) references packages(organization_id, id) on delete restrict`, mesmo padrão de `order_items_professional_fk`. `supabase/migrations/20260728040000_onda3_order_items_package_linkage.sql`
- [x] Nenhum novo valor em `order_items.kind` — evita reabrir o `CHECK` e as constraints que dependem dele
- [x] Pre-flight check (DEC-44): confere `to_regclass('public.order_items')`/`public.packages` e que a coluna ainda não existe
- [x] `checkout_close` redefinida numa migration nova (mesma acima, nunca editando a já aplicada) a partir da definição vigente (`20260726190000...`); único diff: os 3 INSERTs em `order_items` ganham a coluna `package_id` (`v_ref_id` no ramo `package`, `null` nos ramos `product`/`service` avulso)
- [x] Confirmado por leitura + teste de regressão: as 30 assertions pré-existentes de `rpc_checkout_close_test.sql` (preço, rateio por maior-resto, totais, guarda de reconciliação de depósito) continuam passando inalteradas — nenhuma linha de cálculo tocada
- [x] `commission_sale_record_create` redefinida: valida que o pedido contém `order_items` daquele `package_id` antes de gravar comissão — pacote não vendido naquele pedido é rejeitado (`P0002`). `supabase/migrations/20260728050000_onda3_commission_sale_record_package_validation.sql`
- [x] `commission_sale_record_create` calcula `commission_cents` percentual sobre `sum(order_items.total_cents)` daquele `(order_id, package_id)` — valor efetivamente cobrado — em vez de `packages.price_cents`
- [x] pgTAP: checkout com pacote grava `package_id` em cada linha de serviço expandida; checkout com serviço avulso grava `package_id = null`. `supabase/tests/rpc_checkout_close_test.sql` (+2 assertions, plan 32→34)
- [x] pgTAP: `commission_sale_record_create` rejeita `package_id` que não está em nenhum `order_items` daquele `order_id`
- [x] pgTAP: `commission_sale_record_create` calcula a comissão sobre o valor cobrado — cenário com desconto (`8000` cobrado vs. `10000` de tabela) prova a divergência. `supabase/tests/rpc_commission_sale_record_create_test.sql` (+2 assertions, plan 27→29) — suíte completa 651/651 (`supabase test db`, evidência bruta: `Result: PASS`), sem regressão nos 36 arquivos pré-existentes. Backend `npm test` 301/301 e PWA `npm test` 108/108 confirmados pessoalmente na mesma sessão

## Blocked by

None — depende só da fatia 020 (`commission_sale_records`/`commission_sale_record_create`) já mesclada.

## Seções do Blueprint endereçadas

- Emenda DEC-48 à seção "Exclusão deliberada de escopo — fundação sem ativação em `checkout_close`/`create_appointment`" (§1) e à Decisão 2 (§3.2, que trata só da cascata de preço/tempo — não desta emenda)
- Achado P1 de DEC-47 (Decision Log SEÇÃO 13)
