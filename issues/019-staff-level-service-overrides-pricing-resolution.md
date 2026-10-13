## Parent Blueprint

`docs/waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md` (APROVADO, DEC-46), §0, §2, §3.2, §3.3, §3.8, §4.

## What to build

`staff_level_service_overrides` — override de preço/duração/comissão por nível×serviço, mesma forma de `professional_service_capabilities` (nível 1 da cascata) mas para o nível 2. Carrega os 3 eixos (bate com Master §6.1), mas só preço/duração ganham função de resolução nesta fatia.

`private.resolve_service_pricing(p_organization_id, p_professional_id, p_service_id)` — cascata `coalesce`: override profissional×serviço (`professional_service_capabilities`) → override nível×serviço (`staff_level_service_overrides`) → base do serviço (`services`). Equivalente de `resolve_commission()` para preço/tempo. **Sem call site** — não é chamada por `checkout_close`/`create_appointment` nesta fatia (achado §0 do Blueprint: mesmo o override de nível 1 de preço nunca foi ativado em `checkout_close`; duração já está ativa via `professional_service_capabilities` mas a extensão pro nível 2 fica fora também, decisão de sequenciamento, não esquecimento).

Comissão por nível fica gravada na tabela mas **não** é consultada por `private.resolve_commission()` — essa função permanece intocada (Migration Map §4 decisão 2, não reaberta aqui).

## Acceptance criteria

- [x] Migration aditiva cria `staff_level_service_overrides` (`id`, `organization_id`, `staff_level_id`, `service_id`, `duration_override_minutes` nullable `check between 5 and 1440`, `price_override_cents` nullable `check >= 0`, `commission_type`/`commission_value` nullable com par obrigatório e teto de 10000 basis points, `created_at`/`updated_at`). `supabase/migrations/20260728020000_onda3_staff_level_service_overrides_pricing_resolution.sql`
- [x] Unicidade `(organization_id, staff_level_id, service_id)`; FKs compostas para `staff_levels` e `services`, ambas `on delete restrict`
- [x] Índice `staff_level_service_overrides_service_idx on (organization_id, service_id)` (achado do red team de desenho — espelha `professional_service_capabilities_service_idx` em forma; sem `where active`, já que esta tabela não tem coluna `active`, ver comentário na migration)
- [x] Pre-flight check (DEC-44): confere `to_regclass('public.staff_levels') is not null` (e `services`, `professional_service_capabilities`) antes de criar a FK composta
- [x] `private.resolve_service_pricing()` criada, `stable security definer set search_path = pg_catalog, public, private`, `revoke all from public, anon, authenticated`
- [x] pgTAP de `resolve_service_pricing`: sem nenhum override, retorna preço/duração base do serviço; com só override de nível, usa o do nível; com override profissional×serviço E de nível, o profissional×serviço vence (mais específico); profissional sem `staff_level_id` cai direto no nível 3 (base)
- [x] RLS `staff_level_service_overrides`: SELECT `owner`/`admin`/`manager` (sem `reception` — carrega comissão, tratamento mais estrito que `professional_service_capabilities`); INSERT/UPDATE `owner`/`admin`/`manager`; DELETE `owner`/`admin`
- [x] Confirmar por leitura direta (teste de regressão, não só leitura): `checkout_close`/`create_appointment` continuam funcionando exatamente como hoje — nenhuma chamada nova a `resolve_service_pricing` foi introduzida em nenhum dos dois. `supabase/tests/rpc_resolve_service_pricing_test.sql` — 22/22 assertions, suíte completa 620/620 (`supabase test db`, evidência bruta: `Result: PASS`), `rpc_checkout_close_test.sql`/`rpc_appointments_test.sql` inalterados e verdes

## Blocked by

- Blocked by `issues/018-staff-levels-professional-assignment.md` (`staff_level_id` precisa existir em `professionals`)

## Seções do Blueprint endereçadas

- §0 (achado pré-existente — preço nunca ativado, duração já ativa no nível 1)
- §2 (escopo de dados de `staff_level_service_overrides`/`resolve_service_pricing`)
- §3.2 (cascata de preço/tempo sem ativação)
- §3.3 (comissão por nível gravada, não consumida — `resolve_commission()` intocada)
- §3.8 (matriz RLS, nota sobre tratamento financeiro mais estrito)
- §4 (contrato físico de schema)
