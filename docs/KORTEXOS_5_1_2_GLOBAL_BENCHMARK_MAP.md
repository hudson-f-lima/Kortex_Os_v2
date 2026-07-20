# KORTEXOS™ — GLOBAL BENCHMARK MAP

**Arquivo:** `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md`
**Produto:** KortexOS™
**Natureza:** etapa 3 da ordem de construção (Master Briefing §22.1) — matriz rastreável por fonte, transformando pesquisa exploratória em achado citável. **Não é verdade de produto** (RAGOV 20.4) — é insumo para a etapa 4 (Comparative Proposal), que classifica cada achado em HERDAR / RENOMEAR / REFORÇAR / ADICIONAR AO BACKLOG / BLOQUEAR / DESCARTAR.
**Escopo e formato:** DEC-20 (Decision Log) — 6 dos 16 módulos obrigatórios (§23.2), priorizados por já estarem em construção ativa. Execução iterativa, 2–3 módulos por rodada, validados pelo Platform Owner antes de avançar.
**Metodologia de referências:** DEC-21 (Decision Log) — benchmark por domínio de excelência (Tier 1/2/3), nunca por produto integral a copiar. Ver seção "Estratégia Canônica de Benchmark" abaixo.
**Companion docs:** `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` (regra vigente) e `KORTEXOS_5_1_2_DECISION_LOG.md` (histórico de decisões).

---

## Estratégia Canônica de Benchmark

O Global Benchmark Map do KortexOS™ adota uma **estratégia de benchmark por competência**. Nenhuma plataforma é tratada como modelo integral ou arquitetura a ser reproduzida. Cada referência representa excelência comprovada em um domínio específico, servindo exclusivamente como fonte de aprendizado para aquele contexto. O objetivo não é copiar produtos existentes, mas sintetizar as melhores práticas globais em uma arquitetura única, coerente e superior.

### Tier 1 — Beauty Tech (Referências Obrigatórias)

| Referência | Domínio de excelência | Ressalva de calibração (evidência já apurada nesta conversa) |
|---|---|---|
| **Booksy** | Mobile UX, Marketplace, Booking Público, Growth, Marketing, No-show, Waitlist, experiência operacional mobile-first | O **conceito** de aquisição pay-per-performance via marketplace (Boost) é válido; o **mecanismo de atribuição** tem risco documentado publicamente — donos cobrados mesmo com cliente vindo por canal próprio. Referência para o conceito, não para copiar a atribuição; qualquer feature equivalente no KortexOS™ segue a regra de origem rastreável já definida para Partner Benefits (D05) |
| **Zenoti** | Operações enterprise, governança, multiunidade, workflows complexos, checkout, faturamento, gestão corporativa | Sem ressalva — achados desta conversa (trava financeira por invoice fechada, resolução de herança org→unidade) já validaram e reforçaram decisões do KortexOS™ |
| **Boulevard** | Intelligent Capacity, Precision Scheduling, Smart Gap, Resource Locks, otimização avançada da capacidade operacional | Sem ressalva — gap de mercado real confirmado (nem Boulevard nem Vagaro fazem waitlist reativa em tempo real), o que reforça a aposta do KortexOS™ nesse ponto como diferencial, não commodity |
| **Trinks** | Gestão operacional nacional: agenda, financeiro, estoque, comissão, WhatsApp, aderência a práticas locais | Parcialmente ANTI-PADRÃO: edição retroativa de fechamento e alteração de data de movimentação já apurada e rejeitada (Decision Log, Seção 4/6). Referência válida para amplitude de escopo e crédito de cliente nativo — não para integridade de ledger, onde o KortexOS™ diverge deliberadamente |
| **CashBarber** | Assinaturas, recorrência, fidelização, gestão especializada de barbearias, previsibilidade de receita | Lacuna documentada: não comissiona consumo de assinatura nativamente — é exatamente o problema que DEC-10/Gate 14 resolvem como diferencial do KortexOS™. Referência para posicionamento assinatura-first, não para o modelo de comissão |
| **AppBarber** | Ecossistema white-label, aplicativo do cliente, omnichannel, relacionamento, comunicação, marca própria | White-label está **BLOQUEADO** no estágio atual do KortexOS™ por sofisticação prematura (§15/RAGOV). Referência **diferida** para quando esse domínio entrar na fila — não é consulta imediata. Já validado e absorvido: modelo de reabertura de comanda, split de comissão por taxa (DEC-01/11) |

### Tier 2 — Cross-Industry (Referências Obrigatórias)

| Referência | Domínio de excelência |
|---|---|
| **Uber** | Operações em tempo real, despacho inteligente, matching, ETA, balanceamento dinâmico de oferta e demanda, otimização contínua da capacidade |
| **Aviação Comercial** | Planejamento de capacidade, gestão de restrições, reacomodação, operações críticas, confiabilidade operacional |
| **Amazon** | Operational Intelligence, checkout de baixa fricção, personalização, recomendações, automação, redução sistemática da carga cognitiva |
| **Apple** | Human Interface Design, consistência visual, microinterações, ergonomia, simplicidade, experiência mobile premium |
| **Disney** | Experience Orchestration, desenho da jornada do cliente, padronização da experiência, atendimento, fidelização por excelência operacional |

*Tier 2 ainda não pesquisado — entra em pauta quando o módulo correspondente (checkout, matching/Smart Slot Engine, contact orchestration) chegar na rodada.*

### Tier 3 — Domínios Técnicos e Verticais Especializados (Referências Obrigatórias)

Tier 1 e Tier 2 cobrem produtos e experiências. Tier 3 cobre técnica e infraestrutura que nenhum dos dois tiers acima resolve — mantido do §23.1 original para não perder cobertura.

| Categoria | Referências mínimas | Módulo relacionado |
|---|---|---|
| Fintech/ledger | Stripe Connect, Adyen Platforms, Modern Treasury, Stripe Treasury | 04 (Ledger/Wallet) — próxima rodada |
| Scheduling/yield acadêmico | Appointment scheduling, revenue management, capacity optimization, min-cost flow, constraint programming | 01/02 (concluído) — aprofundamento futuro se necessário |
| Corporate wellness | Wellhub/Gympass, ClassPass Corporate, corporate benefits platforms | 10 (fora do escopo priorizado — DEC-20) |
| Causal decisioning | Experimentação, uplift modeling, holdouts, contextual bandits | 15 (fora do escopo priorizado — DEC-20) |
| Lifecycle automation | Rebooking, win-back, waitlist, VIP, frequency caps, contact orchestration | 16 (fora do escopo priorizado — DEC-20) |
| Messaging/AI | AI receptionist, WhatsApp automation, contact center, consent management | 07/08 (fora do escopo priorizado — DEC-20) |

### Referência Metodológica Permanente

**Toyota Production System (Lean/Kaizen)** é adotado como referência metodológica contínua para eliminação de desperdícios, melhoria contínua, gestão visual, padronização e eficiência operacional. Não constitui benchmark competitivo, mas um framework permanente de validação da arquitetura, dos processos e da evolução do KortexOS™ — coerente com princípios já vigentes no Master Briefing ("básico antes do sofisticado", "matemática antes de automação").

### Regra de utilização

```text
Todo módulo funcional, ADR, Blueprint, Comparative Proposal, Truth Map, Migration
Map e implementação deve ser confrontado apenas com os benchmarks relevantes ao
domínio analisado. Nenhuma funcionalidade pode ser copiada integralmente de um
único produto. A arquitetura final do KortexOS™ representa a convergência das
melhores práticas identificadas em todos os benchmarks aplicáveis, preservando
identidade, princípios canônicos e soberania arquitetural do Master Briefing.
Ressalva de calibração é parte obrigatória do registro — "referência" nunca
significa "copiar sem qualificar", como as notas da Tier 1 acima demonstram.
```

