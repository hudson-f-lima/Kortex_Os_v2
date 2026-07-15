# KORTEXOS™ 5.1.1 — MASTER BRIEFING CANÔNICO

**Produto:** KortexOS™
**Versão do produto:** 5.1.1
**Status documental:** CANÔNICO
**Estado de implementação:** DESCONHECIDO neste documento; exige evidência no repositório
**Autoridade:** Platform Owner
**Data de referência:** 2026-07-14
**Natureza:** visão de produto, limites arquiteturais, invariantes, prioridades e critérios de aceite

---

## 0. Resumo executivo

KortexOS™ é um sistema operacional de capacidade, finanças, recorrência e decisão para negócios de beleza e bem-estar.

A agenda é a superfície visível. O produto real é a capacidade perecível do negócio: tempo, profissionais, recursos e demanda que precisam ser coordenados com margem, confiança e segurança transacional.

A tese central é:

```text
Dados canônicos
→ decisão matemática explicável
→ política e elegibilidade
→ execução transacional
→ mensuração incremental
→ automação progressiva
```

O KortexOS™ não deve evoluir como um conjunto de telas, campanhas ou bots independentes. Deve operar como um único core que coordena:

- cliente;
- profissional;
- serviço;
- recurso;
- slot;
- preço;
- benefício;
- pagamento;
- comissão;
- mensagem;
- risco;
- margem;
- resultado.

A prioridade estratégica é construir primeiro um motor determinístico no backend, com dados reconstruíveis e decisões explicáveis. Bot e IA entram depois como interfaces de interpretação, comunicação e assistência.

### Resultado esperado

```text
Menos ociosidade.
Menos no-show.
Mais recorrência.
Mais receita por hora disponível.
Mais margem protegida.
Mais previsibilidade de caixa.
Mais autonomia operacional.
Menos dependência do dono.
```

---

## 1. Função deste documento

### 1.1 O que este documento decide

Este Master Briefing é a fonte canônica para:

- identidade e posicionamento do produto;
- problema estratégico;
- objetivos e prioridades;
- limites de escopo;
- arquitetura-alvo;
- domínios e responsabilidades;
- invariantes críticas;
- políticas de automação;
- critérios de aceite;
- riscos não aceitáveis.

### 1.2 O que este documento não decide

Este documento não é fonte de verdade para:

- estado atual da implementação;
- branch, commit ou release implantada;
- migrations existentes;
- endpoints implementados;
- cobertura de testes;
- configuração de ambientes;
- backlog diário;
- handoff operacional;
- histórico de decisões;
- instruções de instalação;
- runbooks de incidente.

Esses fatos mudam com frequência e devem permanecer próximos da execução. Não devem ser duplicados aqui.

### 1.3 Regra de evidência

Uma decisão pode ser canônica como direção de produto sem estar implementada.

A realidade técnica deve ser classificada separadamente:

| Classificação | Definição |
|---|---|
| **REAL** | Evidência confirmada em código, banco, API, teste ou execução |
| **PARCIAL** | Parte relevante existe, mas a cadeia completa não foi provada |
| **MOCKADO** | Simulação ou demonstração sem verdade operacional |
| **HARDCODED** | Valor ou comportamento fixo fora de configuração ou regra canônica |
| **CRÍTICO** | Controle obrigatório ou risco capaz de comprometer dados, dinheiro, segurança ou confiança |
| **DESCONHECIDO** | Não auditado ou sem evidência suficiente |

**Regra:** nenhuma afirmação de implementação recebe `REAL` apenas por estar descrita neste documento.

### 1.4 Regra contra dupla verdade

```text
Uma informação mutável deve possuir uma única autoridade.
Outros documentos apontam para essa autoridade; não repetem o conteúdo.
```

Duplicação de status, regra, contrato, schema ou decisão é considerada dívida documental.

---

## 2. Identidade e posicionamento

### 2.1 Nome

**KortexOS™**

### 2.2 Categoria

**Intelligent Capacity, Fintech & Decision Operating System for Beauty & Wellness**

### 2.3 Definição operacional

KortexOS™ é a infraestrutura operacional que transforma capacidade disponível em receita protegida, recorrente, previsível e auditável.

```text
Agenda organiza tempo.
KortexOS™ organiza capacidade, dinheiro, confiança e decisão.
```

### 2.4 Problemas que o produto resolve

- horários ociosos e gaps improdutivos;
- cancelamentos e no-show;
- baixa recorrência;
- perda silenciosa de margem;
- cálculo manual de comissão e repasse;
- benefícios sem origem ou controle;
- saldos paralelos;
- campanhas sem coordenação;
- ausência de previsibilidade financeira;
- dependência excessiva do proprietário;
- decisões operacionais baseadas em intuição isolada.

### 2.5 Diferenciais estratégicos

| Eixo | Diferencial |
|---|---|
| Capacidade | Disponibilidade real, matching, ocupação e recuperação de slots |
| Finanças | Checkout, pagamento, ledger, wallet, comissão e payout integrados |
| Recorrência | Rebooking, assinaturas, pacotes, corporativo e parceiros |
| Confiança | No-show progressivo, depósito, reliability e healing |
| Decisão | Expected value, restrições, experimentação e explicabilidade |
| Automação | Execução progressiva, idempotente, auditável e reversível |
| IA | Compreensão e assistência sem soberania sobre regras críticas |

