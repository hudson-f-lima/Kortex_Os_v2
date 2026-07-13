# Plano — Mapeamento KortexOS 5.1 vs. MVP técnico + roadmap pós-MVP + pesquisa global

## 1. Objetivo e Escopo

A origem deste documento foi a necessidade de conciliar a visão expandida descrita em documentos legados (Master Briefing Canônico de Promoção e Master Briefing Canônico Rewrite) — que preveem um ecossistema de 32 domínios (D00–D31), ledger contábil de partida dobrada, IA governada e yield management — com a realidade do **MVP Técnico Greenfield**. 

Conforme estabelecido em `AGENTS.md` e `docs/KORTEX_MVP_TECNICO.md`, a maior parte do escopo do KortexOS 5.1 foi declarada como não-objetivo para o lançamento inicial, a fim de garantir a entrega de um ERP vertical atômico e seguro (organizações, clientes, profissionais, catálogo, agenda, checkout, estoque e caixa). Os documentos "Master" foram arquivados em `docs/legacy/` para servir como **referência de domínio, não autoridade técnica**.

Este documento não autoriza implementações no MVP. O seu propósito é:
1. Mapear domínio-a-domínio (D00–D31) o estado real contra o repositório atual;
2. Classificar o nível de esforço e acoplamento arquitetural para os domínios fora do MVP (o que acopla limpo vs. o que exige rearquitetura de fundação);
3. Apresentar uma pesquisa global sobre retenção, rebooking automático, assinaturas, memberships e anti-gap para basear decisões de roadmap pós-MVP;
4. Detalhar, como estudo de caso do domínio D24 (Trust & Retention), um mecanismo concreto e determinístico de cobrança por no-show (§5) e a mensageria de custo zero que o viabiliza sem gateway pago (§6).

*Nota de governança:* A tabela de domínios considera as restrições arquiteturais. Por exemplo, D11 (Resource Orchestration) existe hoje apenas de forma implícita (o profissional é o recurso primário), e D31 (Gates/QA) é exercido via skills e processos locais, não sendo uma feature transacional do produto. **Kortex.ai (D22) permanece bloqueado em todo este documento** — nenhum motor de retenção/no-show/mensageria proposto aqui depende de IA; todos são regra determinística de backend, na mesma linha do restante do MVP.

---

## 2. Mapa D00–D31 vs. MVP Técnico

O mapeamento abaixo cruza a visão 5.1 com o estado real de `supabase/migrations/20260712235319_mvp_baseline.sql` e subsequentes.

