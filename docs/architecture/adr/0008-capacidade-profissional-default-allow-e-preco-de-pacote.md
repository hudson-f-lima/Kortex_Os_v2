# 8. Capacidades profissional×serviço: preço de pacote ignora override (Accepted) e gate de agendamento por habilidade (Reaberto)

Date: 2026-07-16

## Status

**Parcial.** Decisão 1 (preço de pacote): `Accepted`. Decisão 2 (gate de agendamento por ausência de capability): `Reaberto` — ver testemunho de operação real na seção "Terceira passada" abaixo. Não confundir com `Accepted` geral; este ADR documenta uma pergunta ainda sem resposta final, não uma decisão fechada.

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

**Conclusão da segunda passada (documentação de vendor)**: dentro do beautytech global, o padrão parecia dividido — 2 fontes explícitas em default-allow (Zenoti, Fresha) + 1 "configurável" (Booksy, conforme o help center) vs. 2 em default-deny (Square, Mindbody).

### Terceira passada — testemunho de operação real (2026-07-16, pesa mais que documentação de vendor)

O usuário deste projeto operou Booksy ativamente por 5 anos (uso real, não leitura de help center) e corrigiu a caracterização de "configurável" acima com relato direto:

> "1. ao cadastrar um profissional novo, eu podia escolher o grupos de serviços inteiros. e, escolher serviços individuais dentro de cada grupo. 2. cada profissional tem suas habilidades. 3. ao criar serviço pode escolher 1 ou mais profissionais ou por categoria. 4. override por: tempo, preço, comissão, cada staff tem skill's diferentes."

Isso revela três coisas que a documentação pública do Booksy (e minha leitura dela) não capturou:
1. **A atribuição no Booksy não é "tudo ligado, depois restrinja"** — é uma ação ativa de configuração no cadastro do profissional (escolher grupos e/ou serviços individuais). Um profissional sem nada selecionado não tem serviços — o comportamento de fato é mais próximo de "vazio até configurar" do que "tudo liberado por padrão", mesmo que o produto ofereça atalhos de seleção em massa (por grupo).
2. **"Cada profissional tem suas habilidades" é tratado como fato operacional comum, não exceção** — na vivência de 5 anos do usuário, diferenciação de skill entre profissionais é a norma no dia a dia de salão/barbearia, não um caso de borda raro.
3. **A atribuição é bidirecional** (do profissional → serviços, ou do serviço → profissionais/categoria) e o override cobre **três dimensões** (tempo, preço, comissão), não duas — um detalhe operacional que nenhuma das fontes de documentação pública mencionou.

**Isso muda o peso da evidência, não a contagem de fontes.** Documentação de vendor descreve o que o produto permite tecnicamente; testemunho de operação real descreve o que os salões de fato configuram e vivem no dia a dia. Um relato de 5 anos de uso pesa mais que uma frase de help center — e ele aponta para o lado oposto do que a leitura documental sugeria: skill-based restriction é a prática comum no beautytech real, não um nicho dentro do nicho (Square/Mindbody).

**Nuance que permanece válida**: mesmo com esse peso maior para default-deny/restrição-real, a arquitetura de dados do Zenoti (capacidade como override job/employee-level, "unassigned = todos podem") ainda é o modelo estruturalmente mais próximo do que `professional_service_capabilities` já implementa — a diferença entre Zenoti e Booksy pode ser genuinamente de produto (Zenoti permite operar sem essa restrição como fallback técnico; Booksy, na prática vivida, não deixa esse fallback acontecer porque o fluxo de cadastro força a escolha). Ambos podem estar certos para seus próprios contextos — a pergunta relevante para o Kortex não é mais "qual produto está certo", é "qual comportamento os donos de salão que usam o Kortex esperam viver".

## Decision

