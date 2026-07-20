# KORTEXOS™ 5.1.2 — MASTER BRIEFING CANÔNICO

**Arquivo:** `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md`
**Produto:** KortexOS™
**Versão:** 5.1.2
**Status:** FONTE ÚNICA CANÔNICA — PROMOÇÃO 5.1.2 APROVADA PELO PLATFORM OWNER EM 2026-07-19
**Data:** 2026-07-19
**Autoridade:** Platform Owner
**Conteúdo desta promoção:** PARTE I = tese, domínios, motores, RAGOV e gates; PARTE II = Cadastros Canônicos; PARTE III = Configuração, Onboarding, Comanda, Gorjeta e Níveis.
**Registro de decisões (DEC-01 a DEC-18, D-01 a D-09):** vive em arquivo companion `KORTEXOS_5_1_2_DECISION_LOG.md` — separação aprovada pelo Platform Owner em 2026-07-19 para eliminar ruído de decisões supersedidas. Cada regra abaixo cita o(s) ID(s) que a fundamenta(m); o texto completo de cada decisão, alternativas e histórico de supersessão está no Decision Log.
**Nota de manutenção (2026-07-19):** documento consolidado — RAGOV e Veredito Red Team, antes fragmentados em três ocorrências cada, unificados em ocorrência única; tabelas de decisão histórica extraídas para o Decision Log.
**Natureza:** reescrita canônica integral da versão 5.1; não é patch, delta, adendo, remendo, hotfix, rebranding superficial ou implementação técnica
**Base de promoção:** `KORTEXOS_5_1_MASTER_BRIEFING_CANONICO_REWRITE.md` + `SMART_FLOW_4_0_MASTER_BRIEF_CANONICO.md` + `SMART_FLOW_4_0_BLUEPRINT_UNIFICADO_CANONICO-1.md` + pesquisa global e decisões da conversa sobre rebooking, reativação, waitlist, VIP, agendamento por API, modelos matemáticos e automação governada
**Escopo:** visão, tese, domínios, invariantes, motores, modelos matemáticos, portfólio de automações, gates, RAGOV, bloqueios e ordem de construção
**Fora do escopo:** SQL executável, migrations novas, endpoints finais, telas, design visual, credenciais de provedores e ativação de automações em produção sem Blueprint, Truth Map e gates aprovados

---

## Resumo executivo analítico

### Problema real

O KortexOS™ já possuía agenda, waitlist, retenção, ocupação, mensageria e inteligência de decisão como domínios separados. A conversa revelou que o maior valor não está em adicionar campanhas ou bots isolados, mas em coordenar esses domínios para decidir **quem abordar, quando, por qual canal, para qual serviço, com qual profissional, em qual slot e com qual impacto econômico**.

A causa raiz da ociosidade e do churn não é apenas ausência de comunicação. É a falta de um mecanismo canônico que combine:

- ciclo esperado de retorno do cliente;
- preferência temporal e profissional;
- capacidade futura do profissional e da unidade;
- probabilidade de o slot permanecer vazio;
- margem incremental e custo da ação;
- confiabilidade, consentimento e fadiga de contato;
- restrições operacionais, financeiras e reputacionais;
- efeito causal da intervenção, separado do retorno espontâneo.

### Insight consolidado

```text
Dados canônicos
→ features e mapas de calor
→ decisão matemática explicável
→ otimização sob restrições
→ política e elegibilidade
→ automação transacional
→ mensuração incremental
→ aprendizado controlado
```

Bot, WhatsApp, Telegram, push, e-mail e IA são superfícies de ativação. Eles não são o cérebro do sistema e não podem se tornar fonte de verdade.

### Decisão estratégica 5.1.1

KortexOS™ 5.1.1 incorpora como tese canônica um **Kortex Autonomous Operations Engine**, implementado transversalmente sobre os domínios existentes, sem criar D32. O engine contém:

1. **Decision & Capacity Core** — timing, demanda, ocupação, valor econômico e matching;
2. **Contact & Policy Orchestrator** — prioridade, consentimento, frequência, supressão e conflitos;
3. **Automation Control Plane** — modos, rollout, kill switch, circuit breaker e auditoria;
4. **Incrementality Engine** — grupos de controle, atribuição e margem incremental;
5. **KortexLink Activation Layer** — WhatsApp, canal VIP, push, e-mail, links, QR e webhooks;
6. **Kortex.ai Interface Layer** — interpretação, classificação de intenção, linguagem e handoff, sem soberania.

### Prioridade

A prioridade não é construir IA preditiva ou chatbot autônomo. A prioridade é um **Opportunity Engine determinístico no PostgreSQL**, inicialmente em modo `OBSERVE`, capaz de produzir recomendações reproduzíveis e explicáveis.

### Veredito

| Decisão | Veredito 5.1.1 |
|---|---|
| Regra fixa de 45 dias | PARCIAL; apenas fallback inicial |
| Retorno esperado por cliente/serviço | APROVADO |
| Quatro mapas de calor | APROVADO |
| Expected Value e margem incremental | APROVADO |
| Waitlist inteligente com hold | P1 |
| Rebooking pós-atendimento | P1 |
| Confirmação adaptativa/no-show | P1 |
| Reativação progressiva | P1 |
| Canal VIP WhatsApp | VIÁVEL; grupo aberto não é núcleo |
| Agendamento automático por API | VIÁVEL somente com API transacional e SSOT definida |
| Bot/IA como policy engine | BLOQUEADO |
| Uplift modeling | P2 após experimentação |
| Contextual bandit | P3 após dados e governança |
| Reinforcement learning | BLOQUEADO no MVP |

---

## 0. Regra de autoridade

### 0.1 Hierarquia canônica

| Artefato | Autoridade | Limite |
|---|---|---|
| **Master Briefing KortexOS™ 5.1.1** | Decide identidade, tese, limites, motores, domínios, invariantes, gates, RAGOV e ordem de construção | Não materializa SQL |
| Benchmark Global | Compara KortexOS™ contra referências reais de mercado e boas práticas | Não decide arquitetura sozinho |
| Comparative Proposal | Classifica o que herdar, reforçar, bloquear, adiar ou descartar | Não cria migration |
| Truth Map | Classifica REAL / PARCIAL / MOCKADO / HARDCODED / CRÍTICO / BLOQUEADO | Não implementa |
| Migration Map | Mapeia nomes, tabelas, domínios, prefixos e impacto de promoção | Não executa |
| Blueprint KortexOS™ 5.1.1 | Organiza arquitetura técnica, blocos, migrations, dependências e DoD | Não altera escopo canônico |
| SQL Master | Materializa a verdade no banco | Não inventa domínio, regra ou tabela fora do Blueprint aprovado |
| Dev Handoff | Orienta execução por domínio | Não cria regra soberana |
| UI/UX Spec | Define experiência por superfície | Não calcula verdade crítica |
| Gates | Provam funcionamento real | Não substituem regra canônica |
| Red Team / Skills | Auditam conformidade | Não autorizam expansão fora da ordem |

### 0.2 Substituição da versão 5.1

```text
KORTEXOS_5_1_1_MASTER_BRIEFING_CANONICO.md substitui integralmente
KORTEXOS_5_1_MASTER_BRIEFING_CANONICO_REWRITE.md.
A versão 5.1 permanece apenas como referência histórica de promoção.
Não manter duas fontes canônicas ativas.
```

### 0.3 Regra contra dupla verdade

```text
KortexOS™ é o nome comercial e operacional canônico.
HOPE OS vira legado histórico interno.
SMART Flow™ vira legado conceitual/arquitetural da fase 4.0.
Nenhum documento futuro pode tratar HOPE OS, SMART Flow™ e KortexOS™ como produtos paralelos.
```

### 0.4 Regra de promoção sem implementação

```text
A promoção para KortexOS™ 5.1.1 não cria tabela, endpoint, tela, app, IA, automação, gateway, ledger, job ou migration.
Primeiro governa.
Depois compara.
Depois classifica.
Depois desenha Blueprint.
Depois materializa SQL.
```

### 0.5 Regra de atualização

Toda mudança canônica exige:

1. decisão explícita do Platform Owner;
2. registro de versão;
3. reescrita integral da seção afetada;
4. atualização de gates impactados;
5. atualização de RAGOV;
6. rastreabilidade interna;
7. veredito Red Team;
8. bloqueio de implementação até Blueprint aprovado.

Patch, delta solto, remendo, documento paralelo, cálculo frontend e engine duplicada são proibidos.

---

## 1. Identidade e tese Intelligent Capacity

### 1.1 Nome canônico

**KortexOS™**

### 1.2 Categoria canônica

**Intelligent Capacity, Fintech & Decision Operating System for Beauty & Wellness**

### 1.3 Definição operacional

KortexOS™ é um sistema operacional de capacidade, dinheiro, confiança, recorrência, atendimento, execução e decisão para negócios de beleza e bem-estar.

```text
Agenda é a superfície.
Capacidade perecível é o produto.
Dinheiro é o núcleo de verdade.
Decisão matemática é o diferencial.
Automação governada é o multiplicador.
Execução auditável é o moat.
```

### 1.4 Tese central

KortexOS™ não compete como agenda online. Compete como infraestrutura operacional para transformar tempo disponível em receita protegida, previsível e auditável.

O problema real do salão não é apenas “ter horários disponíveis”. O problema é:

- ocupar horários fracos;
- preservar margem;
- reduzir no-show;
- vender recorrência;
- proteger comissão;
- controlar gorjeta;
- saber quem deve o quê;
- saber qual cliente é confiável;
- saber qual benefício tem origem;
- saber qual parceiro traz margem;
- reduzir dependência do dono.

### 1.5 Promessa principal

```text
Menos buraco na agenda.
Mais ocupação nos dias fracos.
Mais receita por hora disponível.
Mais recorrência.
Mais caixa previsível.
Mais margem protegida.
Mais confiança operacional.
Menos improviso.
Menos dependência do dono.
```

### 1.6 Tese de mercado

O mercado global de beauty/wellness já opera com booking, pagamentos, memberships, marketing e marketplace. O KortexOS™ não deve tentar vencer copiando feature por feature. O diferencial canônico é combinar:

| Eixo | Diferencial KortexOS™ |
|---|---|
| Capacidade | Booking Candidate, Smart Gap, Yield, Occupancy Engines |
| Recorrência | Subscription, Corporate Benefits, Partner Benefits |
| Finanças | KortexFlow, ledger double-entry, wallet, staff account |
| Confiança | Reliability Score, no-show progressivo, Trust Pass, Healing |
| IA | compreensão e triagem com Action Request, sem soberania |
| Execução | backend como única fonte de verdade, gates e auditoria |

---

## 2. Ecossistema das 5 soluções globais

KortexOS™ é o ecossistema. As soluções abaixo são superfícies/camadas do mesmo core. Nenhuma solução cria verdade paralela.

| Solução | Papel | Limite canônico |
|---|---|---|
| **kortex.io** | Portal SaaS, administração, onboarding, billing, cockpit web, página pública, aquisição e gestão de tenants | Não calcula regra crítica no frontend |
| **KortexApp** | Aplicação mobile/PWA para dono, gerente, staff, recepção, cliente, empresa e parceiro | Exibe dados, dispara Commands e consome projections |
| **Kortex.ai** | Camada de IA consultiva: intenção, triagem, explicação, copiloto e recomendação | Nunca escreve verdade crítica soberanamente |
| **KortexFlow** | Fintech core: checkout, pagamentos, ledger, wallet, staff account, corporate billing, partner settlement e payout | Toda mutação financeira exige backend, idempotência e ledger |
| **KortexLink** | Circuito de ativação: WhatsApp, SMS, e-mail, push, QR, links, webhooks, parceiros, campanhas e waitlist | Mensagem não altera verdade diretamente |

### 2.1 Regra de core único

```text
Cinco soluções, um único core.
Nenhuma superfície possui engine paralela de agenda, preço, saldo, benefício, comissão, pagamento ou confiança.
```

### 2.2 Persona por solução

| Persona | kortex.io | KortexApp | Kortex.ai | KortexFlow | KortexLink |
|---|---|---|---|---|---|
| Platform Owner | SaaS, billing, tenants, gates | Cockpit platform | Auditoria assistida | Billing SaaS | Comunicação platform |
| Dono | Cockpit, KPIs, regras | Agenda, caixa, margem | CoPilot | Caixa, ledger, payout | Campanhas e alertas |
| Gerente | Operação e equipe | Agenda e execução | Sugestões operacionais | Fechamento e conferência | Confirmações |
| Staff | Perfil e agenda | Agenda, produção, repasses | Apoio consultivo | Staff account | Lembretes |
| Cliente | Página e portal | Booking, planos, wallet | Atendimento assistido | Pagamento e créditos | WhatsApp/QR/link |
| Empresa corporativa | Contrato e analytics agregado | Portal agregado futuro | FAQ / triagem | Billing corporativo | Convites e links |
| Parceiro local | Portal/link/QR | Performance futuro | Recomendação de campanhas | Settlement se houver fee | QR, link, campanha |

---

## 3. Princípios econômicos e mitigação de custo de IA

### 3.1 Regra homem × máquina

KortexOS™ estabelece uma fronteira rígida entre linguagem natural e decisão crítica.

| Camada | Pode usar IA | Deve ser determinística |
|---|---:|---:|
| Entender intenção | Sim | Não obrigatório |
| Classificar pedido | Sim | Backend valida |
| Sugerir texto | Sim | Não crítico |
| Buscar disponibilidade | Não | Sim |
| Confirmar agenda | Não soberanamente | Sim |
| Calcular preço | Não | Sim |
| Calcular comissão | Não | Sim |
| Liberar benefício | Não | Sim |
| Liberar fiado | Não | Sim |
| Criar ledger | Nunca | Sim |
| Perdoar no-show | Não | Action Request + backend |

### 3.2 Regra econômica

```text
IA é cara quando decide.
IA é barata quando entende linguagem.
Decisão recorrente vira regra matemática backend.
Exceção sensível vira Action Request.
```

### 3.3 Invariante de custo

Kortex.ai deve reduzir custo operacional humano sem criar custo variável imprevisível de tokens para decisões repetitivas. O backend calcula disponibilidade, score, confiança, benefício, preço, comissão, wallet e ledger sem depender de modelo generativo.

### 3.4 Action Request como fronteira

A IA pode propor uma ação. O backend decide se ela é permitida. O humano aprova quando a ação altera dinheiro, reputação, política, confiança, agenda sensível, exceção ou relacionamento.


### 3.5 Regra matemática antes da automação

```text
Primeiro medir.
Depois modelar.
Depois recomendar.
Depois aprovar.
Depois automatizar.
Somente então aprender.
```

O backend deve preferir, nesta ordem:

1. regras determinísticas e constraints;
2. estatística descritiva e suavização;
3. modelos tabulares probabilísticos;
4. otimização matemática;
5. experimentação causal e uplift;
6. contextual bandits;
7. aprendizado por reforço apenas quando houver justificativa econômica, simulação e governança.

LLM não substitui função objetivo, constraint, política, transação, ledger ou experimento.

### 3.6 Invariante de eficiência de custo

A primeira geração do motor deve aproveitar PostgreSQL/Supabase, Node/Express, jobs, materialized views, funções SQL, outbox e pequenos workers sob demanda. Data lake, Kafka, GPU, feature store externo, microserviços excessivos e MLOps completo são bloqueados enquanto não houver escala comprovada.

---

## 4. Arquitetura de camadas e superfícies

### 4.1 Camadas canônicas

