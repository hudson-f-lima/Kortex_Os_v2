# PLANEJAMENTO_EXECUCAO_UNIFICADO

Status: CANÔNICO — única fonte de numeração de fases a partir da Fase 8
Fase atual: 9 | Última atualização: 2026-07-15 | Supersede sequenciamentos de:
PLANEJAMENTO_FINANCEIRO §4-5, PLANEJAMENTO_COMISSOES §8, PLANEJAMENTO_ROADMAP_POS_MVP §7

## 1. Objetivo e Regra de Canonicidade

- Este documento **CONTINUA** a numeração de `KORTEX_MVP_TECNICO.md §10` (Fases 1–7, encerradas).
- **Regra de governança**: nenhum outro documento pode criar numeração própria de "Fase" ou "Camada" executável. Documentos de planejamento apenas propõem; a fase de execução é alocada e registrada exclusivamente aqui.
- **"Propõe, não decide sozinho"**: toda fase possui um bloco "Decisões em aberto" que o usuário resolve ANTES do início da fase (não durante o seu desenvolvimento).
- **Regra de ouro — pesquisar antes de decidir**: nenhuma "Decisão em aberto" pode ser fechada, e nenhum ADR pode passar de `Proposed` para `Accepted`, sem antes pesquisar como o mercado global (não só o nicho de salões/estética) resolve o mesmo problema. Pesquisa vem antes da recomendação, nunca depois. Precedente desta sessão: a migration da Fase 9 (`20260715103200_fase9_foundation.sql`) implementou `order_refund` sem reversão de comissão; só a pesquisa de legislação trabalhista brasileira revelou que isso é o comportamento correto por lei (CLT), não uma lacuna — ver ADR 0005.

## 2. Estado Verificado

Estado atual:
- **Migrations**: 4 (baseline, permissões, grupos/pacotes, comissões).
- **RPCs**: `checkout_close`, `inventory_adjust`, `create_organization`, `membership_set`.
- **Módulos Backend**: 16.
- **Módulos PWA**: 8.
- **Testes**: 123 pgTAP + ~195 backend + 69 frontend.
- **CI**: Fase 7 rodou e passou.
- **Render**: `REAL` (Fase 7 fechou; backend `kortex-api` validado online com `/health` OK).

**Tabela de Rastreabilidade**

