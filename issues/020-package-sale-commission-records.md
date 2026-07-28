## Parent Blueprint

`docs/waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md` (APROVADO, DEC-46), §2, §3.4, §3.5, §3.6, §3.8, §4.

## What to build

`packages.sale_commission_type`/`sale_commission_value` (campo próprio do pacote, DEC-15) + `private.resolve_sale_commission(p_organization_id, p_package_id)` (lê os 2 campos, sem cascata) + `commission_sale_records` (uma linha por comissão de venda reconhecida, `unit_id` denormalizado via FK composta de 3 colunas para `orders`, `status` `accrued`/`clawed_back`, `kortex_ledger_transaction_id` nullable reservado para ativação futura do ledger) + RPC `commission_sale_record_create(p_organization_id, p_actor_user_id, p_idempotency_key, p_order_id, p_package_id, p_seller_professional_id)`.

**Sem call site automático nesta fatia.** O payload de `checkout_close` não carrega "quem vendeu o pacote" (distinto de quem executa cada componente) — nenhuma rota Express chama esta RPC ainda; fica para follow-up com decisão de UI própria (Blueprint §3.4). Testável isoladamente via pgTAP com `p_seller_professional_id` explícito.

**Sem postagem no ledger.** `commission_sale_record_create` não chama `kortex_ledger_post` — a Onda 2 segue sem produtor real e `NO-GO` para `staging`/`main` (Blueprint §3.5).

**Contrato de idempotência (importante, não é constraint de banco):** não existe unicidade de chave de negócio nesta tabela — vender o mesmo pacote 2× no mesmo pedido pelo mesmo vendedor é cenário legítimo (checkout_close não deduplica). Exclusividade de gravação é 100% responsabilidade de `p_idempotency_key`; quando o call site futuro existir, ele precisa compor uma chave distinta por unidade de pacote vendida (ex.: `{order_id}:{package_id}:{índice}`).

## Acceptance criteria

- [ ] Migration aditiva adiciona `packages.sale_commission_type`/`sale_commission_value` (nullable, par obrigatório, mesmo teto de 10000 basis points)
- [ ] Migration aditiva cria `commission_sale_records` (`id`, `organization_id`, `unit_id`, `order_id`, `package_id`, `professional_id`, `commission_type`, `commission_value`, `commission_cents not null`, `status default 'accrued'`, `kortex_ledger_transaction_id` nullable, `created_at`/`updated_at`) — **sem** unicidade de chave de negócio (só `id` PK)
- [ ] FK de `order_id`: 3 colunas `(organization_id, order_id, unit_id) references orders(organization_id, id, unit_id) on delete restrict` (mesmo padrão de `order_items_org_order_unit_fk`) — não FK simples de 2 colunas
- [ ] FKs de `package_id`/`professional_id`/`kortex_ledger_transaction_id`: compostas, `on delete restrict`
- [ ] Pre-flight check (DEC-44): confere `to_regclass('public.packages') is not null` e que `orders_org_id_unit_unique` já existe (Onda 0) antes de criar as FKs
- [ ] `private.resolve_sale_commission()` e `commission_sale_record_create()` criadas com `set search_path = pg_catalog, public, private` (achado do red team — toda função `security definer` do projeto tem isso)
- [ ] `resolve_sale_commission`: pacote sem `sale_commission_type` configurado retorna `null`; pacote configurado retorna o valor exato gravado (sem cascata)
- [ ] `commission_sale_record_create`: valida `actor_has_role(owner/admin/manager/reception)`; valida `order` existe, pertence à org, está `closed`; valida `package`/`professional` existem e pertencem à org; se comissão resolvida for `null`, retorna `{"skipped": true, ...}` sem inserir linha; senão calcula `commission_cents` (mesma fórmula percentage/fixed de `checkout_close`) e insere
- [ ] `commission_sale_record_create` é idempotente via `private.idempotency_keys` — replay da mesma chave retorna a resposta cacheada
- [ ] pgTAP: vender o "mesmo" pacote 2× no mesmo pedido (2 chamadas com `p_idempotency_key` distintos) grava 2 linhas em `commission_sale_records`, nenhuma rejeitada por unicidade
- [ ] pgTAP: cruzamento de tenant — `order_id`/`package_id`/`professional_id` de outra organização são rejeitados
- [ ] RLS `commission_sale_records`: SELECT `owner`/`admin`/`manager` (org-wide) + profissional vendedor self-view (`professionals.user_id = auth.uid()`); nenhum INSERT/UPDATE/DELETE direto de `authenticated`/`anon`
- [ ] Confirmar por leitura direta: `checkout_close` continua sem nenhuma chamada nova a `commission_sale_record_create` ou `resolve_sale_commission`

## Blocked by

None - independente das fatias 018/019 (não depende de `staff_levels`), mas pode rodar em paralelo ou depois

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `commission_sale_records`/`resolve_sale_commission`/`commission_sale_record_create`)
- §3.4 (achado "quem vendeu" não existe no payload; decisão de não ter call site automático)
- §3.5 (sem postagem no ledger)
- §3.6 (clawback não automatizado)
- §3.8 (matriz RLS, self-view do vendedor)
- §4 (contrato físico de schema, FK de 3 colunas, unicidade removida)
