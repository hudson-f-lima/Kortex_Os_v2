# ADR 0018: Onda 1 — Integridade Financeira Imutável de Depósitos

## Status

Implemented locally (DEC-38, 2026-07-26); homologation in `staging` and promotion authorization remain pending. There is no authorization for `main`/production.

## Date

2026-07-26

## Context

A auditoria posterior à implementação inicial da Onda 1 demonstrou que validar somente o `client_id` e a presença de um `service_id` no checkout não prova que o depósito pertence à comanda que o consome. A relação precisava resistir a divergências de unidade, profissional, estado do agendamento, ocorrência repetida e mutações posteriores do agendamento.

O `deposit_hold` representa um compromisso financeiro iniciado antes de existir uma comanda. Logo, a verdade de sua identidade não pode ser reconstituída de campos mutáveis do agendamento nem de uma afirmação `appointment_id` enviada pelo cliente. A falha é especialmente grave porque a reconciliação altera dinheiro e porque uma guarda permissiva pode deixar o checkout aparentemente bem-sucedido.

Também havia um descompasso entre o lifecycle declarado (`released` e `expired`) e os comandos existentes, além de dead-letters de webhook que não retornavam ao fluxo quando o intent correspondente passava a existir.

## Decision

### Identidade financeira congelada

Cada hold ativo terá uma identidade financeira persistida e imutável: `organization_id`, `unit_id`, `appointment_id`, `client_id`, `service_id`, `professional_id`, mecânica, valor, política de no-show e, quando aplicável, expiração. A criação do hold lerá o agendamento sob lock; nenhum caminho posterior inferirá essa identidade apenas do estado atual do agendamento.

Uma trigger ou mecanismo equivalente rejeitará mudanças diretas desses snapshots. Enquanto houver hold `active`, comandos de alteração de agendamento rejeitarão a troca de cliente, serviço ou profissional. Reagendamento permitido será um comando explícito que encerra/libera o hold anterior conforme a política e cria uma nova identidade, nunca uma atualização silenciosa.

### Checkout de agendamento é server-owned

O checkout de um agendamento será exposto pelo comando `POST /appointments/:id/checkout`. O backend resolve tenant por membership autenticada e deriva do agendamento/hold o cliente, a unidade, o profissional e o vínculo financeiro. O fluxo walk-in continua separado e não aceita `appointment_id` fornecido pelo corpo como uma autoridade financeira.

Ao fechar a comanda, a ordem persistirá o vínculo com o agendamento e com o hold. FKs tenant-safe, unicidade apropriada e uma ordem única de locks impedem que uma mesma ocorrência gere mais de uma comanda financeira de agendamento. A reconciliação só prossegue se o hold imutável, o agendamento e a comanda coincidirem em todos os limites aprovados; divergência falha fechada e reverte a transação.

Somente agendamentos `in_service` ou `completed` são elegíveis ao checkout. Cliente, unidade, profissional, serviço e ocorrência devem ser compatíveis com o snapshot do hold e com os itens da comanda.

### Lifecycle transacional do hold

Checkout, no-show, cancelamento e reagendamento usarão comandos transacionais com locks coerentes e compare-and-swap de `active` para um único estado terminal. `released` será usado pelo cancelamento elegível e pelo reagendamento explícito. `expired` será aplicado reativamente por evento do provedor ou de forma fail-closed antes de captura quando a autorização já não for válida.

`immediate_charge` não recebe uma liberação fictícia: o cancelamento que requer devolver dinheiro falha até existir um estorno real e auditável. Nenhum scheduler novo é introduzido por esta decisão.

### Webhook reprocessável e identidade externa não ambígua

O evento do PSP conservará sua chave idempotente, mas uma reentrega de dead-letter deve tentar de novo a resolução do intent antes de ser tratada como duplicata terminal. A identidade externa usada para associar evento e intent deve ser não ambígua dentro da organização/provedor. Somente evento já efetivamente processado é no-op; falhas preservam `processed_at` nulo, contabilizam tentativa e mantêm o último erro para reprocessamento explícito.

## Alternatives Considered

### Ampliar a guarda de `checkout_close` com mais comparações do payload

Rejeitada. Mesmo comparando todos os campos atuais, o modelo continuaria confiando em estado mutável e em um `appointment_id` afirmado pelo cliente, sem vínculo persistido com a comanda.

### Permitir checkout genérico com `appointment_id` opcional

Rejeitada para agendamentos. Um caminho genérico mistura a autoridade do fluxo walk-in com a do fluxo financeiro de agenda e torna fácil ignorar o vínculo.

### Liberar `immediate_charge` na mudança de status

Rejeitada. Mudar o status sem um estorno real produz uma mentira contábil: o dinheiro continua capturado embora o hold pareça liberado.

### Resolver expiração por scheduler novo

Adiada. O contrato requer primeiro a transição reativa e a proteção no momento da captura; um scheduler não é necessário para corrigir a integridade atual.

## Consequences

- Migrations serão aditivas e forward-only; registros existentes ambíguos exigem preflight e não serão preenchidos por suposição.
- Backend, schema e testes passam a compartilhar um contrato explícito de checkout de agendamento.
- A PWA não recebe `service_role` nem deriva regras financeiras; ela chama o comando server-owned.
- Os testes devem atacar isoladamente cliente, serviço, unidade, profissional, estado, ocorrência repetida, mutação pós-hold, replay e concorrência com duas conexões.
- A Onda 1 permanece `NO-GO` para produção até as fatias corretivas, Red Team consolidado, homologação em `staging` e a decisão formal de promoção.
