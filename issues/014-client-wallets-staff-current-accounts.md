## Parent Blueprint

`docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_2_DRAFT.md` (DEC-41), §2, §3, §4, §7.

## What to build

Schema de `client_wallets` e `staff_current_accounts` — identidade + saldo agregado ORG-WIDE da pessoa (nunca por unidade, ao contrário de `kortex_accounts`). Trigger nível 2: disparada quando `kortex_account_balances` (nível 1, fatia 013) muda numa linha `kind IN ('client_wallet', 'staff_current_account')`, soma todas as linhas daquele `client_id`/`professional_id` cruzando unidades e mantém `balance_cents` aqui. Nenhuma escrita direta, mesma disciplina do nível 1.

RLS: `client_wallets` — owner/admin/manager/reception (mesma lista de `clients_select`). `staff_current_accounts` — owner/admin/manager (todas) + professional (só a própria linha, via `professionals.user_id = auth.uid()`, mesmo padrão de `professionals_select`, Fase 11 — Gate 02, Staff Privacy).

## Acceptance criteria

- [ ] Migration aditiva cria `client_wallets` (`id`, `organization_id`, `client_id` FK real, `balance_cents`) e `staff_current_accounts` (idem, `professional_id`), únicas por `(organization_id, client_id)`/`(organization_id, professional_id)`
- [ ] Trigger nível 2 mantém `balance_cents` correto quando `kortex_account_balances` muda numa conta `client_wallet`/`staff_current_account` — soma corretamente entradas de múltiplas unidades da mesma pessoa
- [ ] Nenhuma escrita direta possível em `balance_cents` (RLS/grants confirmam) — sempre derivado do nível 1
- [ ] RLS `client_wallets`: owner/admin/manager/reception veem; nenhum outro papel
- [ ] RLS `staff_current_accounts`: owner/admin/manager veem todas; profissional só a própria linha (self-view); reception não vê nenhuma
- [ ] pgTAP: Gate 13 — recalcula os dois níveis do zero a partir de `kortex_ledger_entries`, compara com `client_wallets`/`staff_current_accounts`, sempre bate; cliente/profissional transacionando em 2 unidades diferentes soma corretamente no agregado; self-view do profissional confirmado (não vê a conta de outro)

## Blocked by

- Blocked by `issues/013-kortex-ledger-post-double-entry.md` (a trigger nível 2 depende da projeção nível 1 já existir)

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `client_wallets`/`staff_current_accounts`)
- §3 (projeção em cascata nível 2, matriz RLS — 4 grupos)
- §4 (contrato físico de schema)
- §7 (matriz RLS completa)