| Camada | Nome | Responsabilidade | Gate mínimo |
|---:|---|---|---|
| 0 | Platform & Isolation | SaaS, tenants, RLS, roles, release, gates | 00/01/22 |
| 1 | Foundation Core | Pessoas, catálogo, setup, agenda base, recursos | 00–08 |
| 2 | Capacity Intelligence | Booking Candidate, Smart Gap, Slot Score, Resource Locks, Yield | 03–09 |
| 3 | Decision & Optimization | Feature tables, heatmaps, expected value, matching, constraints e explainability | 09/19/25 |
| 4 | KortexFlow | Checkout, payment, ledger, wallet, staff account, compensation | 10–15/18 |
| 5 | Revenue & Occupancy | Assinaturas, corporativo, parcerias, pacotes, benefícios, CRM | 15/19 |
| 6 | Automation & Activation | Contact Orchestrator, outbox, KortexLink, Action Requests, campanhas e API booking | 16/17/20/25 |
| 7 | Scale & Learning | Causal ML, bandits, marketplace, multiunidade, white-label, API e enterprise | 19/20/23/24/25 |

### 4.2 Superfícies

| Superfície | Função | Proibição |
|---|---|---|
| App dono | Cockpit, agenda, caixa, margem, ocupação, decisões | Não editar ledger |
| App gerente | Operação diária, equipe, agenda, checkout | Não bypassar política |
| App profissional | Agenda, produção, comissão, repasse | Não ver financeiro alheio |
| PWA cliente | Booking, assinatura, benefício, carteira, histórico | Não confirmar agenda direta |
| Portal empresa | Contrato, elegíveis, uso agregado, faturamento | Não ver dados sensíveis individuais |
| Portal parceiro | Links, QR, campanhas, conversão, margem agregada | Não acessar histórico individual |
| WhatsApp/Link/QR | Ativação e intenção | Não escrever verdade diretamente |
| API/Webhooks | Integração governada | Não bypassar Command |

---

## 5. Domínios canônicos D00–D31

KortexOS™ 5.1.1 preserva a grade D00–D31. Não há renumeração. Não há domínio novo. Novos motores entram como evolução de domínios existentes.

| Domínio | Nome KortexOS™ 5.1.1 | Responsabilidade |
|---:|---|---|
| D00 | Platform Owner Layer | Operação platform, release, suporte, saúde de tenants |
| D01 | Identity & Tenant | Tenants, unidades, memberships, papéis, RLS |
| D02 | Business Configuration & Policy Layer | Fonte canônica de dados cadastrais, configurações, políticas e padrões herdáveis (empresa → unidade); inclui Calendar Policy & Availability Layer. Especificação integral na PARTE III |
| D03 | Onboarding SaaS | Ativação, setup, readiness, trial, plano |
| D04 | SaaS Billing & Platform Finance | Cobrança SaaS sem misturar com checkout tenant |
| D05 | People Hub | Clientes, staff, preferências, consentimentos, horários de staff |
| D06 | Catalog & Offer Hub | Serviços, produtos, preços base, duração, add-ons, yield profiles |
| D07 | Capacity Scheduling Engine | Disponibilidade, Booking Candidate, Smart Gap, Slot Score, Yield |
| D08 | Agenda Core | Appointments, holds, cancelamento, no-show, histórico |
| D09 | Recurring Appointment Engine | Séries recorrentes, ocorrências, pausas, exceções |
| D10 | Group Booking Engine | Agendamento em grupo, participantes, pagador, beneficiários |
| D11 | Resource Orchestration | Recursos físicos, locks, manutenção, capacidade |
| D12 | Checkout Core | Sessão de checkout, totais, descontos, gorjeta, consumo de benefício |
| D13 | Payment Core | Pagamentos, depósitos, COF tokenizado, reembolso, PSP events |
| D14 | Cash & Register Management | Caixa, sangria, suprimento, fechamento, divergências |
| D15 | KortexFlow Ledger | Ledger double-entry append-only, reversões, reconstrução |
| D16 | Wallet & Current Accounts | Client wallet, staff current account, créditos e projeções |
| D17 | Compensation & Payout Engine | Comissão, gorjeta, repasses, privacidade financeira de staff |
| D18 | Subscription, Packages, Corporate Benefits & Partner Occupancy Engine | Assinaturas, pacotes, corporativo, parcerias, benefícios e ocupação |
| D19 | Client Experience Hub | Portal/PWA cliente, booking intent, benefícios visíveis |
| D20 | Public Web Presence / kortex.io | Página pública, SEO, links, ofertas publicadas |
| D21 | KortexLink Messaging & Conversations | WhatsApp, SMS, e-mail, push, templates, consentimento |
| D22 | Kortex.ai Receptionist Engine | IA consultiva, triagem, Action Request, handoff humano |
| D23 | Revenue CoPilot & Opportunity Engine | Fila de oportunidades, expected value, matching, boosters, recomendações e explicações |
| D24 | Trust, Retention & Lifecycle Engine | Reliability Score, CRM, ciclo esperado, churn, rebooking, reativação, no-show, Trust Pass e Healing |
| D25 | Analytics, Experimentation & Decision Intelligence | Ocupação, RevPAH, margem, cohorts, heatmaps, grupos de controle, uplift e dashboards reconstruíveis |
| D26 | Fiscal & LGPD Brasil | NFS-e, LGPD, consentimentos, fiscal. Dados sensíveis (anamnese/saúde) especificados em Parte II §13 — consentimento art. 11,I, isolado do cadastro base |
| D27 | Marketplace & Partner Network | Marketplace, rede local, parceiros, descoberta, aquisição |
| D28 | Multiunit Enterprise | Multiunidade, consolidação, ledgers separados |
| D29 | White-Label App | Marca, domínio, app white-label sem core paralelo |
| D30 | Integration Platform | API pública, webhooks, scopes, retry, outbox |
| D31 | Gate, QA & Governance | Gates, Red Team, rollback, release, QA, evidências |

### 5.1 Regra de evolução sem domínio novo

| Evolução | Domínios impactados |
|---|---|
| KortexFlow | D12/D13/D14/D15/D16/D17 |
| Kortex.ai | D22/D23/D24/D31 |
| KortexLink | D21/D30/D31 |
| Kortex Autonomous Operations | D05/D06/D07/D08/D11/D18/D21/D22/D23/D24/D25/D30/D31 |
| Intelligent Waitlist Recovery | D07/D08/D21/D23/D24/D25/D30 |
| API Booking Orchestration | D07/D08/D12/D13/D21/D30/D31 |
| Incrementality & Experimentation | D23/D24/D25/D31 |
| Subscription Engine | D18/D12/D15/D16/D25 |
| Corporate Benefits | D18/D04/D12/D15/D16/D21/D25/D26 |
| Partner Benefits | D18/D21/D25/D27/D30 |
| Yield & Occupancy | D07/D18/D23/D24/D25 |
| Negative Guard | D02/D12/D13/D15/D16/D17/D18/D24 |

---

## 6. Kortex.ai — governança e soberania

### 6.1 Responsabilidade

Kortex.ai é a camada de compreensão, triagem, recomendação, copiloto e atendimento assistido. Ela não possui soberania sobre agenda, dinheiro, comissão, saldo, benefício, política, score ou ledger.

### 6.2 Matriz de soberania

| Ação | IA pode fazer? | Precisa humano? | Backend valida? | Status |
|---|---:|---:|---:|---|
| Entender mensagem | Sim | Não | Sim | REAL |
| Classificar intenção | Sim | Não | Sim | REAL |
| Extrair serviço, profissional, data e período | Sim | Não | Sim | PARCIAL até gate |
| Resumir conversa e handoff | Sim | Não | Sim | PARCIAL até gate |
| Explicar política | Sim | Não | Sim | REAL |
| Mostrar horários retornados pelo backend | Sim | Não | Sim | REAL |
| Gerar Booking Intent | Sim | Não/depende | Sim | REAL |
| Confirmar appointment | Não soberanamente | Depende | Sim | CRÍTICO |
| Cobrar depósito | Não soberanamente | Política/Command | Sim | CRÍTICO |
| Liberar desconto | Não soberanamente | Sim/política | Sim | CRÍTICO |
| Perdoar no-show | Não | Sim | Sim | CRÍTICO |
| Liberar fiado | Não | Sim/política | Sim | CRÍTICO |
| Alterar comissão | Não | Sim | Sim | BLOQUEADO sem AR |
| Criar ledger | Nunca | Não | Command financeiro | BLOQUEADO |
| Enviar campanha sensível | Não soberanamente | Política/consentimento | Sim | CRÍTICO |

### 6.3 Action Requests obrigatórios

Kortex.ai cria Action Request quando a sugestão impacta:

- dinheiro;
- desconto;
- fiado;
- comissão;
- payout;
- benefício;
- exceção de política;
- no-show;
- reputação;
- campanha;
- dados sensíveis;
- agenda premium.

### 6.4 Proibições

```text
IA não agenda direto.
IA não cobra direto.
IA não perdoa direto.
IA não altera comissão.
IA não cria ledger.
IA não muda política.
IA não inventa preço.
IA não valida benefício sozinha.
IA não decide yield soberanamente.
IA não calcula score econômico soberanamente.
IA não seleciona tratamento causal soberanamente.
IA não cria ou confirma hold fora do Booking Orchestrator.
```

---

## 7. KortexFlow — financial core

### 7.1 Definição

KortexFlow é o núcleo financeiro do KortexOS™. Ele controla checkout, pagamento, carteira, ledger, conta corrente do profissional, gorjeta, comissão, repasse, saldo do cliente, crédito corporativo, benefício de parceiro, assinatura, estorno e reconciliação.

### 7.2 Invariantes financeiras

| Regra | Definição |
|---|---|
| Anti-CRUD | Ledger é append-only; UPDATE/DELETE proibidos em entradas críticas |
| Double-entry | Débitos e créditos sempre fecham em soma zero |
| `_cents bigint` | Todo dinheiro usa centavos inteiros |
| Idempotência | Mutação financeira exige `idempotency_key` |
| Reversão | Correção financeira é lançamento reverso, não edição |
| Reconstrução | Saldo verdadeiro é reconstruível pelo ledger |
| Tip isolation | Gorjeta não vira receita do salão nem base de comissão |
| Staff protection | Profissional não financia fiado autorizado do cliente |
| Backend-only | Frontend nunca calcula total, saldo, taxa, comissão ou benefício |

### 7.3 Fluxos financeiros obrigatórios

| Fluxo | Pipeline canônico |
|---|---|
| Venda normal | checkout → payment → ledger → commission → projection |
| Venda com gorjeta | checkout → tip allocation → ledger tip account → staff current account |
| Venda com assinatura | cobrança → obrigação/benefício → consumo no checkout → reconhecimento/reclassificação |
| Plano corporativo | contrato empresa → elegibilidade funcionário → consumo → billing/ledger → analytics agregado |
| Parceria local | origem parceiro → benefício → checkout → conversão → analytics/CAC/margem |
| Fiado autorizado | Negative Guard → client wallet negativo → staff liquidado → dívida do salão contra cliente |
| Estorno | refund → reversal ledger → wallet/commission adjustment via Command |
| Payout semanal | staff current account → payout batch → payment → ledger reversal/settlement |
| Cashback | grant com origem → wallet/benefit → consumo → ledger/projection |

### 7.4 Objetos conceituais mínimos

| Objeto | Função |
|---|---|
| `kortex_accounts` | Plano de contas financeiro |
| `kortex_ledger_transactions` | Cabeçalho da transação |
| `kortex_ledger_entries` | Lançamentos double-entry append-only |
| `kortex_account_balances` | Projeção reconstruível de saldo |
| `client_wallets` | Carteira do cliente |
| `staff_current_accounts` | Conta corrente do profissional |
| `benefit_obligations` | Obrigações de consumo de planos/pacotes/corporativo/parceiro |
| `payout_batches` | Lotes de repasse |

**Observação:** nomes finais exigem Migration Map. Esta seção define responsabilidade, não SQL.

---

## 8. Staff Current Account & Payout Protection

### 8.1 Tese

```text
Profissional não financia o cliente.
Profissional não depende de cálculo manual.
Profissional não perde gorjeta por mistura contábil.
```

### 8.2 Responsabilidade

A conta corrente do profissional controla produção, comissão, gorjeta, ajustes aprovados, adiantamentos, repasses, estornos e saldo projetado.

### 8.3 Regras

| Regra | Status |
|---|---|
| Comissão nasce de venda real | CRÍTICO |
| Comissão calcula no backend | CRÍTICO |
| Gorjeta é isolada 100% para o destinatário | CRÍTICO |
| Staff não vê financeiro alheio | CRÍTICO |
| Ajuste manual exige Action Request | CRÍTICO |
| Repasse semanal usa payout batch | REAL como tese |
| Estorno ajusta por lançamento reverso | CRÍTICO |
| Comissão negativa silenciosa é proibida | BLOQUEADO |

### 8.4 Modelos nativos de comissão

| Modelo | Regra |
|---|---|
| Bruto Salão | Salão absorve taxa; comissão sobre bruto líquido de desconto |
| Dividido / Parceiro | Taxa deduzida antes do comissionamento |
| Bruto Staff | Profissional absorve taxa sobre parte dele |

---

## 9. Client Wallet

### 9.1 Definição

Client Wallet é a carteira financeira e operacional do cliente. Ela pode representar crédito, saldo, benefício, reembolso, cashback, consumo de pacote, assinatura, crédito corporativo ou dívida autorizada.

### 9.2 Estados

| Estado | Significado | Regra |
|---|---|---|
| Saldo positivo | Cliente possui crédito real | Reconstruível pelo ledger |
| Saldo zero | Sem crédito ou dívida | Normal |
| Saldo negativo autorizado | Fiado governado | Exige Negative Guard |
| Crédito promocional | Benefício com origem e validade | Não vira dinheiro livre |
| Crédito corporativo | Benefício de contrato B2B | Regras do contrato |
| Crédito de parceiro | Benefício de origem rastreável | Regra de parceria |
| Cashback | Crédito futuro | Origem, validade e consumo |
| Reembolso | Devolução/reversão | Ledger reversal |

### 9.3 Proibições

```text
Saldo paralelo é proibido.
Benefício sem origem é proibido.
Crédito sem validade quando exigida é proibido.
Saldo editado manualmente é proibido.
Frontend calculando saldo é proibido.
```

---

## 10. Negative Guard

### 10.1 Definição

Negative Guard é o mecanismo que impede que fiado, benefício, assinatura, parceria, plano corporativo, desconto ou exceção destrua margem, caixa, comissão ou confiança operacional.

### 10.2 Escopo

| Caso | O que o Negative Guard protege |
|---|---|
| Fiado | Limite, confiança, dívida e liquidação do staff |
| Assinatura | Margem mínima, uso indevido, abuso de frequência |
| Plano corporativo | Contrato, limite, elegibilidade e margem por empresa |
| Parceria | Janela, limite, origem e CAC por parceiro |
| Desconto | Receita líquida e comissão |
| Premium window | Horário nobre sem benefício agressivo |
| Cliente de risco | Depósito, pré-pagamento ou bloqueio |

### 10.3 Regras obrigatórias

| Regra | Status |
|---|---|
| Fiado só com Trust Pass ou aprovação/política | CRÍTICO |
| Profissional liquidado no ato quando fiado é autorizado | CRÍTICO |
| Dívida fica sob risco do salão | CRÍTICO |
| Benefício não pode gerar margem negativa invisível | CRÍTICO |
| Plano agressivo deve ser limitado a baixa ocupação | REAL como tese |
| Desconto em horário nobre exige regra superior | CRÍTICO |

---

## 11. No-show, Client Reliability Score, Trust Pass e Healing

### 11.1 Tese