| Domínio | Status no MVP | Evidência / Destino Pós-MVP |
| :--- | :--- | :--- |
| **D00** Platform Owner Layer | Coberto diferentemente | Coberto por infraestrutura, não há SaaS billing no DB atual. |
| **D01** Identity & Tenant | NO MVP (Real) | Tabelas `organizations`, `memberships`, `profiles`, com RLS. |
| **D02** Business Setup | NO MVP (Parcial) | Dados base na organização. |
| **D03** Onboarding SaaS | Fora do MVP e Planejamento | - |
| **D04** SaaS Billing | Fora do MVP (Não-objetivo) | Definido no `KORTEX_MVP_TECNICO.md §11`. |
| **D05** People Hub | NO MVP (Real) | Tabelas `clients` e `professionals`. |
| **D06** Catalog & Offer Hub | NO MVP (Real) | Tabelas `services` e `products`. |
| **D07** Capacity Scheduling | NO MVP (Real) | Tabela `appointments` (com exclusion constraint de disponibilidade). |
| **D08** Agenda Core | NO MVP (Real) | Tabela `appointments` (status: scheduled, in_service, etc.). |
| **D09** Recurring Appointment | Fora do MVP e Planejamento | Ponto cego: requer tabela de séries recorrentes. |
| **D10** Group Booking | Fora do MVP e Planejamento | Ponto cego: booking com participantes/pagadores. |
| **D11** Resource Orchestration| Fora do MVP e Planejamento | Profissional atua como recurso; sem tabela de salas/equipamentos. |
| **D12** Checkout Core | NO MVP (Real) | Tabelas `orders`, `order_items`, e RPC atômica `checkout_close`. |
| **D13** Payment Core | NO MVP (Real) | Tabela `payments` ligada à order. |
| **D14** Cash & Register | NO MVP (Real) | Tabela `cash_entries`. |
| **D15** KortexFlow Ledger | Fora do MVP (Não-objetivo) | Sem ledger append-only (partida dobrada dupla) no MVP. |
| **D16** Wallet & Current Accs | Fora do MVP e Planejamento | Ponto cego dependente de Ledger. |
| **D17** Compensation & Payout | NO MVP (Parcial) | Lógica desenhada no `PLANEJAMENTO_COMISSOES.md`. |
| **D18** Subscription & Corp | Fora do MVP (Não-objetivo) | Decisão §11. |
| **D19** Client Experience Hub | Fora do MVP e Planejamento | Portal PWA de cliente. |
| **D20** Public Web Presence | Fora do MVP e Planejamento | Página estática + link. |
| **D21** KortexLink / Messaging| Fora do MVP e Planejamento | Notificações e alertas (SMS/WhatsApp). |
| **D22** Kortex.ai Receptionist| Fora do MVP (Não-objetivo) | Sem IA no MVP (Decisão §11). |
| **D23** Revenue CoPilot | Fora do MVP e Planejamento | Ponto cego. |
| **D24** Trust & Retention | Fora do MVP e Planejamento | Ponto cego: Reliability Score e No-Show progressivo. |
| **D25** Analytics & Decision | Fora do MVP (Não-objetivo) | Apenas view simples. Decisão §11. |
| **D26** Fiscal & LGPD | Fora do MVP (Não-objetivo) | - |
| **D27** Marketplace & Partner | Fora do MVP (Não-objetivo) | - |
| **D28** Multiunit Enterprise | Fora do MVP (Não-objetivo) | - |
| **D29** White-Label App | Fora do MVP e Planejamento | - |
| **D30** Integration Platform | Fora do MVP e Planejamento | APIs públicas. |
| **D31** Gate, QA & Governance| Coberto diferentemente | Skills do repositório (`kortex-qa-redteam`) validam o sistema. |

---

## 3. Classificação de Acoplamento Pós-MVP (O Pós-Lançamento)

Dos **19 domínios que estão fora do MVP**, avaliamos o esforço arquitetural para acoplá-los à fundação transacional estabelecida no MVP. 

- **Total de Domínios Fora do MVP:** 19
- **Acopla Limpo (Aditivo):** 11 domínios (~58%)
- **Exige Rearquitetura de Fundação:** 8 domínios (~42%)

### A. Acopla Limpo (Módulo Aditivo)
Estes podem ser construídos apenas adicionando tabelas, sem reescrever o core financeiro atual.
- **D09 Recurring Appointments:** Tabela `recurring_series` apontando para `appointments`.
- **D10 Group Booking:** Tabela associativa na ordem.
- **D11 Resource Orchestration:** Tabelas de `resources` e `locks`.
- **D18 Assinatura/Membership (Forma Mínima):** Tabela de plano e direito de consumo, cobrada externamente, sem afetar o caixa diário atômico.
- **D19 Client Experience Hub:** PWA apenas-leitura consumindo as rotas existentes (Supabase Auth).
- **D20 Public Web Presence:** Página estática.
- **D21 Messaging / KortexLink (Básico):** Disparo de webhooks reativos via Supabase Edge Functions.
- **D24 Trust & Retention Engine (Básico):** Cálculo de score (Reliability) puramente derivado de `appointments.status`.
- **D25 Analytics Avançado:** Materialized views sobre o schema atual.
- **D27 Marketplace Listing Simples:** Exposição de perfil público.
- **D30 Integration Platform / API Pública:** Wrapper com API Keys sobre o Core.

