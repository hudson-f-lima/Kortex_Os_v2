# ADR 0019: Onda 2 — Fundação do KortexFlow Ledger (Double-Entry, sem Ativação)

## Status
Accepted (DEC-41, 2026-07-26)

## Date
2026-07-26

## Context

A Onda 2 (Migration Map v1.2, D15/D16) introduz o núcleo financeiro double-entry do KortexOS — `kortex_accounts`, `kortex_ledger_transactions`/`entries`, `client_wallets`, `staff_current_accounts`, `benefit_obligations`, `payout_batches`. Diferente da Onda 1 (borda de pagamento, produtor real ausente só por falta de PSP), esta Onda constrói a fundação de um sistema que **nenhum fluxo de produção ainda alimenta** — `checkout_close` continua calculando comissão e fechando pedido exatamente como hoje, sem escrever no ledger.

### Motivações

1. **Sequenciamento já decidido (Migration Map, Decisão 4):** o schema desta Onda pode nascer em paralelo à Onda 1 — nenhum objeto tem dependência estrutural obrigatória. Mas nenhuma captura real de pagamento pode ativar em produção antes do ledger existir e do Gate 11 (Ledger Balance) passar.
2. **Saldo paralelo é proibido por mandato explícito (§9.3 do Master):** qualquer campo de saldo direto e editável fora do ledger é uma violação de invariante crítico, não um detalhe de implementação.
3. **Staff Privacy (Gate 02):** profissional não pode ver comissão/gorjeta de outro — precisa de RLS self-view desde o desenho, não como retrofit.

### Constraints

- **Não tocar `checkout_close` nesta Onda.** Ligar produtores reais é, por si, um Blueprint/fatiamento próprio (risco equivalente ao HITL da fatia 004 da Onda 1) — decidido via `$grill-me` (pergunta 1) como fora de escopo.
- **`kortex_accounts` é por unidade, `client_wallets`/`staff_current_accounts` são org-wide** (Migration Map, DEC-28) — duas frases que colidem se o segundo par vivesse dentro do primeiro (ver Decision, "conflito unit-scoped vs. org-wide").
- **Nenhum precedente de `CONSTRAINT TRIGGER` deferido neste schema** — toda invariante multi-linha até hoje é resolvida dentro de uma função `plpgsql` só (`checkout_close`).
- **`_cents bigint`, nunca float, nunca valor assinado** (§7.2 do Master + convenção já estabelecida em todo o schema).

## Decision

### Fundação sem ativação — `checkout_close` intocado nesta Onda

Esta Onda constrói só o schema e a porta de escrita (`kortex_ledger_post`), testável com postagens sintéticas via pgTAP. Nenhum produtor real (venda, gorjeta, repasse) é ligado. Ativação fica para uma Onda 2b futura.

**Alternativa rejeitada:** ligar `checkout_close` ao ledger já nesta Onda, tornando o Gate 11 exercitável com dado real desde já. Rejeitada — dobraria o raio de explosão de uma única Onda (schema novo + segunda modificação de `checkout_close`), replicando exatamente o padrão de risco que a fatia 004 da Onda 1 já provou ser o mais perigoso do sistema.

### `kortex_accounts` é o próprio razão auxiliar, não um par polimórfico

Contas fixas do plano de contas (`cash`, `revenue_service`, `revenue_product`, `commission_expense`, `tip_liability`, `refund_expense`, `benefit_obligation_liability`) e contas por entidade (`client_wallet`, `staff_current_account`, que multiplicam por pessoa) vivem na mesma tabela, diferenciadas por `kind`. A referência à entidade dona usa **duas colunas nullable com FK composta** (`client_id`, `professional_id`), não um par genérico `owner_type`/`owner_id` — mesmo padrão já usado em `order_items` (`service_id`/`product_id`), que garante FK real (impossível criar conta de carteira apontando pra cliente de outra organização).

**Alternativa rejeitada:** `owner_type text` + `owner_id uuid` genérico. Rejeitada porque não tem como levar FK nenhuma — a integridade viraria 100% responsabilidade da aplicação, exatamente o tipo de garantia fraca que o resto do schema evita.

### Conflito unit-scoped vs. org-wide: projeção em cascata de dois níveis