---

## Progresso

| Módulo | Nome | Status | Rodada |
|---:|---|---|---|
| 01 | Booking & Capacity Scheduling | ✅ Rodada 1 concluída | 1 |
| 02 | Smart Gap / Waitlist / Resource Locks | ✅ Rodada 1 concluída | 1 |
| 03 | Checkout & Payments | ✅ Rodada 2 concluída | 2 |
| 04 | Ledger / Wallet / Current Accounts | ✅ Rodada 2 concluída | 2 |
| 05 | Compensation / Tips / Payout | ✅ Rodada 3 concluída | 3 |
| 06 | No-show / Deposit / Card-on-file | ✅ Rodada 3 concluída | 3 |
| 07–16 | (fora do escopo priorizado — DEC-20) | não pesquisado | — |

**Escopo priorizado (DEC-20) 100% concluído — 3 rodadas, 6 módulos.**

**Rodada 4 (fora da numeração 01-16, cross-cutting):** motivada pelo mesmo padrão que gerou o adendo D02 do Truth Map (DEC-25) — ao aprofundar as camadas já auditadas antes do início do Blueprint (etapa 7), 4 pontos cegos estruturais foram identificados e pesquisados: hierarquia Empresa→Unidade (D01/D02/D28), profundidade da Calendar Policy (D02/D07), mecanismo de Action Request (D24/D31) e Negative Guard/Client Reliability Score (D16/D24). Ver seção "RODADA 4" abaixo e o relatório dedicado `KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md`.

---

# RODADA 1 — Módulos 01 e 02

## Módulo 01 — Booking & Capacity Scheduling

| Plataforma | Achado | Fonte |
|---|---|---|
| Zenoti | Reagendamento por arrastar-e-soltar move o appointment para outro slot vazio, do mesmo profissional ou de outro; no mobile, toque-e-segure inicia o arraste | help.zenoti.com/en/articles/719255 |
| Zenoti | Redimensionamento de duração via alça arrastável (ponto vermelho) na borda do bloco do appointment, no mobile | help.zenoti.com/en/articles/3629533 |
| Zenoti | Movimentação bloqueada quando a nota/invoice já está fechada — trava financeira, sem exceção na versão clássica | help.zenoti.com/en/articles/694046 |
| Zenoti | Versão redesenhada relaxa a trava: permite mover mesmo com pagamento/desconto/benefício resgatado aplicado, **desde que o preço final permaneça igual** após a mudança | help.zenoti.com/en/articles/appointments/redesigned-appointment-book |
| Zenoti | "Move visit" — arrasta um agendamento composto (múltiplos serviços da mesma visita) como bloco único, preservando o vínculo entre os itens | help.zenoti.com/en/appointments/daily-tasks/manage-appointments |
| Zenoti | Intervalo de exibição do calendário é configurável independente da granularidade real do slot (ex.: marca de hora em hora, mas aceita agendamento de 15 em 15 min) | help.zenoti.com/en/appointments/redesigned-appointment-book |
| Zenoti | Prevenção automática de gap e sobreposição de tempo de processamento — profissional fica disponível para um segundo cliente durante o tempo de coloração, sem configuração manual | zenoti.com/thecheckin/best-hair-salon-scheduling-apps-2026 |
| Mindbody | Buffer time configurável por categoria de serviço, somado à duração do agendamento no cadastro do serviço | mindbodyonline.com/business/scheduling |
| Mindbody | Um único agendamento pode reservar simultaneamente sala + equipamento + profissional (multi-recurso) | mindbodyonline.com/business/education/blog/booking-and-scheduling-software-spas |
| Mindbody vs. Vagaro | Mindbody é mais forte em agendamento baseado em turma (múltiplos clientes no mesmo horário/recurso); Vagaro é mais forte em agendamento individual por profissional | goodcall.com/appointment-scheduling-software/mindbody-vs-vagaro |
| Booksy | Calendário com cores por serviço, múltiplas visualizações e arrastar-e-soltar; comparativos terceirizados apontam Booksy como a app específica de barbearia mais indicada entre os players avaliados — relevância direta ao modelo salão+barbearia do Salão Esperança | biz.booksy.com/en-us/features/calendar-scheduling; biz.booksy.com/en-us/blog/what-app-do-barbers-choose |
| Booksy | Tempo de antecedência mínima (lead time) configurável tanto para agendar quanto para reagendar, definido pelo dono | biz.booksy.com/features |

### Leitura preliminar (não é classificação — isso é etapa 4)

```text
1. A trava financeira "não move se invoice fechada" aparece de forma independente
   em Zenoti — validação de mercado para DEC-03/DEC-11 (reabertura de comanda
   por versão, nunca edição direta de fato consumado).
2. O relaxamento da Zenoti (mover mesmo com pagamento aplicado, contanto que o
   preço final não mude) é um padrão a estudar: reduz fricção sem reabrir o
   ledger, mas só funciona se preço = 0 delta. Candidato a REFORÇAR na etapa 4.
3. Gap prevention automático durante tempo de processamento (ex.: coloração)
   aparece em Zenoti e Boulevard (módulo 02) de forma independente — é padrão
   de dois líderes, não coincidência. HOPE OS ainda não tem isso. Candidato
   forte a REFORÇAR.
```

---

## Módulo 02 — Smart Gap / Waitlist / Resource Locks

| Plataforma | Achado | Fonte |
|---|---|---|
| Boulevard | "Precision Scheduling™": otimização de gap para evitar buracos de 15 min invendáveis; empilha agendamentos considerando tempo de processamento (ex.: coloração) para permitir duplo agendamento controlado sem sobrecarregar o profissional | authencio.com/blog/boulevard-deep-dive |
| Boulevard | Gestão de recurso: atribui automaticamente sala/equipamento ao serviço, evitando conflito de recurso limitado (double-booking de ativo físico) | authencio.com/blog/boulevard-deep-dive |
| Boulevard | Entrada na waitlist exige cartão de crédito (anti-spam); cliente só é cobrado após o atendimento concluído — é hold de identificação, não cobrança antecipada | support.boulevard.io/en/articles/5941433 |
| Boulevard | Waitlist via self-booking **não considera** fechamentos do estabelecimento nem profissional específico solicitado — limitação confirmada pela própria documentação | support.boulevard.io/en/articles/5941433 |
| Boulevard vs. Vagaro | **Nenhum dos dois** preenche a waitlist em tempo real disparado por evento (cancelamento); ambos só mandam lembrete programado (24h/2h antes) — gap de mercado confirmado nos dois líderes do segmento | ustechautomations.com/resources/blog/automate-boulevard-vs-vagaro-for-salons-2026 |
| Zenoti | "Smart gap prevention" + sugestões automáticas de preenchimento de vaga a partir da waitlist | zenoti.com/thecheckin/best-hair-salon-scheduling-apps-2026 |
| Bella Booking | Matching automático da waitlist por data/hora/profissional/serviço; revalida automaticamente e descarta o match se a janela de preferência expirar sem confirmação | bellabooking.com/features/waitlist |
| Bella Booking | Habilitar/desabilitar waitlist por serviço, ou herdar o default do nível da unidade — padrão de herança compatível com o que o KortexOS já define para a Business Configuration & Policy Layer | bellabooking.com/features/waitlist |
| Padrão de engenharia (genérico, não específico de salão) | Resource lock/hold é padrão consolidado de sistemas de reserva: retém o recurso temporariamente durante o checkout, com timeout; falha ou expiração do pagamento libera o hold automaticamente; confirmação só finaliza após pagamento aprovado | benjamindickman.com/blog/system-design-interview-the-double-booking-problem |
| Booksy | Waitlist automatizada: cliente se inscreve para receber notificação quando abrir vaga **dentro de uma janela de tempo específica que ele mesmo define** — diferente de "qualquer vaga futura", é preferência de janela | biz.booksy.com/features |
| Booksy | **"Last Minute Discount"**: desconto automático aplicado a agendamento feito com pouca antecedência (configurável, ex.: até 4h antes do horário) — mecanismo de yield dinâmico para preencher buraco de cancelamento, distinto de waitlist (não depende de fila de espera, é preço reativo) | support.booksy.com/hc/en-us/articles/16485226884370 |
| Booksy | **"Boost"** — feature de marketplace/aquisição, **não é gap-fill de agenda interno**: ativa visibilidade do negócio no marketplace da Booksy (44M+ usuários); cobra comissão de 30% sobre o valor da PRIMEIRA visita de cliente novo trazido pela marketplace enquanto ativo; sem mensalidade adicional (pay-per-performance); da segunda visita em diante, 100% fica com o negócio | biz.booksy.com/en-us/features/boost; support.booksy.com/hc/en-us/articles/16486272070546 |
| Booksy (risco documentado por review terceirizada) | Atribuição de "cliente novo" contestada publicamente: donos relatam cobrança da comissão de 30% mesmo quando o cliente chegou pelo próprio site/rede social/Google — a reserva só passou pela URL da Booksy, e isso bastou para a plataforma classificar como aquisição via Boost | setora.co.uk/blog/booksy-boost-commission-explained |