---

## 3. Objetivos de qualidade

As decisões arquiteturais devem priorizar, nesta ordem:

1. integridade dos dados;
2. segurança e isolamento;
3. consistência transacional;
4. auditabilidade e recuperação;
5. simplicidade operacional;
6. performance;
7. escalabilidade;
8. experiência do usuário.

### 3.1 Metas arquiteturais prioritárias

| Meta | Resultado esperado |
|---|---|
| Integridade | Nenhum estado financeiro, de agenda ou benefício pode divergir silenciosamente |
| Isolamento | Nenhum tenant, usuário ou profissional acessa dados fora do seu contrato |
| Consistência | Operações críticas concluem integralmente ou não alteram o estado |
| Auditabilidade | Toda decisão e mutação crítica possui origem, autor, política e evidência |
| Operabilidade | Falhas são detectáveis, interrompíveis, recuperáveis e explicáveis |

### 3.2 Princípio de evolução

```text
Solução mínima segura
→ validação
→ observação
→ automação limitada
→ escala
```

Sofisticação sem evidência é bloqueada.

---

## 4. Invariantes arquiteturais

### 4.1 Backend como fonte da verdade

O backend decide e valida:

- disponibilidade;
- preço;
- duração;
- elegibilidade;
- benefício;
- desconto;
- comissão;
- saldo;
- pagamento;
- ledger;
- políticas;
- estados de agenda;
- autorização de automação.

Frontend, bot e canais externos apenas:

- apresentam dados;
- coletam intenção;
- enviam Commands;
- exibem resultados confirmados.

### 4.2 Banco e APIs como contratos canônicos

- schemas possuem constraints explícitas;
- APIs possuem contratos versionados;
- mutações críticas usam Commands específicos;
- eventos possuem nomes e payloads versionados;
- integrações não bypassam validação de domínio.

### 4.3 Operações críticas

Toda operação crítica deve ser:

- transacional;
- idempotente;
- autorizada;
- auditável;
- observável;
- recuperável.

### 4.4 Ledger

O ledger financeiro deve ser:

- double-entry;
- append-only;
- balanceado;
- tenant-scoped;
- reconstruível;
- protegido contra `UPDATE` e `DELETE` arbitrários;
- corrigido por reversão, nunca por edição histórica.

### 4.5 Dinheiro

Todo valor monetário usa inteiro em centavos.

```text
money = bigint em centavos
```

Ponto flutuante é proibido para verdade financeira.

### 4.6 Multi-tenant

- tenant explícito em toda entidade relevante;
- RLS real no banco;
- contexto de identidade validado no backend;
- nenhuma confiança em `tenant_id` fornecido livremente pelo frontend;
- funções privilegiadas com escopo mínimo;
- auditoria de acesso e mutação.

### 4.7 Eventos e integrações

- mutação de domínio e publicação de evento usam outbox transacional;
- retries são idempotentes;
- webhooks são autenticados e protegidos contra replay;
- falhas persistentes entram em fila de exceção;
- integrações possuem circuit breaker e observabilidade.

### 4.8 Automação

Nenhuma automação crítica inicia em execução plena.

```text
OBSERVE
→ RECOMMEND
→ APPROVE
→ LIMITED_AUTOMATION
→ FULL_AUTOMATION
```

### 4.9 Inteligência artificial

IA não possui soberania sobre:

- agenda;
- preço;
- benefício;
- comissão;
- payout;
- saldo;
- pagamento;
- ledger;
- política;
- penalidade;
- confirmação transacional.

---

## 5. Ecossistema do produto

Todas as superfícies compartilham o mesmo core.

| Solução | Papel | Limite |
|---|---|---|
| **kortex.io** | Portal SaaS, administração, onboarding, billing e presença pública | Não calcula regra crítica no navegador |
| **KortexApp** | Aplicação operacional para dono, gerente, recepção, profissional e cliente | Consome projeções e envia Commands |
| **Kortex.ai** | Interpretação, triagem, explicação, copiloto e handoff | Não executa mutação crítica soberanamente |
| **KortexFlow** | Checkout, pagamento, ledger, wallet, comissão, repasse e reconciliação | Toda mutação financeira passa pelo backend |
| **KortexLink** | WhatsApp, e-mail, push, QR, links, campanhas, webhooks e integrações | Comunicação não altera verdade diretamente |

### 5.1 Princípio de core único

```text
Cinco superfícies.
Um único domínio operacional.
Nenhuma engine paralela.
```

---

## 6. Mapa de capacidades

### 6.1 Plataforma e identidade

Responsabilidades:

- tenants e unidades;
- usuários e memberships;
- papéis e permissões;
- RLS;
- configuração do negócio;
- planos SaaS;
- feature flags;
- release e auditoria.

### 6.2 Pessoas e catálogo

Responsabilidades:

- clientes;
- profissionais;
- preferências;
- consentimentos;
- serviços;
- produtos;
- preços;
- duração;
- recursos;
- habilitação serviço × profissional.

### 6.3 Capacidade e agenda

Responsabilidades:

- disponibilidade;
- slots;
- holds;
- appointments;
- serviços encadeados;
- recorrência;
- grupos;
- recursos compartilhados;
- cancelamento;
- no-show;
- waitlist;
- gaps e ocupação.

### 6.4 Comércio e finanças

Responsabilidades:

- checkout;
- pagamentos;
- depósitos;
- estornos;
- caixa;
- ledger;
- wallet;
- gorjeta;
- comissão;
- conta corrente do profissional;
- payout;
- reconciliação.

### 6.5 Recorrência e benefícios

Responsabilidades:

- assinaturas;
- pacotes;
- créditos;
- cashback;
- gift cards;
- benefícios corporativos;
- parceiros;
- elegibilidade;
- consumo;
- expiração;
- dunning.

### 6.6 Confiança e ciclo de vida

Responsabilidades:

- rebooking;
- reativação;
- churn;
- confiabilidade;
- no-show;
- depósito progressivo;
- healing;
- referral;
- VIP;
- recuperação de experiência negativa.

### 6.7 Automação e mensageria

Responsabilidades:

- eventos;
- policies;
- contato;
- frequência;
- supressão;
- templates;
- campanhas;
- Action Requests;
- outbox;
- integrações;
- automação controlada.

### 6.8 Analytics e decisão

Responsabilidades:

- KPIs reconstruíveis;
- heatmaps;
- features;
- expected value;
- matching;
- experimentação;
- atribuição;
- uplift;
- explicabilidade;
- monitoramento de dano.

### 6.9 Expansão

Responsabilidades futuras:

- multiunidade;
- marketplace;
- white-label;
- API pública;
- rede de parceiros;
- enterprise;
- integrações financeiras ampliadas.

**Regra:** expansão não pode preceder estabilidade do core.

---

## 7. Capacity & Agenda Core

### 7.1 Tese

Capacidade vendável é a interseção entre:

```text
profissional disponível
+ serviço habilitado
+ duração suficiente
+ recurso disponível
+ política permitida
+ margem aceitável
+ ausência de conflito
```

Slot visualmente livre não é prova de disponibilidade.

### 7.2 Estados mínimos de agendamento

```text
DRAFT
HOLD
PENDING_PAYMENT
CONFIRMED
CANCELLED
COMPLETED
NO_SHOW
EXPIRED
```

Transições inválidas devem ser bloqueadas no backend.

### 7.3 Booking hold

Ao selecionar um horário, o sistema deve criar um hold temporário com:

- identificador;
- cliente;
- profissional;
- serviço;
- recurso;
- início e fim;
- expiração;
- origem;
- chave idempotente.

O hold não é confirmação.

### 7.4 Confirmação

A confirmação deve ocorrer em uma transação que:

1. valida o hold;
2. bloqueia o slot;
3. valida serviço, profissional, recurso e duração;
4. recalcula preço e benefício;
5. valida pagamento ou depósito quando exigido;
6. cria o appointment;
7. consome a oferta quando aplicável;
8. encerra o hold;
9. grava auditoria e evento.

### 7.5 Waitlist inteligente

A waitlist deve armazenar intenção estruturada:

- serviços aceitos;
- profissionais preferidos e alternativos;
- datas e faixas;
- antecedência mínima;
- unidade;
- alternativas aceitas;
- validade;
- consentimento de contato.

Fluxo:

```text
vaga liberada
→ candidatos compatíveis
→ ranking explicável
→ convite em ondas
→ primeiro aceite cria hold
→ confirmação transacional
→ demais convites são invalidados
```

### 7.6 Agenda recorrente

Agendamentos recorrentes devem possuir:

- série canônica;
- ocorrências independentes;
- política de alteração;
- pausa;
- exceções;
- prevenção de conflito futuro.

### 7.7 Reacomodação

Falta ou indisponibilidade de profissional pode gerar recomendação de:

- mesmo horário com outro profissional;
- outro horário com o mesmo profissional;
- outra combinação compatível.

A alteração depende de confirmação do cliente.

### 7.8 Proibições

- confirmação sem hold quando houver concorrência;
- disponibilidade calculada no frontend;
- dupla fonte de agenda;
- appointment criado por mensagem sem Command;
- conflito ignorado por integração externa;
- slot vendido sem recurso necessário;
- preço congelado apenas no canal;
- falsa confirmação em caso de falha de API.

---

## 8. KortexFlow — núcleo financeiro

### 8.1 Tese

Dinheiro não pode depender de cálculo visual, planilha paralela ou mutação informal.

### 8.2 Fluxo canônico

```text
checkout
→ pagamento
→ ledger
→ comissão/gorjeta
→ projeções
→ reconciliação
```

### 8.3 Invariantes

| Regra | Criticidade |
|---|---|
| Ledger double-entry e append-only | CRÍTICO |
| Soma de débitos e créditos igual a zero | CRÍTICO |
| Idempotência em toda mutação financeira | CRÍTICO |
| Reversão em vez de edição histórica | CRÍTICO |
| Gorjeta isolada da receita do salão | CRÍTICO |
| Comissão calculada no backend | CRÍTICO |
| Saldo reconstruível pelo ledger | CRÍTICO |
| Estorno ajusta comissão e benefício | CRÍTICO |
| Profissional não financia fiado autorizado | CRÍTICO |

### 8.4 Checkout

O checkout deve suportar:

- serviços;
- produtos;
- add-ons;
- descontos autorizados;
- benefícios;
- assinaturas;
- pacotes;
- gorjeta;
- pagamento misto;
- depósito;
- saldo de carteira;
- origem de campanha ou parceiro.

### 8.5 Conta corrente do profissional

Controla:

- produção;
- comissão;
- gorjeta;
- ajustes aprovados;
- estornos;
- adiantamentos;
- payouts;
- saldo projetado.

O profissional só acessa seus próprios dados financeiros.

### 8.6 Client Wallet

Pode representar:

- crédito real;
- cashback;
- reembolso;
- saldo de pacote;
- benefício de assinatura;
- crédito corporativo;
- crédito de parceiro;
- dívida autorizada.

Todo saldo possui:

- origem;
- validade quando aplicável;
- regra de consumo;
- trilha de auditoria;
- reconstrução financeira ou operacional.

### 8.7 Negative Guard

Protege contra:

- fiado sem limite;
- benefício com margem negativa;
- desconto excessivo;
- assinatura deficitária;
- uso indevido de plano;
- benefício off-peak em horário premium;
- dívida transferida ao profissional;
- comissão negativa silenciosa.

### 8.8 Reconciliação

O sistema deve detectar:

- pagamento no provedor sem checkout correspondente;
- checkout sem ledger;
- ledger desequilibrado;
- estorno sem reversão;
- duplicidade;
- divergência de taxa;
- payout inconsistente;
- caixa divergente.

---

## 9. Confiança, no-show e relacionamento

### 9.1 Régua progressiva

O tratamento deve ser proporcional, previsível e reversível.

| Situação | Resposta possível |
|---|---|
| Primeiro evento | Comunicação educativa |
| Reincidência | Confirmação reforçada ou depósito parcial |
| Risco elevado | Pré-pagamento conforme política |
| Histórico positivo posterior | Healing e redução de fricção |

### 9.2 Reliability Score

Pode considerar:

- faltas;
- cancelamentos tardios;
- atrasos;
- atendimentos concluídos;
- pagamentos bem-sucedidos;
- chargebacks;
- reagendamentos excessivos;
- tempo desde o último incidente.

O score deve possuir:

- fórmula versionada;
- reason codes;
- data de cálculo;
- explicabilidade;
- tratamento de exceções;
- mecanismo de recuperação.

### 9.3 Recuperação de experiência negativa

Cliente com reclamação ou incidente aberto não deve entrar em campanha comercial comum.

Fluxo:

```text
incidente
→ suspender marketing
→ classificar gravidade
→ atribuir responsável
→ resolver
→ registrar desfecho
→ reativar relacionamento quando seguro
```

### 9.4 Rebooking

Após atendimento concluído, o sistema pode:

- calcular intervalo esperado;
- sugerir próxima data;
- oferecer série recorrente;
- respeitar profissional e horário preferidos.

Prevenir churn é prioritário sobre recuperar churn.

### 9.5 Reativação

Jornada recomendada:

1. lembrete sem incentivo;
2. conveniência e horário compatível;
3. benefício de baixo custo marginal;
4. condição restrita a capacidade ociosa;
5. downsell apenas quando necessário.

Desconto automático na primeira tentativa é bloqueado.

### 9.6 Churn parcial

O sistema deve detectar quando o cliente continua ativo, mas abandona:

- uma categoria de serviço;
- um profissional;
- um produto;
- uma assinatura;
- frequência anterior.

---

## 10. Recorrência e benefícios

### 10.1 Assinaturas

Assinatura deve comprar previsibilidade e recorrência, não apenas desconto.

Pode utilizar:

- ciclos mensais;
- créditos;
- serviços definidos;
- limites por período;
- horários off-peak;
- add-ons;
- regras de pausa;
- renovação;
- dunning.

### 10.2 Regras de assinatura

- cobrança e consumo são separados;
- consumo passa pelo checkout;
- benefício é validado no backend;
- receita antecipada possui obrigação rastreável;
- comissão nasce do uso real ou da política definida;
- plano deficitário deve ser detectado;
- abuso e compartilhamento devem ser controlados.

### 10.3 Benefícios corporativos

Modelo B2B2C com:

- empresa contratante;
- elegíveis;
- créditos ou subsídios;
- regras de uso;
- billing;
- analytics agregados;
- privacidade individual.

A empresa não acessa histórico sensível individual.

### 10.4 Parceiros

Parceria é canal rastreável, não cupom aberto.

Exige:

- parceiro identificado;
- contrato ou política;
- link ou QR com origem;
- validade;
- elegibilidade;
- limite;
- consumo no checkout;
- cálculo de CAC, margem e recorrência;
- isolamento de dados pessoais.

### 10.5 VIP

Modelo recomendado:

```text
Canal de distribuição consentido
+ conversa individual para conversão
+ KortexOS™ para elegibilidade e mensuração
```

VIP representa acesso, prioridade, experiência e oportunidade. Não deve se tornar um canal permanente de desconto.

---

## 11. Kortex Autonomous Operations Engine

### 11.1 Definição

Engine transversal que transforma eventos em oportunidades, recomendações e Commands permitidos.

```text
Domain Event
→ Features
→ Eligibility
→ Policy
→ Expected Value
→ Matching
→ Contact Orchestration
→ Action Request ou Command
→ Outbox
→ Canal/API
→ Outcome Event
→ Measurement
```

### 11.2 Componentes