| Origem da Demanda | Fase Alocada |
|---|---|
| `PLANEJAMENTO_FINANCEIRO` Camada 1 | Fase 9 |
| `PLANEJAMENTO_COMISSOES` §8.3 | Fase 10 |
| `PLANEJAMENTO_COMISSOES` §8.4 | Fase 11 |
| `PLANEJAMENTO_COMISSOES` §8.1+8.2 | Fase 12 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` §5/§6 | Fase 13 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 2 (restante) | Fase 14–15 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 3 | Fase 16 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 4 | Bloqueado (§6) |

## 3. Invariantes Transversais e Arquitetura-alvo do Checkout

Esta é a equação-alvo de reconciliação que será definida **UMA única vez** e implementada em fatias pelas próximas fases.
`sum(payments) == subtotal - discount_total + tip_total - deposit_credit`

(Hoje `discount` = `tip` = `deposit` = 0 forçados. A Fase 9 ativará discount/tip e a Fase 13 ativará deposit_credit; contudo, a equação e os checks nascerão completos já na Fase 9).

- **Contrato de payload extensível** na `checkout_close` com campos opcionais, valores default e **versionamento do hash de idempotência** (para evitar falhas no retry cruzando o deploy de novos campos).
- **Invariantes permanentes**: 
  - Todo o dinheiro usa centavos inteiros.
  - Toda RPC que escreve dinheiro requer `private.idempotency_keys`.
  - A comissão é sempre congelada no checkout (não retroage).
  - Toda tabela nova nasce com a matriz RLS completa e testes pgTAP por papel.

## 4. Fases de Execução (Fase 8 a 13)

### Fase 8 — Consolidação documental e fechamento real do MVP [CONCLUÍDA]
**Escopo**: merge (fast-forward) da branch de docs; criação deste documento; higiene documental de todos os arquivos; fechamento da pendência Render; parametrização de `deploy-pages.yml`.
**Dependências**: Nenhuma técnica — é o pré-requisito de TODAS as outras. (Uma divergência de documentação impede o sequenciamento correto no main).
**Entregáveis**: Higiene nos docs concluída (ADRs ajustados, INDEX renomeado, supersedes adicionados).
**Decisões em aberto**: (a) `/health` do Render: corrigir agora ou re-escopar formalmente o deploy do backend? (~~b) fast-forward vs cherry-pick~~ — resolvido: merge fast-forward aplicado; ~~c) nome do agrupamento no INDEX~~ — resolvido: "Trilhas A–D").
**Riscos**: Manter a pendência de devops silenciada.
**Gate de saída**: main = única verdade; CI verde; evidência real do /health 200 em produção OU decisão registrada de re-escopo documentado. INDEX sem colisão de numeração.

### Fase 9 — Fundação Financeira (Camada 1) [EM ANDAMENTO]
**Escopo**: Desconto real em `checkout_close` (fim do `discount_cents=0`); regra de distribuição do desconto entre itens (pré/pós expansão de pacote); gorjeta; RPC de lançamento manual de caixa (`income`/`expense`/`refund`) com idempotência; estorno de venda (`order_refund`). Nasce aqui a equação-alvo do §3, prevendo já o `deposit_credit`.

**Estado real (auditado em 2026-07-15)**: a migration `20260715103200_fase9_foundation.sql` já implementa desconto/gorjeta rateados por maior resto em `checkout_close`, `cash_entry_manual` e `order_refund`. Comissão passou a ser calculada sobre `total_cents - discount_cents` (equivalente ao modo "Revenue" do Zenoti — ver Fase 12) sem flag de organização ainda. **Sem testes pgTAP, sem rota no backend Express, sem PWA** — a fase não fechou o próprio gate de saída definido abaixo.

**Achado — `order_refund` não reverte comissão (linhas 128–159 da migration): isto está correto por padrão, não é uma lacuna a fechar automaticamente.** Pesquisa de legislação trabalhista (ver ADR 0005) mostrou que estornar comissão já congelada de profissional CLT é ilegal exceto por inadimplência do comprador (Lei 3.207/1957 art. 7º); para profissional autônomo-parceiro (Lei 13.352/2016) a regra depende do contrato de parceria. O schema não distingue hoje a classificação do profissional nem o motivo do estorno — nenhuma automação de reversão de comissão deve ser implementada até essas duas informações existirem (ver ADR 0005).

**Novo deliverable identificado — correção de comanda fechada por erro operacional (ex.: recepção digitou o serviço/profissional errado) é um cenário DIFERENTE de estorno ao cliente, e não deve reusar `order_refund`.** A primeira pesquisa (Zenoti "Reopen a Closed Invoice", Vagaro "Reassign Sold By", Square "Return or Exchange") não achou um padrão único e sugeriu uma RPC isolada `order_correct`. **Pesquisa de seguimento em concorrentes diretos do nicho (AppBarber, Trinks, e confirmação lateral em Avec/Nex) achou um padrão local convergente e mais forte, que substitui essa hipótese**: nos quatro sistemas, reabrir uma comanda fechada não é uma ação isolada na própria comanda — **é travada pelo estado da sessão de caixa que a contém**.
- **AppBarber**: uma comanda só pode ser alterada enquanto o caixa em que ela está ainda está aberto. Se o caixa já fechou, o fluxo documentado é: `Financeiro > Histórico de Caixa` → localizar o caixa pelo usuário/data (a mensagem de erro já informa os dois) → reabrir o caixa (ação própria, auditável) → só então a comanda fica editável → corrigir → finalizar a comanda de volta no mesmo caixa → fechar o caixa de novo.
- **Trinks**: mesmo princípio em granularidade mensal — "Fechamento Mensal" trava os valores a pagar por profissional; existe um botão explícito "reabrir mês" para ajustes retroativos, depois fecha de novo.
- Isso substitui a hipótese de um `order_correct` isolado: **falta uma peça de fundação que hoje não existe em nenhum lugar do schema — sessão de caixa (abertura/fechamento por período/turno)**. `cash_entries` hoje é só uma lista *append-only* sem fronteira de sessão (confirmado por grep no baseline — nenhuma coluna de sessão/período); não há como replicar "só edita se o caixa ainda está aberto" sem essa tabela nova. Isso é maior que uma RPC — é um novo objeto de domínio (ver risco novo no §7 abaixo).

**Entregáveis**: RPC `checkout_close` alterada (concluído); RPCs de lançamento e estorno de caixa (concluído, sem wiring); tabela `cash_sessions` (abertura/fechamento de caixa por período, com usuário/data de abertura e fechamento) — pré-requisito da correção de comanda; RPC de reabertura de comanda condicionada à sessão de caixa estar aberta (substituindo a hipótese de `order_correct` isolado); wiring backend Express; suporte no PWA para Comanda e Caixa.
**Decisões em aberto**: (1) Gorjeta entra na base da comissão ou vai 100% para o profissional? *(decidido implicitamente pela migration: fora da base — falta confirmação explícita)*. (2) Classificação do profissional (CLT vs. autônomo-parceiro) — schema novo necessário antes de qualquer reversão automática de comissão (ADR 0005). (3) Motivo do estorno (inadimplência/desistência do cliente vs. correção operacional) — captura necessária para decidir tratamento de comissão e de caixa. (4) `cash_sessions` entra na Fase 9 (mesma fundação de caixa) ou vira decisão de escopo própria, já que é maior do que o previsto originalmente para esta fase? (5) Reabertura de sessão de caixa exige papel/permissão própria (gerente/dono, como o padrão local sugere) e log auditável de quem/quando reabriu?
**Riscos**: Regressão no cálculo de `checkout_close`; automatizar reversão de comissão sem a classificação do profissional é risco jurídico (CLT), não só técnico; escopo de `cash_sessions` pode estourar o tamanho já planejado da Fase 9.
**Gate de saída**: pgTAP da equação nova com testes negativos e de desconto maior que o subtotal; testes de integração do backend; frontend operando descontos, gorjetas e estornos no Caixa; decisão registrada (não código) sobre `cash_sessions`/reabertura de comanda antes de fechar a fase.

### Fase 10 — Capacidades N:N profissional×serviço
**Escopo**: Tabela N:N (`professional_service_capabilities`) com `duration_override_minutes` (alimentando a janela GiST da agenda) e `price_override_cents`; PWA listando e filtrando agenda e catálogo por capacidades.
**Dependências**: Ocorre depois da Fase 9 porque `price_override` altera a base sobre a qual o desconto/comissão incidem. Precisa ocorrer antes da Fase 12, pois a receita do profissional dependerá desses preços. Ordem trocável com a Fase 11 (sem dependência dura, mas recomendada por nascer RLS completo para as capacidades do profissional).
**Entregáveis**: Migration de capabilities; backend CRUD para gerenciar a tabela; frontend com abas e filtros na Equipe.
**Decisões em aberto**: Nome final da tabela? `price_override` aplica em pacotes ou só avulso? Profissional sem vínculo pode tudo ou nada?
**Riscos**: Bloquear erroneamente um agendamento válido.
**Gate de saída**: pgTAP validando o booking; teste de peso de pacote com override; red team de override negativo/zero.

### Fase 11 — Acesso da Equipe (Convite + RLS self-view)
**Escopo**: SMTP de produção (mailer default Supabase é rate-limited); Fluxo de convite (auth admin → membership → link `professionals.user_id` com UNIQUE garantido); Policies RLS na tabela `professional` focadas em self-view.
**Dependências**: Após a Fase 10 (policies nascem mais robustas). O redirect de callback exige teste real sob o base path do GitHub Pages para não perder o fragment `#access_token` via 404.html (Blind Spot).
**Entregáveis**: Endpoint de invite; SMTP; ajustes RLS; PWA com tela de convite.
**Decisões em aberto**: Qual provedor SMTP usar? Profissional pode enxergar comanda inteira ou apenas seus serviços (allowlist ou não)? Expiração do link de convite?
**Riscos**: Vazamento intra-org.
**Gate de saída**: Teste E2E de convite com e-mail REAL. Red team testando um vazamento de dados de profissionais diferentes na mesma organização.