KortexOS™ não deve educar cliente por punição retroativa agressiva. Deve usar fricção progressiva, previsível e explicável.

### 11.2 Régua progressiva

| Evento | Ação |
|---|---|
| 1ª falta | Aviso elegante e educativo |
| 2ª falta | Sinal compulsório de 50% no próximo agendamento elegível |
| 3ª falta ou recorrência | Pré-pagamento de até 100% conforme política |
| 3 atendimentos seguidos concluídos | Healing parcial/total conforme regra |
| Histórico excelente | Trust Pass para reduzir fricção |

### 11.3 Client Reliability Score

O score deve considerar:

- faltas;
- atrasos;
- cancelamentos tardios;
- reagendamentos excessivos;
- atendimentos concluídos;
- pagamentos bem-sucedidos;
- uso correto de assinatura;
- uso correto de benefício corporativo;
- uso correto de benefício parceiro;
- exceções aprovadas;
- histórico de chargeback/estorno;
- tempo desde o último problema.

### 11.4 Proibições

```text
No-show não pode ser apagado do histórico.
IA não pode perdoar falta.
Recepção não pode remover fricção sem Action Request quando política exigir.
Score fake é proibido.
```

---


## 12. Kortex Autonomous Operations Engine

### 12.1 Definição canônica

O Kortex Autonomous Operations Engine é o runtime transversal que converte eventos operacionais em decisões, recomendações e Commands permitidos. Ele não cria domínio D32 e não possui banco paralelo.

```text
Domain Event
→ Feature/Heatmap Refresh
→ Eligibility Engine
→ Policy Engine
→ Expected Value & Matching
→ Contact Orchestrator
→ Action Request ou Approved Command
→ Transactional Outbox
→ Canal/API
→ Outcome Event
→ Attribution & Incrementality
```

### 12.2 Componentes

| Componente | Responsabilidade | Domínios principais |
|---|---|---|
| Customer Timing Engine | Estimar ciclo esperado e atraso normalizado | D05/D24/D25 |
| Demand & Occupancy Engine | Estimar ocupação e risco de slot vazio | D07/D11/D25 |
| Economic Value Engine | Calcular margem esperada, custo e risco | D06/D12/D17/D23/D25 |
| Matching & Optimization Engine | Selecionar combinações cliente-serviço-profissional-slot-ação | D07/D08/D23/D25 |
| Incrementality Engine | Medir efeito causal e canibalização | D23/D24/D25/D31 |
| Contact & Policy Orchestrator | Prioridade, consentimento, frequência, supressão e conflito | D02/D21/D24/D26 |
| Automation Control Plane | Modo, rollout, versão, kill switch, circuit breaker e rollback | D30/D31 |
| Booking Orchestrator | Disponibilidade, hold, confirmação, cancelamento e integração de agenda | D07/D08/D30 |

### 12.3 Quatro mapas canônicos

#### Customer Heatmap

- frequência e intervalo entre visitas;
- dias e horários habituais;
- serviços e categorias consumidas;
- profissional preferido;
- ticket, margem e recorrência;
- resposta a campanhas;
- risco de no-show e fadiga de comunicação.

#### Professional Heatmap

- ocupação por faixa horária;
- serviços autorizados;
- duração real e prevista;
- ticket e margem por hora;
- retenção de carteira;
- cancelamentos, atrasos e disponibilidade futura.

#### Occupancy Heatmap

- capacidade disponível e utilizável;
- ocupação histórica e futura;
- demanda por antecedência, dia e horário;
- gaps, premium windows e risco de sobrecarga;
- recursos, buffers e restrições de unidade.

#### Economic Heatmap

- margem de contribuição;
- comissão, taxa de pagamento e custo de benefício;
- receita por hora disponível;
- custo do canal;
- probabilidade de venda natural;
- valor econômico da capacidade recuperada.

**Invariante:** slot livre não é automaticamente capacidade vendável. Deve existir profissional, serviço, recurso, duração, buffer, margem e política compatíveis.

### 12.4 Customer Timing Engine

A regra fixa de 45 dias é apenas fallback de cold start. O retorno esperado deve combinar histórico individual, serviço e segmento.

\[
I_{c,s}=\alpha \cdot mediana_{cliente,serviço}+\beta \cdot mediana_{serviço}+\gamma \cdot mediana_{segmento}
\]

```text
α + β + γ = 1
mais histórico individual → maior α
menos histórico individual → maior β/γ
```

Índice de atraso:

\[
DelayRatio_{c,s}=\frac{dias\ desde\ a\ última\ visita}{intervalo\ esperado}
\]

Faixas iniciais são hipóteses versionadas, não verdade universal:

| Delay Ratio | Estado inicial |
|---:|---|
| < 0,80 | NOT_DUE |
| 0,80–1,05 | DUE_SOON |
| 1,05–1,35 | OVERDUE |
| 1,35–2,00 | AT_RISK |
| > 2,00 | LAPSED |

### 12.5 Expected Value e função objetivo

Valor esperado mínimo:

\[
EMV=P(aceite)\times P(comparecimento)\times margem-custo_{canal}-custo_{benefício}-custo_{risco}
\]

Valor incremental:

\[
IncrementalValue=(P(resultado|ação)-P(resultado|sem\ ação))\times margem-custo_{ação}
\]

Restrições duras vêm antes da otimização:

1. integridade e isolamento;
2. consentimento e finalidade;
3. disponibilidade e não conflito;
4. capacidade e compatibilidade;
5. política financeira e de benefício;
6. idempotência e auditabilidade.

Objetivos suaves podem combinar margem incremental, retenção, capacidade recuperada, fit do cliente e fairness. Pesos são hipóteses versionadas e exigem análise de sensibilidade.

### 12.6 Matching e otimização

Primeira versão: SQL + score determinístico + ordenação.

Segunda versão: min-cost flow para atribuições simples.

Terceira versão: CP-SAT/OR-Tools quando houver duração variável, recursos compartilhados, múltiplos serviços, buffers, precedência e restrições de equipe.

```text
maximizar margem incremental esperada
sujeito a capacidade, consentimento, frequência, orçamento,
compatibilidade, disponibilidade, fairness e não duplicidade
```

O solver produz plano. Commands backend validam novamente e executam. O solver não escreve diretamente em agenda, pagamento, benefício ou ledger.

### 12.7 Incrementality Engine

Conversão observada não prova efeito causal. Toda automação comercial deve suportar grupo de controle ou holdout quando o volume permitir.

```text
Incremental Lift = conversão_tratamento - conversão_controle
Incremental Margin = margem_tratamento - margem_controle - custo_da_ação
```

Evolução permitida:

| Nível | Técnica | Status |
|---:|---|---|
| 1 | Regras determinísticas | P0 |
| 2 | Regressão/estatística/survival | P2 |
| 3 | Uplift multi-treatment | P2 após experimentação |
| 4 | Contextual bandit | P3 |
| 5 | Reinforcement learning | BLOQUEADO no MVP |

### 12.8 Contact & Policy Orchestrator

O mesmo cliente não pode receber fluxos conflitantes. Prioridade inicial:

```text
segurança/incidente
> reclamação e recuperação
> cobrança sensível
> agendamento transacional
> confirmação e waitlist
> rebooking
> retenção/reativação
> assinatura/VIP
> marketing amplo
```

Controles obrigatórios:

- limite global por cliente, canal e finalidade;
- consentimento por propósito;
- quiet hours e timezone;
- supressão por reclamação, opt-out, agendamento futuro ou contato humano recente;
- deduplicação entre campanhas;
- exclusão de clientes em outro hold;
- explicação de por que agir ou não agir.

### 12.9 Registro Canônico de Automações

Cada automação exige:

| Campo | Obrigatório |
|---|---:|
| Evento disparador | Sim |
| Objetivo e owner | Sim |
| Elegibilidade e exclusões | Sim |
| Política/versionamento | Sim |
| Command permitido | Sim |
| Aprovação necessária | Sim |
| Canal/finalidade | Sim |
| Frequency cap | Sim |
| Idempotency key | Sim |
| Métrica e custo | Sim |
| Grupo de controle | Quando comercial |
| Kill switch/circuit breaker | Sim |
| Rollback | Sim |
| Reason codes | Sim |

### 12.10 Modos de maturidade

```text
OBSERVE
→ RECOMMEND
→ APPROVE
→ LIMITED_AUTOMATION
→ FULL_AUTOMATION
```

Nenhuma automação crítica estreia em `FULL_AUTOMATION`.

### 12.11 Portfólio prioritário

| Prioridade | Automação | Objetivo | Risco dominante |
|---:|---|---|---|
| P1 | Rebooking pós-atendimento | Evitar churn antes do atraso | frequência excessiva |
| P1 | Confirmação adaptativa | Reduzir no-show | tratamento injusto |
| P1 | Waitlist Recovery | Recuperar cancelamento | concorrência de slot |
| P1 | Reativação por ciclo | Recuperar cliente atrasado | canibalização/desconto |
| P1 | Upsell compatível com slot | Elevar margem por visita | atraso operacional |
| P1 | Reconciliação financeira | Proteger dinheiro | divergência silenciosa |
| P2 | Compactação voluntária | Reduzir gaps | piorar experiência |
| P2 | Agenda recorrente preventiva | Aumentar previsibilidade | conflito futuro |
| P2 | Assinatura/off-peak | Deslocar demanda | plano deficitário |
| P2 | VIP e acesso antecipado | Relacionamento e ativação | virar canal de desconto |
| P3 | Staffing/estoque preditivo | Planejar capacidade | dados operacionais fracos |

### 12.12 Reativação e win-back

A jornada canônica é progressiva:

1. lembrete sem incentivo;
2. conveniência e horário compatível;
3. valor agregado de baixo custo marginal;
4. benefício restrito a capacidade ociosa;
5. downsell apenas como último estágio e para segmento compatível.

Campanha encerra quando houver agendamento, opt-out, resposta negativa, reclamação, contato humano recente ou fluxo superior.

### 12.13 Intelligent Waitlist Recovery

```text
waitlist_request ativo
+ vaga liberada
+ matching compatível
→ oferta em ondas
→ primeiro aceite cria hold
→ confirmação transacional
→ demais ofertas invalidadas
```

Dados mínimos incluem serviço, profissionais aceitos, datas/faixas, antecedência, alternativas, validade e consentimento. Estados mínimos:

```text
ACTIVE → MATCHED → OFFERED → HOLDING → BOOKED
                  ↘ DECLINED / EXPIRED / SUPPRESSED
```

Lista sem expiração, convite sem hold ou confirmação apenas por mensagem são CRÍTICOS.

### 12.14 VIP e canais de relacionamento

Modelo recomendado:

```text
Canal WhatsApp VIP para distribuição
+ conversa individual para conversão
+ KortexOS para segmentação, elegibilidade e mensuração
```

Grupo aberto de WhatsApp não é núcleo por risco de privacidade, ruído e moderação. Telegram pode ser laboratório técnico, mas sua aderência comercial é DESCONHECIDA.

VIP significa acesso, prioridade, experiências e horários especiais; não desconto constante.

### 12.15 Agendamento automático por API

Fluxo seguro:

```text
intent
→ disponibilidade real
→ seleção
→ booking hold com expiração
→ confirmação
→ Command idempotente
→ appointment confirmado
→ mensagem transacional
```

Requisitos:

- API oficial ou agenda canônica do KortexOS;
- disponibilidade em tempo real;
- hold transacional;
- idempotency key;
- webhooks verificados;
- retry sem duplicidade;
- fallback humano sem falsa confirmação;
- adaptador `BookingProvider` para fornecedores externos.

Se a agenda externa não possui API transacional, o fluxo é assistido, não automático. Duas fontes independentes de verdade para agenda são BLOQUEADAS.

### 12.16 Papel do bot e da IA

Bot/IA podem:

- interpretar intenção;
- extrair serviço, profissional, data e período;
- apresentar opções autorizadas;
- resumir contexto;
- gerar texto e handoff.

Bot/IA não podem:

- calcular preço ou comissão;
- criar desconto ou benefício;
- inventar disponibilidade;
- confirmar sem transação;
- ignorar consentimento;
- escolher política causal soberanamente;
- escrever ledger.

### 12.17 Red Team e controles de segurança

Piores cenários:

- confirmação de horário inexistente;
- duas reservas para o mesmo slot;
- desconto para quem voltaria sem incentivo;
- campanha durante reclamação aberta;
- agenda cheia com margem pior e atrasos maiores;
- score enviesado penalizando clientes;
- automação aprendendo com dados gerados pela própria política sem correção causal;
- falha de provedor gerando retries destrutivos.

Toda automação exige kill switch, circuit breaker, observabilidade, reason codes, métricas de dano e rollback.


### 12.18 Catálogo de automações por família

| Família | Automações canônicas exploráveis |
|---|---|
| Capacidade e agenda | waitlist recovery, preenchimento de cancelamento, compactação voluntária, encaixe de add-ons, agenda recorrente, proteção de premium window, reacomodação assistida |
| Retenção e relacionamento | rebooking, reativação progressiva, churn parcial por categoria, indicação contextual, marcos de relacionamento, recuperação de experiência negativa |
| Receita e margem | next best action, upsell contextual, downsell controlado, assinatura adequada, proteção de margem/hora, revisão de preço e duração |
| Confiança e no-show | confirmação adaptativa, depósito por política, healing, prevenção de agenda especulativa, liberação controlada de slot |
| Assinaturas | renovação, dunning, uso de saldo, migração de plano, pausa assistida, prevenção de abuso |
| Financeiro | reconciliação PSP/checkout/ledger, comissão auditável, payout, fechamento de caixa, detecção de vazamento de margem |
| Operação e equipe | atraso em cascata, check-in, fila de chegada, recomendação de escala, previsão de insumos, manutenção de recursos |
| Aquisição e rede | VIP, parceiros, corporate, referral, conversão de canal adquirido para relacionamento próprio |
| Atendimento | recepcionista de intenção, classificação de motivo, resumo e handoff, booking assistido |

**Regra de prioridade:** automatizar primeiro falhas repetitivas, transacionais e mensuráveis. Adiar decisões raras, reputacionais ou com baixa qualidade de dados.

---

## 13. Yield & Occupancy Management

### 13.1 Tese

Yield no KortexOS™ não é apenas subir ou baixar preço. Yield é alocar demanda, preço, benefício e conveniência para maximizar ocupação, margem e previsibilidade.

```text
Yield direto = preço muda.
Yield indireto = assinatura, corporativo e parceria deslocam demanda para horários fracos.
```

### 13.2 Mecanismos

| Mecanismo | Função |
|---|---|
| Desconto off-peak | Preencher baixa ocupação |
| Acréscimo fora de horário | Monetizar conveniência |
| Premium window | Proteger horário nobre |
| Assinatura terça–quinta | Comprar recorrência em dias fracos |
| Plano corporativo off-peak | Ocupar agenda morta com contrato B2B |
| Parceria local | Aquisição qualificada em horários específicos |
| Waitlist econômica | Recuperar cancelamento |
| Slot Score | Ranqueia melhor horário para o negócio |

### 13.3 Regras de acréscimo de conveniência

| Caso | Regra base |
|---|---|
| Antes da abertura | +10% configurável |
| Após fechamento | +10% configurável |
| Domingo/feriado selecionado | +10% adicional configurável |
| Acúmulo | Permitido conforme política |

### 13.4 Bloqueios

```text
Dynamic pricing automático sem política é bloqueado.
Desconto que mascara prejuízo é bloqueado.
Benefício off-peak usado em horário nobre sem regra é bloqueado.
Frontend calculando yield é bloqueado.
```

---

## 14. Subscription & Occupancy Engine

