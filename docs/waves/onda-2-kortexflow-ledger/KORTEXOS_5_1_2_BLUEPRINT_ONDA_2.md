# KortexOS 5.1.2 — Blueprint Onda 2: KortexFlow Ledger + Wallet & Current Accounts

**Status:** **APROVADO E IMPLEMENTADO LOCALMENTE; NÃO PROMOVIDO.** O Blueprint foi aprovado pelo Platform Owner em 2026-07-26 (DEC-41) e a Etapa 8 foi regularizada por DEC-42 para as fatias 012–016 em ambiente local, com migrations e testes físicos. A fundação não ativa produtores reais e permanece `NO-GO` para `staging`/`main` até os gates de ambiente, entrega e homologação. Ver [ADR 0019](../../architecture/adr/0019-onda2-kortexflow-ledger-fundacao.md).
**Etapa:** 7 (Blueprint) concluída; Etapa 8 local autorizada e executada sob DEC-42.
**Escopo:** subconjunto de D15/D16 — `kortex_accounts`, `kortex_ledger_transactions`, `kortex_ledger_entries`, `kortex_account_balances`, `client_wallets`, `staff_current_accounts`, `benefit_obligations`, `payout_batches`/`payout_batch_items`. Exclui explicitamente qualquer produtor real de lançamento (ver §1).

## 1. Autoridade e limites

Este Blueprint materializa `docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md` (Onda 2, D15/D16, DEC-24/DEC-27/DEC-28) e `docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` §7 (KortexFlow), §8 (Staff Current Account & Payout), §9 (Client Wallet). Nenhuma decisão de produto já fechada é reaberta aqui — só as lacunas que o Migration Map deixou em aberto para o Blueprint fechar (nomeadamente: `kortex_account_balances` recalculável vs. projeção, e a reconciliação entre `kortex_accounts` por unidade e `client_wallets`/`staff_current_accounts` org-wide).

**Exclusão deliberada de escopo — esta Onda é fundação, não ativação:** nenhum produtor real de lançamento é construído aqui. `checkout_close` não é tocado; a pipeline "venda normal → ledger" (§7.3 do Master) continua sem existir na prática até uma Onda 2b futura ligar os produtores. Isso preserva a Decisão 4 do Migration Map ("o schema desta onda pode ser criado em paralelo à Onda 1... mas nenhum fluxo de captura real ativa em produção antes do ledger existir e o Gate 11 passar") sem expandir o raio de explosão desta Onda para incluir uma segunda modificação de `checkout_close` (risco equivalente ao HITL da fatia 004 da Onda 1). D18 (Subscription Engine) também não existe — `benefit_obligations` nasce como schema puro, sem produtor, mesmo padrão que `payment_intents.provider = 'internal'` usou na Onda 1 para "fundação pronta para produtor futuro".

`organization_id` continua sendo a fronteira primária de tenant. `unit_id` é fronteira operacional subordinada (Onda 0/DEC-28) aplicada a `kortex_accounts`, `kortex_ledger_transactions`, `kortex_ledger_entries`, `kortex_account_balances` (nível 1, por conta-unidade) e `payout_batches`/`payout_batch_items` — mas **não** a `client_wallets`, `staff_current_accounts` nem `benefit_obligations`, que são saldo/identidade da PESSOA (org-wide), consistente com a classificação já fechada no Migration Map. Este Blueprint não cria UI, não implementa o Subscription Engine (D18) nem os mecanismos de enforcement do Negative Guard (§10 do Master) além do que já está registrado como regra de produto.

## 2. Escopo de dados

