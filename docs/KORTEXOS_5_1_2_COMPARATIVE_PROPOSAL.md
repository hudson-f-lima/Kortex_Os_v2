# KORTEXOS™ — COMPARATIVE PROPOSAL

**Arquivo:** `KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md`
**Produto:** KortexOS™
**Natureza:** etapa 4 da ordem de construção (Master Briefing §22.1) — classifica cada achado do Global Benchmark Map (etapa 3, módulos 01–06) em uma das seis categorias do §23.3.
**Status:** **APROVADO pelo Platform Owner em 2026-07-19 (DEC-22).** 5 itens corrigidos/adicionados por revisão do Platform Owner; 37 itens originais aprovados sem alteração.
**Companion docs:** `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md` (fonte dos achados) e `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` (onde a regra vigente vive, quando aplicável).

---

## Critérios (§23.3, inalterados)

| Classificação | Uso |
|---|---|
| **HERDAR** | Já está correto no Master Briefing — achado só confirma, sem mudar nada |
| **RENOMEAR** | Só muda nomenclatura |
| **REFORÇAR** | Mercado confirma importância — vira regra nova ou prioridade maior |
| **BACKLOG** | Bom, mas não agora |
| **BLOQUEAR** | Sofisticação prematura ou risco |
| **DESCARTAR** | Não serve ao modelo Kortex |

---

## Distribuição geral

**Atualizado após correções e adições do Platform Owner (rodada de revisão 1).**

| Classificação | Qtde | % |
|---|---:|---:|
| HERDAR | 15 | 36% |
| REFORÇAR | 16 | 38% |
| BACKLOG | 10 | 24% |
| DESCARTAR | 1 | 2% |
| RENOMEAR | 0 | 0% |
| BLOQUEAR | 0 | 0% |

```text
42 itens no total (38 originais + 3 adicionados: agendamento recorrente,
cancelamento recorrente, confirmação manual de pagamento, Pix Automático —
menos 01.10 que deixou de ser item novo e virou correção do existente).
Zero BLOQUEAR se mantém. DESCARTAR caiu pra 1 único item (payroll nativo
completo, módulo 05) — o mais baixo possível sem forçar aprovação cega.
REFORÇAR ultrapassou HERDAR pela primeira vez nesta revisão: a correção do
Platform Owner trouxe 3 itens CRÍTICOS que o benchmark original não tinha
identificado sozinho (recorrência de agendamento, Pix Automático) — a revisão
humana encontrou lacuna real que a pesquisa automatizada não achou.
```

---

# Módulo 01 — Booking & Capacity Scheduling