### 14.1 Tese

Assinatura não é desconto. Assinatura compra previsibilidade, antecipa caixa, aumenta retenção e desloca demanda para horários de baixa ocupação.

### 14.2 Modelos B2C

| Modelo | Objetivo |
|---|---|
| Plano mensal corte | Recorrência individual |
| Plano corte + barba | Aumentar ticket e frequência |
| Plano terça–quinta | Ocupar dias fracos |
| Plano família | Recorrência por grupo |
| Plano crédito mensal | Flexibilidade com caixa antecipado |
| Plano premium | Valor percebido e retenção |
| Plano com add-ons | Cross-sell e margem |

### 14.3 Regras obrigatórias

| Regra | Status |
|---|---|
| Plano tem origem, preço, ciclo e validade | CRÍTICO |
| Consumo passa pelo checkout | CRÍTICO |
| Benefício é backend-only | CRÍTICO |
| Comissão calcula no uso real | CRÍTICO |
| Receita antecipada não vira receita livre sem regra | CRÍTICO |
| Uso pode ser limitado a dias fracos | REAL como tese |
| Dunning por falha de cobrança | CRÍTICO |
| Churn e renovação medidos | REAL |

### 14.4 KPIs

```text
MRR de assinaturas
assinantes ativos
churn mensal
renovação mensal
uso por ciclo
ocupação terça–quinta
margem por plano
no-show de assinantes
receita antecipada
conversão avulso → assinatura
```

---

## 15. Corporate Benefits Engine

### 15.1 Tese

Plano corporativo é B2B2C: uma empresa contrata, funcionários usam e o salão ganha recorrência, aquisição e ocupação direcionada.

### 15.2 Estrutura

| Ator | Função |
|---|---|
| Empresa contratante | Paga, subsidia ou compra créditos |
| Funcionário elegível | Usa benefício conforme contrato |
| Dependente | Opcional conforme contrato |
| Salão | Define serviços, horários, limites e margem |
| KortexFlow | Controla billing, crédito, consumo e ledger |
| KortexLink | Convites, links e comunicação |
| Analytics | Uso agregado e performance do contrato |

### 15.3 Modelos

| Modelo | Uso |
|---|---|
| Empresa paga 100% | Benefício premium |
| Empresa subsidia parte | Sustentabilidade financeira |
| Crédito mensal por funcionário | Flexível |
| Voucher por ciclo | Simples e controlado |
| Plano off-peak corporativo | Ocupação de agenda morta |
| Compra de créditos | Campanhas internas |
| Benefício por cargo | Empresas médias/grandes |
| Dia da empresa | Ação pontual |

### 15.4 Privacidade corporativa

| Empresa pode ver | Empresa não pode ver |
|---|---|
| funcionários elegíveis | observações internas individuais |
| taxa de uso agregada | histórico sensível de serviço por pessoa |
| créditos consumidos agregados | dados estéticos/saúde sensíveis |
| faturamento por contrato | notas pessoais do cliente |
| adesão por período | preferências íntimas sem base legal |

### 15.5 Bloqueios

```text
RH não vê histórico individual sensível.
Contrato corporativo sem ledger é bloqueado.
Funcionário sem elegibilidade não usa benefício.
Benefício corporativo sem origem é bloqueado.
Uso em horário nobre com margem ruim é bloqueado por política.
```

---

## 16. Partner Benefits & Local Network Engine

### 16.1 Tese

Parceria local não é cupom aberto. É canal rastreável de aquisição, ocupação e relacionamento com público qualificado.

### 16.2 Parceiros elegíveis

| Tipo | Uso |
|---|---|
| Academia | Pós-treino, estética, corte/barba/manicure |
| Hotel | Hóspede, evento, noivo, executivo |
| Coworking | Profissionais locais |
| Condomínio | Moradores do entorno |
| Clube | Público premium |
| Clínica estética | Cross-sell de beleza/bem-estar |
| Loja premium | Voucher após compra |
| Buffet/eventos | Noivas, noivos e convidados |
| Escola/faculdade | Público jovem e recorrente |

### 16.3 Tipos de benefício

| Tipo | Regra |
|---|---|
| Desconto off-peak | Válido em dias/horários fracos |
| Voucher fixo | Serviço ou valor específico |
| Upgrade | Add-on gratuito ou com condição |
| Primeira visita | Aquisição de cliente novo |
| Recorrência | Depois de X usos, oferta plano próprio |
| Grupo | Hóspedes/equipe/evento |
| Comissão de indicação | Se houver contrato e ledger |

### 16.4 Anti-cupom

| Regra | Status |
|---|---|
| Parceiro cadastrado e contrato definido | CRÍTICO |
| Link/QR com origem rastreável | CRÍTICO |
| Benefício com validade e limite | CRÍTICO |
| Elegibilidade validada no backend | CRÍTICO |
| Consumo no checkout | CRÍTICO |
| Analytics de CAC/margem/conversão | CRÍTICO |
| Parceiro sem acesso a dados sensíveis | CRÍTICO |
| QR aberto sem expiração | BLOQUEADO |
| Cupom genérico sem origem | BLOQUEADO |

### 16.5 KPIs

```text
parceiros ativos
clientes captados por parceiro
conversão parceiro → agendamento
conversão parceiro → recorrência
ocupação terça–quinta
ticket médio por parceiro
margem por parceiro
CAC por parceiro
uso indevido bloqueado
```

---

## 17. KortexLink — activation circuit

### 17.1 Definição

KortexLink é o circuito de distribuição, ativação e integração do KortexOS™. Ele conecta WhatsApp, canal VIP, QR code, links, campanhas, parceiros, empresas, waitlist, lembretes, booking flows e webhooks ao core governado. Toda saída passa pelo Contact & Policy Orchestrator.

### 17.2 Responsabilidades

| Canal | Função |
|---|---|
| WhatsApp | Conversa, confirmação, lembrete, no-show, campanha e booking flow |
| Canal VIP | Distribuição consentida e acesso antecipado; conversão ocorre individualmente |
| QR code | Entrada rápida para parceiro, corporativo, campanha ou assinatura |
| Link inteligente | Origem, elegibilidade, validade, rastreio |
| E-mail/SMS/push | Comunicação transacional e campanhas consentidas |
| Webhooks | Integrações governadas por outbox |
| Partner links | Captação local com origem |
| Corporate links | Funcionários elegíveis |
| Waitlist offers | Recuperação de buracos |

### 17.3 Proibições

```text
Mensagem não agenda direto.
Link não consome benefício direto.
QR não valida elegibilidade sozinho.
Webhook não muta verdade diretamente.
Campanha sem consentimento é bloqueada.
Grupo de clientes com exposição de contatos não é padrão recomendado.
Mensagem fora do Contact Orchestrator é bloqueada.
Confirmação de booking sem hold e Command é bloqueada.
```

---

## 18. KortexApp — personas e limites

### 18.1 Persona matrix

| Persona | O que vê | O que não pode fazer |
|---|---|---|
| Dono | ocupação, margem, caixa, KPIs, equipe, decisões | editar ledger |
| Gerente | agenda, equipe, checkout, atendimento | bypassar política crítica |
| Profissional | agenda, produção, gorjeta, repasse próprio | ver financeiro alheio |
| Recepção | agendar, confirmar, remarcar, cobrar | confirmar conflito |
| Cliente | horários, assinatura, benefício, wallet, histórico | alterar regra ou saldo |
| Empresa | elegíveis, contrato, uso agregado, faturas | ver histórico individual sensível |
| Parceiro | links, QR, conversão, performance agregada | acessar dados individuais sensíveis |

### 18.2 Regra de UI

```text
Frontend exibe.
Frontend solicita.
Frontend filtra visualmente.
Frontend nunca calcula verdade crítica.
```

---

## 19. Action Requests

### 19.1 Estados

```text
draft → ready_for_review → approved → executing → executed → rejected → cancelled → failed
```

### 19.2 Ações que exigem Action Request

| Ação | Domínio |
|---|---|
| Remover depósito obrigatório | D02/D13/D24 |
| Perdoar no-show | D02/D24 |
| Liberar fiado fora de política | D16/D24 |
| Aplicar desconto fora de regra | D12/D18/D23 |
| Usar benefício em horário bloqueado | D18/D07 |
| Ajustar comissão | D17 |
| Ajustar payout | D17 |
| Criar crédito manual | D16/D18 |
| Consumir benefício sensível | D18 |
| Enviar campanha sem régua padrão | D21/D24 |
| Cobrar no-show por COF | D13/D24 |
| Aplicar parceria com fee | D18/D27 |
| Ajustar contrato corporativo ativo | D18/D04 |

### 19.3 Proibições

```text
Action Request não cria ledger direto.
Action Request não cria pagamento direto.
Action Request não cria comissão direta.
Action Request não cria benefício sem Command.
Action Request não substitui backend validation.
```

---

## 20. RAGOV KortexOS™ 5.1.1

### 20.1 REAL

| Categoria | Itens |
|---|---|
| Tese | KortexOS™ como Intelligent Capacity, Fintech & Decision OS |
| Arquitetura | Backend SSOT, frontend burro, Commands, RLS, outbox |
| Domínios | D00–D31 preservados |
| Gates | Gate 00–25 preservados |
| KortexFlow | Ledger append-only, double-entry, `_cents bigint`, idempotência |
| IA | Kortex.ai consultiva, sem soberania |
| Confiança | No-show progressivo, Trust Pass, Healing |
| Ocupação | Assinatura, corporativo e parcerias como tese estratégica |
| Automação | Math-first, backend SSOT, modos de maturidade e Contact Orchestrator como canon |
| Waitlist | Matching, ondas, hold, idempotência e expiração como canon |

### 20.2 PARCIAL

| Item | Condição para REAL |
|---|---|
| KortexFlow implementado | SQL, RPCs, gates financeiros verdes |
| Subscription Engine | Benchmark + Blueprint + Gates + SQL |
| Corporate Benefits | Contratos, elegibilidade, LGPD, billing e gates |
| Partner Benefits | Cadastro, origem, link/QR, analytics e anti-cupom |
| Yield dinâmico | Dados reais, política e gates |
| Kortex.ai operacional | Safety logs, Action Request, handoff e gates |
| KortexLink | Consentimento, templates, outbox, links e webhooks |
| KortexApp | Personas, limites e backend-only provados |
| Opportunity Engine | Feature tables, score versionado, explainability e modo OBSERVE |
| Incrementality Engine | Experimentos, holdouts, atribuição e margem incremental |
| API Booking | Contrato oficial, hold, idempotência, webhooks e SSOT definida |



**Cadastros (Parte II) — mesma classificação PARCIAL:**

| Cadastro | Condição para REAL |
|---|---|
| Formas/tipos de pagamento | Enum de tipos + campos 3.3 no Blueprint; Gates 10–12 verdes |
| Clientes | Dedupe, consentimento e origem obrigatórios materializados |
| Staff | Matriz staff × serviço + vigência de comissão materializadas |
| Serviços | Buffer, consumo técnico e elegibilidade materializados |
| Produtos | Conversão de unidade + duas vias de baixa |
| Complementos | Vínculo obrigatório a serviço pai |
| Combos | Rateio + simulação de margem no backend |
| Planos | KortexFlow real + preço de referência + dunning |
| Pacotes | KortexFlow real + validade + breakage |

**Configuração, Onboarding, Comanda, Gorjeta, Níveis (Parte III) — mesma classificação PARCIAL:**

| Item | Condição para REAL |
|---|---|
| Business Configuration & Policy Layer | Resolução de herança backend + vigência + auditoria materializadas no Blueprint |
| Calendar Policy & Availability Layer | Precedência 2.3 + fila de conflitos materializadas |
| Business Onboarding Workflow | Write-path único provado (mesmo Command do admin) |
| Comanda reopen | Cenários de reversão em cascata verdes nos Gates 10/11/12/14/18 |
| Tip Engine (absorção + split) | Extrato transparente + soma exata + recálculo em reabertura |
| Staff levels & resolução em cascata | Cascata backend + trava de preço no appointment |

### 20.3 MOCKADO — proibido em fluxo crítico

| Proibido |
|---|
| saldo fake |
| comissão fake |
| disponibilidade fake |
| checkout fake |
| benefício fake |
| assinatura sem ledger |
| plano corporativo sem contrato |
| parceria sem origem |
| score de confiança fake |
| yield fake |
| dashboard inventado |
| IA fingindo execução |
| score ou uplift inventado |
| heatmap sem dado canônico |
| confirmação sem appointment real |

### 20.4 HARDCODED — permitido apenas em fixture

| Permitido | Condição |
|---|---|
| IDs de seed | Gate/fixture |
| taxas demonstrativas | Sandbox |
| thresholds iniciais | Versionados |
| exemplos de UI | Sem mutação crítica |
| dados de benchmark | Referência, não verdade de produto |

### 20.5 CRÍTICO

| Item |
|---|
| RLS tenant/platform |
| Booking Candidate |
| Appointment conflict |
| Resource lock |
| Checkout total |
| Payment allocation |
| Ledger balance |
| Wallet rebuild |
| Staff privacy |
| Tip isolation |
| Negative Guard |
| Benefit origin |
| Subscription consumption |
| Corporate privacy |
| Partner anti-cupom |
| Reliability Score |
| Card-on-file consent |
| Action Request |
| Contact & Policy Orchestrator |
| Automation Control Plane |
| Booking hold/idempotência |
| Reason codes e explainability |
| AI governance |
| Outbox |
| LGPD/Fiscal |
| Gates |

### 20.6 BLOQUEADO

| Bloqueio |
|---|
| SQL novo antes do Blueprint |
| domínio novo sem decisão formal |
| gate novo sem aprovação formal |
| frontend calculando regra crítica |
| IA soberana |
| saldo paralelo |
| benefício sem origem |
| comissão negativa mascarada |
| receita antecipada sem obrigação rastreável |
| parceiro vendo dados sensíveis |
| RH vendo histórico sensível |
| marketplace antes do core |
| white-label antes da estabilidade |
| dynamic pricing sem política/gate |
| contextual bandit sem experimento e kill switch |
| reinforcement learning no MVP |
| campanha fora do orquestrador |
| duas fontes de verdade para agenda |
| Onboarding com storage próprio |
| Reabertura após financial lock |
| Split de gorjeta calculado no frontend |
| Herança resolvida no frontend |

---

## 21. Gates obrigatórios 00–25

A grade Gate 00–25 é preservada. O KortexOS™ 5.1.1 adiciona cenários aos gates existentes. Não cria gate novo neste Master Briefing.