### Fase 12 — Comissões Escalonadas + Política de Absorção de Desconto
**Escopo**: Tabela `commission_tiers` + flag na organização de política de desconto (`net_price_split`, `gross_price_salon_absorbs`, `deduct_after_commission`).
**Dependências**: Fase 9 (Desconto) e Fase 10 (Preços Finais) devem estar estabilizadas. Por ser complexa, fica por último e maximiza o tempo de definição.
**Achado de pesquisa (ADR 0004)**: o Zenoti — benchmark citado no próprio ADR — não usa uma única flag por organização; tem granularidade por tipo de item (serviço: "Sale price before discount" vs. "Revenue"; produto/membership: opção separada "Sale price after discount" vs. "Revenue", com dedução adicional). A Fase 9 já hardcodou o equivalente a "Revenue" só para serviços, sem flag. Avaliar se a Fase 12 deve granularizar por tipo de item em vez de uma flag única por organização, alinhando com o padrão de mercado em vez de simplificar demais.
**Entregáveis**: Alterações finais em `checkout_close`; módulo CRUD de Tiers; flag na Org e no PWA.
**Decisões em aberto (Obrigatório resolver antes)**: Marginal vs Cliff (recomendado marginal para não re-calcular comissões antigas). Como dividir split de vendas cruzando o limiar? Timezone de fronteira de mês para Org. Concorrência: leitura com lock (`FOR UPDATE`) no faturamento. O override anula o tier ou o tier escala o override? Estorno altera a comissão acumulada de vendas futuras do mês (recomenda-se não retroagir, ver ADR 0005)? Flag única por organização ou granular por tipo de item (serviço vs. produto), seguindo o padrão Zenoti?
**Riscos**: Deadlocks em transações ou recálculo retroativo inválido de pagamentos efetuados.
**Gate de saída**: Testes de concorrência com dois checkouts batendo o limiar do tier ao mesmo tempo; pgTAP de fronteira mensal/timezone; red team em acumulo manipulado via estornos.

