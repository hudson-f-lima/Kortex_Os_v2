## Parent Blueprint

`docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_2_DRAFT.md` (DEC-41), §2, §3, §4, §5.

## What to build

Schema de `kortex_accounts` — razão auxiliar E plano de contas na mesma tabela, por unidade. `kind` fechado por `CHECK`: contas fixas (`cash`, `revenue_service`, `revenue_product`, `commission_expense`, `tip_liability`, `refund_expense`, `benefit_obligation_liability`) mais contas por entidade (`client_wallet`, `staff_current_account`) que multiplicam por pessoa/unidade. `client_id`/`professional_id` nullable com FK composta tenant-safe (nunca `owner_type`/`owner_id` polimórfico).

Trigger `AFTER INSERT` em `units` cria as 7 contas fixas para toda unidade nova. Backfill retroativo, inline na mesma migration aditiva, cria as 7 contas fixas para toda unidade que já existe hoje em `staging`/local.

Contas por entidade (`client_wallet`/`staff_current_account`) **não** nascem nesta fatia — a criação sob demanda delas depende da fatia 013 (`kortex_ledger_post`), que é quem primeiro as referencia.

## Acceptance criteria

- [ ] Migration aditiva cria `kortex_accounts` com `kind`, FK dupla nullable (`client_id`/`professional_id`) e as constraints de par (nenhum dos dois preenchido pra conta fixa; exatamente um preenchido pra conta por entidade, consistente com `kind`)
- [ ] Unicidade: `(organization_id, unit_id, kind)` pra contas fixas; `(organization_id, unit_id, kind, client_id)` e `(organization_id, unit_id, kind, professional_id)` pra contas por entidade
- [ ] Trigger `AFTER INSERT` em `units` cria as 7 contas fixas para toda unidade nova
- [ ] Backfill, na mesma migration, cria as 7 contas fixas pra toda unidade já existente
- [ ] RLS: SELECT só owner/admin/manager (dado financeiro cru, sem reception/professional); nenhum INSERT/UPDATE direto de `authenticated`/`anon`
- [ ] pgTAP: as 7 contas fixas existem pra unidade nova e pra unidade pré-existente (backfill); `CHECK` de par client_id/professional_id rejeita configuração inválida; unicidade rejeita duplicata; RLS confirma lockdown

## Blocked by

None - can start immediately

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `kortex_accounts`)
- §3 (contas fixas nascem com a unidade, matriz RLS)
- §4 (contrato físico de schema)
- §5 (backfill retroativo)