### Leitura preliminar (não é classificação — isso é etapa 4)

```text
1. O gap de mercado mais relevante encontrado nesta rodada: NEM Boulevard nem
   Vagaro (dois líderes) fazem waitlist reativa em tempo real a evento de
   cancelamento — só lembrete programado. O Master Briefing já aprovou
   "Waitlist Recovery com hold" como P1 (Red Team, Decision Log Seção 5).
   Este achado REFORÇA que essa aposta é diferencial real, não redundância
   com o que já existe no mercado.
2. O padrão de resource lock com timeout (retém durante checkout, libera se
   pagamento falha/expira) é engenharia de reserva consolidada, não
   específica de salão — mapeia diretamente para o conceito de Resource Lock
   que o domínio D07/Booking Candidate do KortexOS já pressupõe. Candidato a
   HERDAR (confirma o que já foi desenhado, não muda nada).
3. Herança de configuração por serviço → unidade (Bella Booking) é o mesmo
   padrão que a Business Configuration & Policy Layer já formaliza (Parte
   III §1.6) — validação cruzada, não achado novo.
```

---

## Índice de fontes desta rodada

```text
help.zenoti.com (6 páginas) — Zenoti Help Center, documentação oficial
zenoti.com/thecheckin — blog institucional Zenoti
mindbodyonline.com (3 páginas) — documentação oficial Mindbody
goodcall.com — comparativo terceirizado Mindbody vs Vagaro
support.boulevard.io — Boulevard Support Center, documentação oficial
authencio.com — review terceirizado Boulevard
ustechautomations.com — comparativo terceirizado Boulevard vs Vagaro
bellabooking.com — documentação de produto (player menor, referência de padrão)
benjamindickman.com — artigo técnico de engenharia de sistemas (padrão genérico)
```

---

---

# RODADA 2 — Módulos 03 e 04

## Módulo 03 — Checkout & Payments

| Referência (Tier) | Achado | Fonte |
|---|---|---|
| Stripe Connect (Tier 3) | Três modelos de cobrança para split multi-parte: **Direct Charges** (o prestador cobra o cliente direto, plataforma fica com uma taxa — menos controle), **Destination Charges** (plataforma cobra e transfere pra UM conectado só, ideal quando é 1 prestador por transação), **Separate Charges and Transfers** (plataforma cobra e depois cria transferências separadas pra MÚLTIPLOS conectados numa única cobrança — modelo recomendado quando é preciso dividir entre vários profissionais na mesma comanda) | docs.stripe.com/connect/charges; docs.stripe.com/connect/marketplace/tasks/accept-payment |
| Stripe Connect (Tier 3) | "Separate Charges and Transfers" também permite **reter fundos por um período antes de transferir** — útil quando o repasse só deve acontecer após o serviço ser de fato entregue, não no ato do pagamento | docs.stripe.com/connect/marketplace/tasks/accept-payment |
| Stripe Connect (Tier 3) | Estornos e chargebacks são puxados **proporcionalmente de cada parte** que recebeu a divisão original, de forma automática — reversão automática do split, não manual | stripe.com/resources/more/how-to-implement-split-payment-systems |
| Stripe Connect (Tier 3) | Usar um orquestrador de pagamento como intermediário evita que a plataforma precise se registrar como instituição de pagamento/money transmitter — a responsabilidade regulatória de custódia migra para o orquestrador | stripe.com/resources/more/how-to-implement-split-payment-systems |
| Amazon (Tier 2) | 1-Click Checkout (1999): elimina as 4-5 etapas tradicionais (carrinho → login → endereço → pagamento → confirmação) reduzindo para clique único usando dados salvos — ligado a aumento relevante de conversão e redução de abandono de carrinho | rockpaperscissors.studio/amazon-one-click-checkout |
| Amazon (Tier 2) | **Contraponto que a própria Amazon aplicou:** evoluiu do 1-Click puro para o "Buy It Now" com uma etapa de confirmação — fricção zero maximiza conversão, mas remove o momento de o cliente perceber um erro antes de confirmar. Fricção proposital tem função quando a decisão é de risco ou segurança | medium.com/@bobbyhinson/the-value-of-friction-in-ux |
| Amazon (Tier 2) | Transparência de preço (nada de custo surpresa na etapa final), indicador de progresso durante o checkout, e validação de campo em tempo real reduzem abandono | raw.studio/blog/how-amazon-uses-5-ux-principles |
| Caso documentado de risco (não Amazon) | Epic Games/Fortnite foi multado pela FTC (US$ 245M) porque o checkout com cartão salvo era frictionless a ponto de permitir compra por menor sem autorização perceptível dos pais — risco regulatório real de fricção zero em cobrança recorrente/cartão salvo sem verificação de autorização | medium.com/design-bootcamp/the-one-click-action-paradox |

### Leitura preliminar (não é classificação — isso é etapa 4)

```text
1. O modelo "Separate Charges and Transfers" da Stripe é a arquitetura de
   referência para o split multi-profissional de uma comanda com vários
   serviços — mapeia diretamente pro Tip Engine (DEC-02) e pra comissão de
   venda vs. execução (DEC-15/18). O detalhe de "reter fundos até o serviço
   ser entregue" é validação direta de por que comissão nasce no uso, não na
   venda (DEC-10/18) — um provedor de infraestrutura de pagamento resolve o
   mesmo problema com a mesma lógica de retenção condicional.
2. A reversão automática e proporcional de estorno em cada parte do split
   confirma que o clawback proporcional (usado antes do DEC-18 e ainda válido
   como lógica geral de estorno) é padrão de mercado consolidado, não
   invenção isolada do KortexOS.
3. O recuo da própria Amazon do 1-Click puro é um alerta direto: qualquer
   fluxo do KortexOS que remova confirmação de ações financeiras (edição de
   valor, comissão, gorjeta) deve manter o passo de confirmação — o que já é
   verdade pela regra de "motivo obrigatório" em mutação financeira (T6),
   mas agora com justificativa de mercado, não só de governança interna.
4. O caso Epic Games/FTC é um lembrete de risco, não uma ameaça direta ao
   modelo do salão — mas reforça que cartão salvo para cobrança futura
   (depósito, assinatura, no-show) precisa de consentimento explícito e
   auditável, o que já está coberto pelas regras de consentimento do módulo
   de dados sensíveis (D26) e do DEC-14 (aceite digital de pacote).
```