| Gate | Nome | Atualização 5.1.1 |
|---:|---|---|
| 00 | Foundation | Roles, schemas, RLS, outbox, idempotência e Kortex naming guard |
| 01 | Tenant Isolation | Benefícios, assinaturas e parceiros tenant-scoped |
| 02 | Staff Privacy | Staff account e comissão/gorjeta própria sem vazamento |
| 03 | Smart Availability | Candidate considera assinatura/off-peak/premium window |
| 04 | Appointment Conflict | Corporate/partner booking não bypassa lock |
| 05 | Chain Booking | Multi-service de assinatura/corporativo preserva sequência |
| 06 | Recurring Appointment | Assinatura recorrente não cria ocorrência sem validação |
| 07 | Group Booking | Corporate/group benefits com pagador/beneficiário separados |
| 08 | Premium Window Protection | Benefício off-peak não entra em horário nobre sem regra |
| 09 | Waitlist Economic Matching | Matching explicável, ondas, expiração, consentimento, hold e conversão idempotente |
| 10 | Checkout Integrity | Consumo de assinatura/corporativo/parceiro no backend |
| 11 | Ledger Balance | Receita, obrigação, consumo, comissão e gorjeta fecham |
| 12 | Payment Allocation | Pagamento recorrente, COF e corporate billing |
| 13 | Wallet Drift | Client wallet, créditos e benefícios reconstruíveis |
| 14 | Commission Privacy & Accuracy | Comissão por uso real de benefício/plano |
| 15 | Benefit Origin & Consumption | Assinatura, corporativo e parceiro com origem, validade e consumo |
| 16 | Action Request Safety | Exceções financeiras/reputacionais exigem aprovação |
| 17 | WhatsApp & AI Safety | KortexLink/Kortex.ai não escrevem verdade direta; Contact Orchestrator, VIP e booking flow respeitam política |
| 18 | Cash Register Integrity | Caixa referencia ledger de planos/benefícios quando aplicável |
| 19 | Analytics Rebuild | Heatmaps, scores, ocupação, margem, CAC, MRR, cohorts, tratamento/controle e uplift reconstruíveis |
| 20 | Integration Safety | Webhooks/links/QR/API booking sem bypass de Command, com assinatura, retry e idempotência |
| 21 | Fiscal & LGPD Compliance | Privacidade corporativa e parceiro sem dados sensíveis |
| 22 | Platform Owner Isolation | Platform não acessa tenant bruto fora do contrato |
| 23 | Marketplace Safety | Partner network sem bypass core |
| 24 | Multi-Unit Integrity | Benefícios multiunidade sem mistura de ledger |
| 25 | Production Readiness | Release bloqueado se gate crítico falhar; automação exige modo, kill switch, rollback e circuit breaker testados |

---

## 22. Ordem de construção

### 22.1 Sequência vinculante pós-auditoria

| Ordem | Artefato / fase | Objetivo | Status |
|---:|---|---|---|
| 1 | Auditoria de lacunas da conversa | Identificar decisões ausentes | CONCLUÍDO |
| 2 | Master Briefing KortexOS™ 5.1.1 | Consolidar fonte única, decisão matemática e automação governada | ESTE DOCUMENTO |
| 3 | Global Benchmark Map formal | Transformar pesquisa exploratória da conversa em matriz rastreável por fonte | ESCOPO PRIORIZADO CONCLUÍDO (DEC-20) — 3/3 rodadas, módulos 01–06; ver `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md` (DEC-20/21). Módulos 07–16 seguem fora de escopo até prioridade real |
| 4 | Comparative Proposal | Classificar HERDAR/REFORÇAR/BLOQUEAR/ADIAR/DESCARTAR | CONCLUÍDO (DEC-22) — 42 itens classificados; ver `KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md` |
| 5 | Truth Map 5.1.2 | Classificar realidade técnica | **CONCLUÍDO (DEC-23, 2026-07-20)** — módulos 01–06 auditados contra código real; ver `KORTEXOS_5_1_2_TRUTH_MAP.md` (v1.0). Veredito: NO-GO para promoção direta ao produto final; fundação MVP preservada como base |
| 6 | Migration Map 5.1.2 | Mapear nomes, tabelas e prefixos | **CONCLUÍDO (DEC-24, 2026-07-20; revisado por DEC-27/DEC-28 → v1.2)** — 7 ondas de dependência mapeadas, escopo de unidade totalmente decidido (N:N profissional↔unidade, `memberships` híbrido, classificação de escopo para as 19 tabelas MVP + objetos novos); ver `KORTEXOS_5_1_2_MIGRATION_MAP.md` (v1.2) |
| 7 | Blueprint Unificado 5.1.2 | Incorporar Opportunity Engine, Contact Orchestrator, Automation Control Plane e API Booking | DESBLOQUEADO por DEC-24, sem ressalva pendente — cobertura de D02 fechada por DEC-25; pontos cegos de profundidade resolvidos por DEC-26; hierarquia Empresa→Unidade modelada e finalizada por DEC-27/DEC-28. Ainda não iniciado |
| 8 | SQL Master | Materializar em banco | BLOQUEADO |
| 9 | Dev Handoff | Execução por domínio | BLOQUEADO |
| 10 | UI/UX Spec | Superfícies e fluxos | BLOQUEADO para regra crítica |

### 22.2 Bloqueios de sequência

| Tentativa | Veredito |
|---|---|
| Criar Blueprint antes do benchmark | BLOQUEADO |
| Criar SQL antes do Migration Map | BLOQUEADO |
| Criar app antes de limites de persona | BLOQUEADO |
| Criar IA operacional antes de Action Request | BLOQUEADO |
| Criar planos antes de ledger/wallet | BLOQUEADO |
| Criar corporativo antes de LGPD mínima | BLOQUEADO |
| Criar parcerias antes de anti-cupom | BLOQUEADO |

---

## 23. Benchmark global obrigatório

Antes do Blueprint KortexOS™ 5.1.1, deve existir benchmark por módulo.

### 23.1 Estratégia e referências

Estratégia de benchmark por competência (Tier 1 Beauty Tech + Tier 2 Cross-Industry + Tier 3 Domínios Técnicos/Verticais + referência metodológica permanente), com ressalvas de calibração por referência: `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md`, seção "Estratégia Canônica de Benchmark" (DEC-21). Nenhuma referência é modelo integral a copiar — cada uma vale para seu domínio de excelência específico.

### 23.2 Módulos obrigatórios do benchmark

| # | Módulo |
|---:|---|
| 01 | Booking & Capacity Scheduling |
| 02 | Smart Gap / Waitlist / Resource Locks |
| 03 | Checkout & Payments |
| 04 | Ledger / Wallet / Current Accounts |
| 05 | Compensation / Tips / Payout |
| 06 | No-show / Deposit / Card-on-file |
| 07 | AI Receptionist / CoPilot |
| 08 | Messaging / Links / QR / Integrations |
| 09 | Subscription & Occupancy Engine |
| 10 | Corporate Benefits & Employee Wellness Engine |
| 11 | Partner Benefits & Local Network Engine |
| 12 | Analytics / Decision Intelligence |
| 13 | Multiunit / Marketplace / White-label |
| 14 | Mathematical Decisioning / Expected Value / Optimization |
| 15 | Experimentation / Incrementality / Uplift |
| 16 | Contact Orchestration / Automation Control Plane |

### 23.3 Critérios de comparação

| Classificação | Uso |
|---|---|
| HERDAR | Já está correto no 4.0/5.1 |
| RENOMEAR | Só muda nomenclatura |
| REFORÇAR | Mercado confirma importância |
| ADICIONAR AO BACKLOG | Bom, mas não agora |
| BLOQUEAR | Sofisticação prematura ou risco |
| DESCARTAR | Não serve ao modelo Kortex |

---

## 24. Critérios de produto final aprovado

| Critério | Obrigatório |
|---|---:|
| Tenant isolation provado | Sim |
| Platform isolation provado | Sim |
| RLS real | Sim |
| Booking Candidate backend | Sim |
| Smart Gap Law | Sim |
| Resource lock | Sim |
| Checkout backend-only | Sim |
| Ledger double-entry append-only | Sim |
| Wallet reconstruível | Sim |
| Staff current account | Sim |
| Tip isolation | Sim |
| Negative Guard | Sim |
| Subscription consumption | Sim |
| Corporate privacy | Sim |
| Partner anti-cupom | Sim |
| Reliability Score | Sim |
| Action Request | Sim |
| Contact & Policy Orchestrator | Sim |
| Automation Control Plane | Sim |
| Reason codes e explainability | Sim |
| IA sem soberania | Sim |
| KortexLink consentido | Sim |
| Analytics reconstruível | Sim |
| Heatmaps e features reconstruíveis | Sim |
| Opportunity score versionado e explicável | Sim |
| Contact Orchestrator global | Sim |
| Automation mode/kill switch/rollback | Sim |
| Booking hold e idempotência | Sim |
| Grupo de controle quando comercial | Sim |
| LGPD/Fiscal | Sim antes de produção comercial |

---

## 25. Veredito Red Team

Itemização completa (tese, motores, bloqueios) preservada no Decision Log, Seção 5. Aqui, apenas o que permanece ativo:

### 25.1 Risco principal

```text
O maior risco do KortexOS™ não é falta de visão.
É automatizar correlações ruins antes de provar dados, causalidade, margem e segurança.
```

### 25.2 Decisão final

```text
Master Briefing KortexOS™ 5.1.2 é a fonte canônica única, aprovada pelo Platform Owner.
Decision Log (arquivo companion) preserva o histórico completo de decisões, sem editá-lo.
Blueprint continua bloqueado até benchmark formal, proposta comparativa, Truth Map e Migration Map.
SQL e automação em produção continuam bloqueados.
```

## 26. Encerramento canônico

Este documento é a fonte única do KortexOS™. Substitui integralmente o Master Briefing 5.1 e todas as versões parciais, anexos (A1, A2) e reescritas anteriores.

Ele consolida três partes:

**Parte I** — tese Intelligent Capacity, as 5 soluções globais, mitigação de custo de IA, soberania do Kortex.ai, KortexFlow financeiro, staff current account, client wallet, Negative Guard, no-show/Reliability Score/Trust Pass/Healing, Autonomous Operations Engine, yield e ocupação, assinaturas, plano corporativo, parcerias locais, KortexLink, KortexApp por persona, Action Requests, RAGOV unificado, Gates 00–25, benchmark obrigatório, ordem de construção.

**Parte II** — os 9 cadastros canônicos (formas de pagamento, clientes, staff, serviços, produtos, complementos, combos, planos, pacotes), suas regras transversais e matriz de dependências.

**Parte III** — Business Configuration & Policy Layer, Calendar Policy & Availability Layer, Business Onboarding Workflow, ciclo de vida da comanda com reabertura governada, Tip Engine, resolução de preço/tempo/comissão por nível de profissional.

**Decision Log** (arquivo companion, `KORTEXOS_5_1_2_DECISION_LOG.md`) — todo o histórico de decisões (DEC-01 a DEC-18, D-01 a D-09), imutável, nunca editado, apenas marcado com status quando superado ou refinado.

```text
Cadastro é a matéria-prima do cálculo. Cálculo sem cadastro completo é chute com interface.
Básico antes do sofisticado. Backend antes de frontend. Ledger antes de dashboard.
Gates antes de escala. Matemática antes de automação.
Causalidade antes de crédito por conversão. Modo OBSERVE antes de execução.
Benchmark antes de Blueprint. Blueprint antes de SQL.
Nenhuma venda de plano ou pacote antes do KortexFlow real e da validação jurídica pendente (DEC-14/DEC-18).
```

### Próximo passo executável (estado atual, 2026-07-19)

```text
1. Global Benchmark Map formal (etapa 3 da ordem de construção, seção 22) — PENDENTE.
2. Validação jurídica: mecanismo de aceite digital (DEC-14), ressalva de canal
   de venda / direito de arrependimento (DEC-18, Parte II seção 11.6), e texto +
   prazo de retenção do consentimento de dado sensível (DEC-19, Parte II seção
   13.3) — PENDENTE. Requer advogado; não é tarefa que este documento resolve.
3. D-07 (anamnese/dados sensíveis) — RESOLVIDA (DEC-19, Parte II seção 13).
Nada neste documento autoriza SQL, migration ou tela antes do Blueprint aprovado.
```

---
---

# PARTE II — CADASTROS CANÔNICOS

## 0. Por que esta parte existe

O Master Briefing 5.1 define motores, invariantes e gates, mas a camada de cadastros — a matéria-prima de todo cálculo — está subespecificada. Quatro buracos concretos:

| # | Buraco | Consequência econômica |
|---:|---|---|
| 1 | Forma de pagamento sem taxa/prazo/conta/absorção obrigatórios | Margem invisível; Gate 11/12 incalculáveis |
| 2 | Plano/pacote sem preço de referência de consumo | "Comissão no uso real" (Gate 14) é matematicamente indefinida |
| 3 | Combo sem regra de rateio de desconto | Comissão ambígua → conflito direto com staff |
| 4 | Pacote sem validade/breakage | Passivo eterno no ledger; receita antecipada sem regra de saída |

Esta parte fecha os quatro e especifica os nove cadastros: formas/tipos de pagamento, clientes, staff, serviços, produtos, complementos, combos, planos de assinatura e pacotes.

---

## 1. Camadas SaaS × cadastros — mapa refinado

### 1.1 Onde cada cadastro vive

| Cadastro | Domínio | Camada | Bloqueio de venda | Gates principais |
|---|---|---:|---|---|
| Formas e tipos de pagamento | D13/D14/D15 | 1 (Foundation) | Nenhum | 10, 11, 12, 18 |
| Clientes | D05 | 1 (Foundation) | Nenhum | 01, 04, 13, 21 |
| Staff | D05/D17 | 1 (Foundation) | Nenhum | 02, 03, 14 |
| Serviços | D06 | 1 (Foundation) | Nenhum | 03, 04, 08, 10 |
| Produtos | D06 | 1 (Foundation) | Nenhum | 10, 11 |
| Complementos (add-ons) | D06 | 1 (Foundation) | Nenhum | 05, 10 |
| Combos | D06/D12 | 1–3 | Rateio aprovado + comissão estável | 05, 10, 14 |
| Planos de assinatura | D18 | 4 (Revenue) | **BLOQUEADO até KortexFlow real** (regra 21.2) | 11, 12, 13, 14, 15 |
| Pacotes de serviços | D18 | 4 (Revenue) | **BLOQUEADO até KortexFlow real** (regra 21.2) | 11, 13, 14, 15 |

### 1.2 Regra de leitura da tabela

```text
Camada 1 pode ser cadastrada e usada assim que o Blueprint liberar Foundation.
Camada 4 pode ser CADASTRADA como rascunho, mas não pode ser VENDIDA
antes de ledger, wallet e benefit_obligations reais.
Cadastro sem os campos CRÍTICOS marcados nesta parte não entra em checkout nem em agenda.
```

---

## 2. Regras transversais — valem para TODOS os cadastros

| # | Regra | Definição | Status |
|---:|---|---|---|
| T1 | Tenant-scoped | Todo registro pertence a um tenant; RLS obrigatória | CRÍTICO |
| T2 | Chave natural declarada | Cada cadastro define sua unicidade (ex.: cliente = telefone E.164; produto = SKU) e o backend rejeita duplicata | CRÍTICO |
| T3 | Arquivar, nunca deletar | Registro com histórico financeiro ou de agenda não é deletado; muda para `arquivado`. Deleção real só sem histórico | CRÍTICO |
| T4 | Vigência de valores | Preço, custo, taxa e comissão mudam por vigência (data de início/fim). Histórico preserva o valor da época. Reescrever valor passado é proibido | CRÍTICO |
| T5 | Ciclo de status mínimo | `rascunho → ativo → inativo → arquivado`. Só `ativo` aparece em checkout/agenda/booking público | REAL |
| T6 | Auditoria de mutação | Toda alteração registra autor, data e valor anterior | CRÍTICO |
| T7 | Cadastro incompleto bloqueia uso | Entidade sem campos CRÍTICOS preenchidos não entra em fluxo financeiro | CRÍTICO |
| T8 | Campos calculados são read-only | Score, saldo, wallet, conta corrente aparecem no cadastro como projeção; nunca são campos editáveis | CRÍTICO |
| T9 | Frontend não deriva regra | Elegibilidade, preço, comissão e taxa vêm do backend; a tela só exibe | CRÍTICO |

---

## 3. Cadastro de Formas e Tipos de Pagamento

### 3.1 Modelo em três níveis

