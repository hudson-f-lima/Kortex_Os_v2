## Parent PRD

`issues/onda1-payment-integrity-corrective-prd.md`

## Type

AFK

## What to build

Criar a identidade financeira imutável de cada hold de depósito e o comando de criação que a captura do agendamento sob lock. O caminho completo deve impedir que cliente, serviço ou profissional sejam alterados enquanto houver hold ativo, preservando alterações não financeiras somente se forem explicitamente compatíveis com o contrato.

## Acceptance criteria

- [ ] O hold armazena snapshots de cliente, serviço e profissional, além dos limites já necessários de tenant, unidade e ocorrência.
- [ ] A identidade, valor, mecânica e política congelados não aceitam alteração direta após a criação.
- [ ] Tentativa de trocar cliente, serviço ou profissional de agendamento com hold ativo é rejeitada de modo atômico.
- [ ] Preflight de dados existentes falha para ambiguidade, sem backfill inferido.
- [ ] Testes RED→GREEN cobrem mutação individual de cliente, serviço, profissional e snapshot direto.

## Blocked by

None — can start immediately.

## User stories addressed

- User story 4
- User story 5
- User story 10