---

## Módulo 04 — Ledger / Wallet / Current Accounts

| Referência (Tier) | Achado | Fonte |
|---|---|---|
| Modern Treasury (Tier 3) | Três princípios inegociáveis do ledger: **double-entry** (toda transação lançada em pelo menos duas contas), **auditabilidade** e **imutabilidade** — lançamento publicado nunca é apagado nem sobrescrito | moderntreasury.com/journal/enforcing-immutability |
| Modern Treasury (Tier 3) | Reversão é sempre um lançamento negativo explícito referenciando o original — o lançamento original permanece no histórico como parte do registro financeiro completo, nunca é editado | finlego.com/blog/designing-a-real-time-ledger-system |
| Modern Treasury (Tier 3) | Chaves de idempotência são obrigatórias para prevenir lançamento duplicado em caso de retry de rede ou timeout — mesma chave, mesmo resultado, nunca duplicata | webflow.moderntreasury.com/products/ledgers |
| Modern Treasury (Tier 3) | Plano de contas (Chart of Accounts) de referência: contas de usuário/carteira, contas de tesouraria (caixa da casa), contas de taxa/receita, contas de reserva/escrow (fundos pendentes ou condicionais), contas de compensação/staging (em trânsito ou não confirmado) | finlego.com/blog/designing-a-real-time-ledger-system |
| Modern Treasury (Tier 3) | Caso de uso citado pela própria Modern Treasury: **ClassPass** usa ledger para rastrear repasse a estúdios **no momento em que o cliente efetivamente comparece à aula** — mesma lógica de "obrigação na venda, receita e repasse no consumo real" que o KortexOS já adotou para planos e pacotes (DEC-10/18) | moderntreasury.com/journal/enforcing-immutability |
| Modern Treasury (Tier 3) | Escala/concorrência: uso de fila assíncrona para lançamentos, controle de concorrência otimista com versionamento por conta, para evitar leitura de saldo desatualizado sob alta escrita simultânea | moderntreasury.com/journal/how-to-scale-a-ledger-part-vi |

### Leitura preliminar (não é classificação — isso é etapa 4)

```text
1. Validação forte e direta: os três princípios do Modern Treasury
   (double-entry, auditabilidade, imutabilidade) são exatamente os três
   pilares que o KortexOS já definiu pro ledger (T6, DEC-03/11 reabertura por
   versão, estorno por lançamento reverso nunca edição). Não é coincidência
   — é o consenso da indústria de infraestrutura financeira. Forte candidato
   a HERDAR/REFORÇAR na etapa 4, sem necessidade de redesenho.
2. O caso ClassPass é a validação mais direta que apareceu em toda a
   pesquisa até agora: é o MESMO modelo de negócio do KortexOS (crédito/
   plano consumido em atendimento pontual, repasse ao prestador no momento
   do uso real) resolvido pela mesma lógica que DEC-10/18 já adotaram.
   Isso não é mais "acho que está certo" — é "outro sistema resolvendo o
   mesmo problema de negócio chegou na mesma resposta".
3. O plano de contas de referência (user/treasury/fee/reserve/clearing) é
   material direto pra quando o Migration Map desenhar as tabelas reais do
   ledger — não é decisão a tomar agora, é insumo pra etapa 6.
4. Concorrência/versionamento otimista é preocupação de escala (produto
   maduro, muitos usuários simultâneos) — fora do horizonte imediato do
   Salão Esperança, mas vale registrar para não ignorar quando o volume
   crescer. Candidato a ADICIONAR AO BACKLOG.
```

---

## Índice de fontes da Rodada 2

```text
docs.stripe.com, stripe.com/connect, stripe.com/resources — documentação oficial Stripe Connect
moderntreasury.com/journal, webflow.moderntreasury.com — documentação e blog técnico oficial Modern Treasury
rockpaperscissors.studio, medium.com (3 artigos), raw.studio — UX case studies terceirizados sobre Amazon checkout
finlego.com, sdk.finance — artigos técnicos de arquitetura de ledger (terceirizados, não específicos de um vendor)
```

---

---

# RODADA 3 — Módulos 05 e 06 (fecha o escopo priorizado, DEC-20)

## Módulo 05 — Compensation / Tips / Payout

| Referência (Tier) | Achado | Fonte |
|---|---|---|
| Zenoti (Tier 1) | Repasse de gorjeta no mesmo dia, via carteira/cartão próprio (Zenoti Wallet/Smart Card), separado do ciclo normal de folha — funcionalidade distinta de payroll completo | zenoti.com/platform/payroll-and-tipping |
| Zenoti (Tier 1) | **Três opções de absorção de taxa de cartão sobre gorjeta** — idênticas em estrutura ao que já documentamos na AppBarber: (1) negócio absorve a taxa, funcionário recebe 100% (default); (2) taxa repassada ao cliente como "convenience fee" visível no checkout; (3) descontada do funcionário | help.zenoti.com/.../configure-tips-convenience-fees |
| Zenoti (Tier 1) | Mudança de configuração de taxa **nunca é retroativa** — aplica-se só a transações futuras, transações passadas não são recalculadas | help.zenoti.com/.../configure-tips-convenience-fees |
| Zenoti (Tier 1) | **"Redo commission"**: quando um segundo profissional refaz um serviço (correção), a comissão do segundo pode ser calculada sobre o preço de venda do serviço OU sobre a receita efetivamente realizada — configurável; em caso de pacote, aplica o rateio sobre o preço de venda do pacote | help.zenoti.com/admin/employee-commissions--payouts- |
| Zenoti (Tier 1) | Base de comissão varia por tipo de redenção: administrador decide se o VALOR ou o PREÇO de cartão pré-pago/gift card conta como receita de serviço para fins de comissão | help.zenoti.com/admin/employee-commissions--payouts- |
| Zenoti (Tier 1) | Payroll nativo completo (slabs escalonados, splits, deduções, filing de imposto, W-2/1099) — ambição além do payroll, não só comissão | zenoti.com/thecheckin/best-salon-commission-payroll-software |

### Leitura preliminar (não é classificação — isso é etapa 4)

```text
1. Validação cruzada forte: o modelo de 3 opções de absorção de taxa sobre
   gorjeta aparece de forma independente em Zenoti (internacional, líder
   enterprise) E AppBarber (nacional, sistema atual do Salão Esperança).
   Dois players não relacionados convergindo na mesma estrutura de 3 vias
   é sinal de padrão de mercado consolidado, não coincidência. Reforça
   DEC-01 com ainda mais confiança.
2. "Config nunca retroage" aparece pela segunda vez nesta pesquisa (já visto
   em Boulevard/redesigned appointment book) — mais uma confirmação
   independente de T4.
3. GAP REAL IDENTIFICADO: "redo commission" (comissão de segundo profissional
   que refaz um serviço) não está coberto em nenhuma parte do Master
   Briefing hoje. É um cenário operacional real (cliente insatisfeito,
   outro profissional corrige). Não é urgente, mas é uma lacuna genuína —
   candidato a ADICIONAR AO BACKLOG para a Comparative Proposal.
4. Base de comissão variável por tipo de redenção (cartão pré-pago vs.
   dinheiro) já é coberta em espírito pelo conceito de "preço de referência
   de consumo" (DEC-10), mas o detalhe de VALOR vs. PREÇO do cartão pré-pago
   como base é granularidade nova a considerar no cadastro de formas de
   pagamento.
```

---

## Módulo 06 — No-show / Deposit / Card-on-file

