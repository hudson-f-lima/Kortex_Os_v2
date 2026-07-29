---
title: "Issue 026 - Resources & Resource Locks"
status: "IMPLEMENTED_LOCAL"
stage: "ISSUE"
governance_ref: ["DEC-49"]
upstream_doc: "docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md"
last_updated: "2026-07-29"
---

## Parent Blueprint

`docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md` (APROVADO, DEC-49), §2, §3.3, §3.8, §4.

## What to build

`resources` (cadastro de recurso físico por unidade — sala/cadeira/equipamento, capacidade opcional) e `resource_locks` (reserva de um recurso num intervalo — ligada a um `appointment` ou bloqueio manual/manutenção), com a mesma disciplina de concorrência otimista de `appointments` (Master, D11: CRÍTICO). Inclui as RPCs `resource_lock_create`/`resource_lock_release` com contrato completo.

## Acceptance criteria

- [x] Migration aditiva cria `resources` (`id`, `organization_id`, `unit_id`, `name`, `resource_type`, `capacity` nullable, `active`, `created_by`/`created_at`, `updated_by`/`updated_at`) com unicidade `(organization_id, unit_id, lower(trim(name)))` (índice único parcial, não constraint inline — expressão não é permitida em `UNIQUE(...)` de tabela) e `(organization_id, id, unit_id)` (habilita FK composta de `resource_locks`). `supabase/migrations/20260729040000_onda4_resources_resource_locks.sql`
- [x] Migration aditiva cria `resource_locks` (`id`, `organization_id`, `unit_id`, `resource_id`, `appointment_id` nullable, `lock_reason`, `starts_at`/`ends_at`, `status`, `version bigint not null default 1`, `created_by`/`created_at`, `released_by`/`released_at`) com `check ((lock_reason = 'appointment') = (appointment_id is not null))`, FK composta de 3 colunas para `resources` e para `appointments` (via `appointments_org_id_unit_unique`), exclusion `EXCLUDE USING gist (organization_id with =, resource_id with =, tstzrange(starts_at, ends_at, '[)') with &&) WHERE (status = 'active')`. Mesma migration
- [x] Trigger `BEFORE UPDATE` (`private.enforce_resource_lock_version()`) incrementa `version`
- [x] RPC `public.resource_lock_create(...)` — `security definer`, idempotente via `private.idempotency_keys` (mesmo padrão de `checkout_close`: hash sha256 dos parâmetros estruturais — `resource_id`/`lock_reason`/`appointment_id`/`starts_at`/`ends_at`, não a nota `reason` livre — `insert...on conflict do nothing` + `select...for update`), autorização `owner`/`admin`/`manager`/`reception` (reception só na própria unidade); para `lock_reason = 'appointment'` confere que `appointment_id` pertence à mesma `(organization_id, unit_id)`; valida `p_reason` livre até 500 caracteres; traduz violação de exclusion constraint (`23P01`) para erro de domínio
- [x] RPC `public.resource_lock_release(...)` — compara `p_version` recebido contra o atual e rejeita com `errcode = 'P0004'` se divergir (fecha a lacuna de concorrência otimista do achado do Red Team — o incremento de `version` sozinho não é suficiente)
- [x] Pre-flight check (DEC-44) na migration
- [x] RLS: `resources` SELECT via `can_access_fact_unit(org: owner/admin/manager; unit: reception/professional)`, INSERT/UPDATE `owner`/`admin`/`manager`, sem DELETE (desativação via `active=false`); `resource_locks` SELECT mesmo padrão, sem grant direto de INSERT/UPDATE/DELETE (só via RPC — confirmado por teste: nem `owner1` consegue `INSERT` direto)
- [x] pgTAP: criar lock para recurso já ocupado no intervalo é rejeitado (`23P01`); `resource_lock_release` com `p_version` desatualizado é rejeitado (`P0004`); `resource_lock_release` com `p_version` correto libera e incrementa `version`; segunda liberação é rejeitada; lock manual (`lock_reason = 'maintenance'`) sem `appointment_id` é aceito; lock `lock_reason = 'appointment'` sem `appointment_id` é rejeitado; `p_reason` acima de 500 caracteres é rejeitado; chamada idempotente repetida (mesma `idempotency_key`, mesmo payload estrutural) retorna o mesmo lock em vez de duplicar; mesma chave com payload estrutural diferente é rejeitada; ator sem membership ativa é rejeitado (fail-closed); RLS unit-aware em `resources`/`resource_locks`. `supabase/tests/rls_resources_resource_locks_test.sql` — 20/20 assertions, suíte completa 764/764 (`supabase test db`, evidência bruta: `Result: PASS`), sem regressão

## Blocked by

None - can start immediately (depende só de `units`/`appointments`, já existentes)

## Seções do Blueprint endereçadas

- §2 (escopo de dados)
- §3.3 (concorrência otimista completa, bloqueio manual)
- §3.8 (matriz RLS)
- §4 (contrato físico + contrato completo das RPCs)

## Correção pós-implementação (2026-07-29, Red Team de implementação)

`resource_lock_release` aceitava uma segunda liberação: comparava só `version`, e a version JÁ atualizada (devolvida pela primeira chamada) passava a checagem sem erro, reescrevendo `released_by`/`released_at` — inclusive por um ator diferente do que liberou originalmente. Corrigido: exige `status = 'active'` antes de aceitar a liberação. Auditoria final de fix também validou `p_reason` livre para remover o achado de `db lint` sem alterar o hash estrutural de idempotência. Evidência atualizada: **20/20** assertions, suíte completa **764/764**.