| # | Achado | Classificação | Justificativa |
|---:|---|---|---|
| 01.1 | Drag-and-drop reagendamento (Zenoti) | **REFORÇAR** | Confirma a prioridade atual do HOPE OS (drag-and-drop é o próximo passo já em execução); ainda não é regra formal no Master Briefing — vira especificação de UI/UX Spec (etapa 10) |
| 01.2 | Redimensionamento por alça arrastável (Zenoti) | **REFORÇAR** | Mesmo motivo — exatamente o "resize" que já está no roadmap imediato |
| 01.3 | Trava financeira: não move se invoice fechada (Zenoti) | **HERDAR** | Já é DEC-03/11 (reabertura de comanda por versão, financial lock) — mercado confirma sem exigir mudança |
| 01.4 | Relaxamento: move mesmo com pagamento se preço não muda (Zenoti) | **BACKLOG** | Refinamento bom, mas adiciona complexidade condicional não necessária agora |
| 01.5 | "Move visit" — arrastar visita composta como bloco (Zenoti) | **REFORÇAR** | Valida o conceito de chain booking (Gate 05) já existente; mecânica específica de UI vai pro backlog de UI/UX Spec |
| 01.6 | Intervalo de exibição configurável ≠ granularidade do slot (Zenoti) | **BACKLOG** | Detalhe de UX bom, não urgente |
| 01.7 | Gap prevention automático em tempo de processamento (Zenoti + Boulevard) | **REFORÇAR** | Dois líderes independentes fazendo a mesma coisa — HOPE OS não tem isso; candidato forte a virar regra nova do Availability Resolver |
| 01.8 | Buffer configurável por categoria de serviço (Mindbody) | **HERDAR** | Já existe no cadastro de serviços (Parte II §6, "buffer pré/pós") |
| 01.9 | Multi-recurso simultâneo: sala+equipamento+profissional (Mindbody) | **REFORÇAR** | Valida o conceito de "recursos exigidos" já no cadastro de serviço (§6), mas a mecânica de reserva simultânea de múltiplos recursos não está plenamente especificada |
| 01.10 | Agendamento por turma/grupo — múltiplos clientes simultâneos (Mindbody, Vagaro "Schedule Multiple Appointments") | **REFORÇAR** *(corrigido pelo Platform Owner — era DESCARTAR)* | Válido para cenários reais do Salão Esperança: grupo de padrinhos, evento familiar, noivas — não é modelo de turma fitness, é agendamento múltiplo simultâneo. Vira regra nova, não coberta hoje |
| 01.13 | **Agendamento recorrente** — cliente com horário fixo repetido (diário/semanal/quinzenal/mensal) (Vagaro, Boulevard) | **REFORÇAR CRÍTICO** *(adicionado pelo Platform Owner)* | Vagaro e Boulevard (2 líderes Tier 1) têm essa feature de forma madura: frequência configurável, data-fim, edição "esta ocorrência vs. série inteira". Realidade central de barbearia (cliente do corte toda quinta) — gap real do Master Briefing hoje, não coberto em nenhum domínio |
| 01.14 | **Cancelamento recorrente** — cancelar uma ocorrência vs. a série inteira (Vagaro, Boulevard) | **REFORÇAR CRÍTICO** *(adicionado pelo Platform Owner)* | Mesma dupla fonte: Vagaro oferece "Cancel This Occurrence" vs. "Cancel Series"; Boulevard exige motivo de cancelamento e limita a 52 ocorrências por série. Toggle de notificação ao cliente existe explicitamente nos dois — mesmo padrão "com aviso/sem aviso" que aparece em 02.9a |
| 01.11 | Calendário colorido + líder específico em barbearia (Booksy) | **REFORÇAR** | Validação direta de relevância — Booksy é referência de barbearia, o modelo mais próximo do Salão Esperança |
| 01.12 | Antecedência mínima configurável (Booksy) | **HERDAR** | Já coberto em "regras gerais de agendamento" da Business Configuration & Policy Layer (Parte III §1.3) |

---

# Módulo 02 — Smart Gap / Waitlist / Resource Locks

