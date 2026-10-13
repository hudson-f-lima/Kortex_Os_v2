## Parent PRD

`issues/onda1-payment-integrity-corrective-prd.md`

## Type

HITL

## What to build

Consolidar a evidência independente da correção, executar Red Team sobre o conjunto em `staging` e submeter o resultado ao gate formal de promoção. Esta fatia não promove ambiente por si própria.

## Acceptance criteria

- [ ] Reset limpo, testes de banco/backend/frontend, lint, build e advisors são executados e registrados com evidência bruta.
- [ ] Todos os exploits conhecidos são reexecutados, incluindo dimensões isoladas e corridas com duas conexões reais.
- [ ] Red Team classifica cada achado como fechado, residual ou bloqueado sem aceitar relato de subagente como prova.
- [ ] Homologação em `staging` valida checkout de agendamento, walk-in, lifecycle e reprocessamento de webhook.
- [ ] Environment Guardian e Delivery Guardian recebem o material necessário para avaliar promoção; nenhuma promoção ocorre sem decisão formal nova.

## Blocked by

- Blocked by `issues/007-appointment-server-owned-checkout.md`
- Blocked by `issues/008-hold-release-cancel-reschedule.md`
- Blocked by `issues/009-webhook-dead-letter-reprocessing.md`
- Blocked by `issues/010-hold-expiration-fail-closed.md`

## User stories addressed

- User story 12
- User story 14