### Fase 13 — No-show FSM + Sinal + Mensageria nativa
**Escopo**: Tabelas de log de estado por cliente×org (`no_show_count`, limiares); Sinal como `deposit_credit` habilitado na RPC `checkout_close` e lançado manualmente no caixa via Pix. PWA envia template manual via Web Share API / `wa.me` sem uso de bot.
**Dependências**: Fase 9 obrigatória (Lançamentos manuais de caixa para sinal). Não depende das F10 a F12.
**Entregáveis**: Módulo Backend/Banco de máquina de estados para no-show; botão de Mensageria PWA nativo; check de impedimento em agendamento (cobrando depósito).
**Decisões em aberto**: Histórico antigo de faltas conta (backfill)? Cancelar status de no-show é idempotente? Políticas de retenção LGPD. Qual o valor do sinal (Fixo vs Percentual)?
**Riscos**: Bloqueio equivocado de clientes ou LGPD.
**Gate de saída**: pgTAP em todas arestas do State Machine; reentrada idempotente; Red team de crédito duplo de depósito; Nota LGPD no repositório.

## 5. Horizonte Reservado (Fases 14 a 16)
Estas fases estão explicitamente marcadas como "reservadas, sem spec" (anti-mock). Elas só receberão detalhamento quando a fase que as antecede cruzar seus gates de saída com sucesso.
- **Fase 14**: Lista de espera e anti-gap básico.
- **Fase 15**: Portal do cliente e booking online. (Requer Red Team próprio na superfície anônima/pública).
- **Fase 16**: Memberships Mínimas de retenção. (Exigirá a revogação formal em ADR do não-objetivo do MVP antes de ser executada).

## 6. Explicitamente Bloqueado

Itens bloqueados exigem a criação de um **novo ADR** + alocação de Fase neste documento. O desbloqueio nunca ocorre de forma implícita.

| Item | Origem | Critério de Desbloqueio Baseado em Evidência |
|---|---|---|
| Kortex.ai / IA (D22) | ROADMAP | Decisão explícita do usuário; nunca por fase ou evolução. |
| Ledger Partidas Dobradas | FINANCEIRO §3.1 | Apenas se o Lançamento Manual (F9) falhar operacionalmente em volume. |
| Gateways Pagamento / Escrow | MVP TECNICO §11 | Apenas se o controle de recebimento via Pix/Manual mostrar atritos. |
| Carteiras de Cliente (Wallets) | ROADMAP | Depende integralmente da quebra de bloqueio do Ledger Partidas Dobradas. |
| Yield e Preço Dinâmico | ROADMAP | Depende da captação prévia de ocupação robusta (Pós-F14). |
| Fiscal, NF-e, Marketplace | MVP TECNICO §11 | Fora de escopo até revisão formal da arquitetura geral em ADR. |

## 7. Riscos Transversais e Operação
- **Escala de pgTAP**: Cada tabela adicionada + novo Papel intra-org (`professional`) trará um aumento combinatorial na suíte. O orçamento da CI deve ser avaliado e splits da suite previstos para acelerar testes localmente.
- **Backup / Restore**: Dados vitais financeiros como sinal pago, comissões em tier e caixa manual elevam os danos em caso de corrupção. As políticas de backup do tier local do Supabase e scripts de dump devem estar definidos antes das Fases 12 e 13.
- **LGPD**:
  - Punições da máquina de estado do no-show representam perfis de consumo e penalidades comportamentais (PII); necessitam de fluxos de "exclusão de cliente".
  - O uso do Web Share e WhatsApp (`wa.me`) revela o número da recepcionista/clínica e o telefone do usuário; requer política limpa de opt-in.
  - Links de convites e emails gerados também tratam e geram registros auditáveis.