| Referência (Tier) | Achado | Fonte |
|---|---|---|
| Stripe (Tier 3) | **SetupIntent**: primitiva específica pra salvar cartão sem cobrar nada no ato — exatamente o mecanismo técnico de "cartão em arquivo" para uso futuro (depósito, no-show) | docs.stripe.com/payments/setup-intents |
| Stripe (Tier 3) | Parâmetro `off_session`: documentação cita explicitamente "capturar forma de pagamento em arquivo para taxas futuras, como taxas de cancelamento ou no-show" — é o caso de uso exato do KortexOS, nomeado pela própria Stripe | docs.stripe.com/payments/checkout/save-during-payment |
| Stripe (Tier 3) | Consentimento explícito é **obrigatório** para salvar cartão pra cobrança futura — checkbox específico ("Save my payment method for future use"), não pode ser implícito | docs.stripe.com/payments/setup-intents |
| Stripe (Tier 3) | **Restrição técnica real**: janela de autorização de hold é limitada por rede de cartão — cerca de 4 dias e 18h pra maioria das transações (Visa encurtou de 7 para 5 dias em abril/2024); não é possível "segurar" uma autorização indefinidamente para agendamento marcado com muita antecedência | docs.stripe.com/payments/place-a-hold-on-a-payment-method |
| Vagaro (Tier 1) | Distingue duas mecânicas: **"Hold with Credit Card"** (só guarda o cartão, não cobra nada no ato de agendar) vs. **depósito real** (cobra um percentual antecipado, no ato) | vagaro.com/learn/deposits-for-hair-appointment-service |
| Boulevard (Tier 1) | Depósito configurado **por serviço individual**, não globalmente; auto-checkout cobra o cartão em arquivo assim que o serviço termina, eliminando fila de pagamento no balcão | support.boulevard.io/pre-payments-and-deposits; authencio.com/boulevard-deep-dive |
| Boulevard (Tier 1) | Depósito aparece como **Account Credit** no perfil do cliente, aplicado no checkout final — mesmo padrão conceitual do client wallet do KortexOS | support.boulevard.io/pre-payments-and-deposits |
| Referências de mercado (agregadas, terceirizadas) | Quatro estruturas de depósito em uso: valor fixo, percentual, por nível de serviço (só serviços caros/longos), vinculado a plano/assinatura. Achado empírico: valor fixo converte melhor que percentual em serviços abaixo de ~R$500 (menos esforço mental no momento da reserva) | sicusmedia.com/blog/salon-deposit-policy-template |
| Referências de mercado (agregadas, terceirizadas) | Depósito não-reembolsável é considerado válido (jurisdição US/Canadá) **desde que claramente disclosed antes da reserva, com reconhecimento explícito** (checkbox ou assinatura) — mesmo princípio universal por trás do DEC-14, confirmado fora do contexto brasileiro | sicusmedia.com/blog/salon-deposit-policy-template |
| Referências de mercado (agregadas, terceirizadas) | Janela de cancelamento comum: 24-48h para serviços padrão, até 72h para serviços de alto ticket | joinblvd.com/blog/salon-cancellation-policy |

### Leitura preliminar (não é classificação — isso é etapa 4)

```text
1. ACHADO MAIS IMPORTANTE DA RODADA: a janela de autorização de hold é
   limitada por rede de cartão (~5 dias), não por escolha de produto. Isso
   é uma restrição técnica real, não uma decisão de negócio — significa que
   "segurar um cartão sem cobrar" só funciona para agendamentos marcados com
   pouca antecedência. Para agendamento com semanas de antecedência (comum em
   plano/pacote e serviços de alto ticket), o mecanismo precisa ser outro:
   cobrança real com reembolso condicional, ou re-autorização mais perto da
   data. Isso NÃO é uma decisão a tomar agora — é um insumo técnico
   obrigatório para quando o Blueprint desenhar o módulo de depósito.
2. O par SetupIntent + off_session é, na prática, a especificação de
   referência de como a integração de pagamento do KortexOS deveria
   funcionar tecnicamente para depósito/no-show, quando a fase de
   integração de PSP chegar. Não é decisão de produto — é blueprint técnico
   já validado por um provedor líder de infraestrutura de pagamento.
3. Consentimento explícito (checkbox específico) pra salvar cartão é a
   MESMA exigência que já está em DEC-14 (aceite digital de pacote) e
   DEC-19 (consentimento específico e destacado de dado sensível) — agora
   confirmada como padrão universal do lado de infraestrutura de pagamento,
   não só do lado jurídico brasileiro. Três fontes independentes (LGPD,
   CDC, Stripe) convergindo na mesma exigência.
4. O padrão "Account Credit" da Boulevard para depósito é literalmente o
   client wallet que o KortexOS já tem cadastrado — validação direta, sem
   necessidade de mudança.
5. Achado empírico de UX (valor fixo converte melhor que percentual em
   serviço de menor ticket) é insumo pra Comparative Proposal, não decisão
   agora — mas vale registrar pra não perder.
```

---

## Índice de fontes da Rodada 3

```text
zenoti.com/platform, help.zenoti.com (5 páginas) — documentação e blog oficial Zenoti
docs.stripe.com (4 páginas) — documentação oficial Stripe (SetupIntents, off_session, holds)
vagaro.com/learn — conteúdo educacional oficial Vagaro
support.boulevard.io, authencio.com — documentação oficial + review terceirizada Boulevard
sicusmedia.com, joinblvd.com/blog — agregadores/blog terceirizados de política de depósito e cancelamento
```

---

## Encerramento do escopo priorizado (DEC-20)

```text
3 rodadas, 6 módulos, concluídos: 01 Booking & Capacity, 02 Smart Gap/Waitlist/
Resource Locks, 03 Checkout & Payments, 04 Ledger/Wallet, 05 Compensation/Tips/
Payout, 06 No-show/Deposit/Card-on-file.

Achados mais fortes do conjunto: (a) os três pilares de ledger do Modern
Treasury validam a arquitetura já decidida sem redesenho; (b) o caso ClassPass
confirma que "comissão no uso, não na venda" é solução de mercado madura pro
mesmo problema de negócio; (c) a janela de autorização de hold por rede de
cartão é restrição técnica real que o Blueprint precisa herdar; (d) três
fontes independentes (LGPD, CDC, Stripe) convergem na mesma exigência de
consentimento explícito para cobrança futura.

Próximo passo: os outros 10 módulos (07-16) entram na fila quando o subsistema
correspondente virar prioridade real (DEC-20) — não pesquisados agora.
A etapa 3 (Global Benchmark Map) está completa para o escopo aprovado.
Próxima etapa da ordem de construção: etapa 4, Comparative Proposal — classificar
cada achado em HERDAR/RENOMEAR/REFORÇAR/BACKLOG/BLOQUEAR/DESCARTAR.
```

---

---

# RODADA 4 — Pontos cegos estruturais pré-Blueprint (2026-07-20)

**Natureza distinta das rodadas 1-3:** não é um novo módulo do §23.2, é uma rodada motivada pela mesma lógica que gerou o adendo D02 do Truth Map (DEC-25) — aprofundar camadas já tocadas pelo escopo aprovado antes do Blueprint (etapa 7) travar decisões sobre elas. Escopo definido pelo Platform Owner: "nova rodada de benchmark, levantamento de profundidade das camadas, procurar pontos cegos". 4 frentes pesquisadas em paralelo. Leitura completa da síntese e das implicações em `KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md` — esta seção é só a matriz rastreável por fonte (mesmo padrão das rodadas 1-3).

## Frente A — Hierarquia Empresa → Unidade (D01/D02/D28)

**Motivação:** o Master define `Sistema → Empresa (tenant) → Unidade → Profissional` (§1.5, Parte III) como hierarquia de herança obrigatória; "unidade" aparece 22× no documento. O schema atual só tem `organizations` — nenhuma tabela de unidade/filial existe.

