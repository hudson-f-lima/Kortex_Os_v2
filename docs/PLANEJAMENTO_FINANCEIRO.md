# Planejamento Financeiro — KortexOS

**Status:** planejamento/análise. Não altera código nem os não-objetivos vigentes de `KORTEX_MVP_TECNICO.md §11` — este documento propõe e classifica, não decide sozinho.

**Ordem de leitura antes deste documento:** `AGENTS.md` → `docs/PROJECT_STATE.md` → `docs/KORTEX_MVP_TECNICO.md` → `docs/legacy/` (não autoritativo). Classificações de estado usam o mesmo vocabulário de `AGENTS.md` (`REAL`, `PARCIAL`, `AUSENTE`, `CONTRADITÓRIO`).

## 1. Objetivo

Os três documentos em `docs/legacy/` (`billing_and_insights_logic.md`, `checkout_math_logic.md`, `state_of_the_art_finance_models.md`) descrevem a camada financeira de um produto anterior (Hope OS/SMART Flow), com escopo bem maior que o MVP vigente: ledger de partidas dobradas, engine de comissão/escrow, máquina de estados de pagamento, agregador de insights (faturamento, margem, repasse). `docs/INDEX.md` já os marca como referência de domínio, não autoridade técnica.

Este documento faz três coisas:
1. **Audita o que já é `REAL`** no schema/backend atual contra o que os docs legados e o mercado global consideram estado da arte.
2. **Pesquisa o estado da arte global** de arquitetura financeira (ledger, idempotência, split/escrow, comissão) fora do nicho de beleza — a mesma lógica de "qualquer segmento" da pesquisa de PWA.
3. **Classifica os gaps em camadas por custo de adiar**, para decisão consciente do usuário — não redefine `KORTEX_MVP_TECNICO.md §11` por conta própria.

## 2. Estado real hoje (evidência, não os docs legados)

Lido diretamente de `supabase/migrations/20260712235319_mvp_baseline.sql`, `checkout_close`, `backend/src/modules/{checkout,orders,cashEntries}`:

| Item | Estado | Evidência |
|---|---|---|
| Dinheiro em centavos inteiros | `REAL` | todo `*_cents` é `bigint`, sem float em nenhuma tabela |
| Checkout atômico multi-item/multi-pagamento | `REAL` | `checkout_close` insere order+items+payments+cash_entry numa única transação, com lock de estoque (`for update`) |
| Idempotência server-side | `REAL` | `private.idempotency_keys` grava hash do payload e a resposta; replay com o mesmo payload retorna a resposta salva; payload diferente com a mesma chave é rejeitado (`22023`) — já equivalente ao padrão Stripe (ver §3.2) |
| Reconciliação pagamento×total | `REAL` | `checkout_close` exige `v_paid = v_subtotal` antes de fechar |
| `orders.discount_cents` | `CONTRADITÓRIO` | a coluna e o `check` existem, mas `checkout_close` sempre insere e atualiza `discount_cents = 0` — nenhum caminho de código o altera; hoje é uma promessa de schema sem funcionalidade |
| `orders.status` (`draft`/`cancelled`/`refunded`) | `PARCIAL` | o `check` permite os 4 valores, mas `checkout_close` é o único inserter e sempre grava `'closed'` — não existe "comanda aberta" persistida no banco nem cancelamento/estorno |
| `cash_entries.kind` (`income`/`expense`/`refund`) | `PARCIAL` | o `check` permite os 4 valores; só `'sale'` é alcançável (via `checkout_close`) — o próprio código documenta isso (`cashEntries.service.js`: "There is no RPC yet for manual income/expense/refund entries") |
| Atribuição de profissional por item vendido | `AUSENTE` | `order_items` não tem `professional_id` nem qualquer coluna de comissão — impossível hoje saber quem produziu cada venda |
| Gorjeta (gorjeta/tip) | `AUSENTE` | não existe em `payments` nem em nenhuma tabela |
| Taxa de cartão / custo de adquirência | `AUSENTE` | `payments.method` distingue `debit_card`/`credit_card`, mas nenhum valor de taxa é capturado |
| Ledger de partidas dobradas (saldo derivado, soma zero) | `AUSENTE` (decisão de design) | `cash_entries` é um log categorizado *append-only*; o saldo depende da aplicação somar com sinal correto por `kind` — nada no banco garante consistência como no §3.1 |
| Máquina de estados de pagamento | `AUSENTE` | `payments` é inserido já como concluído; não há `authorize/capture/void` |
| Relatórios/insights/margem | `AUSENTE` | nenhum módulo de reports existe em `backend/src/modules` |

