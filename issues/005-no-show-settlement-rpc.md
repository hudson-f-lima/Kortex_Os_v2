## Parent Blueprint

`docs/waves/onda-1-payment-core/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1.md` (DEC-34), §3.2, §3.3, §7.1.

## What to build

RPC nova e pequena, **deliberadamente fora de `checkout_close`**, para liquidar a cobrança de no-show. Um no-show não tem serviço prestado, não tem `order` — mas precisa de um pedido sintético real (não uma trilha de comissão paralela) pra que a comissão apareça exatamente onde o colaborador já verifica hoje (`order_items.commission_cents`).

Gera: um `order` mínimo, um `order_item` (`service_id` = o serviço original do agendamento, comissão calculada a partir de `no_show_commission_type`/`no_show_commission_value` — nunca de `resolve_commission()` normal), e um `payment`. O `deposit_hold` correspondente vira `captured_no_show`, com a mesma trava CAS da fatia 004 (mutuamente exclusiva com a reconciliação de checkout).

## Acceptance criteria

- [x] RPC nova não chama `checkout_close` nem `resolve_commission()` — caminho isolado, conforme decisão do Blueprint
- [x] `order`/`order_item`/`payment` sintéticos gerados respeitam as mesmas constraints das tabelas reais (nenhum afrouxamento de `NOT NULL` em `payments`/`order_items`)
- [x] Comissão do `order_item` vem do snapshot já congelado em `deposit_holds` pela fatia 003 (`no_show_commission_type`/`value`), nunca da comissão de venda normal — confirmado inclusive contra um override em `professional_service_commissions`, que é ignorado
- [x] CAS (`WHERE status = 'active'`) idêntico ao da fatia 004 — se o hold já foi capturado pelo checkout, a liquidação de no-show aborta sem duplicar
- [x] Autorização: mesma regra que hoje já governa `create_appointment`/`update_appointment` (owner/admin/manager/reception, org-wide) — nenhuma superfície de autorização nova. Mesmo achado de DEC-35/fatia 003: o §7.1 descreve escopo por unidade para reception/professional, mas essa não é a regra real implementada hoje
- [x] pgTAP: comissão calculada corretamente; CAS bloqueia dupla captura simulando corrida com a fatia 004; autorização nega papel incorreto; visibilidade confirmada — comissão de no-show aparece na mesma consulta que já lista `order_items.commission_cents` do colaborador
- [x] Teste de integração backend: marcar agendamento com hold ativo como no-show gera pedido sintético completo e visível

## Blocked by

- Blocked by `issues/001-services-deposit-policy.md` (precisa de `no_show_commission_type`/`value` configurável)
- Blocked by `issues/003-deposit-holds-creation.md` (precisa de hold existente pra capturar)

## Seções do Blueprint endereçadas

- §3.2 (liquidação de no-show; por que pedido sintético e não trilha paralela)
- §3.3 (trava de concorrência — mesmo CAS da fatia 004)
- §7.1 (autorização herdada de `appointment`)