- **Timezone**: Sem as configurações de Fuso Horário fixadas em Org (America/Sao_Paulo vs UTC), a fronteira do "Final de Mês" do comissionamento (Fase 12) falhará em horários noturnos nos dias 31.
- **Sessão de caixa (confirmado por concorrentes diretos)**: `cash_entries` não tem fronteira de sessão/período — sem isso, não é possível replicar o padrão local (AppBarber/Trinks/Avec/Nex) de travar edição de comanda por caixa fechado. Afeta diretamente a Fase 9 (ver decisões em aberto) e potencialmente o dimensionamento do escopo dessa fase.

## 8. Fontes de Planejamento e ADRs

**Documentos Internos**
- `docs/PLANEJAMENTO_FINANCEIRO.md`
- `docs/PLANEJAMENTO_COMISSOES.md`
- `docs/PWA_PLANEJAMENTO.md`
- `docs/PLANEJAMENTO_ROADMAP_POS_MVP.md`
- `docs/adr/0001-record-architecture-decisions.md`
- `docs/adr/0002-checkout-atomico-idempotente-server-side.md`
- `docs/adr/0003-comissoes-escalonadas.md`
- `docs/adr/0004-politica-absorcao-descontos.md`
- `docs/adr/0005-reversao-de-comissao-em-estornos.md`

**Benchmarks Externos (Padrões da Indústria)**
- **Comissões e Absorção de Descontos:** Zenoti (Employee Commissions; [Configure Service Commissions based on a Percentage of Revenue](https://help.zenoti.com/en/articles/700184-configure-service-commissions-based-on-a-percentage-of-revenue); [Configure Product Commissions based on a Percentage of Sales Price](https://help.zenoti.com/en/articles/700228-configure-product-commissions-based-on-a-percentage-of-sales-price)), Vagaro (Payroll & Commission Setting), Phorest.
- **No-Show e Retenção:** SICUS, DaySmart, GlossGenius, Vagaro, Boulevard.
- **Acesso Nativo Mobile (Web API):** MDN Web Docs (Web Share API), Documentação Meta/WhatsApp (Click-to-chat `wa.me`).
- **Clawback de Comissão em Estornos (mercado global SaaS/afiliados):** [Everstage — Sales Commission Clawback Best Practices](https://www.everstage.com/sales-commission/sales-commission-clawback), [SalesCookie — Complete Guide to Sales Commission Clawbacks](https://blog.salescookie.com/2026/05/05/complete-guide-sales-commission-clawbacks/), [TinyAffiliate — Refunds and affiliate commissions clawback workflow](https://www.tinyaffiliate.com/blog/refunds-and-affiliate-commissions-clawback-workflow).
- **Legislação Trabalhista Brasileira (estorno de comissão):** [Planalto — Lei nº 13.352/2016 (Lei do Salão Parceiro)](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2016/lei/l13352.htm), [BNZ Advogados — A Lei do Salão Parceiro e Seus Elementos](https://www.bnz.com.br/bnz-em-foco/artigos/trabalhista/a-lei-do-salao-parceiro-e-seus-elementos), [Jusbrasil — Descontos de Comissão (jurisprudência)](https://www.jusbrasil.com.br/jurisprudencia/busca?q=descontos+de+comiss%C3%A3o), [ConJur — Contrato de parceria em salões de beleza é constitucional, diz STF](https://www.conjur.com.br/2021-out-28/contrato-parceria-saloes-beleza-constitucional-stf/).
- **Correção de Comanda Fechada / Void vs. Edit (POS geral):** Zenoti (Reopen a Closed Invoice, Manage Invoices), Vagaro (Reassign "Sold By" Employee after Checkout, Undo a Checked-Out Appointment), Square (Process a return, exchange, or unlinked refund), [Modern Treasury — Enforcing Immutability in your Double-Entry Ledger](https://www.moderntreasury.com/journal/enforcing-immutability-in-your-double-entry-ledger), [AMS Retail — How to Void a Return Transaction in a POS System](https://amsretail.com/feeds/blog/void-return-transaction-pos-system).
- **Reabertura de Comanda por Sessão de Caixa (concorrentes diretos do nicho, Brasil):** [AppBarber/AppBeleza — Estou tentando reabrir uma comanda de um caixa fechado, como proceder?](https://appbarber-appbeleza.zendesk.com/hc/pt-br/articles/360001571051-Estou-tentando-reabrir-uma-comanda-de-um-caixa-fechado-como-proceder), [AppBarber/AppBeleza — Como funciona o Caixa?](https://appbarber-appbeleza.zendesk.com/hc/pt-br/articles/360002607332-Como-funciona-o-Caixa), [Trinks — Fechamento Mensal](https://ajuda.trinks.com/fechamento-mensal), [Avec — Como reabrir um caixa?](http://ajuda.avecbrasil.com.br/support/solutions/articles/17000092938-como-reabrir-um-caixa-).