| Componente | Responsabilidade |
|---|---|
| Customer Timing Engine | Estimar ciclo de retorno e atraso normalizado |
| Demand & Occupancy Engine | Estimar ocupação e risco de slot vazio |
| Economic Value Engine | Calcular margem, custo e risco esperados |
| Matching Engine | Selecionar cliente, serviço, profissional, slot e ação |
| Incrementality Engine | Medir efeito causal e canibalização |
| Contact & Policy Orchestrator | Prioridade, consentimento, frequência e supressão |
| Automation Control Plane | Modo, rollout, kill switch, circuit breaker e rollback |
| Booking Orchestrator | Disponibilidade, hold, confirmação e integração de agenda |

### 11.3 Quatro mapas

#### Customer Heatmap

- frequência;
- intervalo de retorno;
- dias e horários;
- serviços;
- profissional preferido;
- ticket e margem;
- resposta a comunicação;
- confiabilidade;
- fadiga de contato.

#### Professional Heatmap

- ocupação;
- serviços habilitados;
- duração prevista e real;
- margem por hora;
- retenção;
- atrasos;
- cancelamentos;
- capacidade futura.

#### Occupancy Heatmap

- capacidade utilizável;
- ocupação histórica e futura;
- demanda por antecedência;
- gaps;
- horários premium;
- sobrecarga;
- recursos e buffers.

#### Economic Heatmap

- margem de contribuição;
- comissão;
- taxa de pagamento;
- custo do benefício;
- receita por hora;
- custo do canal;
- probabilidade de venda natural;
- valor da capacidade recuperada.

### 11.4 Customer Timing

Intervalo esperado:

\[
I_{c,s}=\alpha \cdot mediana_{cliente,serviço}+\beta \cdot mediana_{serviço}+\gamma \cdot mediana_{segmento}
\]

```text
α + β + γ = 1
```

Mais histórico individual aumenta `α`. Pouco histórico aumenta o peso do serviço e do segmento.

Índice de atraso:

\[
DelayRatio_{c,s}=\frac{dias\ desde\ a\ última\ visita}{intervalo\ esperado}
\]

Faixas iniciais são hipóteses versionadas:

| Delay Ratio | Estado |
|---:|---|
| < 0,80 | NOT_DUE |
| 0,80–1,05 | DUE_SOON |
| 1,05–1,35 | OVERDUE |
| 1,35–2,00 | AT_RISK |
| > 2,00 | LAPSED |

### 11.5 Expected Value

Valor esperado:

\[
EMV=P(aceite)\times P(comparecimento)\times margem-custos-riscos
\]

Valor incremental:

\[
IncrementalValue=(P(resultado|ação)-P(resultado|sem\ ação))\times margem-custo_{ação}
\]

O sistema deve preferir margem incremental a conversão bruta.

### 11.6 Matching

Primeira implementação recomendada:

```text
SQL
+ score determinístico
+ ordenação
+ reason codes
```

Evolução:

- min-cost flow para alocação simples;
- constraint solver para múltiplos serviços, buffers, recursos e precedências;
- modelos probabilísticos apenas após qualidade de dados.

O solver propõe. O domínio valida novamente e executa.

### 11.7 Função objetivo

Restrições duras:

1. isolamento;
2. consentimento;
3. disponibilidade;
4. capacidade;
5. compatibilidade;
6. política financeira;
7. idempotência;
8. não duplicidade.

Objetivos suaves:

- margem incremental;
- retenção;
- capacidade recuperada;
- adequação ao cliente;
- fairness;
- fadiga de comunicação.

### 11.8 Incrementalidade

Conversão após mensagem não prova causalidade.

Quando houver volume suficiente:

```text
tratamento
versus
controle/holdout
```

Métricas:

\[
IncrementalLift=Conversion_{tratamento}-Conversion_{controle}
\]

\[
IncrementalMargin=Margin_{tratamento}-Margin_{controle}-Cost_{ação}
\]

### 11.9 Contact & Policy Orchestrator

Prioridade inicial:

```text
segurança e incidente
> reclamação
> cobrança sensível
> agendamento transacional
> confirmação e waitlist
> rebooking
> retenção
> assinatura e VIP
> marketing amplo
```

Controles:

- consentimento por finalidade;
- frequency cap global;
- quiet hours;
- timezone;
- opt-out;
- supressão por reclamação;
- deduplicação;
- contato humano recente;
- agendamento futuro;
- conflito entre campanhas.

### 11.10 Registro de automação

Toda automação deve declarar:

- evento disparador;
- objetivo;
- owner;
- elegibilidade;
- exclusões;
- política e versão;
- Command permitido;
- necessidade de aprovação;
- canal e finalidade;
- limite de frequência;
- chave idempotente;
- custo;
- métrica principal;
- grupo de controle quando aplicável;
- kill switch;
- circuit breaker;
- rollback;
- reason codes.

---

## 12. Portfólio de automações

### 12.1 Prioridade P1

| Automação | Objetivo | Risco dominante |
|---|---|---|
| Rebooking pós-atendimento | Evitar churn | excesso de contato |
| Confirmação adaptativa | Reduzir no-show | tratamento injusto |
| Waitlist Recovery | Recuperar cancelamentos | concorrência de slot |
| Reativação por ciclo | Recuperar clientes | canibalização |
| Upsell compatível com slot | Aumentar margem por visita | atraso operacional |
| Reconciliação financeira | Proteger dinheiro | divergência silenciosa |

### 12.2 Prioridade P2