| # | Achado | Classificação | Justificativa |
|---:|---|---|---|
| 02.1 | Precision Scheduling — otimização de gap (Boulevard) | **REFORÇAR** | Mesmo achado de 01.7, reforçado por segunda fonte independente |
| 02.2 | Gestão automática de recurso físico (Boulevard) | **REFORÇAR** | Valida o conceito de Resource Lock que D07/Booking Candidate já pressupõe; mecânica de auto-atribuição ainda não especificada |
| 02.3 | Waitlist exige cartão (anti-spam) (Boulevard) | **BACKLOG** | Padrão anti-abuso útil, mas Salão Esperança opera com base de clientes majoritariamente conhecida — prioridade baixa agora |
| 02.4 | Waitlist self-service ignora fechamento/staff específico (Boulevard) | **REFORÇAR** (como anti-padrão a evitar) | Não é feature a copiar — é o erro a NÃO cometer; reforça que o Waitlist Recovery do KortexOS precisa considerar essas duas variáveis desde o desenho |
| 02.5 | Nenhum dos dois líderes (Boulevard/Vagaro) faz waitlist reativa em tempo real | **REFORÇAR** | Achado mais forte da rodada 1 — confirma que "Waitlist Recovery com hold" (já P1 no Red Team) é diferencial real, não redundância |
| 02.6 | Smart gap prevention + sugestão de waitlist (Zenoti) | **REFORÇAR** | Mesmo tema de 02.5, terceira confirmação independente |
| 02.7 | Matching automático + revalidação por expiração (Bella Booking) | **REFORÇAR** | Valida o conceito geral de waitlist inteligente que o KortexOS pretende construir |
| 02.8 | Habilitar waitlist por serviço, com herança do nível de unidade (Bella Booking) | **HERDAR** | Já é exatamente o padrão de herança da Business Configuration & Policy Layer (Parte III §1.6) |
| 02.9 | Resource lock/hold com timeout, libera em falha de pagamento (padrão de engenharia) | **HERDAR** | Já pressuposto no domínio D07/Booking Candidate — confirmação técnica, sem mudança |
| 02.9a | Confirmação manual de pagamento offline — transferência bancária, link de pagamento, PIX manual (Wix Bookings "Manual Payments"; Salon Booking System, fluxo Pending → Payment Pending → Paid) | **REFORÇAR** *(pesquisa solicitada pelo Platform Owner)* | Wix exibe instruções de pagamento (ex.: dados bancários) e staff marca manualmente como pago — não entra automático. Salon Booking System muda status pra "Payment Pending" (isso É o gatilho do aviso ao cliente) antes de "Paid". Padrão claro: staff escolhe explicitamente notificar (mudar status → dispara aviso) ou marcar pago direto sem notificar — os dois caminhos existem no mercado. Vira regra nova para o cadastro de formas de pagamento (fiado/depósito/link) |
| 02.9b | **Pix Automático** — modalidade de pagamento recorrente do Banco Central (lançada jun/2025, obrigatória para instituições financeiras desde out/2025) | **REFORÇAR CRÍTICO** *(pesquisa solicitada pelo Platform Owner)* | Cliente autoriza uma vez no app do banco; débito automático nos vencimentos seguintes, sem repetir confirmação; limite de valor e periodicidade travado na autorização; cliente cancela quando quiser. Desenhado explicitamente para "mensalidades e assinaturas" — mapeia direto pro Subscription Engine (D18/planos). É o equivalente brasileiro nativo ao que Stripe Connect resolve com cartão — mas via Pix, o meio dominante no Brasil. Ausência de conferência manual antes de cada débito (diferente de boleto) é ponto de atenção, não motivo pra não adotar |
| 02.10 | Waitlist por janela de tempo específica (Booksy) | **BACKLOG** | Refinamento de UX bom (preferência de janela vs. "qualquer vaga"), não urgente |
| 02.11 | "Last Minute Discount" — desconto automático por proximidade (Booksy) | **REFORÇAR** | Validação direta do domínio Yield & Occupancy já existente no Master Briefing original |
| 02.12 | "Boost" — marketplace pay-per-performance (Booksy) | **BACKLOG** | Relevante para módulo 11 (Partner Benefits/Local Network), fora do escopo priorizado atual — entra na fila quando esse módulo for pesquisado |
| 02.13 | Risco de atribuição de "cliente novo" no Boost (Booksy) | **REFORÇAR** | Não é feature — reforça a necessidade da regra de origem rastreável/anti-cupom (D05) já existente, para quando módulo 11 for construído |

---

# Módulo 03 — Checkout & Payments

| # | Achado | Classificação | Justificativa |
|---:|---|---|---|
| 03.1 | Separate Charges and Transfers — split multi-parte (Stripe Connect) | **HERDAR** | Confirma a arquitetura do Tip Engine (DEC-02) já decidida — nomeia formalmente o padrão que o KortexOS já usa |
| 03.2 | Retenção de fundos até serviço entregue (Stripe Connect) | **HERDAR** | Confirma DEC-10/18 (comissão nasce no uso, não na venda) — validação direta de infraestrutura de pagamento |
| 03.3 | Estorno/chargeback puxado proporcionalmente de cada parte (Stripe Connect) | **HERDAR** | Confirma a lógica de reversão proporcional já usada no sistema |
| 03.4 | Orquestrador evita registro como money transmitter (Stripe Connect) | **BACKLOG** | Insight regulatório relevante só quando a integração de pagamento real acontecer (Fase 4 do roadmap, infraestrutura 24/7) |
| 03.5 | 1-Click Checkout — baixa fricção (Amazon) | **REFORÇAR** | Princípio geral válido para o checkout do KortexOS, mas ver 03.6 para o contraponto necessário |
| 03.6 | Recuo da própria Amazon para "Buy It Now" com confirmação | **HERDAR** | Confirma a regra já existente de motivo obrigatório em mutação financeira (T6) — fricção proposital em decisão de risco já é prática do KortexOS |
| 03.7 | Transparência de preço + indicador de progresso no checkout (Amazon) | **BACKLOG** | Boas práticas de UI, pertencem à etapa 10 (UI/UX Spec), não decisão de produto agora |
| 03.8 | Risco regulatório de fricção zero com menor (Epic Games/FTC) | **REFORÇAR** | Reforça a necessidade do consentimento explícito já coberto por DEC-14/19 — não é feature nova, é justificativa de mercado pra regra existente |

