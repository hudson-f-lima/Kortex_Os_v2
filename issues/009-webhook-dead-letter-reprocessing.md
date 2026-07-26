## Parent PRD

`issues/onda1-payment-integrity-corrective-prd.md`

## Type

AFK

## What to build

Fazer o outbox de webhook reprocessar eventos dead-letter de forma segura quando o intent aparece depois, preservando deduplicação de eventos já processados e identidade externa não ambígua para a associação ao intent.

## Acceptance criteria

- [ ] Um evento não processado recebido antes do intent é resolvido em reentrega posterior ou por comando explícito de reprocessamento.
- [ ] Evento já processado é no-op idempotente e nunca repete efeito financeiro.
- [ ] Falha mantém `processed_at` nulo, incrementa tentativas e atualiza erro observável.
- [ ] A associação evento↔intent usa identidade não ambígua no escopo organização+provedor.
- [ ] Testes RED→GREEN cobrem fora de ordem, replay processado, replay dead-letter e reprocessamento manual.

## Blocked by

None — can start immediately.

## User stories addressed

- User story 9
- User story 10