| Plataforma | Achado | Fonte |
|---|---|---|
| Zenoti | Hierarquia explícita de 2 níveis: Organization → Center. Onboarding single-location ainda cria um Center (não é opcional). Override é seletivo/allowlisted, documentado campo a campo | help.zenoti.com/en/admin/add-new-centers-in-zenoti.html; help.zenoti.com/zenoti-administration/introduction-to-zenoti-admin/general-setup-options-for-a-center |
| Zenoti | API pública confirma Center como entidade de 1ª classe (`GET /v1/centers`), endereçável separadamente | docs.zenoti.com/reference/list-all-centers |
| Boulevard | "Locations tab" dentro de Business Settings; onboarding de nova location é majoritariamente NÃO herdado (endereço, horário, staff, serviços, tax rates, merchant account — tudo configurado por location) | support.boulevard.io/en/articles/11682178-multilocation-business-support; support.boulevard.io/en/articles/11326035 |
| Mindbody | Invariante documentado: "each Site ID has at least one location". Dois padrões nomeados: "Datashare" (1 Site, N Locations, catálogo/staff compartilhado) vs. "Cross-regional" (Site IDs separados = tenants de fato). Franquia ganha 3ª camada opcional ("Enterprise Management") | support.mindbodyonline.com/s/article/215814058; support.mindbodyonline.com/s/article/203260043; mindbodyonline.com/business/enterprise-management |
| Vagaro | Padrão estruturalmente diferente: cada location é sua própria conta de Business completa (`business_id` = identificador da location, sem organization_id pai). "Adicionar location" = criar e linkar 2ª conta, sincronizada via grupo "Flagship" | support.vagaro.com/hc/en-us/articles/204850710; docs.vagaro.com/public/reference/api-introduction |
| Fresha | Lista "Locations" dentro de um único Workspace; recursos/serviços são atribuídos explicitamente a 1+ locations; banking é separável por location | fresha.com/help-center/.../100677-manage-business-locations-1; fresha.com/help-center/.../217-set-up-separate-bank-accounts |
| Trinks (nacional) | Padrão de contas-pares (como Vagaro): 1 login acessa múltiplas "unidades" independentes. Camada opcional de "cadastro modelo" para redes/franquias, com sincronia em lote (não herança em tempo real) e matriz campo-a-campo documentada de o que sincroniza vs. fica sempre local | ajuda.trinks.com/como-cadastrar-uma-nova-unidade; ajuda.trinks.com/cadastro-modelo-e-sincronia |

```text
Leitura preliminar:
1. Dois padrões de mercado, não um: (a) hierarquia pai-filho desde o dia 1,
   independente do tamanho (Zenoti, Mindbody, Boulevard) — a entidade
   "Unidade" sempre existe, mesmo para 1 location; (b) contas-pares
   vinculadas depois (Vagaro, Trinks modo padrão) — só existe uma "unidade"
   conceitual quando uma 2ª é de fato adicionada.
2. Nenhum player pesquisado documenta publicamente uma camada acima de
   "Organização" equivalente ao "Sistema (defaults do KortexOS)" do Master —
   a metade Sistema→Empresa da hierarquia de 4 níveis não tem validação de
   mercado encontrada; a metade Empresa→Unidade→Profissional tem validação
   forte (padrão a).
3. Onde documentado (Zenoti, Trinks), o override é campo-a-campo/allowlisted,
   não "qualquer campo pode ser sobrescrito" — a matriz do Trinks (o que
   sincroniza vs. fica sempre local em Serviço/Produto) é referência concreta
   se o KortexOS desenhar uma matriz de override Empresa→Unidade.
4. Franquia/rede é tratada como camada opcional ACIMA de Org→Location em
   2 dos 7 players (Mindbody Enterprise Management, Trinks cadastro modelo),
   não como o caso-base — não confundir com o par Empresa/Unidade.
```

## Frente B — Profundidade da Calendar Policy & Availability Layer (D02/D07)

**Motivação:** aprofundamento do achado já registrado no adendo D02 (DEC-25) — os 8 objetos de política e a precedência de 7 níveis do Master, comparados à mecânica técnica real de calendário/turno em produção.

| Plataforma / Referência | Achado | Fonte |
|---|---|---|
| Zenoti | Escala de profissional suporta turno duplo (Shift 1/Shift 2, "split shift") com status por dia (Working/On Leave/Weekly Off/Sick Leave). Config de reserva fora do horário é regra ligável/desligável ("Allow override booking restrictions"), não precedência fixa | help.zenoti.com/en/configuration/employee-configurations/set-up-employee-schedules.html; help.zenoti.com/.../allow-override-booking-restrictions.html |
| Booksy | Turno do profissional herda o horário do negócio por padrão, editável individualmente, com suporte a pausas (breaks) dentro do turno. Mudança de horário padrão é versionada por data de vigência (imediata, próxima semana, ou data escolhida) | support.booksy.com/.../16538517199250; support.booksy.com/.../16536020166546 |
| Fresha | Horário de abertura da unidade e turno do profissional são **explicitamente desacoplados** — documentação afirma que o turno do profissional, não o horário da unidade, determina o que é reservável online. Turno suporta até 10 blocos/dia. "Closed periods" (fechamento excepcional) tem precedência sobre turnos individuais mas **não cancela agendamentos já existentes** automaticamente | fresha.com/help-center/.../588-update-your-business-opening-hours; fresha.com/help-center/.../17-schedule-and-update-team-shifts; fresha.com/help-center/.../20-set-business-closed-periods |
| Vagaro | Padrão de precedência invertido: toggle "Use Employee Working Hours" deriva o horário público do negócio da união dos turnos dos funcionários (funcionário define unidade, não o contrário) | support.vagaro.com/hc/en-us/articles/34418132184091 |
| Tier 3 — Microsoft Dynamics 365 Field Service | Rank explícito: ocorrência pontual (Rank 1) sempre vence recorrência semanal (Rank 0); entre regras do MESMO rank que colidem, desempate é por edição mais recente, não por tipo — inclusive "Business Closure" e uma ocorrência pontual de "Working" são o mesmo rank | learn.microsoft.com/en-us/dynamics365/field-service/field-service-work-hours-calendar-api |
| Tier 3 — Oracle Fusion Field Service | Hierarquia formal: "Individual Schedule takes precedence over the Default Schedule", herdado em cascata org→divisão→região | docs.oracle.com/en/cloud/saas/field-service/faaca/c-managingresourcecalendars.html |
| Tier 3 — HighLevel / padrão Cal.com-like | "Date-Specific Hours" sempre vence "Weekly Working Hours"; sobreposição é por SUBSTITUIÇÃO total do dia, não soma | help.gohighlevel.com/support/solutions/articles/155000001716 |

```text
Leitura preliminar:
1. A direção geral do modelo de 7 níveis do KortexOS é consistente com o
   mercado: "data específica vence padrão recorrente, que vence default
   herdado" aparece em todo player pesquisado, vertical ou horizontal.
2. Nenhum concorrente vertical publica uma tabela de precedência formal de
   N níveis — resolvem via UX/defaults, não especificação documentada. Só o
   Dynamics 365 formaliza precedência com regra de desempate explícita. O
   KortexOS ter um modelo explícito é MAIS rigoroso que qualquer concorrente
   direto do nicho expõe publicamente — não prova que 7 é o número certo,
   só que a formalização em si é incomum no nicho.
3. DIVERGÊNCIA REAL: separar "abertura excepcional" e "fechamento
   excepcional/feriado" como dois NÍVEIS de precedência distintos (fechamento
   sempre vence abertura) não aparece em nenhum sistema pesquisado. Todos
   usam um único mecanismo genérico de override por data (abre OU fecha),
   resolvido por recência de edição (Dynamics 365) ou substituição total do
   dia (Cal.com/HighLevel) — não por um tipo vencer o outro por definição.
4. GAP MAIS ROBUSTO DA RODADA: horário partido/pausa no meio do turno.
   100% dos players pesquisados têm algum mecanismo pra isso (Zenoti shift
   duplo, Fresha até 10 blocos/dia + "blocked time" dedicado, Vagaro até 4
   blocos, Booksy breaks dentro do turno, Dynamics 365 com WorkHourType
   "Break" formal). Os 8 objetos de política do Master NÃO incluem um objeto
   explícito de pausa/intervalo — pergunta em aberto: o objeto "turno" do
   KortexOS permite múltiplos registros por profissional/dia, ou é um único
   par início/fim por dia da semana?
5. Timezone como propriedade da unidade é confirmado em Zenoti, Fresha e
   Booksy — decisão do KortexOS validada sem ressalva.
6. Achado colateral: Fresha confirma que um fechamento excepcional criado
   depois NÃO cancela agendamentos já existentes — sugere que o gate de
   precedência do KortexOS só precisa atuar na escrita (criação/edição),
   não como revalidação retroativa quando a política muda.
```