| Objeto | Contrato técnico | Estado |
|---|---|---|
| `kortex_accounts` | Razão auxiliar E plano de contas na mesma tabela — por unidade (Migration Map, D28). `kind` fechado por `CHECK`: contas fixas (`cash`, `revenue_service`, `revenue_product`, `commission_expense`, `tip_liability`, `refund_expense`, `benefit_obligation_liability`) mais contas por entidade (`client_wallet`, `staff_current_account`) que multiplicam — uma linha por unidade em que a pessoa transacionou. `client_id`/`professional_id` nullable, FK composta tenant-safe (nunca `owner_type`/`owner_id` polimórfico — sem FK real), preenchido só quando `kind` é de entidade. | Novo |
| `kortex_ledger_transactions` | Cabeçalho de transação double-entry. `idempotency_key` obrigatório, reaproveita `private.idempotency_keys` (nenhuma tabela de idempotência nova). `unit_id` obrigatório (consistente com D28). | Novo |
| `kortex_ledger_entries` | Linhas double-entry, append-only (sem UPDATE/DELETE em produção — só `service_role`/RPC, RLS nunca concede escrita). `direction` (`debit`\|`credit`) + `amount_cents` sempre positivo (nunca valor assinado — evita a classe de bug "inverti o sinal"). `unit_id`/`organization_id` denormalizados da transação-pai (mesmo padrão de todo fato transacional deste schema). Único caminho de escrita: RPC `kortex_ledger_post` (§3). | Novo |
| `kortex_account_balances` | Projeção nível 1 — saldo por `kortex_accounts.id` (por conta-unidade), mantida **só** por trigger `AFTER INSERT` em `kortex_ledger_entries`. Nenhum grant de escrita direta a ninguém, nem a `service_role` fora do trigger — é sempre derivável recalculando `SUM(kortex_ledger_entries)` do zero (Gate 13 trivial por construção). | Novo (projeção) |
| `client_wallets` | Identidade + saldo agregado da PESSOA (org-wide) — **não** vive dentro de `kortex_accounts`. `id`, `organization_id`, `client_id` (FK real), `balance_cents`. Projeção nível 2: um segundo trigger, disparado quando `kortex_account_balances` muda numa linha `kind = 'client_wallet'`, soma todas as linhas daquele `client_id` (cruzando unidades) e mantém `balance_cents` aqui. Nenhuma escrita direta, mesma disciplina do nível 1. | Novo |
| `staff_current_accounts` | Mesmo padrão de `client_wallets`, para `professional_id`. Self-view: o próprio profissional só enxerga a própria linha (RLS, §7). | Novo |
| `benefit_obligations` | Org-wide (Migration Map). `client_id` (FK real), `source_type` (`CHECK`: `package`\|`plan`\|`corporate`\|`partner`), `source_reference` (texto livre — `plan`/`corporate`/`partner` não têm tabela própria ainda; FK real só para `package` deixaria a coluna inconsistente entre tipos), `total_cents`/`consumed_cents` (nunca `remaining_cents` guardado — derivado na leitura), `status` (`active`\|`expired`\|`exhausted`\|`cancelled`), `expires_at` nullable. **Nasce vazia — nenhum produtor nesta Onda (D18 não existe).** | Novo |
| `payout_batches` | Por unidade (Migration Map). Cabeçalho: `period_start`/`period_end`, `status` (`draft`\|`processing`\|`paid`\|`failed`), `created_at`/`closed_at`. **Nasce vazia — nenhum produtor nesta Onda** (repasse real depende de comissão real, que depende da Onda 2b). | Novo |
| `payout_batch_items` | Linhas de `payout_batches` — mesmo padrão cabeçalho+linhas de `orders`/`order_items` e de `kortex_ledger_transactions`/`entries`. `payout_batch_id`, `professional_id` (via `staff_current_accounts`), `amount_cents`, `status` próprio. | Novo |

## 3. Integridade e invariantes

**Único caminho de escrita no ledger.** `kortex_ledger_entries` não recebe `INSERT` de ninguém além da RPC nova `kortex_ledger_post(p_organization_id, p_actor_user_id, p_idempotency_key, p_unit_id, p_entries jsonb)` — grants trancados, mesmo padrão fail-closed de `deposit_holds`/`payment_intents` (Onda 1). A RPC valida `SUM(amount_cents WHERE direction='debit') = SUM(amount_cents WHERE direction='credit')` **antes** de inserir qualquer linha, atomicamente, dentro do mesmo bloco `plpgsql` — mesma disciplina de `checkout_close` validando `v_paid = v_total`. Não existe `CONSTRAINT TRIGGER` deferido (infraestrutura nova sem precedente neste schema); a garantia vem de "existe exatamente uma porta de entrada, e ela audita antes de escrever" — reversão financeira (§7.2 do Master) é só uma segunda chamada a `kortex_ledger_post` com as linhas espelhadas (nunca edição), sem precisar de RPC própria.

