## Parent Blueprint

`docs/waves/onda-2-kortexflow-ledger/KORTEXOS_5_1_2_BLUEPRINT_ONDA_2.md` (DEC-41), §2, §4.

## What to build

Schema puro de `payout_batches` (cabeçalho, por unidade — `period_start`/`period_end`, `status`: `draft`/`processing`/`paid`/`failed`) e `payout_batch_items` (linhas — `payout_batch_id`, `professional_id` via `staff_current_accounts`, `amount_cents`, `status` próprio: `pending`/`paid`/`failed`), mesmo padrão cabeçalho+linhas de `orders`/`order_items`.

Sem produtor nesta Onda — repasse real depende de comissão real, que depende da Onda 2b (ativação). Fundação pura.

## Acceptance criteria

- [ ] Migration aditiva cria `payout_batches` e `payout_batch_items` com as constraints descritas (`amount_cents > 0`, `status` fechado por `CHECK` nas duas tabelas)
- [ ] `payout_batch_items.professional_id` referencia `staff_current_accounts` corretamente (via FK composta tenant-safe)
- [ ] RLS: SELECT só owner/admin/manager, nas duas tabelas; nenhum INSERT/UPDATE direto de `authenticated`/`anon`
- [ ] pgTAP: constraints rejeitam valores/`status` inválidos; RLS confirma lockdown; nenhum teste de "produtor" (não existe nesta fatia)

## Blocked by

- Blocked by `issues/014-client-wallets-staff-current-accounts.md` (`payout_batch_items.professional_id` referencia `staff_current_accounts`)

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `payout_batches`/`payout_batch_items`)
- §4 (contrato físico de schema)