## Frente C — Mecanismo de Action Request (D24/D31)

**Motivação:** o Master exige Action Request (fluxo de aprovação formal) para 13 ações sensíveis (§19.2) — hoje 100% ausente do código (nenhum módulo de aprovação/workflow existe).

| Plataforma / Referência | Achado | Fonte |
|---|---|---|
| Zenoti | Desbloquear/reabrir fatura fechada exige usuário+senha (e, para reabrir, "Comments" obrigatório) de alguém com a permissão — override SÍNCRONO por credencial no momento, não objeto de solicitação assíncrono. Fora da janela de financial lock (90 dias), reabertura é bloqueada mesmo com permissão | help.zenoti.com/en/articles/1544560; help.zenoti.com/appointment-book/manage-invoices/reopen-a-closed-invoice |
| Vagaro | "Approve a Discount at Checkout": desconto fora do limite trava o checkout até alguém autorizado digitar a própria senha e aprovar — mesmo padrão síncrono, no ponto de venda | support.vagaro.com/hc/en-us/articles/20731572341531 |
| Boulevard | "Discount Reasons" é motivo obrigatório em dropdown, SEM aprovação/bloqueio — é trilha de auditoria pura. Único workflow de aprovação real documentado é para prontuários/formulários clínicos (compliance de medspa), não para exceção financeira | support.boulevard.io/en/articles/5941352; support.boulevard.io/en/articles/11662777 |
| Square / Roller (POS genérico, fora do nicho) | Padrão "manager override by PIN": ação restrita (void, desconto, reimpressão, cortesia) exige PIN de quem tem role de gerente; síncrono, bloqueia a transação, fica registrado em log de atividade do POS. Roller é o exemplo mais completo e explícito de manager override documentado em qualquer categoria pesquisada | squareup.com/help/us/en/article/5822; mysupport.roller.software/hc/en-us/articles/115001725474 |
| Ramp / Expensify (fintech despesas corporativas) | Violação de política vira registro SEPARADO da transação, roteado a aprovador com nome/timestamp/justificativa, sincronizável ao ERP. É o padrão assíncrono "maker-checker" mais próximo do desenho do KortexOS entre tudo que foi encontrado | ramp.com/answers/policy-enforcement/can-violations-be-overridden-or-approved; help.expensify.com/articles/expensify-classic/workspaces/Enable-and-set-up-expense-violations |
| Apache Fineract/Mifos X (core banking open-source, produção real) | Comandos que mudam estado são persistidos; maker-checker liga/desliga por API; endpoint dedicado aprova/rejeita a entrada guardada SEM duplicar lógica — dispara o mesmo comando original armazenado | mifos.readme.io/reference/approvemakercheckerentry; fineract.apache.org/docs/stable |
| Tier 3 — padrão de engenharia "maker-checker" | Dois artigos técnicos independentes descrevem a mesma arquitetura de referência: tabela de solicitação (payload+status+maker+checker+timestamps), Execution Engine que só dispara a ação original após aprovação, segregação de função em código. Nomenclatura de estados muito próxima do ciclo draft→ready_for_review→approved→executing→executed/rejected/cancelled/failed do KortexOS | opcito.com/blogs/maker-checker-implementation-guide-for-secure-fintech-systems; medium.com/hevo-data-engineering/building-a-maker-checker-system-with-audit-trail |

```text
Leitura preliminar:
1. O desenho do KortexOS é consistente com um mercado DIFERENTE do que
   "Action Request" concorre diretamente. Dentro do nicho beauty-tech, o
   padrão dominante é SÍNCRONO (PIN/senha no momento), não um objeto de
   solicitação assíncrono — mais simples, suficiente quando o aprovador está
   fisicamente presente.
2. Nenhum concorrente direto de beauty-tech documenta publicamente um fluxo
   assíncrono para as exceções financeiras que o Master lista (perdoar
   no-show, liberar fiado, ajustar comissão, crédito manual, contrato
   corporativo) — o único approve/reject workflow documentado no nicho
   (Boulevard) é para prontuário clínico, não dinheiro. Reforça que esse
   mecanismo é lacuna real do nicho, não retrabalho do que já existe lá.
3. Fora do nicho, o padrão já existe, é maduro e está em produção: Fineract
   (core banking open-source) implementa literalmente "comando persistido →
   aprovação por terceiro → execução do MESMO comando original, sem duplicar
   lógica" — arquiteturalmente idêntico ao princípio "Action Request não cria
   ledger/pagamento/comissão direto, delega ao Command normal".
4. Técnica de implementação já validada (Opcito, Ash/Medium): no momento da
   aprovação, o motor de execução chama o mesmo endpoint/função de negócio
   original com uma flag de bypass/contexto — não reimplementa a ação dentro
   do módulo de aprovação. Vale como guia de implementação para o Blueprint.
5. GAP NO MASTER: o documento só especifica o modelo assíncrono completo.
   Nada impede a mesma entidade Action Request ter um caminho rápido
   (gerente presente colapsa draft→ready_for_review→approved numa
   interação só, tipo PIN) para casos com aprovador no local, reservando o
   ciclo assíncrono completo para quando não há aprovador presente (ajuste
   de contrato corporativo, revisão de comissão de fim de mês) — Fineract e
   Expensify já operam assim (maker-checker por ação individual, auto-aprova
   quando não há violação).
6. Primitivo barato e convergente: Zenoti, Boulevard e Ramp, cada um a seu
   modo, exigem TEXTO DE JUSTIFICATIVA obrigatório no momento da submissão —
   ortogonal ao workflow, barato de garantir no campo motivo do Action
   Request desde a primeira versão.
```

## Frente D — Negative Guard / Client Reliability Score (D16/D24)

**Motivação:** o Master define régua progressiva (aviso → sinal 50% → pré-pagamento 100% → healing após 3 atendimentos) e um score multi-variável — hoje 100% ausente do código (`clients` não tem nenhum campo de risco/score/contador).

