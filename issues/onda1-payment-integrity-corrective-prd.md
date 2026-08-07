# PRD — Correção de integridade financeira da Onda 1

## Problem Statement

O fluxo inicial de depósito da Onda 1 permite que um hold financeiro seja consumido sem uma prova persistida de que pertence à comanda, à unidade, ao profissional e à ocorrência de agendamento que o utilizam. Estados de lifecycle declarados não têm todos os comandos necessários, e um dead-letter de webhook pode permanecer sem reprocessamento efetivo. O resultado é risco de captura indevida, perda de rastreabilidade e um bloqueio de promoção para produção.

## Solution

Implementar, exclusivamente forward-only, um contrato de depósito imutável e server-owned. Um checkout de agendamento passa a ser comandado pelo recurso de agendamento, persiste o vínculo com o hold e falha fechada em qualquer divergência. O hold tem lifecycle transacional completo, o webhook reprocessa dead-letters de modo idempotente e a expiração impede captura inválida. A conclusão depende de Red Team, homologação em `staging` e decisão formal posterior para promoção.

## User Stories

1. Como recepcionista, quero fechar um agendamento pelo próprio agendamento, para que a comanda use a unidade, cliente e profissional corretos.
2. Como operador, quero que um depósito só seja abatido da ocorrência que o originou, para não consumir dinheiro de outro cliente ou agendamento.
3. Como gestor multiunidade, quero que um depósito não atravesse unidades, para que os relatórios e o caixa preservem sua fronteira operacional.
4. Como profissional, quero que o depósito permaneça ligado ao profissional originalmente reservado, para que uma troca não autorizada não altere a verdade financeira.
5. Como cliente, quero que uma alteração do meu serviço ou profissional seja tratada explicitamente quando existe depósito, para que não haja captura para uma reserva diferente da que aceitei.
6. Como operador, quero que agendamentos cancelados, futuros ou inelegíveis não possam ir a checkout, para evitar cobrança indevida.
7. Como gestor, quero que cancelamento, reagendamento, checkout e no-show tenham somente uma transição terminal possível, para evitar duplicidade financeira sob concorrência.
8. Como financeiro, quero que uma cobrança imediata não pareça liberada sem estorno real, para que o sistema não esconda dinheiro capturado.
9. Como integrador de PSP, quero que um evento recebido antes do intent possa ser reprocessado, para que uma entrega fora de ordem não seja perdida.
10. Como auditor, quero que cada evento PSP tenha uma identidade externa não ambígua e histórico de tentativas, para investigar e reprocessar falhas com segurança.
11. Como operador, quero que uma autorização vencida seja rejeitada antes de captura, para não criar uma comanda que depende de dinheiro indisponível.
12. Como Platform Owner, quero evidência independente contra os exploits conhecidos antes de promover, para que uma suíte verde incompleta não seja confundida com segurança.
13. Como equipe de produto, quero preservar o checkout walk-in separado do checkout de agendamento, para que a correção não quebre o fluxo sem reserva.
14. Como responsável por compliance, quero que toda promoção para produção dependa de gate formal, para não transformar autorização de correção em autorização de deploy.

## Implementation Decisions

- O contrato é regido por DEC-38 e ADR 0018; toda alteração de schema e comportamento é aditiva e forward-only.
- A identidade do hold inclui tenant, unidade, ocorrência, cliente, serviço, profissional, valor, mecânica e política relevante; ela é capturada sob lock e não pode ser alterada.
- O checkout de agendamento usa comando server-owned por identificador de agendamento. Tenant deriva da membership autenticada e os dados financeiros não derivam de body/query isoladamente.
- O pedido resultante persiste o vínculo com o agendamento e o hold; unicidade e chaves tenant-safe impedem duplicidade por ocorrência.
- Somente estados `in_service` e `completed` permitem checkout de agendamento.
- Checkout, no-show, cancelamento, reagendamento e expiração fazem transição por transações atômicas e CAS; cancelamento de cobrança imediata fica bloqueado sem estorno real.
- Eventos PSP preservam chave de deduplicação, mas dead-letter não processado é reavaliado quando chega nova entrega ou comando manual de reprocessamento.
- Não há integração PSP real, scheduler novo, promoção a `main` ou produção neste PRD.

## Testing Decisions

- Testar comportamento observável e invariantes financeiros, nunca detalhes internos de uma função.
- Cada fatia começa com teste RED para o comportamento que corrige e só então ganha a implementação GREEN.
- Exercitar separadamente divergência de cliente, serviço, unidade, profissional, estado e ocorrência; nunca combinar todas as divergências em um único caso.
- Executar corridas com duas conexões reais para checkout×cancelamento, checkout×no-show e checkout×expiração.
- Reexecutar todos os exploits auditados, além de regressões de checkout legítimo e walk-in.
- Validar schema/RLS/tenant, backend HTTP, PWA, idempotência de webhook, lint, build e reset limpo antes do gate final.

## Out of Scope

- Captura financeira real e escolha de PSP da Etapa 9.
- Ledger da Onda 2 e Gate 11.
- Scheduler de expiração, carteira de crédito ou estorno novo.
- Promoção para `main`/produção.

## Further Notes

As fatias `issues/006` a `issues/010` são AFK dentro do contrato já aprovado, mas continuam sujeitas a TDD e Red Team. A fatia `issues/011` é HITL porque consolida evidências, homologação e a decisão de promoção, que não pode ser inferida desta aprovação.
