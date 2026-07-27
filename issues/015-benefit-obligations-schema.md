## Parent Blueprint

`docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_2_DRAFT.md` (DEC-41), §2, §4.

## What to build

Schema puro de `benefit_obligations` — org-wide, sem produtor nesta Onda (D18/Subscription Engine não existe). `client_id` (FK real), `source_type` (`CHECK` em `package`/`plan`/`corporate`/`partner`), `source_reference` (texto livre, não FK — `plan`/`corporate`/`partner` não têm tabela própria ainda), `total_cents`/`consumed_cents` (nunca `remaining_cents` guardado), `status` (`active`/`expired`/`exhausted`/`cancelled`), `expires_at` nullable.

Nenhuma linha é inserida por nenhum fluxo nesta fatia — é fundação pura, pronta para receber um produtor quando D18 (ou equivalente) existir.

## Acceptance criteria

- [ ] Migration aditiva cria `benefit_obligations` com as constraints descritas (`total_cents >= 0`, `consumed_cents >= 0`, `consumed_cents <= total_cents`, `status`/`source_type` fechados por `CHECK`)
- [ ] RLS: SELECT só owner/admin/manager; nenhum INSERT/UPDATE direto de `authenticated`/`anon`
- [ ] pgTAP: constraints rejeitam `consumed_cents > total_cents`, `source_type`/`status` inválidos; RLS confirma lockdown; nenhum teste de "produtor" (não existe nesta fatia)

## Blocked by

None - can start immediately (independente das demais fatias desta Onda; só depende de `clients`, já existente)

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `benefit_obligations`)
- §4 (contrato físico de schema)