1. **`price_override_cents` nunca se aplica a um componente de pacote — só a um item de serviço avulso.** Nenhuma mudança de código é necessária: `checkout_close` (Fase 5.1) já não consulta `professional_service_capabilities` para nenhum propósito — nem avulso, nem pacote (o campo existe hoje só para leitura/exibição na PWA, ainda não fiado ao checkout, fora do escopo declarado da Fase 10). Esta decisão fixa o contrato para quando o wiring acontecer: a alocação proporcional do preço do pacote (maior resto, já implementada) permanece a única fonte de verdade para o valor de um componente vendido dentro de um pacote. **Esta parte permanece `Accepted`, não afetada pelo testemunho de operação real (é sobre preço de pacote, não sobre gate de agendamento).**

2. **REABERTA — não mais `Accepted` sem ressalva.** O comportamento hoje implementado (`resolveDurationMinutes`: sem capability, cai no padrão do serviço; qualquer profissional ativo pode ser agendado para qualquer serviço ativo) permanece **em produção sem mudança de código nesta sessão**, mas a base de evidência mudou depois do testemunho de operação real: skill-based restriction é a prática comum vivida em 5 anos de Booksy, não a exceção. Isso desafia a recomendação de manter default-allow.

   A citação original a `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` segue removida por conflação incorreta (aquilo é sobre jornada, Fase 15) — isso não muda. O que muda é que a pergunta de fundo ("profissional pode ser agendado para qualquer serviço, ou só para os que sabe fazer?") tem agora evidência real e diretamente aplicável ao domínio (salão/barbearia) apontando para **"só para os que sabe fazer"**, não para "qualquer um, por padrão".

   **Duas rotas possíveis, ambas honestas com a evidência atual — decisão de escopo cabe ao usuário, não a este ADR:**
   - **(a) Manter default-allow por ora** (nenhum código muda): correto para o estágio atual do Kortex — MVP de organização única, ainda sem UX de atribuição em massa por grupo (o Booksy só torna "escolher no cadastro" viável na prática porque tem seleção por grupo inteiro e por categoria; sem isso, forçar seleção manual de cada par profissional×serviço seria fricção real de onboarding). Risco aceito: um salão pode hoje agendar um cliente com um profissional que não tem a habilidade certa, sem qualquer aviso do sistema.
   - **(b) Escopar uma feature de restrição de habilidade** (trabalho novo, fora do que a Fase 10 entregou): `professional_service_capabilities` passaria a ter um papel duplo — override de valores **e** gate de "pode fazer" —, ou ganharia uma coluna nova (ex.: um booleano explícito, com ausência de linha significando **não pode**, invertendo o fallback atual). Exigiria: (i) migration alterando a semântica de ausência de linha; (ii) UX de atribuição em massa por grupo de serviço na Equipe (replicando o que o Booksy oferece no cadastro do profissional, sem o qual a restrição vira fricção); (iii) validação em `appointments.service.js` bloqueando a criação/edição quando não há capability ativa; (iv) migração de dados para as organizações que já usam o Kortex hoje (que atualmente não têm nenhuma linha e dependiam do fallback "todos podem") — sem isso, todo profissional existente ficaria subitamente impedido de fazer qualquer serviço no dia do deploy.

   Este ADR não escolhe entre (a) e (b) — o corpo do testemunho é forte o bastante para não fechar a questão como "sem evidência" (como a primeira revisão fez), mas fraco demais em relação ao custo de implementação de (b) para eu decidir sozinho, seguindo o princípio "propõe, não decide sozinho" já estabelecido neste projeto (`PLANEJAMENTO_EXECUCAO_UNIFICADO.md §1`).

Nenhuma migration ou código mudou como resultado desta sessão. O valor deste ADR, atualizado pela terceira vez, é registrar que a pergunta 2 passou de "fechada por engano" → "fechada com pesquisa rasa" → "reaberta com evidência real de prática operacional, aguardando decisão de escopo do usuário" — sem nunca decidir por conta própria uma mudança de arquitetura com esse custo.

## Consequences

