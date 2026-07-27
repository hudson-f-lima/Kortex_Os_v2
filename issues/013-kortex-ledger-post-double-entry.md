## Parent Blueprint

`docs/waves/onda-2-kortexflow-ledger/KORTEXOS_5_1_2_BLUEPRINT_ONDA_2.md` (DEC-41), §2, §3, §4.

## What to build

Schema de `kortex_ledger_transactions` (cabeçalho, `idempotency_key` via `private.idempotency_keys` já existente, `unit_id`) e `kortex_ledger_entries` (linhas append-only, `direction`/`amount_cents` sempre positivo, `unit_id`/`organization_id` denormalizados). RPC nova `kortex_ledger_post(p_organization_id, p_actor_user_id, p_idempotency_key, p_unit_id, p_entries jsonb)` — única porta de escrita em `kortex_ledger_entries`, valida `SUM(debit) = SUM(credit)` antes de inserir, atomicamente.

`kortex_ledger_post` também é responsável pela criação sob demanda de conta por entidade (`client_wallet`/`staff_current_account`) referenciada pela primeira vez, usando `INSERT ... ON CONFLICT DO NOTHING` + `SELECT` (achado #1 do Red Team de desenho — nunca `SELECT` seguido de `INSERT` desprotegido). Valida que todo `account_id` do payload pertence a `p_organization_id` (achado #2) e exige `actor_has_role(owner/admin/manager)` (achado #3).

Trigger nível 1: `AFTER INSERT` em `kortex_ledger_entries` mantém `kortex_account_balances` (projeção por `kortex_accounts.id`, nunca escrita direta).

Nenhuma rota Express chama `kortex_ledger_post` nesta fatia — sem produtor real (Blueprint §1). Só pgTAP.

## Acceptance criteria

- [ ] Migration aditiva cria `kortex_ledger_transactions`, `kortex_ledger_entries` e `kortex_account_balances`, todas append-only/projeção (sem grant de UPDATE/DELETE a ninguém)
- [ ] `kortex_ledger_post` rejeita um conjunto de linhas onde `SUM(debit) != SUM(credit)`, sem inserir nada
- [ ] `kortex_ledger_post` rejeita `account_id` que não pertence a `p_organization_id` (achado #2), sem inserir nada
- [ ] `kortex_ledger_post` exige `owner`/`admin`/`manager` (achado #3) — outro papel recebe `42501`
- [ ] Duas chamadas concorrentes de `kortex_ledger_post` referenciando a mesma conta por entidade pela primeira vez não duplicam nem falham (achado #1) — `ON CONFLICT DO NOTHING` + `SELECT`
- [ ] `kortex_ledger_post` é idempotente via `private.idempotency_keys` — replay da mesma chave retorna a resposta cacheada, não reprocessa
- [ ] Trigger nível 1 mantém `kortex_account_balances` correto a cada `INSERT` em `kortex_ledger_entries` — nenhuma escrita direta possível (RLS/grants confirmam)
- [ ] pgTAP: Gate 13 (reconstrução) — soma `kortex_ledger_entries` do zero, compara com `kortex_account_balances`, sempre bate
- [ ] Teste de integração backend: nenhum — sem rota Express nesta fatia (sem produtor real)

## Blocked by

- Blocked by `issues/012-kortex-accounts-chart-of-accounts.md` (postagem referencia `kortex_accounts`)

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `kortex_ledger_transactions`/`entries`/`kortex_account_balances`)
- §3 (porta única de escrita, autorização, validação de tenant, concorrência — os 3 achados do Red Team)
- §4 (contrato físico de schema)