**Autorização (achado #3 do Red Team de desenho).** `kortex_ledger_post` exige `private.actor_has_role(p_organization_id, p_actor_user_id, array['owner','admin','manager'])` — mesma lista de papéis que já enxerga o ledger cru (§3, matriz RLS), nenhuma superfície nova. Esta Onda não expõe a RPC via nenhuma rota Express (não há produtor real, §1) — só pgTAP chama diretamente nesta fase; a checagem de papel já nasce pronta para quando uma Onda futura ligar um produtor real.

**Validação de tenant por linha (achado #2 do Red Team de desenho).** Antes de inserir qualquer entrada, `kortex_ledger_post` verifica, para cada `account_id` do payload, que a linha correspondente em `kortex_accounts` tem `organization_id = p_organization_id` — se qualquer `account_id` não pertencer à organização do chamador (ou não existir), a RPC inteira aborta sem inserir nada, mesmo padrão de "active service not found"/"professional not found" já usado em `checkout_close`. Nenhuma entrada é aceita para uma conta de unidade diferente de `p_unit_id` tampouco, salvo o caso de contas por entidade cujo `unit_id` é o de nascimento daquela linha (§3, criação sob demanda) — a RPC nunca escreve numa `kortex_accounts` de outra unidade que não `p_unit_id`.

**Criação de conta por entidade sob concorrência (achado #1 do Red Team de desenho).** A criação sob demanda de conta por entidade (`client_wallet`/`staff_current_account`, primeira postagem daquele `client_id`/`professional_id` naquela unidade) usa `INSERT ... ON CONFLICT (organization_id, unit_id, kind, client_id) DO NOTHING` (e o par equivalente para `professional_id`), seguido de `SELECT` da linha resultante — nunca um `SELECT` seguido de `INSERT` desprotegido. Duas postagens concorrentes para o mesmo cliente, na mesma unidade, pela primeira vez: uma cria a linha, a outra bate no `ON CONFLICT DO NOTHING` e simplesmente lê a linha que a primeira acabou de criar — nenhuma das duas falha, nenhuma cria duplicata.

**Projeção em cascata, nunca saldo paralelo (§9.3 do Master).** Dois níveis de trigger, cada um só lê o nível abaixo, nenhum aceita escrita direta: `kortex_ledger_entries` → (trigger 1) → `kortex_account_balances` (por `kortex_accounts.id`, por unidade) → (trigger 2, só quando a linha afetada é `kind IN ('client_wallet','staff_current_account')`) → `balance_cents` em `client_wallets`/`staff_current_accounts` (agregado, cruzando unidades daquela pessoa). Gate 13 (Wallet Drift) é um teste pgTAP que recalcula os dois níveis do zero a partir de `kortex_ledger_entries` e compara — qualquer divergência é bug de trigger, nunca edição manual (proibida por construção, sem grant de `UPDATE` a ninguém nessas três tabelas).

**Contas fixas nascem com a unidade, nunca sob demanda dentro da RPC de postagem.** Trigger `AFTER INSERT` em `units` cria as 7 linhas fixas de `kortex_accounts` (`cash`, `revenue_service`, `revenue_product`, `commission_expense`, `tip_liability`, `refund_expense`, `benefit_obligation_liability`) para a unidade nova — `kortex_ledger_post` só posta, nunca cria conta. Contas por entidade (`client_wallet`/`staff_current_account`) nascem sob demanda, na primeira postagem que referencia aquele `client_id`/`professional_id` naquela unidade (não há como pré-seedar — não se sabe antecipadamente quais clientes/profissionais vão transacionar em qual unidade).

**Matriz de autorização — RLS, 4 grupos (§7):**

| Grupo | SELECT | INSERT/UPDATE |
|---|---|---|
| `kortex_accounts`, `kortex_ledger_transactions`, `kortex_ledger_entries`, `kortex_account_balances` | owner/admin/manager (org-wide) — dado financeiro cru, mesmo padrão de `professional_service_commissions` (sem reception, sem professional) | Nenhum grant direto — só `kortex_ledger_post` (`SECURITY DEFINER`) |
| `staff_current_accounts` | owner/admin/manager (todas) + professional (só a própria linha, via `professionals.user_id = auth.uid()` — mesmo padrão de `professionals_select`, Fase 11) | Nenhum grant direto — só as duas triggers de projeção |
| `client_wallets` | owner/admin/manager/reception (mesma lista de `clients_select`) | Nenhum grant direto — só a trigger de projeção nível 2 |
| `benefit_obligations`, `payout_batches`, `payout_batch_items` | owner/admin/manager | Nenhum grant direto |

**Idempotência.** `kortex_ledger_post` reaproveita `private.idempotency_keys` (mesma tabela, mesmo padrão de `checkout_close`/`create_appointment`) — nenhuma tabela de idempotência nova.

## 4. Contrato físico de schema

### `kortex_accounts`
`id`, `organization_id` (FK `organizations`), `unit_id` (FK composta `units`), `kind` (`CHECK` em `cash`\|`revenue_service`\|`revenue_product`\|`commission_expense`\|`tip_liability`\|`refund_expense`\|`benefit_obligation_liability`\|`client_wallet`\|`staff_current_account`), `client_id` nullable (FK composta `clients`), `professional_id` nullable (FK composta `professionals`), `created_at`/`updated_at`. **Constraints:** `client_id`/`professional_id` nunca ambos preenchidos; preenchidos se e somente se `kind` for a entidade correspondente (`client_wallet` ⇒ `client_id` obrigatório, `professional_id` nulo; `staff_current_account` ⇒ inverso; contas fixas ⇒ ambos nulos). **Unicidade:** `(organization_id, unit_id, kind)` para contas fixas (uma por unidade); `(organization_id, unit_id, kind, client_id)` e `(organization_id, unit_id, kind, professional_id)` para contas por entidade (uma por pessoa por unidade).

### `kortex_ledger_transactions`
`id`, `organization_id`, `unit_id` (FK composta `units`), `idempotency_key` (via `private.idempotency_keys`, não coluna própria — a linha de idempotência já guarda a resposta cacheada), `description` text, `created_by` nullable (`auth.users`), `created_at`.

### `kortex_ledger_entries`
`id`, `organization_id`, `unit_id` (denormalizado da transação-pai), `transaction_id` (FK composta `kortex_ledger_transactions`), `account_id` (FK composta `kortex_accounts`), `direction` (`CHECK` em `debit`\|`credit`), `amount_cents` (`bigint`, `CHECK > 0`), `created_at`. Append-only: nenhuma policy de `UPDATE`/`DELETE`, nenhum grant para além de `service_role` (que só escreve via a RPC).

### `kortex_account_balances`
`account_id` (PK, FK composta `kortex_accounts`, um-para-um), `organization_id`, `unit_id`, `balance_cents` (`bigint`, pode ser negativo — ex.: `client_wallet` em fiado autorizado), `updated_at`. Mantida só pela trigger 1 (§3) — nenhuma policy de escrita para nenhum papel.

### `client_wallets`
`id`, `organization_id`, `client_id` (FK composta `clients`, único por `(organization_id, client_id)`), `balance_cents` (mantido pela trigger 2), `created_at`/`updated_at`.

### `staff_current_accounts`
`id`, `organization_id`, `professional_id` (FK composta `professionals`, único por `(organization_id, professional_id)`), `balance_cents` (mantido pela trigger 2), `created_at`/`updated_at`.

### `benefit_obligations`
`id`, `organization_id`, `client_id` (FK composta `clients`), `source_type` (`CHECK` em `package`\|`plan`\|`corporate`\|`partner`), `source_reference` text nullable, `total_cents` (`bigint`, `CHECK >= 0`), `consumed_cents` (`bigint`, `CHECK >= 0`, `CHECK <= total_cents`), `status` (`CHECK` em `active`\|`expired`\|`exhausted`\|`cancelled`), `expires_at` nullable, `created_at`/`updated_at`.

### `payout_batches`
`id`, `organization_id`, `unit_id` (FK composta `units`), `period_start`/`period_end` (`date`), `status` (`CHECK` em `draft`\|`processing`\|`paid`\|`failed`), `created_at`, `closed_at` nullable.

### `payout_batch_items`
`id`, `organization_id`, `payout_batch_id` (FK composta `payout_batches`), `professional_id` (FK composta `professionals`), `amount_cents` (`bigint`, `CHECK > 0`), `status` (`CHECK` em `pending`\|`paid`\|`failed`), `created_at`.

## 5. Compatibilidade e backfill

Toda mudança é aditiva — nenhuma tabela existente ganha coluna, constraint ou trigger novo, exceto `units`, que ganha a trigger `AFTER INSERT` de seed das 7 contas fixas (§3). Nenhum caller existente (rota, RPC) referencia qualquer uma das 8 tabelas novas — confirmado por leitura direta: nenhuma menção a `kortex_`/`client_wallets`/`staff_current_accounts`/`benefit_obligations`/`payout_batches` em `backend/src/` ou nas migrations anteriores a esta.

**Backfill obrigatório, inline na mesma migration aditiva** (mesmo padrão do backfill de `units`/`professional_units` na Onda 0): toda unidade que já existe em `staging`/local (criada pela Onda 0) precisa das 7 contas fixas retroativamente — sem isso, a primeira postagem sintética contra uma unidade pré-existente falharia por conta inexistente. O `INSERT` de backfill roda a mesma lógica da trigger, uma vez, contra `SELECT id, organization_id FROM units`.

## 6. Plano de execução e rollback

Toda a Onda é aditiva por construção — nenhuma tabela/RPC/função existente é alterada (nem `checkout_close`, nem `create_appointment`, nem nenhuma das RPCs da Onda 1). Rollback de qualquer migration desta Onda é: reverter a migration inteira — zero dado existente é tocado, então não há risco de perda além do próprio schema novo.

Esta Onda **passa pelo Fatiamento** (`$prd-to-issues`, DEC-33) antes de qualquer SQL. Fatias verticais candidatas, cada uma testável isoladamente (a decidir/ajustar na etapa de Fatiamento, não fechado aqui):

1. `kortex_accounts` — schema, `kind`/FK dupla, trigger de seed em `units` + backfill retroativo
2. `kortex_ledger_transactions`/`kortex_ledger_entries` + RPC `kortex_ledger_post` (valida double-entry, idempotente) + trigger de projeção nível 1 (`kortex_account_balances`)
3. `client_wallets`/`staff_current_accounts` + trigger de projeção nível 2 (agregado org-wide) + RLS self-view do profissional
4. `benefit_obligations` — schema puro, sem produtor
5. `payout_batches`/`payout_batch_items` — schema puro, sem produtor

Cada fatia segue `$tdd` e passa por `$kortex-qa-redteam` antes de integrar — mesmo processo da Onda 1.

## 7. Matriz RLS e contratos afetados

| Objeto | SELECT | INSERT/UPDATE |
|---|---|---|
| `kortex_accounts` | owner/admin/manager (org-wide) | Nenhum grant direto — só a trigger de seed/backfill (`service_role`) e a RPC de postagem, quando referenciar conta por entidade nova |
| `kortex_ledger_transactions`/`kortex_ledger_entries` | owner/admin/manager (org-wide) | Nenhum grant direto — só `kortex_ledger_post` (`SECURITY DEFINER`) |
| `kortex_account_balances` | owner/admin/manager (org-wide) | Nenhum grant — só a trigger 1 |
| `client_wallets` | owner/admin/manager/reception | Nenhum grant — só a trigger 2 |
| `staff_current_accounts` | owner/admin/manager (org-wide); professional (só a própria linha, self-view) | Nenhum grant — só a trigger 2 |
| `benefit_obligations`, `payout_batches`, `payout_batch_items` | owner/admin/manager | Nenhum grant direto |

Nenhum caller existente quebra: confirmado por `grep` que nenhuma rota Express, RPC ou teste atual referencia qualquer objeto desta Onda — são 8 tabelas inteiramente novas, sem consumidor hoje.

---

Depois de redigido, este documento segue para `$kortex-qa-redteam` (gate de desenho) antes de qualquer pedido de aprovação ao Platform Owner.
