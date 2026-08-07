## Parent PRD

`issues/onda1-payment-integrity-corrective-prd.md`

## Type

AFK

## What to build

Implementar expiração reativa e fail-closed de hold sem scheduler. A expiração por webhook e a detecção antes de captura devem produzir um único estado terminal e impedir a criação de efeitos financeiros indevidos.

## Acceptance criteria

- [ ] Evento aplicável do PSP transiciona hold `active → expired` de forma idempotente.
- [ ] Tentativa de captura com autorização vencida recusa o checkout/no-show e não cria pedido, pagamento ou caixa.
- [ ] `immediate_charge` não recebe expiração fictícia.
- [ ] Corrida expiração×captura resulta em exatamente um estado terminal e efeitos coerentes.
- [ ] Testes RED→GREEN cobrem webhook, falha antes de captura, replay e concorrência real.

## Blocked by

- Blocked by `issues/006-hold-financial-identity.md`
- Blocked by `issues/007-appointment-server-owned-checkout.md`
- Blocked by `issues/009-webhook-dead-letter-reprocessing.md`

## User stories addressed

- User story 7
- User story 11
