## Parent Blueprint

`docs/waves/onda-1-payment-core/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1.md` (DEC-34), §2, §3.4, §3.5, §4.

## What to build

Schema de `payment_intents` e `psp_webhook_events`, mais o outbox mínimo de ingestão de webhook — específico deste domínio, sem generalizar para outros casos de uso (decisão explícita do Blueprint, §2.2). Nenhuma integração real com PSP nesta fatia: testável com evento sintético (payload fabricado no teste, não uma chamada real a Mercado Pago/Pagar.me/etc.).

`payment_intents`: satélite do fluxo de PSP, `order_id` nullable, `purpose` (`checkout`/`deposit`), `provider`/`provider_reference` agnósticos de fornecedor, unicidade `(organization_id, provider, provider_reference)`.

`psp_webhook_events`: outbox com `provider_event_id`, unicidade `(provider, provider_event_id)`, payload bruto (jsonb), dead-letter com `payment_intent_id`/`organization_id`/`unit_id` nullable quando não há correspondência — nunca descarta um evento não correspondido.

Módulo backend novo com rota de ingestão de webhook: recebe o payload, resolve `payment_intent_id` por `provider_reference`, grava em `psp_webhook_events` com dedup, processa (atualiza `payment_intents.status`).

## Acceptance criteria

- [x] Migration aditiva cria `payment_intents` e `psp_webhook_events` com as unicidades descritas em §3.5/§4
- [x] RLS: `payment_intents` — SELECT para owner/admin/manager (org-wide) e reception/professional (unidade); nenhum INSERT/UPDATE direto de `authenticated`/`anon`. `psp_webhook_events` — nenhum grant a `anon`/`authenticated`, escrita só via `service_role`
- [x] Reentrega do mesmo `provider_event_id` não duplica processamento — o outbox trata conflito de unicidade como sucesso idempotente, não como erro
- [x] Evento sem correspondência a nenhum `payment_intent` conhecido grava como dead-letter (não é descartado, não derruba a ingestão)
- [x] pgTAP: unicidade das duas tabelas, grants, dead-letter, isolamento cross-tenant/cross-unit
- [x] Teste de integração backend: dois envios do mesmo evento sintético produzem o mesmo estado final (idempotência ponta a ponta)

## Blocked by

None - can start immediately

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `payment_intents`/`psp_webhook_events`)
- §3.4 (grants e RLS)
- §3.5 (idempotência contra replay — achados #1 e #2 da 1ª rodada de Red Team)
- §4 (contrato físico de schema)