O Migration Map registra `kortex_accounts` como por-unidade E `client_wallets`/`staff_current_accounts` como org-wide — sem reconciliar as duas frases. Resolução: `kortex_accounts` continua 100% por unidade (inclusive as linhas de `client_wallet`/`staff_current_account` — um cliente que transaciona em duas unidades tem duas linhas). `client_wallets`/`staff_current_accounts` viram tabelas separadas, enxutas, org-wide de verdade (identidade + saldo agregado, sem `unit_id`). Dois níveis de trigger, cada um só lê o nível abaixo: `kortex_ledger_entries` → projeção nível 1 (`kortex_account_balances`, por conta-unidade) → projeção nível 2 (`client_wallets`/`staff_current_accounts`, soma cruzando unidades da mesma pessoa). Nenhum dos dois níveis aceita escrita direta.

**Alternativa rejeitada:** coluna polimórfica extra (`party_type`/`party_id`) em `kortex_ledger_entries`, mantendo `client_wallets` fora de `kortex_accounts` desde o início. Rejeitada — reintroduziria o mesmo problema de FK fraca já descartado na decisão anterior, só que numa tabela ainda mais crítica (o próprio lançamento contábil).

### Porta única de escrita, sem `CONSTRAINT TRIGGER` deferido

`kortex_ledger_entries` só recebe `INSERT` de uma RPC nova, `kortex_ledger_post` — grants trancados a todo o resto, mesmo padrão fail-closed de `deposit_holds`/`payment_intents`. A RPC valida `SUM(debit) = SUM(credit)` **antes** de inserir, atomicamente, em `plpgsql` — mesma disciplina de `checkout_close` validando `v_paid = v_total`. Reversão financeira (§7.2 do Master) é só uma segunda chamada com as linhas espelhadas, nunca edição.

**Alternativa rejeitada:** `CONSTRAINT TRIGGER` deferido, validando no `COMMIT`. Daria garantia no nível do banco mesmo se um segundo caminho de escrita aparecesse no futuro, mas introduziria infraestrutura sem precedente neste schema, com sua própria superfície de erro (timing de deferred trigger). Descartada em favor de "existe exatamente uma porta, e os grants garantem isso" — mesma filosofia já aplicada em toda RPC financeira existente.

### Sinal por coluna categórica, nunca valor assinado

`direction` (`debit`\|`credit`) + `amount_cents` sempre positivo, nunca uma coluna assinada. Mesmo padrão de `cash_entries.kind`/`payments.method` — evita a classe de bug "inverti o sinal sem querer" numa RPC nova.

### Achados do Red Team de desenho, corrigidos antes da aprovação

1ª rodada `$kortex-qa-redteam`: `NO-GO`, 3 achados — (a) criação sob demanda de conta por entidade sem trava de concorrência (dois lançamentos concorrentes pro mesmo cliente, mesma unidade, primeira vez, colidiam em `unique_violation` não tratado); (b) `kortex_ledger_post` não validava que cada `account_id` do payload pertence à organização do chamador; (c) autorização da RPC nunca especificada. Corrigidos: `INSERT ... ON CONFLICT DO NOTHING` + `SELECT` pra criação de conta; checagem explícita de `organization_id`/`unit_id` por linha antes de qualquer `INSERT`; `actor_has_role(owner/admin/manager)`, mesma lista que já enxerga o ledger cru. 2ª rodada: `GO`.

## Alternatives Considered

### A: Ligar `checkout_close` ao ledger já nesta Onda
- **Pros:** Gate 11 exercitável com dado real imediatamente; uma Onda a menos no roadmap
- **Cons:** dobra o raio de explosão (schema novo + segunda modificação da RPC financeira mais crítica do sistema); repete o padrão de risco que a fatia 004 da Onda 1 já provou ser o mais perigoso
- **Rejected:** sequenciamento — fundação primeiro, ativação depois, mesmo princípio que guiou a Onda 1 (schema de `payment_intents` antes de qualquer PSP real)

### B: `kortex_account_balances` como view (materializada ou não) em vez de projeção por trigger
- **Pros:** sempre reconstruível por definição, zero código novo de manutenção de saldo
- **Cons:** recalcula tudo a cada leitura (ou a cada refresh) — não serve pra qualquer tela de saldo em produção; Gate 13 viraria "recalcular tudo toda vez"
- **Rejected:** trigger `AFTER INSERT`, único escritor possível (nenhum grant de `UPDATE` a ninguém), leitura O(1) sem abrir mão de reconstrutibilidade — Gate 13 continua um teste pgTAP trivial (soma o ledger do zero, compara)

