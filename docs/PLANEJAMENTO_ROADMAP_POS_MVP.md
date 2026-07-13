# Plano — Mapeamento KortexOS 5.1 vs. MVP técnico + roadmap pós-MVP + pesquisa global

## 1. Objetivo e Escopo

A origem deste documento foi a necessidade de conciliar a visão expandida descrita em documentos legados (Master Briefing Canônico de Promoção e Master Briefing Canônico Rewrite) — que preveem um ecossistema de 32 domínios (D00–D31), ledger contábil de partida dobrada, IA governada e yield management — com a realidade do **MVP Técnico Greenfield**. 

Conforme estabelecido em `AGENTS.md` e `docs/KORTEX_MVP_TECNICO.md`, a maior parte do escopo do KortexOS 5.1 foi declarada como não-objetivo para o lançamento inicial, a fim de garantir a entrega de um ERP vertical atômico e seguro (organizações, clientes, profissionais, catálogo, agenda, checkout, estoque e caixa). Os documentos "Master" foram arquivados em `docs/legacy/` para servir como **referência de domínio, não autoridade técnica**.

Este documento não autoriza implementações no MVP. O seu propósito é:
1. Mapear domínio-a-domínio (D00–D31) o estado real contra o repositório atual;
2. Classificar o nível de esforço e acoplamento arquitetural para os domínios fora do MVP (o que acopla limpo vs. o que exige rearquitetura de fundação);
3. Apresentar uma pesquisa global sobre retenção, rebooking automático, assinaturas, memberships e anti-gap para basear decisões de roadmap pós-MVP.

*Nota de governança:* A tabela de domínios considera as restrições arquiteturais. Por exemplo, D11 (Resource Orchestration) existe hoje apenas de forma implícita (o profissional é o recurso primário), e D31 (Gates/QA) é exercido via skills e processos locais, não sendo uma feature transacional do produto.

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

## 5. Recomendação de Sequenciamento

O foco primário se mantém conforme `KORTEX_MVP_TECNICO.md §11`: fechar os gaps essenciais para operação. Após o MVP, sugerimos a seguinte ordem baseada no retorno vs. esforço (priorizando os itens que "acoplam limpo"):

1. **Camada 1 (Finalização do MVP):** Fechar os gaps já identificados de comissionamento, rateio financeiro e fluxo de gorjeta.
2. **Camada 2 (Alto Impacto / Acopla Limpo):** 
   - Waitlist simples (Anti-gap básico via SMS).
   - Trust & Retention (Cálculo de Score por faltas e cancelamentos para penalização progressiva e bloqueio preventivo no checkout).
   - Portal Client Experience (Web Booking App apenas para consumo, tirando peso da recepção manual).
3. **Camada 3 (Crescimento de Recorrência):**
   - Módulo de Assinaturas (Vouchers renováveis de forma mensal mínima, sem Ledger Complexo).
4. **Camada 4 (Exige Fundação Complexa):**
   - Transição para Ledger de Partida Dobrada e Wallets (preparando terreno para fintech real).
   - Kortex.ai Receptionist e Yield Management automatizado.

---

## 6. Fontes Globais

- **Zenoti Benchmark:** [The Power of Memberships](https://www.zenoti.com/)
- **Phorest Insights:** [Reducing No-Shows with Automated Reminders](https://www.phorest.com/)
- **Vagaro / Mindbody:** Relatórios sobre MRR e previsibilidade na indústria de Spa/Salon.
- **Lutily / Meevo:** Estudos de caso sobre o impacto psicológico do pre-pagamento e aumento no ticket vitalício (LTV).