- compactação voluntária de agenda;
- agenda recorrente preventiva;
- preenchimento de gaps com add-ons;
- assinaturas off-peak;
- VIP segmentado;
- churn parcial;
- referral contextual;
- recuperação de créditos não utilizados;
- previsão de insumos;
- dunning.

### 12.3 Prioridade P3

- previsão de demanda;
- previsão de no-show;
- uplift multi-treatment;
- melhor canal;
- melhor incentivo;
- contextual bandit;
- recomendação de staffing;
- otimização multiunidade.

### 12.4 Bloqueado no estágio inicial

- reinforcement learning;
- preço individual opaco;
- campanhas autônomas geradas e disparadas por LLM;
- alteração automática de comissão;
- cancelamento reputacional sem política;
- automação sem modo `OBSERVE`;
- modelo sem grupo de comparação quando causalidade for necessária.

---

## 13. Bot e inteligência artificial

### 13.1 Função correta do bot

O bot pode:

- interpretar intenção;
- coletar preferências;
- apresentar opções autorizadas;
- consultar o backend;
- solicitar confirmação;
- resumir contexto;
- encaminhar para humano.

O bot não pode:

- inventar disponibilidade;
- calcular preço crítico;
- criar desconto;
- consumir benefício;
- confirmar reserva sem transação;
- alterar comissão;
- criar ledger;
- ignorar consentimento.

### 13.2 Função correta da IA generativa

- classificação de intenção;
- extração de entidades;
- resumo de conversa;
- personalização de linguagem;
- explicação de recomendação;
- detecção de possível insatisfação;
- handoff.

### 13.3 Machine learning clássico

Adequado para:

- retorno;
- no-show;
- ocupação;
- escolha de horário;
- serviço provável;
- resposta por canal.

### 13.4 Otimização matemática

Adequada para:

- matching;
- capacidade;
- agenda;
- orçamento;
- recursos;
- alocação;
- restrições.

### 13.5 Causal ML

Adequado para:

- efeito incremental;
- incentivo mínimo;
- canibalização;
- comparação entre tratamentos.

---

## 14. Agendamento automático por API

### 14.1 Condição de viabilidade

Automação completa exige:

- API oficial e transacional;
- disponibilidade em tempo real;
- criação e expiração de hold;
- criação, alteração e cancelamento;
- webhooks;
- idempotência;
- autenticação;
- tratamento de falhas;
- uma única fonte de agenda.

### 14.2 Adapter

Integrações externas devem implementar um contrato interno estável:

```text
getAvailability
createHold
confirmBooking
rescheduleBooking
cancelBooking
getBooking
```

O domínio do KortexOS™ não depende diretamente do formato do fornecedor.

### 14.3 Fallback

Quando a API não permite confirmação segura:

```text
pedido assistido
→ revisão humana
→ confirmação apenas após registro real
```

Nunca enviar confirmação falsa.

---

## 15. Dados e analytics

### 15.1 Princípio

Analytics é projeção reconstruível, não fonte primária de verdade.

### 15.2 Features mínimas do cliente

- visitas em 30, 90 e 365 dias;
- dias desde última visita;
- mediana do intervalo;
- ticket;
- margem;
- serviço preferido;
- profissional preferido;
- dia e período preferidos;
- no-show;
- cancelamento tardio;
- resposta a campanhas;
- fadiga de comunicação;
- agendamento futuro.

### 15.3 Features mínimas do slot

- profissional;
- início e fim;
- duração disponível;
- serviço compatível;
- ocupação histórica;
- ocupação atual;
- lead time;
- cancelamento histórico;
- margem esperada;
- probabilidade de preenchimento natural;
- recursos necessários.

### 15.4 Métricas centrais

#### Capacidade

- ocupação;
- horas recuperadas;
- gaps;
- cancelamentos preenchidos;
- receita por hora disponível;
- margem por hora disponível.

#### Retenção

- rebooking;
- reativação;
- churn;
- churn parcial;
- retenção em 30, 60 e 90 dias.

#### Financeiro

- margem incremental;
- ticket;
- receita recuperada;
- custo de ação;
- comissão;
- payout;
- divergência de reconciliação.

#### Comunicação

- entrega;
- resposta;
- conversão;
- opt-out;
- bloqueio;
- reclamação;
- mensagens por conversão.

#### Automação

- ações geradas;
- ações suprimidas;
- aprovação humana;
- falhas;
- rollback;
- circuit breaker;
- dano evitado.

---

## 16. Segurança, privacidade e conformidade

### 16.1 Segurança

Controles mínimos:

- autenticação forte;
- autorização server-side;
- RLS;
- segredo fora do código;
- rotação de credenciais;
- logs de auditoria;
- rate limiting;
- assinatura de webhooks;
- proteção contra replay;
- criptografia em trânsito;
- minimização de dados;
- backup e recuperação testados.

### 16.2 Consentimento

Registrar:

- titular;
- canal;
- finalidade;
- versão do texto;
- origem;
- timestamp;
- revogação;
- fonte da revogação.

### 16.3 Privacidade

- empresas recebem dados agregados;
- parceiros não acessam histórico individual;
- grupos não devem expor contatos como padrão;
- IA recebe apenas contexto necessário;
- logs não armazenam conteúdo sensível sem necessidade;
- exclusão e retenção obedecem à política legal.

### 16.4 Fairness