| Plataforma / Referência | Achado | Fonte |
|---|---|---|
| Vagaro | Achado mais forte do grupo beauty-tech: grava automaticamente no-show/cancelamento no perfil do cliente e permite exigir cartão em arquivo "de clientes que já faltaram/cancelaram pelo menos 1 vez" — contador binário que já dispara fricção a partir da 1ª ocorrência. Relatório filtrável por número de faltas | support.vagaro.com/hc/en-us/articles/17733255316763; support.vagaro.com/hc/en-us/articles/115004772554 |
| Booksy | Confirmado explicitamente: SEM score automático. "Blocked client" é toggle manual; reincidência é rastreada por nota/tag manual da equipe; proteção de no-show é % fixo, igual para todos os clientes | biz.booksy.com/en-us/features/no-show-protection; support.booksy.com/hc/en-us/articles/16484478850066 |
| Zenoti / Boulevard / Mindbody / Fresha | Depósito/cartão em arquivo configurado por SERVIÇO ou por política global do negócio — nenhuma evidência pública de tiering automático por histórico/score do cliente em nenhum dos 4 | zenoti.com/thecheckin/enforce-cancellation-no-show-fees; joinblvd.com/blog/salon-cancellation-policy; support.mindbodyonline.com/s/article/No-Shows-Overview-FAQs; fresha.com/help-center/.../613-payments-policies-overview |
| OpenTable | Política pública unificada "four strikes": 4 no-shows em 12 meses = suspensão da CONTA (plataforma inteira, não por restaurante) — contador discreto binário, sem estágio intermediário público. Único achado de reputação CROSS-TENANT: tags geradas por IA compartilhadas entre restaurantes da rede (plano Pro, beta, opt-out pelo cliente) | help.opentable.com/s/article/What-is-your-no-show-policy; foxnews.com/tech/how-restaurant-reservation-platform-opentable-tracks-customer-dining-habits |
| Resy | Sem threshold numérico público — política de no-show definida restaurante a restaurante, sem regra central | helpdesk.resy.com/resyos-faq |
| Klarna / Affirm (fintech, referência de padrão) | Limite de crédito recalculado dinamicamente por algoritmo — não fixo. Fator mais citado: histórico de pagamento pontual. Affirm decide POR TRANSAÇÃO, não por conta ("dynamic, not static") | klarna.com/us/help/.../does-klarna-perform-a-credit-check; investors.affirm.com/news-releases/.../affirms-underwriting-approach-and-advantage |
| Tier 3 — literatura acadêmica de no-show em saúde | Campo maduro (revisões sistemáticas, AUROC 0,75-0,95). Histórico prévio de faltas é o preditor mais forte — valida a variável central do KortexOS. **"Lead time" (antecedência do agendamento) aparece como um dos preditores mais fortes e consistentes — ausente da lista de variáveis do KortexOS** | pmc.ncbi.nlm.nih.gov/articles/PMC7517206; sciencedirect.com/science/article/pii/S2666521225000328 |
| Tier 3 — Ayres & Braithwaite, "Enforcement Pyramid" (1992) | Teoria regulatória clássica: sanção começa branda e só escala se o comportamento se repetir — paralelo estrutural mais próximo da régua do KortexOS entre tudo pesquisado, mas é teoria genérica de regulação, não desenhada para crédito ao cliente | researchgate.net/figure/Ayres-and-Braithwaites-enforcement-pyramid |

```text
Leitura preliminar:
1. A régua progressiva do KortexOS (aviso → 50% → 100% → healing) NÃO foi
   encontrada implementada e documentada publicamente em nenhum dos 6
   players de beauty-tech pesquisados. O que existe é fragmentado: Vagaro
   tem contador automático sem estágio intermediário; um vendor pequeno
   (Sicus, fonte não-oficial/marketing) salta direto pra 100% já na 1ª
   falta; OpenTable tem só corte binário duro (4 faltas = banimento). Pode
   ser diferencial genuíno do KortexOS OU um padrão que existe internamente
   em algum player sem documentação pública — não dá pra descartar a 2ª
   hipótese.
2. Divisão nítida por setor: beauty-tech/restaurantes usam CONTADORES
   DISCRETOS simples (número de eventos, regra manual); fintech e a
   literatura acadêmica usam SCORE CONTÍNUO/algorítmico interno → decisão
   externa. O desenho do KortexOS (várias variáveis ponderadas → score →
   tiers de ação visíveis) é estruturalmente mais parecido com o padrão
   fintech (score interno → tier externo, tipo "FICO → faixa de APR") do
   que com o padrão atual do setor de beleza (contagem bruta de evento).
3. GAP NA LISTA DE VARIÁVEIS DO MASTER: "lead time" (antecedência do
   agendamento) é preditor forte na literatura e não está entre as 12
   variáveis que o Master já lista (faltas, atrasos, cancelamento tardio,
   reagendamento, atendimento concluído, pagamento, uso de benefício,
   chargeback, tempo desde último problema).
4. DECISÃO CONSCIENTE PENDENTE: o Master parece escopar o score por
   organização (um salão só vê o histórico do próprio cliente). OpenTable é
   o único player com reputação CROSS-TENANT, e mesmo assim em beta/opt-out.
   Vale registrar como decisão consciente do KortexOS, não como omissão.
5. AMBIGUIDADE ENCONTRADA: não está claro no Master se um evento grave
   isolado (chargeback, fraude comprovada) pode PULAR degraus da régua
   (ir direto a pré-pagamento 100% sem esperar a "3ª falta") — a teoria de
   sanção graduada (Braithwaite) sugere que severidade deveria poder
   acelerar a escalada, não só repetição.
```

## Índice de fontes da Rodada 4

```text
help.zenoti.com, docs.zenoti.com, zenoti.com/thecheckin — Zenoti, documentação e API oficiais
support.boulevard.io — Boulevard Support Center, documentação oficial
support.mindbodyonline.com, mindbodyonline.com/business, developers.mindbodyonline.com — Mindbody, documentação e API oficiais
support.vagaro.com, docs.vagaro.com — Vagaro, documentação e API oficiais
fresha.com/help-center — Fresha, documentação oficial
support.booksy.com, biz.booksy.com — Booksy, documentação oficial
ajuda.trinks.com — Trinks (nacional), central de ajuda oficial
squareup.com, mysupport.roller.software — Square e Roller, POS genérico fora do nicho beauty
ramp.com, help.expensify.com — Ramp e Expensify, fintech de despesas corporativas
mifos.readme.io, fineract.apache.org — Apache Fineract/Mifos X, core banking open-source em produção
opcito.com, medium.com (Hevo Data Engineering, Ash Framework) — artigos técnicos de arquitetura maker-checker
learn.microsoft.com (Dynamics 365), docs.oracle.com (Fusion Field Service), support.microsoft.com (Project), help.salesforce.com, help.gohighlevel.com — Tier 3, sistemas de calendário/recurso enterprise
help.opentable.com, helpdesk.resy.com — OpenTable e Resy, reservas de restaurante
klarna.com, investors.affirm.com — Klarna e Affirm, fintech de crédito
pmc.ncbi.nlm.nih.gov, sciencedirect.com — literatura acadêmica de predição de no-show em saúde
researchgate.net, tspa.org — teoria de regulação responsiva e moderação de plataforma
```

---

## Encerramento da Rodada 4

```text
4 frentes pesquisadas, 1 achado estrutural maior que o esperado: a hierarquia
Empresa→Unidade não tem NENHUMA representação no schema atual — mais amplo que
o gap de Calendar Policy já registrado em DEC-25, porque Calendar Policy é uma
das camadas que DEPENDE de Unidade existir. As outras 3 frentes (Calendar
depth, Action Request, Negative Guard/Reliability) confirmam AUSENTE já
esperado pelo Truth Map/Migration Map, mas cada uma trouxe pelo menos 1
divergência ou gap específico do Master que a versão atual do Migration Map
(DEC-24) não previa.

Síntese completa, com implicações sobre o Migration Map já aprovado e
recomendação de próximo passo, em KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md
— este documento é a matriz rastreável por fonte; aquele é a análise.

Nenhuma decisão de arquitetura foi tomada aqui. Nenhuma classificação
HERDAR/REFORÇAR/BACKLOG/BLOQUEAR/DESCARTAR foi aplicada — isso é etapa 4
(Comparative Proposal), e esta rodada aconteceu depois da etapa 4 original
já ter fechado (DEC-22), então cabe ao Platform Owner decidir se os achados
entram como uma mini-proposta comparativa complementar ou são resolvidos
direto no Blueprint.
```
