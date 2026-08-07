## Parent PRD

`issues/onda1-payment-integrity-corrective-prd.md`

## Type

AFK

## What to build

Completar o lifecycle transacional de hold para cancelamento, reagendamento e no-show, sem inventar liberação financeira para cobrança imediata. Cada comando deve ter um único resultado terminal observável sob concorrência.

## Acceptance criteria

- [ ] Cancelamento elegível de hold cria transição `active → released` na mesma transação do agendamento.
- [ ] Reagendamento explícito encerra o hold anterior segundo a política e exige nova identidade para o novo agendamento.
- [ ] No-show usa os snapshots do hold, não campos atuais mutáveis do agendamento.
- [ ] Cancelamento de `immediate_charge` que demande devolução falha sem estorno real e auditável.
- [ ] Corridas cancelamento×checkout e no-show×checkout têm exatamente um vencedor e nenhum pedido/pagamento parcial.
- [ ] Testes RED→GREEN cobrem replay e falha intermediária de cada comando.

## Blocked by

- Blocked by `issues/006-hold-financial-identity.md`
- Blocked by `issues/007-appointment-server-owned-checkout.md`

## User stories addressed

- User story 5
- User story 7
- User story 8