## 3. Pesquisa global — estado da arte fora do nicho

### 3.1 Ledger de partidas dobradas como infraestrutura, não afterthought

O padrão que Stripe usa internamente e que motivou bancos de dados dedicados como o TigerBeetle (OLTP especializado, 100k–500k transferências/s) é: **saldo nunca é uma coluna, é derivado da soma de lançamentos imutáveis, e toda transação deve somar exatamente zero** entre débito e crédito. Isso é o que o legacy `state_of_the_art_finance_models.md §1` também propõe (`Ledger.postTransaction` valida soma zero antes de gravar). É genuinely estado da arte — mas é infraestrutura de banco/fintech, não um recurso de produto isolado; adotá-lo significa migrar `cash_entries` inteiro para um modelo de lançamentos, não adicionar uma tabela ao lado.

### 3.2 Idempotência — o KortexOS já está no padrão-ouro

A implementação da Stripe (chave de até 255 caracteres, UUID v4 recomendado, mesmo corpo de requisição obrigatório sob a mesma chave, resposta cacheada e devolvida em replay, mesmo em erro) é exatamente o que `checkout_close` já faz via `private.idempotency_keys`, com a vantagem de ser garantido pela própria transação de banco (não uma race condition possível de um `Map` em memória, que é a limitação explícita do `IdempotencyStore` do doc legado — ele mesmo comenta "num cenário real, isso seria Redis"). **Não há gap aqui — o real já supera o exemplo legado.**

### 3.3 Split/comissão/escrow — Stripe Connect como referência de mercado

O padrão de mercado (Stripe Connect) para "quem recebe quanto de uma venda" é: o valor cheio entra na plataforma, a plataforma retém uma taxa (`application_fee_amount`) e transfere o restante à conta conectada; quando é preciso reter até confirmação (ou janela de disputa), usa-se *delayed payout* em vez de uma conta de escrow formal. O template `TEMPLATE_VENDA_COMISSIONADA` do doc legado (`state_of_the_art_finance_models.md §2`) modela essencialmente a mesma ideia com contas transitórias. **Isso só é implementável se existir, antes de tudo, atribuição de profissional por item** — que hoje não existe (§2). É pré-requisito, não o gap em si.

### 3.4 O próprio nicho já trata comissão/gorjeta como padrão, não diferencial

Pesquisa nos concorrentes diretos (Vagaro, Fresha, POS de nail salon) confirma que cálculo automático de comissão por profissional e split automático de gorjeta por quem realizou o serviço são recursos padrão de mercado, não avançados — Vagaro liga isso direto à folha de pagamento. Isso muda a classificação de "atribuição de profissional por item" de "analytics avançado" (não-objetivo declarado) para **funcionalidade mínima esperada de um ERP do segmento** — ver recomendação no §4.

### 3.5 Máquina de estados de pagamento

O padrão (Stripe PaymentIntent: `requires_payment_method → processing → requires_capture → succeeded/canceled`) existe para proteger contra estornar antes de capturar ou capturar duas vezes — problema real quando há um *gateway* de pagamento assíncrono. O MVP atual não integra gateway (`KORTEX_MVP_TECNICO.md §11`: "integrações de pagamento... fora do MVP") — o pagamento é sempre presencial e imediato (dinheiro, PIX, maquininha já liquidada). **A FSM do doc legado resolve um problema que o KortexOS não tem enquanto não houver gateway assíncrono.**

