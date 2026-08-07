## Parent Blueprint

`docs/waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md` (APROVADO, DEC-46), §2, §3.1, §3.8, §4.

## What to build

Cadastro de `staff_levels` (nível de carreira por organização — nome e ordem livres, org-wide, sem `unit_id`) e a coluna `professionals.staff_level_id` (ponteiro simples, nullable, `on delete restrict`, sem tabela de vigência temporal).

**Desvio de produto registrado, não silencioso:** o Master Briefing (`KORTEXOS_5_1_2_POLITICAS_DE_NEGOCIO.md` §6.1) declara nível "Obrigatório" — esta fatia mantém a coluna nullable de propósito (fundação sem ativação; `staff_levels` nasce vazia por organização, não há nível nenhum pra apontar até o owner cadastrar). Este desvio já foi aprovado explicitamente como parte da DEC-46 — ver Blueprint §3.1 para o texto completo.

Nenhuma cascata de resolução nasce nesta fatia — isso é a 019.

## Acceptance criteria

- [x] Migration aditiva cria `staff_levels` (`id`, `organization_id`, `name`, `rank`, `active`, `created_at`/`updated_at`) com unicidade `(organization_id, id)`, `(organization_id, name)`, `(organization_id, rank)`. `supabase/migrations/20260728010000_onda3_staff_levels_professional_assignment.sql`
- [x] Migration aditiva adiciona `professionals.staff_level_id` nullable, FK composta `(organization_id, staff_level_id) references staff_levels(organization_id, id) on delete restrict`. Mesma migration
- [x] Pre-flight check (DEC-44): confere `to_regclass('public.professionals') is not null` (e `organizations`, e que `staff_levels`/`staff_level_id` ainda não existem) antes de criar a FK nova
- [x] RLS `staff_levels`: SELECT `is_member`; INSERT/UPDATE `owner`/`admin`/`manager`; DELETE `owner`/`admin`
- [x] `staff_level_id` aceita `null` (profissional sem nível atribuído continua funcionando normalmente, nenhum `CHECK`/trigger força preenchimento)
- [x] Tentar apontar `staff_level_id` para um nível de outra organização falha por violação de FK composta (teste de cruzamento de tenant)
- [x] pgTAP: CRUD básico de `staff_levels` respeitando RLS por papel; `professionals.staff_level_id` aceita null e aceita nível válido da mesma org; rejeita nível de outra org; `DELETE` de nível referenciado por profissional é bloqueado (`on delete restrict`). `supabase/tests/rls_staff_levels_test.sql` — 19/19 assertions, suíte completa 598/598 (`supabase test db`, evidência bruta: `Result: PASS`), sem regressão nos 35 arquivos pré-existentes

## Blocked by

None - can start immediately (independente da fatia 017)

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `staff_levels`/`professionals.staff_level_id`)
- §3.1 (ponteiro simples, sem vigência temporal, desvio "Obrigatório" aprovado via DEC-46)
- §3.8 (matriz RLS)
- §4 (contrato físico de schema)