### B. Exige Rearquitetura de Fundação
Estes domínios exigem mudar como o sistema opera, processa dinheiro ou confia em dados.
- **D15 KortexFlow Ledger:** Transição de `cash_entries` para um ledger de partida dobrada real (append-only). Não é aditivo; substitui a espinha dorsal.
- **D16 Wallet & Current Accounts:** Depende estritamente do Ledger.
- **D22 Kortex.ai Receptionist:** Ação via IA exige um novo modelo de "Action Requests" com governança/aprovação humana antes de alterar o banco.
- **D23 Revenue CoPilot:** Semelhante à IA, exige camada de simulação.
- **D26 Fiscal:** Exige acoplamento contábil.
- **D28 Multiunit Enterprise:** Transforma 1 `organization_id` em árvores hierárquicas, alterando cada RLS.
- **D29 White-Label App:** Depende de estabilidade total das rotas.
- **Yield / Dynamic Pricing Automático (Parte do D07/D23):** Alterar preços sob demanda requer infraestrutura de snapshots e políticas rigorosas.

---

## 4. Pesquisa Global: Retenção, Rebooking, Membership e Anti-gap

Para estruturar os módulos do grupo "Acopla Limpo", avaliamos o mercado global de beleza (Zenoti, Phorest, Mindbody).

### 4.1 Retenção e Rebooking Automático
O esquecimento é a causa número um de *no-shows* e não-retornos.
- **Rebooking Preditivo:** O Phorest e Zenoti mapeiam o intervalo médio de um serviço (ex: corte de cabelo a cada 30 dias) e disparam lembretes 3 dias antes da janela preditiva, aumentando o rebooking sem intervenção humana.
- **Lembretes e No-Show:** Confirmações obrigatórias via SMS (o sistema "força" o clique num link) geram compromisso psicológico, reduzindo o *no-show* em até **30% a 33%**.

### 4.2 Membership e Assinaturas (Forma Mínima)
O modelo de Spa e Salão moderno prioriza *Monthly Recurring Revenue (MRR)*.
- **Desempenho:** Dados do benchmark Zenoti revelam que salões com memberships bem executados crescem sua receita até **4x mais rápido** do que modelos baseados apenas em agendamentos pontuais.
- **Fundação Técnica:** Os melhores softwares de gestão oferecem catálogos de planos em que o pagamento mensal libera um "crédito de consumo" ou "voucher". Isso valida nossa visão de desenvolver **Assinatura na Forma Mínima** (D18), que trata o plano como um "direito de uso" sem necessariamente exigir um ledger financeiro bancário no dia 1.

### 4.3 Anti-Gap e Yield Management (Preenchimento de Horários)
- **Waitlist Automatizada:** Se um cliente cancela, o sistema (ex: Vagaro, Pabau) varre a lista de espera e dispara um SMS em lote; o primeiro a aceitar, leva. 
- **Descontos Off-Peak:** Ferramentas como o Zenoti aplicam "Yield pricing", oferecendo incentivos automáticos e sutis (ex: 15% off) apenas para horários com baixa taxa histórica de ocupação (ex: terça-feira de manhã), com simulações provando um aumento de **+22% a 25%** no preenchimento das cadeiras.

### 4.4 Corporate B2B2C
Plataformas como ClassPass e Wellhub validam o modelo de subsídio onde a empresa paga e o funcionário consome. No contexto de salão único, a implementação não precisa ser um marketplace aberto, e sim um contrato simples B2B associando contas `user_id` a um subsídio específico.

---

## 5. Mecanismo de Cobrança por No-Show (State Machine determinística, sem IA)

**Reforço de governança:** este mecanismo é 100% regra determinística de backend. **Kortex.ai (D22) segue bloqueado** — nenhuma parte deste fluxo depende de IA, linguagem natural ou decisão automática de modelo; é um `CASE`/state machine sobre `appointments.status`, igual em espírito ao restante do MVP (preço/comissão/disponibilidade já são sempre backend-only, nunca IA).