### Positivo
- Fecha a Decisão 1 (preço de pacote) da Fase 10 com evidência real, cumprindo a regra de ouro retroativamente.
- Documenta o contrato de `price_override_cents` × pacotes **antes** de qualquer fase futura fiar esse campo ao checkout — evita retrabalho ou uma decisão inconsistente com Zenoti tomada sob pressão de prazo.
- Reabre honestamente a Decisão 2 em vez de mantê-la fechada com uma justificativa que a evidência mais recente (testemunho de operação real) enfraqueceu — evita que uma decisão errada vire dívida técnica silenciosa disfarçada de "Accepted".
- Corrige uma citação incorreta na cadeia de planejamento (`PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` não é sobre capacidade de serviço) antes que ela se propague para a Fase 15 real.
- Registra a diferença de peso entre documentação de vendor e testemunho de operação real como lição reaproveitável — ver `[[feedback-research-before-deciding]]` e `[[user-booksy-experience]]` na memória do agente.

### Trade-off
- **Enquanto a Decisão 2 fica em aberto**, o Kortex opera com o risco já descrito na rota (a): um profissional pode ser agendado para um serviço que não sabe fazer, sem qualquer aviso do sistema — risco aceito implicitamente até uma decisão de escopo explícita, não um risco novo introduzido por este ADR.
- Se a rota (b) for escolhida no futuro, o custo é real e não incremental: migration de semântica invertida (ausência de linha passa a significar bloqueio, não liberação), UX de atribuição em massa nova, validação em `appointments.service.js`, e uma migração de dados cuidadosa para não bloquear profissionais já cadastrados no dia do deploy.

## References
- [Zenoti Help — Update the services an employee can perform](https://help.zenoti.com/en/employee-and-payroll/employee-related-manager-tasks/update-the-services-an-employee-can-perform.html) — fonte decisiva: "unassigned = all employees can perform the service"
- [Zenoti Help — Price scaling](https://help.zenoti.com/en/configuration/employee-configurations/price-scaling.html)
- [Fresha Help — Add team members to your workspace](https://www.fresha.com/help-center/knowledge-base/team/47-add-team-members-to-your-workspace)
- [Booksy Help — How do I add a staff member?](https://support.booksy.com/hc/en-us/articles/16536054878354-How-do-I-add-a-staff-member) — documentação pública, superada pelo testemunho de operação real abaixo
- **Testemunho de operação real do usuário deste projeto** (5 anos operando Booksy ativamente, 2026-07-16) — fonte primária de maior peso que a documentação pública para esta decisão; ver `[[user-booksy-experience]]` na memória do agente para o relato completo
- [Cal.com Docs — Create an event type](https://cal.com/docs/api-reference/v2/teams-event-types/create-an-event-type)
- [Calendly Help — How to set up a team Collective event type](https://help.calendly.com/hc/en-us/articles/14074913220247-How-to-set-up-a-team-Collective-event-type)
- [Square Support — Create, edit, and assign resources for appointments](https://squareup.com/help/us/en/article/7065-square-appointments-resource-management)
- [Mindbody Support — Appointments setup: assign availability and pricing](https://support.mindbodyonline.com/s/article/203254123-Appointments-setup-assign-availability-and-pricing?language=en_US) — staff deve estar conectado ao serviço para ficar reservável; toggle "Do not require staff on availability search" desliga essa exigência
- [OWASP Cheat Sheet Series — Authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) — princípio geral de "deny by default"; citado para mostrar que Square/Mindbody são consistentes com um princípio de segurança genérico, mas essa categoria (permissão de acesso) não é a mesma de *atribuição de capacidade de catálogo*, onde o mercado beautytech mais relevante para este projeto (Zenoti) diverge desse princípio deliberadamente
- `docs/PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` — fonte da citação original incorretamente aplicada à Fase 10 (é sobre jornada de trabalho, Fase 15)
- `docs/PLANEJAMENTO_EXECUCAO_UNIFICADO.md` (Fase 10, Fase 5.1, Fase 15 §5) — escopo de `checkout_close`, alocação de pacotes, e princípio de "não modelar sem evidência"
- Memória do agente `feedback-research-before-deciding` — registro da lição de triangulação em 4 quadrantes que motivou esta revisão
