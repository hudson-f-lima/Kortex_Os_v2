# 8. Capacidades profissional×serviço: default-allow (não default-deny) e preço de pacote ignora override

Date: 2026-07-16

## Status

Accepted

## Context

A Fase 10 (`professional_service_capabilities`) deixou duas "Decisões em aberto" registradas em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md`, fechadas apressadamente na sessão de implementação sem pesquisa própria — violação direta da regra de ouro (`PLANEJAMENTO_EXECUCAO_UNIFICADO.md §1`: "nenhuma Decisão em aberto pode ser fechada... sem antes pesquisar como o mercado global resolve o mesmo problema"). Este ADR corrige isso.

### Decisão 1 — `price_override_cents` aplica a componentes de pacote ou só a serviço avulso?

### Decisão 2 — Profissional sem capability cadastrada para um serviço pode ser agendado (usando o padrão do serviço) ou fica bloqueado até uma capability existir?

**Achado ao revisar antes de pesquisar**: a Decisão 2, no texto original da Fase 10, citava `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` como recomendação ("indisponível por padrão"). Ao reler a fonte diretamente, **§10.3 é sobre `professional_working_hours_template` (jornada/expediente, conceito da Fase 15) — uma entidade completamente diferente de `professional_service_capabilities` (Fase 10, override de preço/duração)**. A citação foi um erro de conflação entre duas fases do planejamento, carregado sem verificação. A pergunta "profissional sem jornada cadastrada está disponível?" (físico: ele literalmente não está trabalhando) não tem a mesma resposta que "profissional sem capability cadastrada pode fazer o serviço?" (lógico: é uma questão de permissão/catálogo, não de disponibilidade física) — são perguntas diferentes que merecem pesquisa própria.

## Pesquisa

### Decisão 1 — preço de pacote vs. override individual

**Zenoti** (benchmark já usado nos ADRs 0003/0004/0006/0007 deste projeto) documenta "Price Scaling" (override de preço por profissional, equivalente a `price_override_cents`):
> "the standard price for nail gel polish is $15, and if an employee with price scaling enabled performs the service, the scaled price is $20. However, if gel polish is part of a complete nail package, guests booking the same service via the package will have to pay the standard price of $15, even if the employee performs the service." — [Zenoti Help — Price scaling](https://help.zenoti.com/en/configuration/employee-configurations/price-scaling.html)

Achado confirmado por busca independente (segunda query, mesmo texto reproduzido de forma consistente) — **o preço do pacote sempre vence o override individual do profissional**. O pacote é vendido pelo preço composto/fechado; o override de preço só se aplica quando o serviço é vendido avulso.

### Decisão 2 — bloqueio por ausência de capability

Pesquisa cruzando o nicho direto (salão/estética) com SaaS de agendamento genérico (fora do nicho, conforme exige a regra de ouro):

- **Fresha** (concorrente direto do nicho): "By default, new team members are assigned to all services... you can tick checkboxes next to each individual service or tick 'All services' to assign everything at once." — [Fresha Help — Add team members](https://www.fresha.com/help-center/knowledge-base/team/47-add-team-members-to-your-workspace) → **default-allow, opt-out**.
- **Cal.com** (SaaS de agendamento genérico, fora do nicho): a API usa `assignAllTeamMembers: true` para atribuir automaticamente todos os membros atuais e futuros do time a um tipo de evento — o padrão é inclusão total, não exclusão. → **default-allow, opt-out**.
- **Calendly** (SaaS de agendamento genérico, fora do nicho): eventos "Collective" e "Round Robin" incluem automaticamente todos os membros do time; a customização é remover, não adicionar. → **default-allow, opt-out**.
- **Square Appointments** (contraponto): exige atribuição explícita profissional↔serviço para o serviço ficar visível/reservável — **default-deny**. É o único dos quatro exemplos pesquisados com esse padrão, e sua atribuição é um checkbox binário (visibilidade), não um mecanismo de override de preço/duração como o que a Fase 10 implementou.

**Conclusão da pesquisa**: 3 de 4 fontes (incluindo a única do nicho direto e as duas fora do nicho, cumprindo a exigência "não só o nicho") convergem em default-allow/opt-out para atribuição de capacidade de serviço. Square é a exceção, e mesmo assim resolve um problema estruturalmente diferente (visibilidade/bookability binária, não override de valores).

## Decision

1. **`price_override_cents` nunca se aplica a um componente de pacote — só a um item de serviço avulso.** Nenhuma mudança de código é necessária: `checkout_close` (Fase 5.1) já não consulta `professional_service_capabilities` para nenhum propósito — nem avulso, nem pacote (o campo existe hoje só para leitura/exibição na PWA, ainda não fiado ao checkout, fora do escopo declarado da Fase 10). Esta decisão fixa o contrato para quando o wiring acontecer: a alocação proporcional do preço do pacote (maior resto, já implementada) permanece a única fonte de verdade para o valor de um componente vendido dentro de um pacote.
2. **Ausência de `professional_service_capabilities` para um par (profissional, serviço) não bloqueia o agendamento.** O comportamento correto — e já implementado em `appointments.service.js` (`resolveDurationMinutes`) — é: sem capability, usa os valores padrão do serviço (`duration_minutes`); qualquer profissional ativo pode ser agendado para qualquer serviço ativo da organização por padrão. A citação original a `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` é removida por conflação incorreta entre Fase 10 (capacidade de serviço) e Fase 15 (jornada de trabalho) — a recomendação de "indisponível por padrão" continua válida **só** para jornada (Fase 15, decisão própria, não revisitada aqui).

Nenhuma migration ou código precisou mudar como resultado deste ADR — a implementação já feita na Fase 10 coincidia, por acidente, com o padrão correto de mercado. O valor deste ADR é substituir uma justificativa incorreta (citação errada) por uma correta (pesquisa própria), e deixar o contrato de `price_override_cents` em pacotes registrado antes que o checkout seja revisitado numa fase futura.

## Consequences

### Positivo
- Fecha as duas "Decisões em aberto" da Fase 10 com evidência real, cumprindo a regra de ouro retroativamente.
- Documenta o contrato de `price_override_cents` × pacotes **antes** de qualquer fase futura fiar esse campo ao checkout — evita retrabalho ou uma decisão inconsistente com Zenoti tomada sob pressão de prazo.
- Corrige uma citação incorreta na cadeia de planejamento (`PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` não é sobre capacidade de serviço) antes que ela se propague para a Fase 15 real.

### Trade-off
- Nenhum — decisão sem custo de implementação, puramente de governança documental.

## References
- [Zenoti Help — Price scaling](https://help.zenoti.com/en/configuration/employee-configurations/price-scaling.html)
- [Fresha Help — Add team members to your workspace](https://www.fresha.com/help-center/knowledge-base/team/47-add-team-members-to-your-workspace)
- [Cal.com Docs — Create an event type](https://cal.com/docs/api-reference/v2/teams-event-types/create-an-event-type)
- [Calendly Help — How to set up a team Collective event type](https://help.calendly.com/hc/en-us/articles/14074913220247-How-to-set-up-a-team-Collective-event-type)
- [Square Support — Create, edit, and assign resources for appointments](https://squareup.com/help/us/en/article/7065-square-appointments-resource-management)
- [OWASP Cheat Sheet Series — Authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — princípio geral de "deny by default" (citado para mostrar que a exceção de Square é consistente com um princípio de segurança genérico, mas não é o padrão majoritário para *atribuição de capacidade de catálogo*, categoria diferente de *permissão de acesso*)
- `docs/PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` — fonte da citação original incorretamente aplicada à Fase 10 (é sobre jornada de trabalho, Fase 15)
- `docs/PLANEJAMENTO_EXECUCAO_UNIFICADO.md` (Fase 10, Fase 5.1) — escopo de `checkout_close` e alocação de pacotes