- não usar atributos sensíveis para preço ou prioridade;
- não inferir renda para tratamento comercial;
- incluir tempo de espera em matching;
- monitorar distribuição de benefícios e fricções;
- permitir revisão humana;
- armazenar reason codes.

---

## 17. Observabilidade e controle operacional

Toda operação crítica deve emitir:

- trace ou correlation ID;
- actor;
- tenant;
- origem;
- política;
- versão;
- resultado;
- latência;
- erro;
- tentativa;
- chave idempotente.

### 17.1 Kill switch

Automação pode ser pausada por:

- tenant;
- unidade;
- canal;
- campanha;
- serviço;
- profissional;
- tipo de ação.

### 17.2 Circuit breaker

Suspender automaticamente quando houver:

- falhas repetidas;
- duplicidade;
- divergência de agenda;
- aumento de opt-out;
- aumento de reclamação;
- erro de provedor;
- inconsistência financeira;
- latência acima do limite;
- resultado econômico negativo persistente.

### 17.3 Replay e recuperação

Eventos, outbox e Commands devem permitir:

- retry seguro;
- reprocessamento controlado;
- identificação de duplicidade;
- reconstrução de projeções;
- correção por evento compensatório.

---

## 18. Estratégia de implementação

### Fase 0 — Qualidade dos dados

- eventos canônicos;
- timestamps confiáveis;
- tenant e actor;
- estados válidos;
- duração real;
- origem;
- consentimento;
- margem calculável;
- idempotência;
- observabilidade.

### Fase 1 — Inteligência SQL

- RFM;
- intervalo de retorno;
- heatmaps;
- ocupação;
- confiabilidade;
- score determinístico;
- reason codes;
- modo `OBSERVE`.

### Fase 2 — Opportunity Engine

Gerar fila única com:

```text
cliente
serviço
profissional
slot
ação
score
valor esperado
custo
motivos
política
```

### Fase 3 — Automação limitada

Automatizar primeiro:

1. lembrete e confirmação;
2. rebooking;
3. waitlist;
4. recuperação de cancelamento;
5. reativação sem desconto automático.

### Fase 4 — Experimentação

- tratamento e controle;
- atribuição;
- margem incremental;
- canibalização;
- análise de dano.

### Fase 5 — Modelos probabilísticos

- retorno;
- no-show;
- ocupação;
- resposta;
- melhor horário.

### Fase 6 — Otimização avançada

- min-cost flow;
- constraint solver;
- uplift;
- contextual bandit quando justificado.

---

## 19. Gates de aceite

### Gate A — Integridade e isolamento

- RLS validada;
- tenant isolation testada;
- constraints de estado;
- auditoria;
- idempotência;
- outbox.

### Gate B — Agenda

- disponibilidade backend-only;
- conflitos bloqueados;
- holds expiram;
- confirmação transacional;
- waitlist sem dupla reserva;
- integração não cria dupla verdade.

### Gate C — Finanças

- checkout consistente;
- pagamentos reconciliados;
- ledger balanceado;
- wallet reconstruível;
- comissão e gorjeta corretas;
- reversões testadas;
- payout auditável.

### Gate D — Benefícios

- origem e validade;
- elegibilidade;
- consumo idempotente;
- margem protegida;
- privacidade corporativa;
- antiabuso.

### Gate E — Automação

- modo de maturidade definido;
- policy versionada;
- frequency cap;
- consentimento;
- reason codes;
- kill switch;
- circuit breaker;
- rollback;
- grupo de controle quando necessário.

### Gate F — Produção

- testes críticos verdes;
- observabilidade ativa;
- runbook de falha;
- backup e restauração validados;
- segurança revisada;
- nenhuma afirmação `REAL` sem evidência.

---

## 20. Governança documental

### 20.1 Princípio SSOT

Cada classe de informação possui uma única autoridade.

| Informação | Autoridade |
|---|---|
| Visão, escopo, limites e invariantes | Master Briefing |
| Estado atual e próxima ação | Registro operacional de estado |
| Decisão arquitetural e justificativa | ADR |
| Contrato de API | Especificação gerada ou validada pelo código |
| Schema e migrations | Banco e migrations versionadas |
| Como operar | Runbook ou how-to |
| Mudanças entregues | Changelog de release |
| Regras para agentes e contribuidores | Instruções do repositório |

Uma informação não pode ser mantida manualmente em duas autoridades.

### 20.2 Separação por finalidade

A documentação deve distinguir:

- **explicação:** por que o sistema existe e como pensar sobre ele;
- **referência:** contratos, estados, schemas e regras exatas;
- **how-to:** como executar uma tarefa;
- **tutorial:** aprendizado guiado.

Misturar essas finalidades no mesmo documento aumenta ambiguidade e custo de manutenção.

### 20.3 Política de ADR

Criar ADR quando a decisão afetar:

- estrutura do sistema;
- qualidade arquitetural;
- segurança;
- consistência;
- contratos externos;
- tecnologia central;
- persistência;
- integração;
- custo operacional relevante.

Cada ADR deve registrar uma única decisão:

```text
Título
Status
Contexto e problema
Drivers
Opções consideradas
Decisão
Consequências
Riscos
Critérios de revisão
```

Estados recomendados:

```text
PROPOSED
ACCEPTED
REJECTED
DEPRECATED
SUPERSEDED
```

ADR aceito não deve ser reescrito para apagar a decisão original. Uma mudança cria novo ADR e marca o anterior como `SUPERSEDED`.