---

# Módulo 04 — Ledger / Wallet / Current Accounts

| # | Achado | Classificação | Justificativa |
|---:|---|---|---|
| 04.1 | Três princípios: double-entry, auditabilidade, imutabilidade (Modern Treasury) | **HERDAR** | Confirma a arquitetura do ledger já decidida (T6, DEC-03/11) sem necessidade de redesenho |
| 04.2 | Reversão como lançamento negativo explícito, original preservado (Modern Treasury) | **HERDAR** | Já é exatamente o modelo de reabertura por versão (DEC-03/11) |
| 04.3 | Chaves de idempotência obrigatórias (Modern Treasury) | **HERDAR** | Já é invariante do sistema em toda mutação financeira |
| 04.4 | Plano de contas de referência: user/treasury/fee/reserve/clearing (Modern Treasury) | **BACKLOG** | Insumo direto para a etapa 6 (Migration Map), não decisão de produto agora |
| 04.5 | Caso ClassPass — repasse no consumo real, não na venda (Modern Treasury) | **HERDAR** | Confirmação mais forte de toda a pesquisa: mesmo modelo de negócio (crédito consumido pontualmente), mesma solução (DEC-10/18) — validação independente completa |
| 04.6 | Concorrência/versionamento otimista para escala (Modern Treasury) | **BACKLOG** | Preocupação de escala futura, fora do horizonte atual do Salão Esperança |

---

# Módulo 05 — Compensation / Tips / Payout

| # | Achado | Classificação | Justificativa |
|---:|---|---|---|
| 05.1 | Repasse de gorjeta no mesmo dia via wallet/cartão próprio (Zenoti) | **BACKLOG** | Feature de liquidez para o staff, não urgente na fase atual — considerar quando o Staff Current Account amadurecer |
| 05.2 | Três opções de absorção de taxa sobre gorjeta (Zenoti) | **HERDAR** | Confirma DEC-01 pela SEGUNDA vez de forma independente (já validado por AppBarber) — dois players não relacionados, mesma estrutura |
| 05.3 | Config de taxa nunca retroativa (Zenoti) | **HERDAR** | Confirma T4 pela segunda vez nesta pesquisa (já visto em Boulevard) |
| 05.4 | "Redo commission" — comissão de segundo profissional que refaz serviço (Zenoti) | **BACKLOG** | Gap real identificado, cenário operacional genuíno, mas não urgente — não há regra hoje |
| 05.5 | Base de comissão varia por tipo de redenção — valor vs. preço de cartão pré-pago (Zenoti) | **BACKLOG** | Granularidade nova para o cadastro de formas de pagamento, não decisão urgente |
| 05.6 | Payroll nativo completo (slabs, tax filing, W-2/1099) (Zenoti) | **DESCARTAR** | Ambição de folha de pagamento completa não serve ao modelo Kortex nesta fase — regras trabalhistas brasileiras são outro domínio inteiro, fora do escopo do produto atual |

---

# Módulo 06 — No-show / Deposit / Card-on-file