### C: Owner_type/owner_id polimórfico em vez de FK dupla nullable
- **Pros:** uma coluna a menos, mais "genérico"
- **Cons:** sem FK real — integridade vira 100% aplicação; inconsistente com o padrão já usado em `order_items`
- **Rejected:** FK composta tenant-safe, mesmo padrão do resto do schema

### D: `benefit_obligations`/`payout_batches` com FK real para as tabelas de origem (`packages`, futuro `plans`/`corporate_contracts`/`partner_grants`)
- **Pros:** integridade referencial completa desde o desenho
- **Cons:** `plan`/`corporate`/`partner` não têm tabela própria ainda (D18 não existe) — forçar FK só pra `package` deixaria a coluna inconsistente entre os 4 tipos, e as duas tabelas não têm nenhum produtor nesta Onda de qualquer forma
- **Rejected:** `source_reference` texto livre por enquanto; vira FK real quando D18 (ou a Onda que criar essas tabelas) existir — mudança aditiva, não redesenho

## Consequences

### Aplicação
- **Evidência:** 2 rodadas de `$kortex-qa-redteam` (design), 1ª `NO-GO` com 3 achados, 2ª `GO` após correção de todos com mecanismo concreto
- **Fatiamento (DEC-33):** 5 fatias verticais candidatas (`kortex_accounts` + seed/backfill → `kortex_ledger_transactions`/`entries` + `kortex_ledger_post` + projeção nível 1 → `client_wallets`/`staff_current_accounts` + projeção nível 2 + self-view → `benefit_obligations` → `payout_batches`/`payout_batch_items`), cada uma testável isoladamente via `$tdd`
- **Rollback:** toda a Onda é aditiva pura — nenhuma tabela/RPC existente é alterada (nem sequer `units`, que só ganha uma trigger nova) — reverter qualquer migration não toca dado existente

### Código
- **`checkout_close`:** não é tocado nesta Onda — nenhuma linha alterada, nenhum risco novo introduzido na RPC financeira mais crítica do sistema
- **`kortex_ledger_post`:** RPC nova, sem rota Express nesta Onda (sem produtor real) — só pgTAP chama diretamente
- **Frontend:** nenhuma UI nesta onda, mesma decisão já aplicada nas Ondas 0 e 1

### Futuro
- **Onda 2b (ativação):** liga `checkout_close`/comissão/gorjeta a `kortex_ledger_post` de verdade — Blueprint próprio, mesmo nível de escrutínio da fatia 004 da Onda 1
- **D18 (Subscription Engine):** quando existir, `benefit_obligations.source_reference` pode evoluir de texto livre para FK real — mudança aditiva
- **Overflow de reconciliação da Onda 1 (ADR 0017):** quando `client_wallets` estiver realmente alimentado (Onda 2b), pode evoluir de "estorno" para "crédito automático" — já registrado como consequência futura na Onda 1, agora com a fundação pronta pra receber essa evolução

## Related Decisions

- **DEC-24:** Migration Map v1.2 define Onda 2 como KortexFlow Ledger + Wallet & Current Accounts (D15/D16)
- **DEC-28:** escopo por unidade — `kortex_accounts`/`kortex_ledger_transactions`/`entries`/`kortex_account_balances`/`payout_batches` por unidade; `client_wallets`/`staff_current_accounts`/`benefit_obligations` org-wide
- **DEC-33:** reforma de processo (fatiamento, TDD, evidência) sob a qual este Blueprint foi desenhado
- **DEC-41:** aprovação formal deste Blueprint pelo Platform Owner
- **ADR 0006/0007:** distinção void/refund — overflow futuro da Onda 1 pode evoluir pra usar `client_wallets` desta fundação
- **ADR 0011:** padrão de snapshot — não reaproveitado diretamente nesta Onda (nenhum produtor ainda), mas relevante quando a Onda 2b nascer
- **ADR 0012:** concorrência otimista — `ON CONFLICT DO NOTHING` desta Onda é a variante "criação idempotente" do mesmo princípio, aplicada a criação de conta em vez de atualização de versão
- **ADR 0016/0017:** Ondas 0/1 — `unit_id` e o padrão fail-closed de grants que esta Onda reaproveita integralmente