## 4. Classificação em camadas (para decisão, não implementação automática)

**Camada 0 — já é estado da arte, não mexer.** Centavos inteiros, checkout atômico, idempotência server-side. Nenhuma ação.

**Camada 1 — gap barato hoje, caro depois (recomendo priorizar).**
- `order_items.professional_id`: sem essa coluna agora, qualquer relatório futuro de "quem vendeu o quê" exige migração com backfill impossível (o dado simplesmente não foi capturado). É uma coluna e uma linha a mais no payload de `checkout_close`, adicionável sem tocar no não-objetivo de "analytics avançado" — só captura o fato, não calcula comissão.
- Resolver a contradição de `discount_cents`: ou remover o `check`/coluna morta, ou implementar de fato (decisão de produto: o checkout aceita desconto?).
- Decidir se `orders.status`/`cash_entries.kind` além de `closed`/`sale` são necessários para o MVP (ex.: **estorno** é razoavelmente esperado num sistema de checkout, mesmo mínimo) — hoje uma venda fechada é permanente e não há caminho de reversão.

**Camada 2 — estado da arte genuíno, mas contraria `KORTEX_MVP_TECNICO.md §11` hoje (não iniciar sem revisar o não-objetivo).**
- Ledger de partidas dobradas para `cash_entries` (§3.1).
- Engine de comissão/escrow com split automático (§3.3) — depende da Camada 1 primeiro.
- Gorjeta e taxa de cartão como campos de pagamento.
- Módulo de insights/relatórios/margem (`FinanceReadModel`/`margin.js` do doc legado — a ideia de agregação é boa; o código específico não, por já assumir campos que não existem, como `comissao_centavos` e `receita_empresa_centavos`).
- Máquina de estados de pagamento (só ganha sentido com gateway assíncrono, também não-objetivo atual).

## 5. Recomendação

Tratar a Camada 1 como uma decisão de produto a resolver **antes** de fechar a fase de checkout como definitivamente encerrada — o custo de adicionar `professional_id` a `order_items` agora é uma migration pequena; feito depois de haver dados em produção, vira backfill impossível (o histórico não tem a informação). A Camada 2 permanece corretamente fora do MVP por enquanto, mas agora com pesquisa concreta (§3) para quando a fase for reaberta — nenhum código dos docs legados deve ser copiado literalmente (usa nomenclatura e campos que não existem no schema atual), mas os *padrões* (ledger imutável de soma zero, split via conta transitória, FSM de pagamento) são a referência a seguir quando chegar a hora.

## Fontes

- [TigerBeetle — Debit/Credit: The Schema for OLTP](https://docs.tigerbeetle.com/concepts/debit-credit/)
- [TigerBeetle — System Architecture](https://docs.tigerbeetle.com/coding/system-architecture/)
- [dev.to — Building a Payment System: Stripe's Architecture](https://dev.to/sgchris/building-a-payment-system-stripes-architecture-for-financial-transactions-3mlg)
- [Stripe — Idempotent requests (API Reference)](https://docs.stripe.com/api/idempotent_requests)
- [Stripe — Designing robust and predictable APIs with idempotency](https://stripe.com/blog/idempotency)
- [Stripe Connect — Build a marketplace](https://docs.stripe.com/connect/marketplace)
- [Stripe Connect — Collect application fees](https://docs.stripe.com/connect/marketplace/tasks/app-fees)
- [Homebase — Salon Payroll Software Guide](https://www.joinhomebase.com/blog/salon-software-with-payroll)
- [Zenoti — Best Nail Salon POS Systems 2026](https://www.zenoti.com/thecheckin/best-nail-salon-pos-systems)