| # | Achado | Classificação | Justificativa |
|---:|---|---|---|
| 06.1 | SetupIntent + `off_session` — mecanismo técnico de cartão em arquivo (Stripe) | **BACKLOG** | Blueprint técnico de referência para quando a integração de PSP real acontecer — não é decisão de produto agora |
| 06.2 | Consentimento explícito obrigatório para salvar cartão (Stripe) | **HERDAR** | Confirma DEC-14/19 pela TERCEIRA fonte independente (LGPD, CDC, e agora infraestrutura de pagamento) |
| 06.3 | Janela de autorização de hold limitada por rede (~5 dias) (Stripe) — **solução adotada: hold local/manual + retentativa automática ou lembrete próximo da data** | **REFORÇAR CRÍTICO — resolução definida pelo Platform Owner** | Restrição técnica real (não é feature opcional). Solução: para agendamento além da janela de hold do cartão, o KortexOS mantém a reserva via **hold LOCAL** (estado interno do sistema, não do PSP) e dispara **retentativa automática de autorização ou lembrete de pagamento** conforme a data se aproxima. Validado por referência cruzada fora dos Tiers formais: hotelaria (pré-autorização hoteleira) resolve exatamente o mesmo problema estrutural do mesmo jeito — solicita a pré-autorização apenas 7-15 dias antes da data, nunca no ato da reserva distante. Mesma lógica que aviação usa pra gestão de restrições (Tier 2) |
| 06.4 | Duas mecânicas distintas: "hold" (só guarda cartão) vs. depósito real (cobra na hora) (Vagaro) | **REFORÇAR** | KortexOS ainda não distingue essas duas mecânicas formalmente no cadastro — vira regra nova |
| 06.5 | Depósito configurado por serviço individual (Boulevard) | **HERDAR** | Já coberto como "políticas próprias" do serviço (Parte II §6) |
| 06.6 | Auto-checkout: cobra cartão em arquivo ao fim do serviço (Boulevard) | **REFORÇAR** | Elimina fila de pagamento no balcão — não coberto hoje, vira candidato a regra nova |
| 06.7 | Depósito aparece como Account Credit no perfil do cliente (Boulevard) | **HERDAR** | Confirma o client wallet já existente, sem mudança |
| 06.8 | Quatro estruturas de depósito + achado de conversão (fixo > percentual em ticket baixo) (mercado agregado) | **BACKLOG** | Granularidade de configuração e insight de UX, não urgente |
| 06.9 | Depósito não-reembolsável válido com disclosure claro (mercado agregado, US/Canadá) | **REFORÇAR** | Confirma o princípio universal por trás de DEC-14, fora do contexto brasileiro — mais uma fonte independente |
| 06.10 | Janela de cancelamento 24–72h conforme valor do serviço (mercado agregado) | **HERDAR** | Já coberto como política configurável (D02, cancelamento) |

---

## Itens BACKLOG consolidados (ordem sugerida, não vinculante)

```text
Alta relevância futura (considerar cedo):
- 01.9  Multi-recurso simultâneo (sala+equipamento+profissional)
- 05.4  Redo commission
- 06.1  SetupIntent/off_session (blueprint técnico de PSP)
- 06.4  Distinção hold vs. depósito real

Média relevância:
- 01.4  Relaxamento de trava financeira (mover com preço igual)
- 02.3  Waitlist exige cartão
- 02.10 Waitlist por janela de tempo
- 04.4  Chart of Accounts de referência
- 05.5  Base de comissão por tipo de redenção
- 06.6  Auto-checkout
- 06.8  Estruturas de depósito + insight de conversão

Baixa relevância / UI-UX Spec (etapa 10, não etapa 4):
- 01.6  Intervalo de exibição configurável
- 03.7  Transparência de preço/indicador de progresso

Fora do escopo priorizado (aguarda módulo correspondente):
- 02.12 Boost/marketplace (módulo 11)
- 03.4  Orquestrador de pagamento (Fase 4 infraestrutura)
- 04.6  Concorrência/versionamento (escala futura)
- 05.1  Repasse de gorjeta same-day (staff liquidity, futuro)
```

---

## Próximo passo executável

```text
1. Revisão do Platform Owner incorporada nesta versão: 01.10 corrigido,
   01.13/01.14/02.9a/02.9b adicionados com pesquisa própria, 06.3 resolvido
   com solução definida pelo Platform Owner. TODOS os demais 37 itens
   originais estão APROVADOS sem alteração.
2. Aprovação completa (42 itens) registrada como DEC-22 no Decision Log.
3. Master Briefing §22.1 atualiza etapa 4 para CONCLUÍDA.
4. Próxima etapa da sequência: 5, Truth Map — classificar realidade técnica
   atual do HOPE OS (REAL/PARCIAL/MOCKADO/HARDCODED) contra as decisões
   REFORÇAR/HERDAR aqui aprovadas. Os 4 itens CRÍTICOS (agendamento e
   cancelamento recorrente, Pix Automático, hold local+retentativa) entram
   com prioridade alta no Truth Map por serem lacunas reais, não refinamentos.
Nenhum item classificado aqui autoriza SQL, migration ou tela.
```
