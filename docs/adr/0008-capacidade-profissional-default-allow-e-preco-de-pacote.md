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

**Primeira passada (rasa — mantida aqui para auditoria, não escondida)**: pesquisa inicial cruzou só 4 fontes (Fresha, Cal.com, Calendly, Square) e concluiu "3 de 4 convergem em default-allow, Square é exceção". O usuário pediu, numa sessão seguinte, para provar essa triangulação de forma mais rigorosa antes de aceitar a conclusão — cruzando explicitamente **mercado nacional × mercado global** e **beautytech (nicho) × outros mercados (fora do nicho)**, não só "nicho vs. não-nicho" de forma solta. A pesquisa ampliada revelou um quadro mais dividido do que a primeira passada sugeria (ver `[[feedback-research-before-deciding]]` na memória do agente para o registro desse achado como lição geral).

**Pesquisa ampliada, por quadrante:**

| | Beautytech (nicho) | Outros mercados (fora do nicho) |
|---|---|---|
| **Nacional (BR)** | AppBarber/Trinks: existe um passo de "vincular o serviço com os profissionais que irão realizá-lo", mas a documentação associa isso especificamente a **definir comissão diferenciada por profissional** — mesmo padrão de override (não gate) que Zenoti usa. Ambíguo quanto ao default, não é evidência clara de default-deny. | Pesquisa inconclusiva (iClinic/Simples Dental, dados insuficientes). |
| **Global** | **Zenoti** (fonte mais citada em todo o histórico de ADRs deste projeto — 0003/0004/0006/0007): "*If you have services that are not yet assigned to any employee (by Job or direct assignment at the Employee level), it means, all employees can perform the service.*" — [Zenoti Help — Update the services an employee can perform](https://help.zenoti.com/en/employee-and-payroll/employee-related-manager-tasks/update-the-services-an-employee-can-perform.html) → **default-allow, explícito e textual**. Arquitetura estruturalmente idêntica ao que a Fase 10 implementou: tabela de override (job-level ou employee-level), ausência de linha = comportamento padrão vale para todos. **Fresha**: "By default, new team members are assigned to all services" — [Fresha Help](https://www.fresha.com/help-center/knowledge-base/team/47-add-team-members-to-your-workspace) → default-allow. **Booksy**: suporta os dois modos, à escolha do negócio ("assign to all or select") — [Booksy Help](https://support.booksy.com/hc/en-us/articles/16536054878354-How-do-I-add-a-staff-member) → configurável. **Square Appointments**: exige atribuição explícita para o serviço ficar reservável — [Square Support](https://squareup.com/help/us/en/article/7065-square-appointments-resource-management) → default-deny. **Mindbody**: "*it may be because there are no employees... connected to the Service*" bloqueia o agendamento, com um toggle específico ("Do not require staff on availability search") para desligar essa exigência — default de fábrica é default-deny, mas configurável. | **Cal.com**: `assignAllTeamMembers: true` — default-allow. **Calendly**: eventos Collective/Round Robin incluem todos por padrão — default-allow. Unânime nas duas fontes checadas. |

**Conclusão revisada**: dentro do beautytech global, o padrão está genuinely dividido — 2 fontes explícitas em default-allow (Zenoti, Fresha) + 1 configurável (Booksy) vs. 2 em default-deny (Square, Mindbody). Não é mais "3 de 4, Square é exceção" — essa framing da primeira passada superestimava o consenso por amostra pequena. Mas dentre as fontes divergentes, **Zenoti pesa mais que as outras** por dois motivos: (1) é o único benchmark que este projeto já usa consistentemente como referência de confiança nos ADRs anteriores, não uma fonte nova introduzida ad-hoc; (2) sua arquitetura (capacidade como override associável a um job/employee, com fallback explícito para "todos podem" na ausência de configuração) é estruturalmente idêntica à tabela `professional_service_capabilities` que a Fase 10 já implementou — não é só "o mesmo resultado", é "o mesmo modelo de dados". Square e Mindbody resolvem esse problema com uma primitiva diferente (um flag binário de "quem pode ver/reservar este serviço", separado de qualquer override de preço/duração) — uma feature que o Kortex simplesmente não tem hoje, não uma variação do que já existe.

## Decision

1. **`price_override_cents` nunca se aplica a um componente de pacote — só a um item de serviço avulso.** Nenhuma mudança de código é necessária: `checkout_close` (Fase 5.1) já não consulta `professional_service_capabilities` para nenhum propósito — nem avulso, nem pacote (o campo existe hoje só para leitura/exibição na PWA, ainda não fiado ao checkout, fora do escopo declarado da Fase 10). Esta decisão fixa o contrato para quando o wiring acontecer: a alocação proporcional do preço do pacote (maior resto, já implementada) permanece a única fonte de verdade para o valor de um componente vendido dentro de um pacote.
2. **Ausência de `professional_service_capabilities` para um par (profissional, serviço) não bloqueia o agendamento — mantido, mas com o mercado dividido, não unânime.** O comportamento já implementado em `appointments.service.js` (`resolveDurationMinutes`) — sem capability, usa os valores padrão do serviço; qualquer profissional ativo pode ser agendado para qualquer serviço ativo — permanece. A citação original a `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` é removida por conflação incorreta entre Fase 10 (capacidade de serviço) e Fase 15 (jornada de trabalho) — "indisponível por padrão" continua válida **só** para jornada (Fase 15, decisão própria, não revisitada aqui). A justificativa nova não é mais "o mercado converge nisso" (não converge), é: **Zenoti — o benchmark mais usado neste projeto, com uma arquitetura estruturalmente idêntica à tabela que a Fase 10 implementou — confirma default-allow de forma explícita e textual**, e Kortex está no estágio de MVP de organização única, sem UX de atribuição em massa (o que Square/Mindbody exigiriam para não virar fricção de onboarding: toda combinação profissional×serviço precisaria ser criada manualmente antes de qualquer agendamento funcionar).

**Item explicitamente NÃO decidido aqui — fica para decisão futura, não implementado agora:** se o Kortex algum dia quiser oferecer o modo Square/Mindbody (restringir quais profissionais podem ser agendados por serviço, não só customizar preço/duração), isso é uma **feature nova e distinta** — um flag de "restringir a profissionais atribuídos" por organização ou por serviço, com UX de atribuição em massa para não quebrar o onboarding — não uma reinterpretação de `professional_service_capabilities`. Não há evidência hoje (nenhum incidente relatado, nenhuma reclamação de usuário) que justifique construir isso agora; fica registrado como candidato para quando essa evidência aparecer, seguindo o mesmo princípio de "não modelar sem evidência" já usado em outras decisões deste projeto (ex.: Fase 15 §5, "unidade" só vira entidade própria com evidência de multiunidade).

Nenhuma migration ou código precisou mudar como resultado deste ADR — a implementação já feita na Fase 10 coincide com o padrão de mercado mais relevante para este projeto (Zenoti), ainda que não seja unânime no nicho. O valor deste ADR é substituir uma justificativa incorreta (citação errada, depois consenso superestimado por amostra pequena) por uma pesquisa real e honesta sobre a divergência, e deixar o contrato de `price_override_cents` em pacotes registrado antes que o checkout seja revisitado numa fase futura.

## Consequences

### Positivo
- Fecha as duas "Decisões em aberto" da Fase 10 com evidência real, cumprindo a regra de ouro retroativamente — incluindo uma segunda passada mais rigorosa depois que a primeira se mostrou rasa demais.
- Documenta o contrato de `price_override_cents` × pacotes **antes** de qualquer fase futura fiar esse campo ao checkout — evita retrabalho ou uma decisão inconsistente com Zenoti tomada sob pressão de prazo.
- Corrige uma citação incorreta na cadeia de planejamento (`PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` não é sobre capacidade de serviço) antes que ela se propague para a Fase 15 real.
- Registra honestamente que o mercado beautytech está dividido nesta questão (não fabrica um consenso que não existe), e explica por que Zenoti pesa mais que a média para as decisões deste projeto especificamente.
- Deixa o modo "restringir por atribuição" (padrão Square/Mindbody) registrado como feature candidata futura, não descartado nem implementado sem evidência.

### Trade-off
- Nenhum custo de implementação imediato — decisão de governança documental. O trade-off real é de **risco aceito**: se surgir evidência de que orgs precisam restringir quem faz o quê (ex.: reclamação de cliente agendado com profissional sem qualificação para um serviço especializado), será preciso desenhar e construir a feature de restrição do zero, não é um ajuste incremental da tabela atual.

## References
- [Zenoti Help — Update the services an employee can perform](https://help.zenoti.com/en/employee-and-payroll/employee-related-manager-tasks/update-the-services-an-employee-can-perform.html) — fonte decisiva: "unassigned = all employees can perform the service"
- [Zenoti Help — Price scaling](https://help.zenoti.com/en/configuration/employee-configurations/price-scaling.html)
- [Fresha Help — Add team members to your workspace](https://www.fresha.com/help-center/knowledge-base/team/47-add-team-members-to-your-workspace)
- [Booksy Help — How do I add a staff member?](https://support.booksy.com/hc/en-us/articles/16536054878354-How-do-I-add-a-staff-member) — confirma suporte aos dois modos (default-allow ou seleção manual)
- [Cal.com Docs — Create an event type](https://cal.com/docs/api-reference/v2/teams-event-types/create-an-event-type)
- [Calendly Help — How to set up a team Collective event type](https://help.calendly.com/hc/en-us/articles/14074913220247-How-to-set-up-a-team-Collective-event-type)
- [Square Support — Create, edit, and assign resources for appointments](https://squareup.com/help/us/en/article/7065-square-appointments-resource-management)
- [Mindbody Support — Appointments setup: assign availability and pricing](https://support.mindbodyonline.com/s/article/203254123-Appointments-setup-assign-availability-and-pricing?language=en_US) — staff deve estar conectado ao serviço para ficar reservável; toggle "Do not require staff on availability search" desliga essa exigência
- [OWASP Cheat Sheet Series — Authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — princípio geral de "deny by default"; citado para mostrar que Square/Mindbody são consistentes com um princípio de segurança genérico, mas essa categoria (permissão de acesso) não é a mesma de *atribuição de capacidade de catálogo*, onde o mercado beautytech mais relevante para este projeto (Zenoti) diverge desse princípio deliberadamente
- `docs/PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` — fonte da citação original incorretamente aplicada à Fase 10 (é sobre jornada de trabalho, Fase 15)
- `docs/PLANEJAMENTO_EXECUCAO_UNIFICADO.md` (Fase 10, Fase 5.1, Fase 15 §5) — escopo de `checkout_close`, alocação de pacotes, e princípio de "não modelar sem evidência"
- Memória do agente `feedback-research-before-deciding` — registro da lição de triangulação em 4 quadrantes que motivou esta revisão
