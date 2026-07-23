# KORTEXOS™ — DECISION LOG

**Arquivo:** `KORTEXOS_5_1_2_DECISION_LOG.md`
**Produto:** KortexOS™
**Natureza:** registro histórico de decisões (padrão ADR — Architecture Decision Record). Append-only: decisões aprovadas NUNCA são editadas ou apagadas — apenas marcadas com status (Accepted / Superseded by DEC-XX / Refinada por DEC-XX). O registro superado permanece como prova de como o pensamento evoluiu.
**Companion doc:** `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` — a regra VIGENTE de cada decisão está especificada lá, sempre citando o(s) DEC(s)/D(s) que a fundamenta(m). Este arquivo é a prova/auditoria; o Master Briefing é a fonte de verdade operacional.
**Motivo da separação (2026-07-19):** o Master Briefing havia acumulado três tabelas RAGOV, duas tabelas de Veredito Red Team e uma tabela inteira ("Decisões pendentes") em que 8 de 9 itens já haviam sido decididos alhures — risco real de leitura desatualizada. Esta separação segue a prática consolidada de ADR (Microsoft, AWS, indústria): nunca apagar decisão superada, mas tirá-la do caminho de quem só precisa saber a regra atual.
**Como usar:** para saber a regra vigente de um tema, use o Master Briefing. Para entender POR QUE a regra é essa, ou o que ela substituiu, busque o ID (DEC-XX ou D-XX) aqui.

---

## Índice de status

| Prefixo | Escopo | Numeração |
|---|---|---|
| DEC-01 a DEC-19 | Decisões formais do Platform Owner, registradas em 2026-07-19, escopo: comanda, gorjeta, comissão, pacotes, planos, cadastros, configuração, dados sensíveis | Cronológica, imutável |
| DEC-20 a DEC-29 | Decisões de processo/auditoria da ordem de construção (§22.1): escopo e formato do benchmark, estratégia de benchmark por Tier, aprovação do Comparative Proposal, aprovação do Truth Map, aprovação do Migration Map, aprovação do adendo de cobertura D02, aprovação dos pontos cegos pré-Blueprint (Rodada 4), reconsideração da hierarquia Empresa→Unidade (Onda 0), finalização do escopo de unidade + itens operacionais consolidados, fechamento do ambiente de homologação (DEC-28c) | Cronológica, imutável |
| D-01 a D-09 | Decisões conceituais originais do anexo A1 (cadastros) — **todas as 9 resolvidas**, a última (D-07) por DEC-19 | Letrada, anterior às DEC |

---

# SEÇÃO 1 — REGISTRO DEC-01 A DEC-18 (Platform Owner, 2026-07-19)

Decisões tomadas em 2026-07-19, vinculantes a partir da aprovação deste anexo:

| # | Decisão | Conteúdo | Substitui |
|---:|---|---|---|
| DEC-01 | Absorção de taxa da gorjeta | Gorjeta segue o MESMO modelo de absorção de taxa da forma de pagamento (Bruto Salão / Dividido / Bruto Staff), conforme a forma usada. Realidade operacional do salão desde o primeiro dia | Revoga a recomendação D-02 do anexo A1 |
| DEC-02 | Split de gorjeta multi-profissional | Comanda fechada com diversos serviços, produtos e múltiplos profissionais: rateio dinâmico ponderado por valor do serviço e tempo de execução (seção 5) | Nova regra canônica |
| DEC-03 | Reabertura de comanda | Além do estorno, existe a modalidade "reabrir comanda": após fechar, ao perceber erro, reabrir, editar e refechar — com preservação total do ledger (seção 4) | Nova regra canônica |
| DEC-04 | Preço por nível de profissional | SIM, no produto final. Override triplo por profissional×serviço: preço, tempo e valor (comissão) (seção 6) | Revoga a recomendação D-01b do anexo A1 |
| DEC-05 | Escopo | Especificação para produto final, não MVP. Sequência de construção do 5.1.1 permanece vinculante | — |
| DEC-11 | Reabertura e edição plena de comanda | Realidade obrigatória (evidência: telas do AppBarber em produção no Salão Esperança). Comanda finalizada oferece "Reabrir" imediatamente, com edição plena de itens, valores, profissionais e pagamentos — dentro das travas financeiras da seção 4.3 | Corrige a leitura de benchmark da versão anterior deste anexo |
| DEC-12 | Modal de edição de item | Clicar em qualquer item da comanda abre modal com TODAS as alterações possíveis (seção 4.5): valor, quantidade, profissional, comissão, desconto, cortesia, benefício, exclusão — governadas por permissão e trilha, nunca silenciosas | Nova regra canônica |
| DEC-13 | Duas semânticas de valor editável | (a) No item: altera o VALOR COBRADO daquele item (reprecificação, afeta base de comissão). (b) Na tela da comanda: DIVERGÊNCIA entre valor devido e valor cobrado — a diferença vira crédito ou débito do cliente na wallet, sem tocar itens nem comissão (seção 4.5) | Substitui a regra anterior de rateio automático do total |
| DEC-14 | Breakage de pacote — sequência em 4 estágios, mecanismo e texto finalizados | **Aprovado em 2026-07-19, substitui DEC-07. Finalizado em 2026-07-19 (mecanismo + texto + regra de extensão).** (1) Compra exige aceite digital — clique simples + assinatura desenhada na tela, com registro de hash/timestamp — usando o texto canônico da seção 11.4 (Parte II); (2) uso normal dentro da validade contratada; (3) ao vencer, abre automaticamente janela de extensão: cadastro do pacote define motivos elegíveis (subconjunto de saúde / férias / outro) e prazo MÁXIMO permitido (7, 14, 21 ou 28 dias); no momento da concessão, pessoa autorizada seleciona motivo e prazo dentro desse limite, registrando autor e data (T6); saldo remanescente vira crédito de wallet visível ao cliente durante a extensão, com aviso ativo; (4) só ao fim da extensão sem uso, aplica-se breakage puro (reconhecimento de receita, encerra o passivo). Reembolso por desistência ANTECIPADA (dentro da validade) é regra distinta e configurável por pacote: `valor pago − (sessões consumidas × preço avulso da época)`, nunca negativo; forma de devolução (dinheiro/wallet/percentual) configurável. **Segue com VENDA BLOQUEADA até validação jurídica** do mecanismo de aceite (clique + assinatura na tela) para o valor/perfil de contrato do Salão Esperança | Aceito pelo Platform Owner. Combina opções B+A como estágio intermediário, C como estágio final; adiciona reembolso configurável, aceite automatizado e regra de extensão por motivo+prazo enumerado |
| DEC-15 | Comissão pela venda (nova categoria, distinta da comissão de uso) | **Aprovado em 2026-07-19. Condição de clawback REFINADA por DEC-18 em 2026-07-19 — ver abaixo.** Escopo imediato: PACOTES. Cria uma segunda comissão, independente da comissão de execução/uso já existente (DEC-10, Gate 14): a **comissão de venda** remunera quem processou a venda do pacote (o "vendedor"), que pode ou não ser quem executa as sessões. Regras: (a) campo próprio no cadastro do pacote — % ou valor fixo, com vigência; (b) reconhece no momento do pagamento da venda (consistente com a tese "comissão nasce de venda real", seção 8.1/8.3), NÃO no consumo de sessões; (c) reversão governada por DEC-18 (não mais proporcional a qualquer reembolso — ver DEC-18); (d) independente da comissão de execução: as duas coexistem sem se reduzirem mutuamente; mesma pessoa pode receber ambas se vender e executar. **Escopo futuro, registrado e NÃO implementado agora:** estender comissão de venda a PLANOS DE ASSINATURA — pendente porque plano tem cobrança recorrente (múltiplos "momentos de venda": adesão + cada renovação), o que exige decidir se a comissão de venda se aplica só na adesão, em toda renovação, ou com degrau — decisão explicitamente adiada. **A condição de clawback (item c) já está pré-decidida por DEC-18 e vale desde já para quando essa extensão for implementada** | Nova regra canônica; fecha o ponto cego identificado no benchmark AppBarber (seção 8.2) |
| DEC-16 | Gorjeta e desconto — duas modalidades obrigatórias ($ ou %) | **Aprovado em 2026-07-19.** Todo campo que captura gorjeta ou desconto — no item (modal, seção 4.5), no combo (modo de preço, seção 9.2), no checkout (chips +desconto/+gorjeta, seção 8.4) e em qualquer outra superfície futura — oferece duas modalidades de entrada, nunca uma só: **valor fixo (R$)** ou **percentual (%)**. Quem lança escolhe a modalidade; o backend resolve e persiste sempre o valor absoluto (`_cents`) aplicado — a modalidade é UX de entrada, nunca ambiguidade armazenada (consistente com T9, frontend não deriva regra). Percentual de desconto/gorjeta calcula sobre a base resolvida do item ou da comanda, conforme o nível em que foi lançado | Nova regra transversal; corrige campos que hoje descrevem só uma modalidade (combo, item) |
| DEC-17 | Multa de desistência de plano de assinatura | **Aprovado em 2026-07-19. SUPERADA por DEC-18 em 2026-07-19** — o percentual de multa autônomo é removido; o problema que a multa tentava resolver (custos reais já incorridos) passa a ser resolvido pela fórmula unificada de reembolso (parte não utilizada) combinada com a regra de clawback condicionado a uso zero. Mantida aqui apenas como histórico da formulação original | Substituída por regra unificada (DEC-18) a pedido do Platform Owner |
| DEC-18 | Regra unificada de reembolso e comissão de venda — planos e pacotes | **Aprovado em 2026-07-19. Unifica e substitui a lógica de reembolso de DEC-15 (clawback proporcional) e DEC-17 (multa percentual).** Quatro princípios, válidos igualmente para planos e pacotes: **(1)** Comissão de EXECUÇÃO/USO, uma vez que a sessão/benefício foi efetivamente realizado, é definitiva e NUNCA entra em cálculo de devolução — está protegida por construção, porque a base de reembolso é sempre "parte não utilizada", nunca o total pago. **(2)** Fórmula de reembolso única: `valor pago − (valor da parte já utilizada, pelo preço avulso/preço de referência vigente à época)`, nunca negativo — mesma fórmula de pacotes (11.3), agora também para planos, reaproveitando o campo "preço de referência de consumo por item" que planos já possuem (seção 10.2) como base de cálculo. **(3)** Comissão de VENDA: clawback (reversão total) SE E SOMENTE SE o cliente não utilizou NENHUMA sessão/benefício do plano ou pacote; havendo qualquer uso, a comissão de venda é definitiva e não é revertida — mesmo que o restante não utilizado seja reembolsado. **(4)** Direito de arrependimento (art. 49 CDC): aplica-se somente quando a venda ocorreu FORA do estabelecimento comercial (online, app, telefone, KortexLink) — não cobre, pela leitura corrente da lei, venda presencial na comanda do salão. Dentro dos 7 dias corridos a contar da assinatura/aceite ou do recebimento, e sem qualquer uso, o reembolso é integral e imediato, sem dedução de qualquer custo — mandato legal, não política de negócio; nesse cenário o clawback total do item (3) também se aplica, pois uso=0. Fora desse prazo, ou em venda presencial, vale a política contratual dos itens (1)-(3), ainda sujeita a validação jurídica (ver ressalva) | Aceito pelo Platform Owner: "a comissão que já foi paga por serviço devidamente realizado não deve entrar na devolução"; modelo de pacotes migra para a fórmula de planos (parte não utilizada); clawback restrito a uso zero |
| DEC-19 | Resolução de D-07 — base legal de dados sensíveis do cliente | **Aprovado em 2026-07-19.** Fecha a última decisão conceitual em aberto do anexo A1. Base legal única: consentimento específico e destacado (LGPD art. 11, I) — verificado que não há alternativa viável, pois não existe "legítimo interesse" para dado sensível (art. 7º, IX, exclusivo de dado comum) e a exceção de "tutela da saúde" (art. 11, II, f) vale só para profissional/serviço/autoridade de saúde, o que exclui salão de beleza e barbearia. Módulo isolado especificado (Parte II §13, domínio D26): consentimento separado de qualquer outro aceite, com finalidade própria e destacada; dado sensível estruturado por serviço (não ficha médica ampla — minimização); visibilidade restrita a quem executa o atendimento + dono/gerente; EXCEÇÃO à regra T3 (arquivar sempre) — dado sensível tem prazo de retenção definido e é deletado/anonimizado de fato ao expirar ou por revogação, não arquivado para sempre; cliente pode consultar/excluir a qualquer momento (LGPD art. 18). **Texto exato do consentimento e prazo de retenção seguem como VALIDAÇÃO JURÍDICA PENDENTE** — mesma ressalva já aplicada a DEC-14/DEC-18; a base legal em si (art. 11, I) está fundamentada no texto da lei, a redação final não | Resolve D-07 (Seção 2 abaixo), que era a única das 9 decisões originais do anexo A1 ainda sem resposta |
| DEC-20 | Escopo e formato do Global Benchmark Map formal (etapa 3) | **Aprovado em 2026-07-19.** Dos 16 módulos obrigatórios do §23.2, priorizar os 6 que já estão em construção ativa (HOPE OS): 01 Booking & Capacity Scheduling, 02 Smart Gap/Waitlist/Resource Locks, 03 Checkout & Payments, 04 Ledger/Wallet/Current Accounts, 05 Compensation/Tips/Payout, 06 No-show/Deposit/Card-on-file. Os outros 10 módulos (07 a 16) entram na fila quando o subsistema correspondente virar prioridade real — não pesquisados agora, para não violar "básico antes do sofisticado" pesquisando Marketplace/White-label ou Experimentation/Incrementality antes de existir ledger. **Formato de execução:** iterativo — 2 a 3 módulos por rodada, dentro de conversas de chat, com matriz módulo × concorrente × achado × fonte apresentada a cada rodada para validação do Platform Owner antes de avançar (não via Research automatizado de uma vez). Primeira rodada: módulos 01 e 02 | Rejeitada a Opção A (benchmark completo dos 16 módulos de uma vez) e a Opção C (via função Research); escolhida Opção B (escopo) executada no formato D (iterativo) |
| DEC-21 | Estratégia canônica de benchmark: organização por domínio de excelência (Tier), não por concorrente | **Aprovado em 2026-07-19, redigido pelo Platform Owner.** Reformula a metodologia do Global Benchmark Map: nenhuma plataforma é modelo integral a reproduzir — cada referência vale para um domínio de excelência específico. Três tiers: **Tier 1 — Beauty Tech** (Booksy, Zenoti, Boulevard, Trinks, CashBarber, AppBarber, cada um com domínio de excelência declarado). **Tier 2 — Cross-Industry** (Uber, Aviação Comercial, Amazon, Apple, Disney — ainda não pesquisado, entra por módulo quando relevante). **Tier 3 — Domínios Técnicos/Verticais** (Fintech/ledger, Scheduling/yield acadêmico, Corporate wellness, Causal decisioning, Lifecycle automation, Messaging/AI — preserva as categorias do §23.1 original, que os Tiers 1/2 não cobrem). Mais **Referência Metodológica Permanente**: Toyota Production System (Lean/Kaizen) — framework de validação contínua, não benchmark competitivo. **Ressalvas de calibração adicionadas por Claude, aprovadas por decorrência da aprovação geral:** Trinks (parcialmente anti-padrão — edição retroativa de fechamento, já rejeitada), AppBarber (white-label BLOQUEADO no estágio atual — referência diferida, não imediata), CashBarber (lacuna de comissão de assinatura é o que o KortexOS™ supera, não copia), Booksy (conceito de marketplace pay-per-performance válido; mecanismo de atribuição do Boost tem risco documentado — não copiar sem regra de origem rastreável). §23.1 do Master Briefing passa a apontar para esta estratégia em vez de manter lista de referências duplicada | Substitui a lista de referências simples do §23.1 original; localização física: `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md`, seção "Estratégia Canônica de Benchmark" |
| DEC-22 | Comparative Proposal (etapa 4) aprovada — 42 achados classificados | **Aprovado em 2026-07-19.** Classifica os achados do Global Benchmark Map (módulos 01-06) em HERDAR/RENOMEAR/REFORÇAR/BACKLOG/BLOQUEAR/DESCARTAR (§23.3). Distribuição final: 15 HERDAR, 16 REFORÇAR, 10 BACKLOG, 1 DESCARTAR, 0 RENOMEAR, 0 BLOQUEAR. **Correções e adições do Platform Owner sobre a proposta original de Claude:** (1) 01.10 corrigido de DESCARTAR para REFORÇAR — agendamento por turma/grupo é válido para eventos reais (padrinhos, noivas), não modelo de turma fitness; (2) NOVO 01.13 — Agendamento recorrente (REFORÇAR CRÍTICO), gap real não coberto por nenhum domínio, validado por Vagaro e Boulevard; (3) NOVO 01.14 — Cancelamento recorrente, ocorrência vs. série inteira (REFORÇAR CRÍTICO), mesma dupla fonte; (4) NOVO 02.9a — Confirmação manual de pagamento offline, com/sem aviso ao cliente (REFORÇAR), validado por Wix Bookings e Salon Booking System; (5) NOVO 02.9b — **Pix Automático** do Banco Central, lançado jun/2025, obrigatório desde out/2025 (REFORÇAR CRÍTICO) — mapeia direto para o Subscription Engine (D18); (6) 06.3 resolvido — solução definida pelo Platform Owner: hold local/manual + retentativa automática ou lembrete próximo da data, validada por referência cruzada com pré-autorização hoteleira. Os outros 37 itens da proposta original de Claude foram aprovados sem alteração | Fecha a etapa 4 da ordem de construção (§22.1); registro completo em `KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md`. Os 4 itens CRÍTICOS entram com prioridade alta na etapa 5 (Truth Map) |
| DEC-23 | Truth Map (etapa 5) aprovado — classificação de realidade técnica dos módulos 01–06 | **Aprovado pelo Platform Owner em 2026-07-20.** Auditoria de código real (não documental) contra o Master Briefing 5.1.2, escopo módulos 01–06 (DEC-20), com prioridade aos 4 itens REFORÇAR CRÍTICO de DEC-22. Achado: a fundação MVP (tenant/JWT/RLS em 17 tabelas, `create_appointment`/`update_appointment` idempotentes com concorrência otimista, `checkout_close` atômico, comissão em cascata profissional>serviço>grupo, PWA modular com sync incremental) é `REAL` e é a base a preservar, não a redesenhar. Confirmada `AUSENTE` por completo: Availability Resolver/Smart Gap/recursos físicos com lock/waitlist (D07/D11); agendamento e cancelamento recorrente (D09 — os 2 itens REFORÇAR CRÍTICO 01.13/01.14 de DEC-22); borda real de pagamento — PSP/Pix Automático/card-on-file/hold de depósito (D13 — os 2 itens REFORÇAR CRÍTICO 02.9b/06.3 de DEC-22, enum de forma de pagamento hoje é só rótulo local sem integração); KortexFlow — ledger double-entry append-only/wallet/staff current account/payout (D15/D16, hoje só existe `cash_entries` como caixa operacional). Também achado, fora do escopo dos 6 módulos: release não gateado pela CI (`deploy-pages.yml` publica independente de teste/lint) e configuração da segunda superfície de deploy (Render `kortex-pwa`) incompatível com `base` fixo do Vite e sem CORS liberado. **Veredito registrado: NO-GO para promoção direta ao produto final; GO apenas para iniciar a etapa 6 (Migration Map), começando pelos blocos 1–3 da ordem única de correção do Truth Map (fundação/release → borda de pagamento → KortexFlow mínimo)** | Fecha a etapa 5 da ordem de construção (§22.1) — muda o status de "Truth Map 5.1.1 — PENDENTE" para CONCLUÍDO; registro completo em `KORTEXOS_5_1_2_TRUTH_MAP.md` (v1.0). Desbloqueia o início da etapa 6 (Migration Map), que segue BLOQUEADA para SQL/schema até o Blueprint (etapa 7) ser aprovado (§22.2) |
| DEC-24 | Migration Map (etapa 6) aprovado — domínios, objetos e dependências mapeados | **Aprovado pelo Platform Owner em 2026-07-20.** Mapeia, para cada lacuna `CRÍTICO`/`AUSENTE` do Truth Map (DEC-23), domínio dono (D00–D31), nome de objeto proposto, estende/novo, dependência e impacto de promoção — sem SQL, sem coluna, sem tipo. 6 ondas de dependência: (1) Payment Core — `payment_intents`, `psp_webhook_events`, `card_on_file_tokens`, `deposit_holds`, `pix_automatico_mandates` (D13); (2) KortexFlow Ledger + Wallet — `kortex_accounts`, `kortex_ledger_transactions`, `kortex_ledger_entries`, `kortex_account_balances`, `client_wallets`, `staff_current_accounts`, `benefit_obligations`, `payout_batches` (D15/D16); (3) Compensation & Payout — `private.resolve_commission()` permanece intocada, `private.resolve_sale_commission()` + `commission_sale_records` novos e independentes (D17); (4) Calendar Policy + Availability/Resource — `calendar_policies`, `professional_shifts` (D02, achado suplementar fora do escopo original do Truth Map), `resources`, `resource_locks`, Availability Resolver sem cache na v1 (D07/D11); (5) Recurring/Group/Waitlist — `appointment_series` (estende `appointments`), `appointment_participants`, `waitlist_entries` (D09/D10/D07-D08); (6) versionamento de comanda — objeto de revisão de venda, altera fluxo de `checkout_close`/`order_refund`, só depois do ledger existir (D12/D15). **4 decisões de alto impacto resolvidas nesta aprovação:** (1) `payments` (MVP) e `payment_intents` (novo) coexistem permanentemente — captura via PSP gera linha em `payments`, nunca a substitui; (2) `resolve_commission()` (execução) fica intocada por ser `security definer` chamada 2× dentro da transação atômica de `checkout_close` e coberta por testes pgTAP existentes — comissão de venda (DEC-15) ganha função e tabela próprias; (3) sem cache de disponibilidade na v1 — Availability Resolver calcula on-demand, cache revisitado só se o Gate 03 mostrar necessidade com dado real; (4) schema de Payment Core e KortexFlow pode ser criado em paralelo, mas ativação de captura real de pagamento fica gateada até o ledger existir e o Gate 11 (Ledger Balance) passar — evita "saldo paralelo" (§20.6 do Master). **Achado suplementar registrado, não resolvido:** D02 (Calendar Policy & Availability Layer) não tem nenhuma tabela no schema MVP hoje e não fazia parte do escopo original do Truth Map (só módulos 01–06); recomenda-se auditoria dedicada, com o mesmo rigor de evidência, antes do Blueprint tratar Availability como pronta para desenho técnico | Fecha a etapa 6 da ordem de construção (§22.1); registro completo em `KORTEXOS_5_1_2_MIGRATION_MAP.md` (v1.0). Desbloqueia o início da etapa 7 (Blueprint), que segue exigindo aprovação própria antes do SQL Master (etapa 8, §22.2) |
| DEC-25 | Adendo do Truth Map aprovado — cobertura de D02 (Calendar Policy & Availability Layer) | **Aprovado pelo Platform Owner em 2026-07-20.** Fecha a lacuna de cobertura identificada pelo Migration Map (DEC-24, achado suplementar): D02 Calendar Policy & Availability Layer (Master Parte III §2) não fazia parte do escopo original do Truth Map (só módulos 01–06, DEC-20). Auditoria complementar confirmou `CRÍTICO`/`AUSENTE` em toda a extensão do domínio, com evidência de código: `organizations` (`supabase/migrations/20260712235319_mvp_baseline.sql:11-18`) e `professionals` (mesmo arquivo, linhas 125-136) não têm nenhuma coluna de horário, turno, timezone ou `settings`; nenhuma tabela de feriado, abertura/fechamento excepcional, folga ou bloqueio pontual existe em nenhuma das 12 migrations; `validateDateTime` (`backend/src/modules/appointments/appointments.validation.js:26-35`) só valida formato ISO 8601, sem checar expediente — confirmado que hoje é tecnicamente possível agendar em qualquer horário/dia, a única proteção real sendo o exclusion constraint GiST que impede sobreposição do mesmo profissional. Não altera o veredito geral do Truth Map (`NO-GO`, DEC-23) nem reabre DEC-23/DEC-24 — é cobertura complementar, não correção | Fecha a lacuna de cobertura de D02 antes do início da etapa 7 (Blueprint); registro completo em `KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md` (v1.0). Confirma e eleva a prioridade da Onda 4 do Migration Map (`calendar_policies`, `professional_shifts`), sem criar onda nova |
| DEC-26 | Pontos Cegos Pré-Blueprint (Rodada 4) aprovados — 7 resoluções + 1 item de backlog | **Aprovado pelo Platform Owner em 2026-07-20.** Fecha a rodada de aprofundamento de camadas pedida explicitamente ("nova rodada de benchmark, levantamento de profundidade das camadas, procurar pontos cegos") — 4 frentes de pesquisa externa com fonte real (RODADA 4, `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md`) mais 1 achado estrutural interno. Resoluções: **(1) Hierarquia Empresa→Unidade (D01/D02/D28) — SUPERADA por DEC-27 em 2026-07-20** — confirmava o padrão Vagaro/Trinks como decisão consciente de escopo: `organizations` continuaria sendo o de-facto "unidade" enquanto o negócio for single-location (Salão Esperança); `units` como tabela própria só entraria quando D28 virasse prioridade real. Preservada aqui apenas como histórico da primeira decisão — o Platform Owner reconsiderou no mesmo dia e optou pelo padrão Zenoti/Mindbody (unidade como entidade própria desde já); ver DEC-27. **(2) Precedência de exceção de calendário simplificada** — "abertura excepcional" e "fechamento excepcional" (§2.3 do Master) deixam de ser dois níveis hierárquicos fixos; Blueprint implementa como um único objeto "exceção pontual" com campo de tipo (aberto/fechado/horário customizado), resolvido por recência de edição dentro do mesmo nível — mesmo resultado de negócio, mecanismo já provado em produção (padrão Dynamics 365 Field Service). **(3) Turno permite múltiplos blocos por dia** — `professional_shifts` (Onda 4, Migration Map) confirmado para suportar múltiplos registros por profissional/dia (horário partido/pausa) desde o desenho inicial, não um único par início/fim. **(4) Action Request com dois modos** — mantido o desenho assíncrono do Master como fundação (validado por precedente real em produção, Fineract/Mifos X), mas explicitamente também suporta colapso síncrono (draft→approved numa interação só, motivo obrigatório) quando o aprovador está presente e tem a permissão; ciclo assíncrono completo reservado para quando não há aprovador presente. **(5) Client Reliability Score — variável de antecedência** — "antecedência do agendamento no momento da marcação" (lead time) adicionada como 13ª variável considerada pelo score (§11.3 do Master), preditor forte de no-show na literatura, ausente da lista original. **(6) Client Reliability Score — eventos que pulam degrau** — evento classificado `CRÍTICO` (chargeback confirmado, fraude comprovada) pode saltar diretamente ao degrau máximo da régua progressiva, independente da contagem de ocorrências prévias. **(7) Client Reliability Score — escopo confirmado por organização** — sem compartilhamento cross-tenant, consistente com a postura de privacidade de DEC-19/D26; registrado como decisão consciente, não omissão. **Item de backlog aprovado, não urgente:** D00 Platform Owner Layer entra na fila nomeada de domínios futuros do Migration Map — nunca auditado até agora, zero módulo no código; acesso direto a banco/infra continua viável enquanto o KortexOS operar single-tenant real | Fecha a rodada de aprofundamento pré-Blueprint; registro completo em `KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md` (v1.0) e `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md` (RODADA 4). Não reabre DEC-23/24/25. Item (1) confirma a Onda 4 do Migration Map (DEC-24) sem alterar suas linhas; itens (2)-(7) são refinamento/adição de detalhe para o Blueprint (etapa 7), que segue desbloqueado e passa a incorporar este material |
| DEC-27 | Migration Map — Onda 0 adicionada: `units` como entidade própria (D01), supera DEC-26 item (1) | **Aprovado pelo Platform Owner em 2026-07-20.** Reconsidera a decisão de escopo de DEC-26 item (1): em vez de tratar `organizations` como unidade de-facto (padrão Vagaro/Trinks), o KortexOS adota o padrão Zenoti/Mindbody — `units` vira entidade própria desde a Onda 4 do Migration Map, mesmo com o negócio hoje sendo single-location (Salão Esperança). Motivação: opção mais correta a longo prazo, evita retrofit doloroso depois que múltiplas tabelas já dependerem de `organization_id` como se fosse unidade. D01 (Identity & Tenant) já é `REAL` no Truth Map (DEC-23) — isso é extensão da fundação existente, não domínio novo do zero. Nova **Onda 0** no Migration Map, antes da Onda 1: `units` (novo, depende de `organizations`); vínculo profissional↔unidade (cardinalidade N:1 ou N:N não decidida — Blueprint resolve, o benchmark da Rodada 4 mostra os dois padrões em uso no mercado); escopo de `memberships` por unidade (aberto — nem o Master nem o benchmark resolveram isso publicamente para nenhum player). Onda 4 atualizada: `calendar_policies`/`professional_shifts` passam a depender de `units`, não mais de `organizations` diretamente — timezone e horário são propriedade da unidade (Master §2.4), agora modelado no nível certo desde o início. **Explicitamente NÃO decidido nesta DEC:** se as outras 5 ondas do Migration Map (Payment Core, KortexFlow, Compensation, Recurring/Group/Waitlist, versionamento de comanda) e as 19 tabelas MVP existentes (clients, professionals, services, appointments, orders etc.) também passam a escopar por `unit_id` — cada uma exige decisão própria no Blueprint; nenhuma mudou de dependência nesta DEC. Risco marcado `Alto`: é retrofit da fundação de tenant (D01), toca RLS e todo FK chain em produção — não é capability isolada como as demais ondas | Reabre e supera especificamente o item (1) de DEC-26 (não reabre os itens 2-7, o backlog D00, nem DEC-23/24/25). Atualiza `KORTEXOS_5_1_2_MIGRATION_MAP.md` para v1.1 (nova Onda 0 + Onda 4 revisada). Blueprint (etapa 7) segue desbloqueado, ainda não iniciado |
| DEC-28 | Decisões consolidadas: escopo de unidade finalizado (Migration Map v1.2), release/deploy, verificação operacional, higiene de repositório | **Aprovado pelo Platform Owner em 2026-07-20**, em resposta a um levantamento de todos os itens deixados explicitamente em aberto após DEC-27. **Escopo de unidade (finaliza a Onda 0 e classifica todas as demais ondas + 19 tabelas MVP existentes):** vínculo profissional↔unidade é **N:N** (`professional_units`, tabela de vínculo — não `unit_id` direto em `professionals`); `memberships` ganha **escopo híbrido** (`unit_id` nullable — papéis estruturais dono/gerente ficam org-wide com `unit_id` nulo; papéis operacionais profissional/recepção ficam por unidade); todas as Ondas 1-3/5-6 e as 19 tabelas MVP existentes classificadas em 3 categorias — **org-wide** (identidade/saldo da pessoa: `clients`, `professionals`, `client_wallets`, `staff_current_accounts`, `benefit_obligations`, `card_on_file_tokens`, `pix_automatico_mandates`, `staff_levels`), **catálogo/config com herança e override padrão Zenoti** (`services`, `products`, `service_groups`, `packages`, `professional_service_*`), ou **transacional com `unit_id` direto** (`appointments`, `orders`, `payments`, e todos os objetos novos de ledger/checkout/agenda/waitlist). Risco registrado para o Blueprint: wallets/contas correntes org-wide alimentados por lançamentos de ledger unit-scoped exigem reconstrução (Gate 13) que some múltiplas unidades. Detalhe completo em `KORTEXOS_5_1_2_MIGRATION_MAP.md` v1.2. **Release/deploy:** (a) corrigir o conflito `base` do Vite × domínio Render e completar `CORS_ORIGINS` — mantém as duas superfícies de deploy (GitHub Pages + Render) funcionando; (b) deploy do Pages passa a depender do sucesso da CI (hard gate); (c) criar ambiente de homologação via segundo projeto Supabase + Render gratuitos — **fechado por DEC-29 em 2026-07-22**. **Verificação operacional:** (d) confirmar paridade da migration Fase 11 em produção; (e) reexecução integral das 3 suítes de teste adiada para o início do Blueprint (baseline), não executada agora. **Higiene de repositório:** (f) remover a worktree `claude/gracious-northcutt-61f4e4` (conteúdo já mesclado em `main` via PRs #9/#10, confirmado seguro); (g) commitar o diff de `OrganizationContext.jsx`/`OrganizationContext.test.jsx` (trabalho do usuário, confirmado pronto). **Validação jurídica (DEC-14/18/19):** confirmado — o Blueprint desenha o schema normalmente em paralelo à validação jurídica; só a ativação comercial (venda de pacote/plano, coleta de dado sensível) continua bloqueada até o parecer sair, sem mudança da regra já registrada em DEC-14/18/19 | Não reabre DEC-23/24/25/26/27 — finaliza o que DEC-27 deixou explicitamente pendente e resolve itens operacionais independentes. Atualiza `KORTEXOS_5_1_2_MIGRATION_MAP.md` para v1.2. Execução das decisões (a)/(b)/(d)/(f)/(g) prossegue na mesma sessão (commits e mudanças de arquivo próprios, não novas DEC); (c) exigiu passos manuais do Platform Owner no painel do Render/Supabase, concluídos e fechados por DEC-29. Blueprint (etapa 7) segue desbloqueado, ainda não iniciado |
| DEC-29 | Ambiente de homologação (staging) criado e validado — fecha DEC-28(c) | **Concluído em 2026-07-22.** Modelo de 2 branches (`main` produção, `staging` homologação — sem `develop`). Segundo projeto Supabase gratuito (`kortex-os-v2-staging`, ref `hyzoocmmtmjlgdyifwhu`) com as 12 migrations aplicadas e verificadas por chamada própria (`list_migrations`/`list_tables`/`get_advisors`, não por relato de subagente — ver incidente de fabricação de relatório registrado em `kortex-supabase-guard`, seção 6). Dois serviços novos no Render (`kortex-api-staging`, `kortex-pwa-staging`), blocos aditivos em `render.yaml`, branch de deploy `staging`. CI (`ci.yml`) ampliada para rodar também em `staging`. Achado durante a validação: o primeiro deploy do `kortex-api-staging` falhou (`Exited with status 1`) por faltar `SITE_URL` — variável exigida em runtime por `backend/src/config/env.js` (redirect do convite de equipe por e-mail, ADR 0014) que também faltava no bloco de produção do `render.yaml` (produção só funciona porque o valor foi configurado manualmente no painel do Render, fora do que o arquivo documenta); corrigido nos dois blocos. Validação final direta (não por confiança): bundle JS publicado do `kortex-pwa-staging` inspecionado por download+grep, confirmando referência exclusiva ao Supabase de staging (zero ocorrência do ref de produção) e `VITE_API_BASE_URL` apontando para `kortex-api-staging.onrender.com`. Proteção de branch aplicada via `gh api`: `main` exige PR, 0 aprovações mínimas mas `enforce_admins: true` (sem exceção nem para o dono), sem force-push/delete; `staging` só exige CI verde (`strict: true`), sem PR obrigatória. Nova skill `.agents/skills/kortex-environment-guardian/SKILL.md` referenciada em `AGENTS.md` (seção "Processo MAS") como gate de toda promoção entre branches, encadeando `kortex-delivery-guardian` como checklist final pré-merge em `main` | Fecha definitivamente o item (c) de DEC-28. Não reabre DEC-20 a DEC-28. Atualiza `docs/PROJECT_STATE.md` (remove Gap #4) e `docs/KORTEXOS_5_1_2_TRUTH_MAP.md` (ponto cego "ambiente de homologação inexistente" deixa de ser verdade) |

Pendências do A1 resolvidas por benchmark (justificativas na seção 8):

| # | Pendência | Resolução canônica |
|---:|---|---|
| DEC-06 | Ordem de consumo no split de pagamento | benefício → wallet → forma externa. Prática de mercado: créditos de membership aplicam automaticamente antes do pagamento |
| DEC-07 | Breakage de pacote expirado | **SUPERADA por DEC-14** (seção 0) — mantida aqui apenas como histórico da primeira formulação |
| DEC-08 | Overuse de plano | Configurável por plano: excedente a preço de membro (retenção) ou avulso (proteção de margem). Default do sistema: preço avulso; o plano declara explicitamente se oferece preço de membro |
| DEC-09 | Rateio de desconto (combo/pacote) | Confirmado: proporcional ao preço base de cada item, regra única. Comissão e reconhecimento calculam sobre o valor rateado |
| DEC-10 | Preço de referência de consumo de plano | Confirmado obrigatório por item do plano. Sem ele, Gate 14 é incalculável |

---


---

# SEÇÃO 2 — REGISTRO D-01 A D-09 (anexo A1, decisões conceituais originais)

**Status geral:** das 9 decisões originais, todas foram resolvidas ou substituídas por DEC-01 a DEC-19. D-07, a última em aberto, foi resolvida por DEC-19 em 2026-07-19.

| # | Decisão | Recomendação | Risco de adiar |
|---:|---|---|---|
| D-01a | Duração própria por profissional no MVP | SIM | Agenda mente sobre capacidade real |
| D-01b | Preço por nível de profissional no MVP | NÃO (adiar) | Sofisticação prematura; complica comissão |
| D-02 | Taxa da gorjeta em cartão | Salão absorve; custo visível no ledger | Tip isolation vira mentira contábil |
| D-03 | Ordem de consumo no split | benefício → wallet → forma externa | Checkout ambíguo; disputa com cliente |
| D-04 | Rateio de desconto (combo/pacote) | Proporcional ao preço base, regra única | Comissão ambígua → conflito com staff |
| D-05 | Preço de referência de consumo de plano | Obrigatório por item do plano | Gate 14 incalculável; comissão vira briga |
| D-06 | Breakage de pacote expirado | Reconhece receita na expiração, por regra | Passivo eterno ou receita fantasma |
| D-07 | Anamnese/dados sensíveis | Adiar para D26 com base legal | Risco LGPD se entrar no cadastro base |
| D-08 | Overuse de plano | Excedente paga avulso (default) | Plano canibaliza receita cheia |
| D-09 | Comissão de add-on | Própria e explícita, não herdada | Comissão implícita gera erro silencioso |

---


### Reconciliação D → DEC

| D-XX | Status atual | Resolvido/substituído por |
|---|---|---|
| D-01a | CONFIRMADO | Duração própria por profissional: SIM (consistente com DEC-04) |
| D-01b | SUPERADA | DEC-04 reverteu a recomendação — preço por nível é produto final, não adiado |
| D-02 | SUPERADA | DEC-01 (absorção de taxa da gorjeta segue o modelo da forma de pagamento) |
| D-03 | SUPERADA | DEC-06 (ordem de consumo: benefício → wallet → forma externa) |
| D-04 | CONFIRMADA | DEC-09 confirma rateio proporcional como regra única |
| D-05 | CONFIRMADA | Preço de referência de consumo por item — mantido obrigatório; base reaproveitada por DEC-18 para reembolso |
| D-06 | SUPERADA (duas vezes) | DEC-14 primeiro, depois DEC-18 unificou com a regra de planos |
| **D-07** | **RESOLVIDA** | DEC-19 (2026-07-19) — base legal art. 11,I; módulo isolado em Parte II §13/D26 |
| D-08 | SUPERADA | DEC-18 unificou overuse/desistência na fórmula única de reembolso |
| D-09 | CONFIRMADA | Comissão de add-on própria e explícita, sem alterações |

---

# SEÇÃO 3 — DELTAS DE CADASTRO (anexo A1 → 5.1.1, histórico)

O corpo de cadastros do anexo A1 (formas/tipos de pagamento, clientes, staff, serviços, produtos, complementos, combos, planos, pacotes) permanece válido com os seguintes deltas vinculantes:

| # | Delta | Efeito |
|---:|---|---|
| 1 | DEC-04 substitui D-01b | Preço/tempo/comissão por nível e por profissional entram no produto final. A matriz staff × serviço ganha os três eixos de override |
| 2 | DEC-01 substitui D-02 | Campo "aceita gorjeta" da forma de pagamento passa a referenciar o modelo de absorção da própria forma |
| 3 | DEC-03 adiciona estados | Cadastro/ciclo da comanda ganha `reaberta` e `refechada`; travas da seção 4.3 |
| 4 | DEC-06 fecha D-03 | Ordem de consumo no split: benefício → wallet → forma externa |
| 5 | DEC-14 fecha D-06 (substitui DEC-07) | Pacote exige validade + sequência de 4 estágios (aceite digital → uso → extensão → breakage) + política de reembolso por desistência antecipada configurável; validação jurídica antes de produção comercial |
| 6 | DEC-08 fecha D-08 | Overuse configurável por plano; default avulso |
| 7 | Escopo produto final | Nenhum campo do A1 é cortado por "ser MVP"; a ordem de construção continua regida pelo Master 5.1.1 (seção 22) |

---


---

# SEÇÃO 4 — EVIDÊNCIAS DE BENCHMARK (pesquisa que fundamentou DEC-01, DEC-02, DEC-04, DEC-06, DEC-11 a DEC-15)

### 8.1 Players internacionais

| Tema | Prática observada | Uso no KortexOS™ |
|---|---|---|
| Reabertura de venda fechada | Zenoti permite desbloquear/editar fatura pós-fechamento apenas com permissões específicas; fatura sob trava financeira não pode ser desbloqueada; fechamento diário lista voids | Valida o modelo permissão + janela + financial lock (seção 4.3) |
| Split de gorjeta | Vagaro e Mangomint fazem split automático proporcional ao preço do serviço de cada profissional como default, com split manual disponível; Square oferece pooling por horas/função | Valida DEC-02: valor como default, tempo como política, manual como exceção |
| Preço/tempo por profissional | Phorest ajusta automaticamente tempo e preço por indivíduo; segmentação por nível é prática comum no mercado premium | Valida DEC-04 |
| Herança org → unidade | Zenoti define configurações na organização e lista explicitamente quais podem ser sobrepostas por unidade, com flag "override para esta unidade" e cadeias de fallback | Valida a semântica ponteiro + override autorizado por campo (seção 1.6) |
| Consumo de benefício no checkout | Créditos de membership aplicam automaticamente no checkout antes de pagamento externo | Valida DEC-06 |
| CDC / validade de pacote | Cláusulas que colocam o consumidor em desvantagem exagerada são nulas (art. 51); direito a reembolso protegido | Fundamenta DEC-07 e o flag de validação jurídica |

### 8.2 Players nacionais — Trinks, AppBarber, CashBarber

| Player | Prática observada | Leitura KortexOS™ |
|---|---|---|
| AppBarber | **CORRIGIDO por evidência primária (telas em produção, 2026-07):** reabertura e edição de comanda são FLUXO PADRÃO — comanda finalizada oferece "Reabrir agendamento" imediatamente, com edição plena (itens, valores, comissão, pagamentos múltiplos). O bloqueio existe apenas DEPOIS: caixa finalizado (valor faturado no financeiro) ou comanda dentro de pagamento de comissão | Reabrir+editar é comportamento base do mercado nacional, não exceção — DEC-11 o torna obrigatório no KortexOS™. As travas posteriores (caixa, comissão) CONFIRMAM a seção 4.3. Diferencial KortexOS™: a mesma liberdade operacional, mas por versões no ledger (v1→v2) em vez de mutação da história |
| AppBarber | Recibo de comissão com três opções de taxa de cartão: não descontar, descontar ou dividir com o profissional; sem taxas de bandeira cadastradas, valores líquido/descontado não calculam | CONFIRMA DEC-01 (os três modelos de absorção já operam no mercado nacional) e o invariante "forma sem taxa cadastrada = margem cega" |
| AppBarber | Clube de Assinaturas por quota (ex.: 2 cortes + 2 barbas/mês); excedente é cobrado normalmente; fatura vencida sem pagamento → serviços voltam a preço cheio | CONFIRMA DEC-08 (default avulso) e a suspensão de benefício por inadimplência (dunning) |
| AppBarber | Comissão de assinatura: percentual reduzido sobre o preço de tabela do serviço, ou faixas por produtividade | O preço de referência da DEC-10 SUBSUME esse modelo (referência = preço de tabela × fator). KortexOS™ mantém referência por item como base canônica única |
| AppBarber | Modal "Editar Item" com valor unitário, comissão %, cortesia e exclusão editáveis; parâmetro do sistema controla se o campo de comissão aparece, bloqueia ou oculta por perfil | Realidade obrigatória absorvida pela DEC-12. Diferencial KortexOS™: a mesma edição existe, porém GOVERNADA — permissão por persona (padrão que o próprio AppBarber já esboça no parâmetro), motivo registrado e trilha de auditoria; nunca edição silenciosa. Ajuste FORA da alçada da persona vira Action Request (Master 19.2) |
| AppBarber | Pacote associado à comanda desconta sessão; parâmetro para não gerar comissão em serviço de pacote; pacote e clube são mutuamente exclusivos por cliente | A ambiguidade de comissão em pacote que a DEC-10 elimina; a exclusividade pacote×plano é limitação que o KortexOS™ NÃO herda (obrigações coexistem com origem própria) |
| Trinks | Edição/exclusão de serviço direto em fechamento e alteração retroativa de data de movimentação | ANTI-PATTERN central: história financeira mutável. KortexOS™ entrega a mesma flexibilidade operacional via reabertura por versões, sem destruir auditabilidade |
| Trinks | Cancelar comanda libera o número, mas o serviço permanece registrado | Compatível com o invariante "nada é apagado" (seção 4.1) |
| Trinks | Crédito de cliente nativo: registrar, usar no fechamento, troco vira crédito, usar crédito de outro cliente, VENDER crédito por link de pagamento; débito (dívida) nativo | Valida client wallet + fiado governado. Duas práticas a ABSORVER: venda de crédito de wallet por link (KortexLink + wallet top-up) e uso de crédito de outro cliente (resolvido no KortexOS™ via household/pagador≠beneficiário, Gate 07) |
| Trinks | Profissional Parceiro (Lei do Salão Parceiro), assistente por serviço, módulo de anamnese, alerta ao fechar conta com serviço não finalizado | Valida vínculo Parceiro no cadastro de staff, percentual de assistente declarado (seção 5.2) e anamnese isolada em D26 |
| Trinks | Rodízio de profissionais (fila de atendimento por ordem) | LACUNA IDENTIFICADA no KortexOS™ — ver 8.3 |
| CashBarber | Posicionamento assinatura-first; planos com personalização de quantidade, procedimento e dias da semana | CONFIRMA a janela de uso por dias fracos (Master 14.2, plano terça–quinta) como demanda real do mercado nacional |
| CashBarber | NÃO distribui comissão de assinatura aos barbeiros nativamente (depende de app externo do ecossistema do fornecedor) | LACUNA DO LÍDER NACIONAL DE ASSINATURA: comissão de consumo de plano é exatamente o que DEC-10 + Gate 14 resolvem nativamente. Diferencial competitivo direto do KortexOS™ |
| CashBarber | Barbeiro lança serviços/produtos na própria comanda pelo celular | Compatível com persona Profissional (Master 18.1), sempre via Command |

### 8.3 Lacuna nova identificada no benchmark nacional

| Item | Decisão |
|---|---|
| **Rodízio / fila de walk-in** | Distribuição justa de clientes por ordem de chegada entre profissionais disponíveis (realidade diária de barbearia, presente na Trinks). O Master 5.1.1 cobre waitlist de agendamento, mas NÃO cobre fila de walk-in com rodízio. Registrar como evolução de D07/D08 na promoção 5.1.2. Não especificar solução neste anexo — apenas a lacuna. |

### 8.4 Realidades operacionais do AppBarber a preservar (evidência primária — telas em produção)

| Realidade | Destino no KortexOS™ |
|---|---|
| Split de pagamento nativo na comanda (Pagamento + Segundo Pagamento/Bandeira) | Já canônico (split multi-forma, DEC-06) |
| Chips de ação na comanda: +produto, +serviço, +pagamento, +desconto, +gorjeta | Padrão de superfície do checkout (UI/UX Spec; sem cálculo no frontend) |
| Prontuário do atendimento com material, tipo de corte, observação e fotos | Ficha técnica do cliente: D26 (dado potencialmente sensível, base legal e consentimento antes de fotos) |
| Status visível na agenda: assinatura ativa/inadimplente, multi, pacote, cupom, aniversário, pago online | Projeções de benefício/pagamento na agenda (D08/D18/D19) |
| Flag "não quer conversar" | Supressão de contato no Contact & Policy Orchestrator (Master 12.8) — consentimento e fadiga |
| Encaixe (overbooking manual) | Evolução de D07/D08: encaixe governado por permissão, registrado como exceção de capacidade |
| Pós-fechamento: mensagem de agradecimento, prontuário, enviar recibo | KortexLink transacional consentido |

```text
Dados de benchmark são referência, não verdade de produto (RAGOV 20.4).
O Global Benchmark Map formal (etapa 3 da ordem de construção) continua PENDENTE
e não é substituído por esta síntese.
```

---


---

# SEÇÃO 5 — VEREDITO RED TEAM (Parte I — aprovação do 5.1.1 como fonte canônica)

### 25.1 Aprovado como tese canônica

| Item | Veredito |
|---|---|
| KortexOS™ como nome canônico | APROVADO |
| Intelligent Capacity thesis | APROVADO |
| Ecossistema das 5 soluções | APROVADO |
| KortexFlow | APROVADO como tese; implementação pendente |
| Kortex.ai sem soberania | APROVADO |
| KortexLink como circuito de ativação | APROVADO |
| Negative Guard expandido | APROVADO |
| No-show progressivo + Trust Pass + Healing | APROVADO |
| Yield & Occupancy | APROVADO |
| Subscription Engine | APROVADO como motor central |
| Corporate Benefits | APROVADO como motor obrigatório |
| Partner Benefits | APROVADO como motor obrigatório |
| Kortex Autonomous Operations Engine | APROVADO como engine transversal |
| Modelo math-first no PostgreSQL | APROVADO como prioridade |
| Waitlist Recovery com hold | APROVADO P1 |
| Contact & Policy Orchestrator | APROVADO como obrigatório |
| Incrementality Engine | APROVADO por evolução |

### 25.2 Bloqueado

| Item | Motivo |
|---|---|
| Blueprint imediato | Falta benchmark, comparative proposal, truth map e migration map |
| SQL novo | Falta Blueprint aprovado |
| IA executora | Viola soberania backend |
| Plano sem ledger/wallet | Cria saldo paralelo |
| Corporativo sem privacidade | Risco LGPD |
| Parceria como cupom aberto | Perde rastreabilidade e margem |
| Dynamic pricing automático | Precisa política, dados e gate |
| Bot/LLM como cérebro de decisão | Viola soberania backend |
| Automação sem modo OBSERVE | Risco não mensurado |
| RL no MVP | Complexidade e risco sem evidência |

### 25.3 Risco principal

```text
O maior risco do KortexOS™ 5.1.1 não é falta de visão.
É automatizar correlações ruins antes de provar dados, causalidade, margem e segurança.
```

### 25.4 Decisão final

```text
Master Briefing KortexOS™ 5.1.1 aprovado como fonte canônica após aprovação do Platform Owner.
A versão 5.1 anterior torna-se histórica e é substituída por esta reescrita.
Blueprint KortexOS™ 5.1.1 continua bloqueado até benchmark formal, proposta comparativa, Truth Map e Migration Map.
SQL e automação em produção continuam bloqueados.
```

---


---

# SEÇÃO 6 — VEREDITO RED TEAM (anexo A2 — configuração, onboarding, comanda, gorjeta, níveis)

| Item | Veredito |
|---|---|
| Renomear D02 → Business Configuration & Policy Layer | APROVADO (RENOMEAR) |
| Herança ponteiro + override autorizado por campo | APROVADO |
| Onboarding sem persistência própria | APROVADO |
| Reabertura por versões + financial lock | APROVADO |
| Gorjeta com absorção da forma + split valor/tempo | APROVADO |
| Níveis com cascata tripla de resolução | APROVADO |
| Risco nº 1 | Reabertura de comanda é o ponto de maior risco contábil do sistema: sem a cascata completa de reversão (comissão, benefício, estoque, gorjeta, pagamento), cria dupla verdade financeira. Gate antes de produção é inegociável |
| Risco nº 2 | Breakage de pacote sem validação jurídica pode gerar passivo CDC. Não ativar comercialmente antes do parecer |
| Risco nº 3 | Este anexo não pode virar documento paralelo permanente. Incorporar no 5.1.2 por reescrita integral das seções afetadas |
| Oportunidade nº 1 | O líder nacional de assinatura não comissiona consumo de plano nativamente. DEC-10 + Gate 14 são diferencial competitivo direto — proteger na comunicação de produto |
| Lacuna registrada | Rodízio/fila de walk-in (8.3) entra na pauta da promoção 5.1.2 como evolução de D07/D08 |

---


---

# SEÇÃO 7 — ENCERRAMENTO DO ANEXO A1 (histórico, 2026-07-19)

Este anexo não altera domínios, gates nem a ordem de construção do Master Briefing 5.1. Ele aprofunda a especificação conceitual dos cadastros para que Benchmark (etapa 3), Truth Map (etapa 5) e Blueprint (etapa 7) tenham base concreta de comparação e materialização.

```text
Cadastro é a matéria-prima do cálculo.
Cálculo sem cadastro completo é chute com interface.
Nenhuma venda de plano ou pacote antes do ledger.
```


---
---


---

# SEÇÃO 8 — PRÓXIMO PASSO DO ANEXO A2 (histórico — CONCLUÍDO em 2026-07-19)

**Status: CONCLUÍDO.** O passo abaixo foi executado — anexo A2 aprovado e incorporado ao Master Briefing 5.1.2 na mesma sessão. Preservado apenas como registro histórico.

```text
1. Platform Owner aprova ou veta DEC-01 a DEC-10 (já refletem suas decisões verbais).
2. Incorporar este anexo no Master Briefing 5.1.2 por reescrita integral
   (D02, D03, D05, D06, D12, D14, D15, D17 e cadastros).
3. Só então: Global Benchmark Map formal (etapa 3), que segue PENDENTE.
Nada deste anexo autoriza SQL, migration ou tela.
```

---

*Fim do Decision Log. Para a regra vigente de qualquer tema aqui referenciado, consulte `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md`.*