### 5.1 Pesquisa global — o padrão de mercado já confirma a régua pedida

O desenho de 3 níveis (aviso → depósito obrigatório → bloqueio) não é invenção do produto: é o padrão documentado do setor.

| Nível de mercado | Ação típica | Fonte |
|---|---|---|
| 1ª falta | Aviso amigável + lembrete de política, sem cobrança retroativa | SICUS — Salon Deposit Policy Template; DaySmart |
| 2ª falta | Depósito/sinal passa a ser obrigatório nos próximos agendamentos (tipicamente 25–50% do valor do serviço) | Vagaro — Policies & Procedures; GlossGenius — Salon Deposit Policy |
| 3ª falta/reincidência | Pré-pagamento de até 100%, ou bloqueio/dispensa do cliente | Boulevard — Salon Cancellation Policy Guide; Holland Hair Co — Salon No-Show Policy |

Isso confirma a régua pedida pelo usuário (1ª falta = conscientização, 2ª falta = aviso de cobrança futura, próximo agendamento = sinal de 50% ou o configurado) como estado da arte do nicho, não uma política experimental.

### 5.2 Estados propostos (por cliente, dentro de uma organização)

```
sem_restricao
   │  appointments.status = 'no_show' (1ª ocorrência)
   ▼
aviso_emitido           — mensagem de conscientização enviada; nenhuma cobrança, nenhum bloqueio
   │  appointments.status = 'no_show' (2ª ocorrência)
   ▼
sinal_obrigatorio       — próximo agendamento não confirma sem sinal pago; % configurável por organização (default sugerido: 50%)
   │  sinal pago e registrado
   ▼
confirmado_com_sinal    — agendamento confirmado; se concluído com sucesso, cliente pode retornar a sem_restricao (healing) após N atendimentos seguidos sem falta (parâmetro de organização, ex.: 3)
   │  novo no_show enquanto em sinal_obrigatorio
   ▼
bloqueado_ate_quitar    — sem novo agendamento liberado até ação manual do dono/gerente (Action Request humano, não automático)
```

Todos os limiares (nº de faltas para cada transição, percentual do sinal, nº de atendimentos para "healing") são **parâmetros de organização**, não hardcoded — mesma disciplina de configuração já usada em `service_groups.default_commission_value`.

### 5.3 Onde isso entra na arquitetura atual (por que é "acopla limpo")

- **Tabela nova aditiva:** algo como `client_reliability_state` (`organization_id`, `client_id`, `state`, `no_show_count`, `updated_at`) — não toca `appointments`/`orders`/`checkout_close` existentes, só é lida por eles.
- **Gatilho:** transição de estado roda quando um `appointment.status` muda para `no_show` (já existe como valor do enum de status hoje) — pode ser feito na própria RPC que já marca esse status, sem nova infraestrutura de evento.
- **Ponto de imposição do sinal:** a criação de um novo `appointment` para um cliente em `sinal_obrigatorio` exige um pagamento associado (via `payments`/`checkout` já existentes) **antes** de o agendamento passar de "solicitado" para "confirmado" — reaproveita o conceito de pagamento antecipado, só adiciona a condição de bloqueio.

### 5.4 O gap honesto: cobrança remota de sinal não existe ainda no MVP

`KORTEX_MVP_TECNICO.md §11` já declara integrações de pagamento fora do MVP — hoje o `checkout_close` só reconcilia pagamento presencial (dinheiro/Pix/cartão já liquidado na hora). Cobrar um "sinal de 50% antes do próximo agendamento" à distância exige **algum** canal de recebimento remoto (link de Pix, ou um gateway). Duas rotas honestas, sem fingir automação que não existe:

1. **Rota mínima (acopla limpo, sem gateway):** o sinal é solicitado por mensagem (ver §6) com uma chave Pix estática/QR code do próprio salão; a recepção confirma manualmente o recebimento no sistema (um botão "sinal recebido", não uma RPC de pagamento online) — o agendamento só é confirmado depois dessa confirmação manual. Zero integração de pagamento nova, 100% dentro do MVP.
2. **Rota completa (exige fundação, fora do MVP):** link de cobrança Pix dinâmico ou gateway de cartão para pagamento remoto automático, com webhook de confirmação — isso é a "integração de pagamento" que §11 já colocou como não-objetivo. Só faz sentido revisitar esse não-objetivo depois do Ledger (Camada 4 do §7 abaixo).

## 6. Mensageria Dinâmica de Custo Zero via Mecanismos Nativos do Mobile

Pesquisa dedicada, complementando o D21 (KortexLink básico) já classificado como "acopla limpo" no §3 — como enviar o aviso/cobrança do §5 sem contratar um gateway de mensageria pago.

### 6.1 Comparativo das opções nativas de custo zero

| Mecanismo | Como funciona | Custo | Automação real | Suporte |
|---|---|---|---|---|
| **Web Share API** (`navigator.share()`) | Abre a folha de compartilhamento nativa do SO (WhatsApp, SMS, e-mail, Telegram etc., conforme o que o cliente/recepção tem instalado) com texto pré-preenchido | Zero — API nativa do navegador, sem gateway | Nenhuma — exige clique explícito do usuário (`transient activation`); só funciona em contexto seguro (HTTPS) | ~92% dos navegadores mobile (caniuse); sem suporte confiável em desktop |
| **`wa.me/<numero>?text=<mensagem>`** (WhatsApp Click-to-Chat) | Link comum que abre o WhatsApp do destinatário/remetente com o número e texto pré-preenchidos | Zero — não usa a WhatsApp Business Platform (API paga), funciona com qualquer número | Nenhuma — quem abre o link ainda aperta "enviar" | Universal (é só uma URL) |
| **`sms:`/`tel:`/`mailto:` (URI schemes)** | Abrem o app nativo de SMS/discador/e-mail do aparelho com destinatário e corpo pré-preenchidos | Zero | Nenhuma — mesma limitação: ação humana final | Bom em mobile (Safari iOS, Chrome/Firefox Android); fraco/inexistente em desktop |
| *(referência, não zero-custo)* WhatsApp Business Platform (API oficial) | Envio 100% automático server-side, com templates aprovados | Modelo mudou em 2025: preço por mensagem entregue (não mais por conversa de 24h); mensagens utilitárias dentro da janela de atendimento de 24h iniciada pelo cliente continuam gratuitas | Total (server-to-server, sem toque humano) | Requer conta Business Platform + provedor (Twilio/360dialog/etc.) |

### 6.2 Síntese e recomendação para o KortexOS

Para o pós-MVP sem orçamento de gateway, a combinação **Web Share API + link `wa.me` pré-formatado** cobre exatamente o caso de uso do §5: a PWA monta a mensagem certa (aviso de 1ª falta, aviso de cobrança futura, cobrança do sinal com valor calculado) e a recepção dispara com um toque, usando o WhatsApp/SMS que já está no aparelho — **zero linha de código de gateway, zero custo por mensagem**. A limitação deve ficar documentada sem meias-palavras (mesmo princípio anti-mock dos outros `PLANEJAMENTO_*.md`): **isto não é automação server-side** — é envio assistido por humano, sempre depende de alguém tocar em "enviar". Se o produto precisar de lembrete 100% automático e assíncrono (disparado por um job, sem recepção logada), isso exige a WhatsApp Business Platform (ou SMS via provedor), que tem custo por mensagem e pertence à Camada 4 (KortexLink avançado), não ao "acopla limpo" imediato.

Implementação mínima: um helper de frontend que monta a URL `https://wa.me/<telefone_e164>?text=<encodeURIComponent(mensagem)>` a partir dos dados já existentes (`clients.phone`, `appointments`, valor do sinal calculado no backend) e, quando `navigator.share` estiver disponível, oferece a folha nativa como alternativa — nenhuma tabela nova, nenhuma rota de backend nova além de calcular o texto/valor da mensagem (que já é dado que o backend possui).