### 20.4 Relação entre Master Briefing e ADR

- o Master Briefing contém apenas a direção atualmente válida;
- o ADR preserva o motivo, alternativas e consequências;
- o Master Briefing não carrega histórico de versões;
- o ADR não repete o briefing inteiro;
- alterações arquiteturais relevantes atualizam ambos na mesma mudança.

### 20.5 Docs-as-code

Documentação operacional deve:

- viver versionada com o software;
- ser alterada na mesma mudança que o comportamento;
- passar por revisão;
- ter lint de links e estrutura quando possível;
- possuir owner;
- evitar conteúdo gerado manualmente quando puder vir do código;
- permitir diff e histórico;
- ser legível por humanos e agentes.

### 20.6 Limpeza documental

Um documento deve ser removido da área ativa quando:

- duplica uma autoridade existente;
- descreve estado superado;
- não possui owner;
- não possui função clara;
- contradiz código ou contrato;
- contém apenas histórico sem valor operacional;
- mistura várias finalidades sem controle.

Material histórico necessário deve ficar isolado da navegação e das instruções carregadas por agentes. Histórico não pode competir com a documentação ativa.

### 20.7 Regra de atualização

Toda mudança deve responder:

1. qual comportamento mudou;
2. qual autoridade documental é afetada;
3. existe duplicação a remover;
4. precisa de ADR;
5. precisa atualizar estado operacional;
6. precisa atualizar contrato, teste ou runbook;
7. a documentação continua coerente com o código.

---

## 21. Auditoria Brutal

### Pontos fortes

- backend como verdade única;
- math-first reduz custo e dependência de IA;
- ledger e idempotência protegem dinheiro;
- automação progressiva reduz risco;
- heatmaps e matching conectam retenção e capacidade;
- arquitetura permite evolução sem microserviços prematuros;
- documentação separa visão, estado e decisão.

### Pontos fracos

- exige disciplina de dados;
- função objetivo mal calibrada pode otimizar a métrica errada;
- automação pode amplificar falhas operacionais;
- integração externa de agenda pode limitar consistência;
- modelos causais exigem volume e experimentação;
- benefícios e assinaturas podem esconder margem negativa.

### Pontos cegos

- duração cadastrada pode divergir da duração real;
- slot livre pode não ser utilizável;
- margem pode omitir custos;
- retorno após campanha pode ser espontâneo;
- score pode reproduzir viés;
- excesso de contato pode destruir confiança;
- agenda mais cheia pode aumentar atraso e reclamação;
- current state pode divergir do briefing se a governança falhar.

### Pior cenário plausível

O sistema aumenta ocupação aparente, mas reduz margem, cria reservas inconsistentes, gera comunicação excessiva e toma decisões a partir de dados enviesados.

### Controles

- modo `OBSERVE`;
- restrições duras;
- reason codes;
- grupo de controle;
- kill switch;
- circuit breaker;
- revisão humana;
- reconciliação;
- gates de produção;
- auditoria documental.

---

## 22. Decisões canônicas

| Decisão | Estado |
|---|---|
| Backend como única fonte da verdade | CRÍTICO |
| Frontend sem regra crítica | CRÍTICO |
| Ledger double-entry append-only | CRÍTICO |
| Operações críticas transacionais e idempotentes | CRÍTICO |
| Multi-tenant com RLS real | CRÍTICO |
| Matemática antes de automação | CANÔNICO |
| Bot e IA como interfaces, não policy engine | CANÔNICO |
| Opportunity Engine determinístico primeiro | PRIORIDADE P0 |
| Waitlist com matching, ondas e hold | PRIORIDADE P1 |
| Rebooking pós-atendimento | PRIORIDADE P1 |
| Confirmação adaptativa | PRIORIDADE P1 |
| Reativação por ciclo esperado | PRIORIDADE P1 |
| Contact & Policy Orchestrator | CRÍTICO |
| Automation Control Plane | CRÍTICO |
| Incrementalidade antes de atribuição definitiva | CANÔNICO |
| Contextual bandit antes de dados confiáveis | BLOQUEADO |
| Reinforcement learning no estágio inicial | BLOQUEADO |
| Dynamic pricing individual opaco | BLOQUEADO |
| Duas fontes de agenda | BLOQUEADO |
| Benefício sem origem | BLOQUEADO |
| Saldo paralelo | BLOQUEADO |
| IA escrevendo ledger | BLOQUEADO |

---

## 23. Critério final de aprovação

O produto só pode ser considerado pronto para escala quando:

- dados críticos são íntegros e isolados;
- agenda não permite conflito;
- transações possuem idempotência;
- ledger fecha e reconstrói saldos;
- comissão e gorjeta são auditáveis;
- benefícios possuem origem e consumo controlado;
- automações possuem políticas, métricas e rollback;
- comunicação respeita consentimento e frequência;
- decisões são explicáveis;
- incidentes possuem detecção e recuperação;
- documentação ativa não contém dupla verdade;
- o estado real é comprovado por código, banco, testes e execução.

---

## 24. Encerramento

```text
Integridade antes de conveniência.
Segurança antes de automação.
Backend antes de frontend.
Ledger antes de dashboard.
Dados antes de modelo.
Matemática antes de bot.
Causalidade antes de atribuição.
OBSERVE antes de executar.
Estabilidade antes de expansão.
Uma verdade por informação.
```