```text
NÍVEL 1 — TIPO: a natureza econômica da liquidação (enum fechado do sistema).
NÍVEL 2 — FORMA: o instrumento concreto configurado pelo tenant (tipo + adquirente + conta + bandeira).
NÍVEL 3 — CONDIÇÃO: à vista, parcelado N×, com/sem antecipação — cada condição com sua taxa e prazo.
```

### 3.2 Tipos canônicos (Nível 1 — não editável pelo tenant)

| Tipo | Natureza | Cria receita nova? | Observação |
|---|---|---:|---|
| Dinheiro | Liquidação imediata | Sim | Único que aceita troco |
| PIX | Liquidação D+0 | Sim | Taxa possível conforme conta |
| Débito | Cartão presente | Sim | Taxa MDR |
| Crédito à vista | Cartão | Sim | Taxa MDR |
| Crédito parcelado | Cartão | Sim | Taxa por faixa de parcela |
| Transferência/boleto | Liquidação D+n | Sim | Uso corporativo/B2B |
| Wallet do cliente | Consumo de crédito existente | Não | Debita `client_wallets`; receita já reconhecida ou reclassificada |
| Voucher / gift | Consumo de crédito pré-vendido | Não | Origem e validade obrigatórias |
| Benefício de assinatura | Consumo de obrigação | Não | Debita `benefit_obligations` |
| Benefício de pacote | Consumo de obrigação | Não | Debita sessão do pacote |
| Benefício corporativo | Consumo de contrato B2B | Não | Regras do contrato |
| Benefício de parceiro | Consumo com origem rastreável | Não | Anti-cupom (seção 15.4 do Master) |
| Fiado autorizado | Dívida governada | Sim (contra recebível) | Só aparece se Negative Guard aprovar para o cliente |
| Cortesia | Baixa sem receita | Não | Exige Action Request; comissão conforme política |

### 3.3 Campos canônicos da FORMA (Nível 2)

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome exibido | Sim | Ex.: "Crédito Visa — Stone" |
| Tipo (Nível 1) | Sim | Enum acima |
| Adquirente / maquininha | Se cartão | Rastreio de conciliação |
| Conta de destino | Sim | Onde o dinheiro cai |
| Taxa (% + fixa) por condição | Sim | MDR por parcela; vigência (T4) |
| Prazo de liquidação (D+n) por condição | Sim | Fluxo de caixa previsto |
| Modelo de absorção de taxa | Sim | Bruto Salão / Dividido / Bruto Staff (seção 8.4 do Master); default da forma, override por contrato de staff |
| Aceita gorjeta | Sim | E destino da gorjeta no ledger (tip isolation) |
| Permite estorno | Sim | E via de estorno (mesma forma / wallet) |
| Superfícies habilitadas | Sim | Presencial, link de pagamento, booking online |
| Ordem de exibição no checkout | Não | UX apenas |
| Status | Sim | T5 |

### 3.4 Invariantes

| Regra | Status |
|---|---|
| Forma sem taxa + prazo + conta + modelo de absorção = bloqueada no checkout | CRÍTICO |
| Benefício não é pagamento: é consumo de obrigação. No ledger, nunca gera receita nova em duplicidade | CRÍTICO |
| Recibo/checkout histórico preserva a taxa vigente na data (T4) | CRÍTICO |
| Fiado só é exibido no checkout se o Negative Guard autorizar aquele cliente naquele valor | CRÍTICO |
| Split multi-forma permitido; ordem default de consumo: benefício → wallet → forma externa | DECISÃO D-03 |
| Gorjeta em cartão: salão absorve a taxa da gorjeta para preservar "100% para o destinatário"; custo visível no ledger | DECISÃO D-02 |
| Estorno segue a via da forma original; ajuste por lançamento reverso, nunca edição | CRÍTICO |

### 3.5 Proibições

```text
Tipo novo criado pelo tenant é proibido (enum é do sistema).
Forma ativa sem mapeamento contábil completo é proibida.
Taxa "média estimada" no lugar da taxa real por condição é proibida.
Cortesia sem Action Request é proibida.
```

---

## 4. Cadastro de Clientes

### 4.1 Blocos canônicos

| Bloco | Campos | Regra |
|---|---|---|
| Identidade | Nome, telefone (chave natural, E.164), e-mail, data de nascimento, CPF (opcional) | Dedupe por telefone; merge governado por Command, nunca deleção manual do duplicado |
| Consentimento (LGPD) | Por canal: WhatsApp, SMS, e-mail, push — com data, origem e prova | Pré-requisito para KortexLink; campanha sem consentimento é bloqueada |
| Origem de aquisição | Orgânico, indicação (quem), parceiro (qual), corporativo (qual contrato), campanha (qual) | Obrigatório na criação; alimenta CAC e analytics de parceiro |
| Relacionamento | Preferências, tags, staff preferido, observações operacionais NÃO sensíveis | Observação sensível (saúde/estética) NÃO entra aqui — ver 4.3 |
| Família / grupo | Vínculo a household para plano família e group booking | Pagador ≠ beneficiário sempre explícito (Gate 07) |
| Confiança | Reliability Score, Trust Pass, fricções ativas (depósito compulsório, pré-pagamento, bloqueio) | Todos calculados/aplicados por política; read-only no cadastro (T8) |
| Financeiro | Wallet (saldo, créditos com origem/validade), obrigações ativas (planos, pacotes, corporativo), fiado autorizado e limite | 100% projeção do ledger; nenhum campo editável |

### 4.2 Estados

```text
ativo → inativo (sem movimento por N meses, automático, reversível)
→ bloqueado (política/Action Request) → arquivado → anonimizado (LGPD)
```

### 4.3 Regras e invariantes

| Regra | Status |
|---|---|
| Telefone único por tenant; segundo cadastro com mesmo telefone força fluxo de merge | CRÍTICO |
| Score e wallet jamais editáveis em tela de cadastro | CRÍTICO |
| Remoção de fricção (depósito, bloqueio) exige política ou Action Request | CRÍTICO |
| Dados sensíveis (anamnese, alergia, saúde, estética íntima) ficam FORA do cadastro base; módulo próprio especificado em Parte II §13 | DEC-19 — RESOLVIDO |
| Cliente com histórico financeiro é anonimizado, nunca deletado | CRÍTICO |
| Origem de aquisição não é editável após primeiro checkout (protege CAC/parceiro) | CRÍTICO |

---

## 5. Cadastro de Staff

### 5.1 Blocos canônicos

| Bloco | Campos | Regra |
|---|---|---|
| Identidade | Nome, apelido de exibição, telefone, e-mail, foto, documentos | Documento de contrato anexável |
| Vínculo legal | Tipo: **Parceiro (Lei do Salão Parceiro)** / CLT / autônomo / assistente. Se Parceiro: contrato, cota-parte %, data de homologação | Vínculo legal ≠ role do sistema. Cota-parte com vigência (T4) |
| Role do sistema | dono / gerente / profissional / recepção (persona matrix, seção 17 do Master) | Um humano pode ter vínculo Parceiro e role gerente |
| Habilitação técnica | Matriz staff × serviço: habilitado?, duração própria (override), comissão específica | Fonte do Booking Candidate; serviço não habilitado não aparece na agenda do staff |
| Agenda de trabalho | Grade semanal, pausas, bloqueios, exceções, férias | Fonte de disponibilidade; mudança não altera appointments já confirmados sem fluxo de conflito |
| Comissão | Regra default por vínculo + override por serviço, produto, plano e forma de pagamento (absorção de taxa) | Sempre com vigência; mudança nunca retroage |
| Financeiro | Conta corrente (produção, comissão, gorjeta, adiantamentos, saldo projetado) | Projeção read-only; ajuste manual só via Action Request |

### 5.2 Regras e invariantes

| Regra | Status |
|---|---|
| Staff não vê cadastro financeiro alheio (Gate 02) | CRÍTICO |
| Comissão sem vigência é proibida; edição retroativa é proibida | CRÍTICO |
| Duração própria por serviço: SIM no MVP (afeta agenda real) | DECISÃO D-01a — RECOMENDADO |
| Preço próprio por nível de profissional: NÃO no MVP (sofisticação prematura) | DECISÃO D-01b — ADIADO |
| Desligamento arquiva o staff, preserva histórico e trava agenda futura; conta corrente liquida por payout final | CRÍTICO |
| Cota-parte do Parceiro é a base do modelo de absorção de taxa (seção 3.3) | REAL como tese |

---

## 6. Cadastro de Serviços

### 6.1 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome + categoria | Sim | Navegação e analytics |
| Descrição pública vs interna | Não | Booking online vs operação |
| Duração de execução | Sim | Minutos reais na cadeira |
| Buffer pré/pós | Sim (pode ser 0) | Preparo/higienização; ocupa agenda mas não é "atendimento" |
| Preço base | Sim | Com vigência (T4); `_cents` |
| Comissão default | Sim | Override por staff na matriz 5.1 |
| Recursos exigidos | Se aplicável | TIPO de recurso (cadeira de barbeiro, sala de estética), não instância — D11 resolve a instância |
| Consumo técnico de produtos | Se aplicável | Receita de baixa de estoque por execução (ex.: 30 ml de produto X) |
| Elegibilidade a benefício | Sim | Flags: assinável / empacotável / corporativo / parceiro / off-peak only |
| Yield | Não | Participa de premium window? Aceita desconto off-peak? Multiplicadores com vigência |
| Políticas próprias | Não | Depósito, antecedência mínima, janela de cancelamento (default herda D02) |
| Visibilidade | Sim | Público (booking online) / interno |

### 6.2 Regras e invariantes

| Regra | Status |
|---|---|
| Serviço sem duração + preço + comissão default = não entra em agenda nem checkout (T7) | CRÍTICO |
| Buffer conta na ocupação e no Slot Score | REAL como tese |
| Mudança de preço não altera appointments já agendados com preço travado | CRÍTICO |
| Serviço off-peak only não é agendável em premium window sem regra superior (Gate 08) | CRÍTICO |
| Consumo técnico dispara baixa de estoque no checkout concluído | CRÍTICO |

---

## 7. Cadastro de Produtos

### 7.1 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome, SKU (chave natural), código de barras | SKU sim | Dedupe e conciliação |
| Finalidade | Sim | **Revenda / uso interno / ambos** |
| Categoria + fornecedor | Não | Compras e analytics |
| Unidade de venda vs unidade de consumo + fator de conversão | Se uso interno | Ex.: frasco 1000 ml vendido inteiro, consumido em ml |
| Custo | Sim | Com vigência; base da margem |
| Preço de venda | Se revenda | Com vigência |
| Comissão de revenda | Se revenda | Default + override por staff |
| Estoque mínimo / alerta | Não | Reposição |
| Status | Sim | T5 |

### 7.2 Regras e invariantes

| Regra | Status |
|---|---|
| Duas vias de baixa: venda (checkout) e consumo técnico (execução de serviço) — ambas idempotentes | CRÍTICO |
| Produto sem custo cadastrado gera ALERTA de margem cega (não bloqueia venda) | REAL como tese |
| Estoque negativo é proibido silenciosamente: exige registro de divergência | CRÍTICO |
| Ajuste de estoque manual registra motivo + autor (T6) | CRÍTICO |

---

## 8. Cadastro de Complementos (Add-ons)

### 8.1 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome | Sim | Ex.: "Sobrancelha", "Hidratação express" |
| Serviços compatíveis | Sim | Add-on só existe acoplado a serviço pai |
| Delta de duração | Sim (pode ser 0) | Soma na agenda |
| Delta de preço | Sim | Com vigência |
| Comissão própria | Sim | Não herda cegamente do serviço pai |
| Elegibilidade a benefício | Sim | Inclui uso como "upgrade" de parceria (seção 15.3 do Master) |
| Limite por atendimento | Não | Anti-abuso |

### 8.2 Regras e invariantes

| Regra | Status |
|---|---|
| Add-on sem serviço pai no mesmo appointment/checkout é proibido | CRÍTICO |
| Comissão do add-on é própria e explícita | DECISÃO D-09 — RECOMENDADO |
| Add-on gratuito via benefício de parceiro exige origem rastreável (anti-cupom) | CRÍTICO |

---

## 9. Cadastro de Combos

### 9.1 Definição

Combo é venda conjunta de itens (serviços + add-ons + produtos) com preço fechado ou desconto estruturado, executada em sequência (chain booking) e paga em um checkout.

### 9.2 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome + descrição | Sim | Ex.: "Corte + Barba + Sobrancelha" |
| Itens (tipo, referência, quantidade) | Sim | Serviços, add-ons, produtos |
| Modo de preço | Sim | Preço fechado OU desconto sobre a soma — desconto em **R$ (valor fixo) ou % (percentual)**, modalidade escolhida no cadastro (DEC-16) |
| **Regra de rateio do desconto** | Sim | Proporcional ao preço base de cada item (regra canônica única) |
| Modelo de absorção do desconto | Sim | Salão absorve / compartilhado — liga com o modelo de comissão 8.4 do Master |
| Sequência de execução | Sim | Ordem + staff único ou múltiplo (Gate 05 — chain booking) |
| Janela de validade / restrição de horário | Não | Combos off-peak; premium window exige regra superior |
| Elegibilidade a benefício | Sim | Combo dentro de plano/pacote/parceria? |
| Status | Sim | T5 |

### 9.3 Regras e invariantes

| Regra | Status |
|---|---|
| Rateio proporcional ao preço base é a ÚNICA regra de rateio; comissão de cada item calcula sobre o valor rateado | DECISÃO D-04 — RECOMENDADO CANÔNICO |
| Combo sem rateio definido não pode ser vendido | CRÍTICO |
| Na criação/edição, o backend simula margem do combo (preço − custo técnico − comissão rateada − taxa média); margem negativa exige aprovação explícita | CRÍTICO (Negative Guard) |
| Desconto de combo em horário nobre exige regra superior (herda 10.3 do Master) | CRÍTICO |
| Item removido no atendimento recalcula o combo no backend (perde preço de combo conforme política) | CRÍTICO |

---

## 10. Cadastro de Planos de Assinatura

### 10.1 Arquétipos canônicos de benefício

```text
QUOTA    → N usos de serviço/add-on por ciclo (ex.: 4 cortes/mês).
CRÉDITO  → R$ X em wallet por ciclo, com regras de uso.
DESCONTO → % em categoria/serviço durante a vigência.
Um plano pode combinar arquétipos, mas cada item declara o seu.
```

### 10.2 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome + ciclo (mensal) + preço | Sim | `_cents`, vigência |
| Itens de benefício (arquétipo + referência + quantidade) | Sim | Conforme 10.1 |
| **Preço de referência de consumo por item** | Sim | Base de comissão e de reconhecimento de receita no uso. SEM ISSO O GATE 14 É INCALCULÁVEL |
| Janela de uso | Sim | Dias/horários (ex.: terça–quinta); premium window excluída por default |
| Rollover | Sim | Default: expira no ciclo. Alternativa: acumula até N ciclos |
| Overuse | Sim | Excedente paga avulso (default) ou preço de membro |
| Beneficiários | Sim | Individual ou família (N dependentes do household) |
| Carência / fidelidade / pausa (freeze) | Sim | Limites explícitos; pausa máxima por ano |
| Cancelamento e desistência | Sim | **Fórmula unificada com pacotes (DEC-18):** `valor pago − (valor da parte utilizada, pelo preço de referência de consumo do item — mesmo campo usado para comissão)`, nunca negativo. Sem multa percentual autônoma (DEC-17 superada). Se uso=0, reembolso é integral E a comissão de venda (quando existir) é revertida (DEC-18); havendo qualquer uso, comissão de venda fica definitiva |
| Dunning | Sim | Tentativas, degraus, suspensão do benefício em inadimplência |
| Staff elegível | Sim | Qualquer habilitado (default) ou lista restrita |
| Comissão no uso | Sim | Calcula sobre o preço de referência do item consumido |
| Status | Sim | rascunho → ativo → **suspenso para novas vendas** → arquivado |