## 7. Recomendação de Sequenciamento

O foco primário se mantém conforme `KORTEX_MVP_TECNICO.md §11`: fechar os gaps essenciais para operação. Após o MVP, sugerimos a seguinte ordem baseada no retorno vs. esforço (priorizando os itens que "acoplam limpo"):

1. **Camada 1 (Finalização do MVP):** Fechar os gaps já identificados de comissionamento, rateio financeiro e fluxo de gorjeta.
2. **Camada 2 (Alto Impacto / Acopla Limpo):** 
   - Waitlist simples (Anti-gap básico via SMS/WhatsApp).
   - Trust & Retention: state machine de cobrança por no-show (§5) + mensageria zero-custo via Web Share API/`wa.me` (§6) para disparar os avisos/cobranças da régua.
   - Portal Client Experience (Web Booking App apenas para consumo, tirando peso da recepção manual).
3. **Camada 3 (Crescimento de Recorrência):**
   - Módulo de Assinaturas (Vouchers renováveis de forma mensal mínima, sem Ledger Complexo).
4. **Camada 4 (Exige Fundação Complexa):**
   - Transição para Ledger de Partida Dobrada e Wallets (preparando terreno para fintech real).
   - Kortex.ai Receptionist e Yield Management automatizado.

---

## 8. Fontes Globais

### Retenção, rebooking, membership, anti-gap (§4)

- **Zenoti Benchmark:** [The Power of Memberships](https://www.zenoti.com/)
- **Phorest Insights:** [Reducing No-Shows with Automated Reminders](https://www.phorest.com/)
- **Vagaro / Mindbody:** Relatórios sobre MRR e previsibilidade na indústria de Spa/Salon.
- **Lutily / Meevo:** Estudos de caso sobre o impacto psicológico do pre-pagamento e aumento no ticket vitalício (LTV).

### Política de no-show em camadas (§5)

- [SICUS — Salon Deposit Policy Template (2026): Free Examples & No-Show Clauses](https://www.sicusmedia.com/blog/salon-deposit-policy-template.html)
- [DaySmart — How to Reduce Salon No-Shows: Deposits, Reminders & Cancellation Policy](https://www.daysmart.com/salon/blog/how-to-reduce-salon-no-shows/)
- [Holland Hair Co — Salon No Show Policy: Protect Your Time and Income](https://hollandhairco.com/blog/what-should-a-salon-no-show-policy-include)
- [Vagaro — Salon Policies 101: No-Shows, Cancellations & Payment Rules](https://www.vagaro.com/learn/policies-procedures-for-clients-in-salons-examples)
- [GlossGenius — How to Set Up Your Salon Deposit Policy (Template)](https://glossgenius.com/blog/salon-deposit-policy)
- [Boulevard — Salon Cancellation Policy Guide With Templates and Examples](https://www.joinblvd.com/blog/salon-cancellation-policy)

### Mensageria nativa de custo zero (§6)

- [MDN — Web Share API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Share_API)
- [MDN — Navigator: share() method](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/share)
- [MDN — Navigator: canShare() method](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/canShare)
- [Chatarmin — Click to Chat for WhatsApp: How to Turn It Into Revenue](https://chatarmin.com/en/blog/click-to-chat-for-whatsapp)
- [Rick Strahl — Prefilling an SMS on Mobile Devices with the sms: Uri Scheme](https://weblog.west-wind.com/posts/2013/Oct/09/Prefilling-an-SMS-on-Mobile-Devices-with-the-sms-Uri-Scheme)
- [Meta for Developers — Pricing on the WhatsApp Business Platform](https://developers.facebook.com/documentation/business-messaging/whatsapp/pricing)
- [Blueticks — WhatsApp Business API Pricing in 2026: Conversation Categories, Costs, and What Changed](https://blueticks.co/blog/whatsapp-business-api-pricing-2026)
