## Parent PRD

`issues/onda1-payment-integrity-corrective-prd.md`

## Type

AFK

## What to build

Entregar checkout de agendamento server-owned, com vínculo persistido entre comanda, agendamento e hold. O fluxo de agendamento deriva identidade no servidor, aceita somente estados elegíveis e falha fechada perante divergência; o checkout walk-in continua independente.

## Acceptance criteria

- [ ] Existe um comando HTTP de checkout por identificador de agendamento que valida JWT e membership antes de resolver a ocorrência.
- [ ] Cliente, unidade, profissional e hold do checkout de agendamento são derivados no servidor, não do payload.
- [ ] A comanda persiste vínculo tenant-safe com agendamento e hold, com unicidade que impede consumo financeiro duplicado da mesma ocorrência.
- [ ] Apenas `in_service` e `completed` são elegíveis; cancelado, futuro e outros estados não geram efeito financeiro.
- [ ] Divergências individuais de cliente, serviço, unidade, profissional e ocorrência são rejeitadas com rollback; checkout legítimo e walk-in continuam válidos.
- [ ] A ordem de locks e a idempotência são testadas sob concorrência real.

## Blocked by

- Blocked by `issues/006-hold-financial-identity.md`

## User stories addressed

- User story 1
- User story 2
- User story 3
- User story 6
- User story 13