### 10.3 Regras e invariantes

| Regra | Status |
|---|---|
| Alterar plano ativo NÃO altera contratos vigentes: gera nova versão; assinantes migram por ação explícita | CRÍTICO |
| Cobrança gera obrigação (`benefit_obligations`); consumo passa pelo checkout; receita reconhece/reclassifica no consumo | CRÍTICO |
| Benefício suspenso por inadimplência não é consumível | CRÍTICO |
| Uso fora da janela exige regra superior ou paga avulso | CRÍTICO |
| Plano com margem de referência negativa (preço do ciclo < custo do consumo máximo × referência) exige aprovação explícita | CRÍTICO (Negative Guard) |
| Reembolso calcula sobre a parte NÃO utilizada (mesma fórmula de pacotes, DEC-18); nunca sobre valor já consumido; nunca resulta em reembolso negativo (piso zero) | CRÍTICO |
| Comissão de execução já paga por sessão/benefício realizado nunca entra na conta de devolução — protegida por construção (DEC-18) | CRÍTICO |
| Canal da venda (presencial vs. distância) é registrado no plano; determina se o direito de arrependimento do art. 49 CDC se aplica (7 dias, sem uso, reembolso integral sem dedução) — ver ressalva jurídica, seção 11.6 | CRÍTICO |
| **VENDA BLOQUEADA até ledger + wallet + obrigações reais** (regra 21.2 do Master) | BLOQUEADO |

---

## 11. Cadastro de Pacotes de Serviços

### 11.1 Definição

Pacote é compra pontual pré-paga de N sessões de serviço(s), com validade. Difere de assinatura: não recorre, não tem ciclo, não tem dunning.

### 11.2 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome + itens (serviço, nº de sessões) | Sim | Ex.: 10 sessões de limpeza de pele |
| Preço do pacote | Sim | Desconto embutido vs soma avulsa |
| **Rateio por sessão** | Sim | Preço do pacote ÷ sessões, proporcional por item — base de comissão e reconhecimento de USO |
| **Validade** | Sim | Dias após a compra. Pacote sem validade é proibido |
| **Motivos elegíveis para extensão** | Sim (DEC-14) | Subconjunto de: saúde / férias / outro |
| **Prazo máximo de extensão** | Sim (DEC-14) | Enum: 7, 14, 21 ou 28 dias. Concessão real seleciona motivo + prazo ≤ máximo, com autor e data registrados |
| **Texto e mecanismo de aceite digital** | Sim (DEC-14) | Texto canônico (seção 11.4); aceito por clique simples + assinatura desenhada na tela; registra hash/timestamp |
| Transferibilidade | Sim | Default: intransferível; família permitida se marcado |
| **Política de reembolso por desistência antecipada** | Sim (DEC-14) | `valor pago − (sessões consumidas × preço avulso da época)`, nunca negativo; percentual e forma de devolução (dinheiro/wallet) configuráveis por pacote |
| Regra de breakage | Sim | Aplica-se somente ao fim da janela de extensão sem uso (DEC-14) — nunca no vencimento direto da validade |
| **Comissão de venda** | Não (DEC-15) | % ou valor fixo, com vigência; default desligada. Distinta e independente da comissão de uso/execução |
| Staff elegível | Sim | Igual a planos |
| Status | Sim | T5 |

### 11.3 Regras e invariantes

| Regra | Status |
|---|---|
| Compra gera obrigação (passivo); sessão consumida no checkout debita a obrigação e reconhece receita rateada | CRÍTICO |
| **Comissão de USO** por sessão calcula sobre o valor rateado, no momento do consumo — nunca na venda do pacote (DEC-10/Gate 14) | CRÍTICO |
| **Comissão de VENDA** (DEC-15, se configurada) reconhece no momento do pagamento da venda, remunera quem processou a venda (independente de quem executa). Revertida por lançamento reverso (T6) SE E SOMENTE SE nenhuma sessão foi utilizada (uso=0); havendo qualquer uso, a comissão de venda é definitiva, nunca revertida (DEC-18) | CRÍTICO |
| Comissão de venda e comissão de uso são independentes: não se substituem, não se reduzem mutuamente; mesma pessoa pode receber ambas | CRÍTICO |
| Pacote sem validade, sem rateio ou sem aceite digital configurado = BLOQUEADO na criação | CRÍTICO |
| Sequência de breakage é sempre: validade vencida → janela de extensão (motivo + prazo ≤ máximo, crédito de wallet + aviso) → só então reconhecimento de receita. Pular a extensão é proibido (DEC-14) | CRÍTICO |
| Reembolso por desistência antecipada é regra distinta do breakage; aplica-se enquanto o pacote está dentro da validade original | CRÍTICO |
| **VENDA BLOQUEADA até KortexFlow real E validação jurídica do mecanismo de aceite digital** (regra 21.2 do Master + DEC-14) | BLOQUEADO |

### 11.4 Texto canônico de aceite digital (DEC-14)

```text
TERMOS DO PACOTE

Você está adquirindo [N] sessões de [serviço], válidas por [X] dias a partir da compra.

- Sessões não usadas na validade entram automaticamente em janela de extensão
  (7 a 28 dias, conforme motivo aprovado). Você será avisado antes do vencimento.
- Encerrada a extensão sem uso, o saldo não é mais reembolsável.
- Desistindo dentro da validade, você recebe reembolso do valor pago menos as
  sessões já usadas (pelo preço avulso vigente).
- Pacote [intransferível / válido para o grupo familiar].

Ao assinar abaixo, você confirma que leu e concorda com estes termos.
[campo de assinatura]  —  Data/hora registradas automaticamente.
```

```text
Texto sujeito a validação jurídica antes de uso comercial (DEC-14).
Placeholders [N], [X], [intransferível/família] resolvidos pelo backend
a partir do cadastro do pacote — nunca hardcoded no frontend.
```

### 11.5 Comissão de venda — escopo futuro (DEC-15) e regra de reembolso unificada (DEC-18)

```text
Extensão da comissão de venda para PLANOS DE ASSINATURA está registrada como
intenção, NÃO implementada nesta versão.
Motivo do adiamento: plano tem múltiplos momentos de cobrança (adesão + cada
renovação), o que exige decidir separadamente se a comissão de venda se aplica
só na adesão, em toda renovação, ou em degrau decrescente — esse ponto
permanece aberto.
A condição de CLAWBACK, porém, já está pré-decidida (DEC-18) e vale desde já
quando essa extensão for implementada: reversão total apenas se uso=0;
qualquer uso torna a comissão de venda definitiva.
Nenhuma implementação de comissão de venda em planos antes de decisão explícita
do Platform Owner sobre o ponto ainda aberto (momento de aplicação).
```

### 11.6 Ressalva jurídica — direito de arrependimento e canal de venda (DEC-18)

```text
O art. 49 do CDC garante devolução integral e imediata, sem custos adicionais,
em compras fechadas FORA do estabelecimento comercial (online, app, telefone,
WhatsApp/KortexLink), dentro de 7 dias da assinatura/aceite ou do recebimento.

Pela leitura corrente da lei, venda PRESENCIAL na comanda do salão não se
enquadra nesse dispositivo especificamente — mas o sistema deve registrar o
CANAL da venda (presencial vs. distância) em todo pacote e plano vendido,
porque é esse dado que determina qual regra de reembolso se aplica.

Pontos que exigem validação jurídica antes de produção comercial (somam-se
aos já registrados em DEC-14):
- Se o uso de 1 sessão dentro dos 7 dias de um pacote/plano vendido a
  distância extingue ou não o direito de arrependimento do art. 49.
- Se a retenção de custos (taxa de cartão, nota fiscal) em reembolso de
  venda presencial com uso=0, fora do prazo de reflexão, é defensável.
```

---

## 12. Matriz de dependências e ordem de implementação dos cadastros

| Ordem | Cadastro | Depende de | Libera |
|---:|---|---|---|
| 1 | Formas de pagamento | — | Checkout real |
| 2 | Staff | — | Agenda, comissão |
| 3 | Serviços | Staff (matriz de habilitação) | Agenda, checkout |
| 4 | Clientes | — (contínuo) | Agenda, score, LGPD |
| 5 | Produtos | — | Revenda + consumo técnico |
| 6 | Complementos | Serviços | Up-sell no booking |
| 7 | Combos | 1–3 + rateio aprovado (D-04) | Chain booking com preço fechado |
| 8 | Pacotes | KortexFlow (ledger + obrigações) | Receita antecipada governada |
| 9 | Planos | KortexFlow + dunning + wallet | MRR e ocupação terça–quinta |

---

## 13. Dados Sensíveis do Cliente — Módulo Isolado (D26/DEC-19)

**Resolve D-07.** Anamnese, alergia, contraindicação, saúde e estética íntima ficam **fora** do cadastro base de cliente (Parte II §4), em módulo próprio, isolado por regime jurídico mais restrito.

### 13.1 Base legal

```text
Dado de saúde é dado sensível (LGPD art. 5º, II). O art. 11 permite apenas dois
caminhos: consentimento específico e destacado (inciso I), ou uma das 7 exceções
do inciso II — nenhuma das quais se aplica a salão de beleza/barbearia:
- Não há "legítimo interesse" para dado sensível (essa base só existe no art. 7º,
  para dado comum) — a rota mais simples do resto do sistema NÃO está disponível aqui.
- A exceção de "tutela da saúde" (alínea f) vale só para profissional de saúde,
  serviço de saúde ou autoridade sanitária — não cobre salão/barbearia.

BASE LEGAL ÚNICA: consentimento específico e destacado (art. 11, I).
```

### 13.2 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Consentimento específico | Sim | Separado de qualquer outro consentimento (LGPD, marketing, aceite de pacote); finalidade própria: "prestar o serviço com segurança, evitando reação alérgica ou contraindicação" |
| Data, hora e canal do consentimento | Sim | T6 (auditoria de mutação) |
| Dado sensível estruturado | Não | Alergias e contraindicações relevantes ao serviço contratado — não ficha médica completa (minimização) |
| Serviço/procedimento vinculado | Sim | Todo registro sensível associa-se a um serviço ou categoria de serviço específico — nunca genérico |
| Prazo de retenção | Sim | Vigência definida; NÃO usa T3 (arquivar para sempre) — ver 13.3 |
| Status do consentimento | Sim | ativo → revogado. Revogação apaga o dado sensível especificamente, não o cadastro de cliente inteiro |

### 13.3 Regras e invariantes

| Regra | Status |
|---|---|
| Nenhum dado sensível é coletado, exibido ou processado sem o consentimento específico e destacado (13.1) ativo | CRÍTICO |
| Consentimento sensível NUNCA é pré-marcado, agrupado ou implícito em outro aceite (LGPD exige "específico e destacado") | CRÍTICO |
| Visibilidade restrita: apenas staff que executa o atendimento vinculado + dono/gerente. Não é visível a toda a equipe (diferente do cadastro geral de cliente) | CRÍTICO |
| **Exceção à regra T3 (arquivar, nunca deletar):** dado sensível tem prazo de retenção definido; ao expirar ou mediante revogação, é deletado ou anonimizado de fato — não apenas arquivado | CRÍTICO |
| Cliente pode consultar e solicitar exclusão do próprio dado sensível a qualquer momento (LGPD art. 18) | CRÍTICO |
| Minimização: coleta-se apenas o necessário para o serviço específico, nunca histórico médico amplo | CRÍTICO |
| Compartilhamento com terceiros (ex.: fornecedor de produto, plataforma de IA) exige novo consentimento específico — nunca herda do consentimento original | CRÍTICO |
| **VALIDAÇÃO JURÍDICA PENDENTE:** texto exato do consentimento e prazo de retenção — mesma ressalva já aplicada a DEC-14/DEC-18. Base legal (art. 11, I) está fundamentada; redação final não | BLOQUEADO até validação |

---

## 14. Decisões conceituais originais (D-01 a D-09)

Todas as 9 decisões foram endereçadas — nenhuma pendência restante. Registro completo, com reconciliação D → DEC, no Decision Log, Seção 2. D-07 resolvida em 13 acima (DEC-19).

## 15. O que NÃO construir agora

```text
Preço dinâmico por profissional/nível.
Tipos de pagamento customizados pelo tenant.
Ficha de anamnese dentro do cadastro de cliente.
Venda de planos ou pacotes antes do KortexFlow real.
Combos com rateio "manual caso a caso".
Importação em massa de cadastros sem regra de dedupe.
Campos livres de desconto no cadastro (desconto é política, não cadastro).
```

---

---
---

# PARTE III — CONFIGURAÇÃO, ONBOARDING, COMANDA, GORJETA E NÍVEIS

## 0. Registro de decisões do Platform Owner

As decisões DEC-01 a DEC-18, com texto completo, rationale e histórico de supersessão, vivem no Decision Log (`KORTEXOS_5_1_2_DECISION_LOG.md`, Seção 1) — arquivo companion, nunca editado.

As regras VIGENTES resultantes dessas decisões estão especificadas nas seções 1 a 6 abaixo; cada uma cita o(s) DEC(s) que a fundamenta(m).

## 1. Business Configuration & Policy Layer (evolução de D02)

### 1.1 Nome canônico

**Business Configuration & Policy Layer — Camada de Configuração e Políticas do Negócio.**
Interface administrativa: **Business Settings / Configurações do Negócio.**

D02 deixa de se chamar "Business Setup & Policy Hub" e passa a este nome. RENOMEAR, não recriar.

### 1.2 Definição

Centraliza os dados cadastrais, configurações globais, políticas operacionais e padrões herdáveis da empresa e de suas unidades, servindo como fonte canônica para os demais domínios do sistema.

### 1.3 O que pertence à camada

| Grupo | Conteúdo |
|---|---|
| Identidade | Dados cadastrais, CNPJ, identidade comercial, identidade visual |
| Estrutura | Unidades, endereços, fusos horários |
| Regional | Moeda, idioma, configurações regionais |
| Calendário | Horários operacionais padrão (ver seção 2 — Calendar Policy) |
| Políticas | Cancelamento, atraso, no-show, depósito, fiado, régua progressiva |
| Agendamento | Regras gerais: antecedência, janela de booking, buffers default |
| Padrões financeiros | Padrões de preço, comissão, duração, absorção de taxa |
| Atendimento | Canais habilitados, configurações de atendimento |
| Plataforma | Preferências globais, feature flags governadas |
| Herança | Valores padrão herdados pelas unidades |

### 1.4 O que NÃO pertence à camada

```text
Não calcula disponibilidade (Availability Resolver, D07).
Não cria appointments (D08).
Não calcula comissão ou pagamento (D17/D13).
Não controla ledger (D15).
Não executa campanhas (D21/Automation Control Plane).
Não armazena regra específica de um cliente (D05/D24).
Não substitui os domínios especializados: fornece políticas; cada domínio valida e executa.
```

### 1.5 Hierarquia canônica de herança

```text
Sistema (defaults do KortexOS™)
→ Empresa (tenant): padrão global
→ Unidade: herda a empresa; aplica overrides autorizados
→ Profissional: apenas para domínios delegados (calendário próprio, nível, overrides de serviço)
```

### 1.6 Semântica de herança — regra central

| Regra | Definição | Status |
|---|---|---|
| Herdar ≠ copiar | Campo não configurado na unidade é um PONTEIRO para o nível acima. Mudança na empresa propaga automaticamente a todas as unidades que herdam | CRÍTICO |
| Override congela | Override na unidade congela o campo até ação explícita "restaurar herança" | CRÍTICO |
| Override autorizado por campo | Cada política declara `override_permitido`: sim / não / com aprovação (Action Request). Padrão validado por mercado: plataformas enterprise listam explicitamente quais configurações de unidade podem sobrepor a organização | CRÍTICO |
| Resolução backend-only | O domínio consumidor consulta a política EFETIVA resolvida pelo backend. Frontend nunca resolve herança | CRÍTICO |
| Vigência | Políticas mudam por vigência; mudança não retroage sobre fatos consumados | CRÍTICO |
| Auditoria | Toda mudança registra autor, data, escopo, valor anterior | CRÍTICO |

Exemplo canônico: Empresa define cancelamento até 24 h. Unidade A não configura → herda 24 h e acompanha mudanças futuras da empresa. Unidade B faz override para 12 h → congela em 12 h até restaurar herança.

### 1.7 Proibições

```text
Segunda fonte de configuração é proibida (inclusive onboarding — seção 3).
Configuração duplicada por cópia é proibida.
Override sem autorização declarada no campo é proibido.
Feature flag alterando verdade financeira sem gate é proibido.
```

---

## 2. Calendar Policy & Availability Layer (evolução de D02 + D05)

### 2.1 Nome canônico

**Calendar Policy & Availability Layer — Camada de Políticas de Calendário e Disponibilidade.**

```text
Esta camada mantém POLÍTICAS de calendário.
Quem calcula horários reserváveis é o Availability Resolver, dentro do D07.
Chamar esta camada de "Calendar Engine" é proibido — ela não calcula nada.
```

### 2.2 Objetos de política

| Objeto | Escopo | Conteúdo |
|---|---|---|
| Horário padrão | Unidade | Grade semanal (abertura/fechamento por dia) |
| Turnos | Profissional | Grade semanal de trabalho, pausas, intervalos |
| Feriados | Empresa/Unidade | Nacional, estadual, municipal, custom; com flag "unidade abre?" |
| Aberturas excepcionais | Unidade | Dia/horário fora do padrão (ex.: véspera de festa) |
| Fechamentos excepcionais | Unidade | Reforma, evento, força maior |
| Folgas e férias | Profissional | Períodos de indisponibilidade |
| Bloqueios pontuais | Profissional/Recurso | Trecho do dia indisponível |
| Exceções pontuais | Qualquer | Sobrepõem tudo, com autor e motivo |

### 2.3 Precedência canônica de resolução

```text
1. Exceção pontual autorizada
2. Fechamento excepcional / feriado sem abertura
3. Abertura excepcional
4. Folga / férias do profissional
5. Turno do profissional
6. Horário padrão da unidade
7. Padrão herdado da empresa
```

### 2.4 Regras e invariantes

| Regra | Status |
|---|---|
| Turno de staff ⊆ horário da unidade. Trabalho fora do horário exige abertura excepcional autorizada e ativa o acréscimo de conveniência (seção 13.3 do Master) | CRÍTICO |
| Feriado com abertura opcional: a unidade decide; acréscimo configurável conforme yield | REAL |
| Mudança de política NÃO altera appointments confirmados: gera fila de conflitos para resolução humana via Command; remarcação em massa exige Action Request | CRÍTICO |
| Timezone é propriedade da unidade; todo cálculo de calendário resolve no timezone da unidade | CRÍTICO |
| Availability Resolver (D07) consome: política de calendário resolvida + appointments + locks + holds + yield → produz slots. A camada de política nunca produz slot | CRÍTICO |
| Política de calendário versionada com vigência; histórico reconstruível | CRÍTICO |

---

## 3. Business Onboarding Workflow (evolução de D03)

### 3.1 Nome e princípio canônico

**Business Onboarding Workflow — Fluxo de Onboarding do Negócio.**

```text
Onboarding coleta e valida.
A Business Configuration & Policy Layer governa e persiste.
Onboarding → Commands → Configuration Layer → domínios consomem.
Onboarding NÃO é uma segunda fonte de configuração
nem uma camada independente de regras.
```

### 3.2 Etapas canônicas, dependências e critérios de conclusão

| # | Etapa | Depende de | Critério de conclusão |
|---:|---|---|---|
| 1 | Dados cadastrais da empresa | — | CNPJ/razão social/contato validados |
| 2 | Primeira unidade | 1 | Endereço + timezone definidos |
| 3 | Regional: moeda, idioma | 2 | Persistido na Configuration Layer |
| 4 | Horários padrão | 2 | Grade semanal completa (Calendar Policy) |
| 5 | Profissionais iniciais | 2 | ≥1 staff com vínculo, role e nível |
| 6 | Serviços e grupos | 5 | ≥1 serviço com duração, preço e comissão default |
| 7 | Políticas básicas | 2 | Cancelamento, no-show e depósito definidos (defaults sugeridos, aceitos ou editados) |
| 8 | Meios de pagamento | 2 | ≥1 forma completa: tipo, taxa, prazo, conta, absorção |
| 9 | Identidade visual | 1 | Logo/cores (não bloqueia ativação) |
| 10 | Usuários e permissões | 5 | Dono + roles iniciais confirmados |

### 3.3 Readiness e gates de ativação

| Ativação | Exige |
|---|---|
| Agenda interna | Etapas 4, 5, 6 |
| Checkout | Etapa 8 completa (forma sem taxa/prazo/conta/absorção não ativa checkout) |
| Booking público | Agenda interna + política de cancelamento/no-show + visibilidade de serviços |
| Campanhas (KortexLink) | Consentimento configurado; nunca no onboarding |

Readiness score = % de etapas concluídas + estado dos gates de ativação. Exibido no cockpit até 100%.

### 3.4 Regras e invariantes

| Regra | Status |
|---|---|
| Onboarding é retomável e idempotente; reexecutar uma etapa não duplica registro | CRÍTICO |
| Templates por segmento (barbearia, salão, estética) aceleram catálogo; nada é criado sem confirmação explícita | REAL |
| Estados: `not_started → in_progress → completed → closed`. Após `closed`, o fluxo se encerra definitivamente | CRÍTICO |
| Alterações posteriores acontecem nas telas administrativas (Business Settings), usando OS MESMOS contratos backend do onboarding — write-path único | CRÍTICO |
| Onboarding não grava em storage próprio, não mantém rascunho paralelo de configuração | CRÍTICO |

### 3.5 Texto canônico para o Blueprint

> Business Configuration & Policy Layer — fonte canônica dos dados cadastrais, configurações globais, políticas operacionais e padrões herdáveis da empresa e de suas unidades. O Business Onboarding Workflow coleta e valida a configuração inicial, mas toda persistência e alteração posterior ocorre pelos contratos canônicos dessa camada.

---

## 4. Comanda Lifecycle & Reopen (evolução de D12 + D14 + D15) — DEC-03

### 4.1 Estados canônicos da comanda

```text
aberta → em_atendimento → fechada
fechada → reaberta → refechada
qualquer estado antes de fechada → cancelada
Nenhum estado é destrutivo. Nada é apagado.
```

### 4.2 Princípio: reabrir não é editar o passado

| Regra | Definição | Status |
|---|---|---|
| Versões, não edição | Fechamento v1 permanece imutável. Reabertura cria v2 vinculada à v1. O ledger recebe reversão da v1 + lançamentos da v2 | CRÍTICO |
| Cascata completa de reversão | Reabrir reverte automaticamente: comissão, split de gorjeta, consumo de benefício (devolve sessão/quota/crédito), baixa de estoque e alocação de pagamento | CRÍTICO |
| Delta de pagamento | Novo total > pago → cobra diferença. Novo total < pago → devolve pela mesma forma ou credita wallet, conforme política | CRÍTICO |
| Motivo obrigatório | Reabertura registra motivo, autor e diff v1→v2 | CRÍTICO |
| Idempotência | Reabrir e refechar exigem `idempotency_key` como toda mutação financeira | CRÍTICO |

### 4.3 Janela de reabertura e travas financeiras

Padrão validado por mercado: plataformas enterprise permitem editar fatura pós-fechamento apenas com permissão explícita e bloqueiam quando a fatura está sob trava financeira.

| Momento | Quem pode | Mecanismo |
|---|---|---|
| Antes do fechamento de caixa do dia | Gerente ou dono | Reabertura direta com motivo |
| Após fechamento de caixa, antes do payout/fiscal | Dono | Action Request obrigatório |
| Após payout do staff, liquidação do PSP ou emissão fiscal | Ninguém reabre | **Financial lock.** Correção só por estorno/lançamento corretivo (fluxo de estorno do Master 7.3) |

### 4.4 Estorno vs. reabertura — fronteira canônica

```text
Estorno: desfaz o efeito financeiro de item ou venda. A comanda permanece fechada.
Reabertura: corrige a COMPOSIÇÃO da comanda (itens, profissionais, formas, gorjeta)
preservando vínculo, histórico e ledger por versão.
Reabertura após financial lock é proibida — vira estorno + nova venda.
```

### 4.5 Edição plena de comanda e modal de item — DEC-11 e DEC-12

Realidade operacional obrigatória: a comanda é um documento vivo até as travas da seção 4.3. Clicar em qualquer item abre o modal canônico de edição com todas as alterações possíveis.

| Alteração no modal do item | Governança |
|---|---|
| Valor unitário | Editável por permissão; delta contra preço resolvido registra como desconto/acréscimo de item com motivo; Negative Guard simula margem |
| Quantidade | Editável; recalcula estoque/consumo técnico |
| Profissional executor (e assistente) | Editável; recalcula comissão e split de gorjeta |
| Comissão (% ou valor) do item | Editável conforme alçada da persona (padrão: dono/gerente); motivo + trilha obrigatórios; fora da alçada → Action Request; comissão negativa mascarada segue proibida |
| Desconto do item | Editável em **R$ ou %** (DEC-16), dentro da política; fora dela → Action Request |
| Cortesia | Liga/desliga conforme política; comissão da cortesia definida em política, nunca implícita |
| Associar/desassociar benefício (pacote, plano, corporativo, parceiro) | Sempre disponível; consumo/devolução de obrigação via backend |
| Identificador externo (token/fidelidade) | Editável; sem efeito financeiro direto |
| Excluir item | Permitido até fechamento; após fechamento, só via reabertura (v2) |

| Regra estrutural | Status |
|---|---|
| Toda edição de item é evento auditado (autor, antes/depois, motivo quando exigido) | CRÍTICO |
| Duas semânticas de valor editável (DEC-13), nunca misturadas: | — |
| (a) VALOR DO ITEM (modal): reprecificação — muda o valor devido, recalcula comissão, desconto/acréscimo com motivo, Negative Guard simula margem | CRÍTICO |
| (b) VALOR COBRADO na comanda ≠ valor devido: a diferença NÃO reprecifica itens — cobrado a menor vira débito autorizado do cliente (fiado governado: Negative Guard + staff liquidado pelo devido, Master 7.3) e cobrado a maior vira crédito de wallet com origem "pagamento a maior/troco" | CRÍTICO |
| Comissão calcula sempre sobre o valor DEVIDO dos itens; divergência de cobrança jamais altera base de comissão | CRÍTICO |
| Comanda aberta/reaberta edita livre dentro das permissões; comanda sob trava financeira (4.3) não edita | CRÍTICO |
| Frontend exibe o modal; todo recálculo (comissão, split, benefício, estoque, totais) é backend | CRÍTICO |

### 4.6 Gates impactados

Gate 10 (Checkout Integrity), 11 (Ledger Balance), 12 (Payment Allocation), 14 (Commission Accuracy) e 18 (Cash Register Integrity) ganham cenários de reabertura: reabrir → editar → refechar deve fechar soma zero no ledger, recompor estoque, recompor benefício e recalcular comissão/gorjeta sem resíduo.

---

## 5. Tip Engine — gorjeta canônica (evolução de D12 + D17) — DEC-01 e DEC-02

### 5.1 Absorção de taxa (DEC-01)

```text
A gorjeta segue o MESMO modelo de absorção de taxa da forma de pagamento usada:
Bruto Salão, Dividido ou Bruto Staff — conforme cadastro da forma (Parte II, seção 3.3)
e contrato do profissional.
```

Tip isolation reinterpretado sem mentira contábil:

| Regra | Status |
|---|---|
| Gorjeta nunca vira receita do salão nem base de comissão | CRÍTICO (inalterado) |
| "100% para o destinatário" = 100% do valor líquido conforme o modelo de absorção da forma | CRÍTICO |
| Extrato do staff mostra: gorjeta bruta, taxa aplicada, modelo de absorção, líquido | CRÍTICO |
| Gorjeta em dinheiro não sofre taxa | REAL |
| Lançamento de gorjeta aceita **R$ ou %** (DEC-16); percentual calcula sobre o valor dos serviços da comanda (base igual à do split, seção 5.2); backend resolve e persiste o valor absoluto antes de rodar o split | CRÍTICO |

### 5.2 Split multi-profissional (DEC-02)

Comanda fechada com múltiplos serviços, produtos e profissionais:

```text
peso(profissional_i) = Σ valor_serviços_i  ×  fator_tempo_i (opcional)
gorjeta_i = gorjeta_total × peso_i / Σ pesos
```

| Regra | Definição | Status |
|---|---|---|
| Default canônico | Rateio proporcional ao VALOR dos serviços de cada profissional. Prática dominante de mercado (split automático por preço do serviço) | CRÍTICO |
| Fator tempo | Política do tenant pode ponderar por tempo de execução (puro ou híbrido valor×tempo) — cobre serviços de valor próximo e duração muito diferente | REAL, configurável |
| Split manual | Recepção/cliente pode direcionar valores específicos por profissional no checkout (custom split) | REAL |
| Produtos fora da base | Produtos não entram na base de rateio de gorjeta; gorjeta é sobre serviço | CRÍTICO |
| Assistente | Percentual do assistente, quando existir, sai declarado na política, nunca implícito | REAL |
| Arredondamento | Centavos residuais vão ao profissional de maior peso; soma dos splits = gorjeta total, sempre | CRÍTICO |
| Reabertura | Reabrir a comanda recalcula o split integralmente na v2 | CRÍTICO |

---

## 6. Staff Levels & Pricing Resolution (evolução de D05 + D06 + D17) — DEC-04

### 6.1 Cadastro de níveis

| Campo | Regra |
|---|---|
| Níveis por tenant | Nome e ordem livres (ex.: Aprendiz → Barbeiro → Sênior → Master) |
| Nível do profissional | Obrigatório; com vigência (promoção não retroage) |
| Multiplicador ou tabela por nível | Nível pode definir preço/duração/comissão por serviço |

### 6.2 Cascata canônica de resolução (preço, tempo e comissão)

```text
1. Override profissional × serviço   (preço, tempo, valor de comissão)
2. Tabela nível × serviço
3. Serviço base
Yield (off-peak, premium window, conveniência) multiplica SOBRE o valor resolvido.
```

| Regra | Status |
|---|---|
| Os três eixos do override são independentes: pode haver override só de tempo, só de preço ou só de comissão | CRÍTICO |
| Booking com profissional escolhido mostra o preço resolvido daquele profissional; sem profissional, exibe "a partir de" (menor preço resolvido entre habilitados) | CRÍTICO |
| Preço/tempo resolvidos travam no appointment confirmado; promoção de nível posterior não reprecifica | CRÍTICO |
| Comissão calcula sobre o preço efetivamente cobrado (resolvido + yield + rateios) | CRÍTICO |
| Prática validada por mercado: plataformas líderes ajustam tempo e preço por profissional individual automaticamente | REFORÇAR |
| Frontend nunca resolve a cascata; consome o valor resolvido do backend | CRÍTICO |

---
