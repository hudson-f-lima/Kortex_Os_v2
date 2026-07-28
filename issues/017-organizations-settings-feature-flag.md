## Parent Blueprint

`docs/waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md` (APROVADO, DEC-46), §3.7, §4.

## What to build

Coluna nova `organizations.settings jsonb not null default '{}'::jsonb` — fundação de Dark Launching por Feature Flag (DEC-44, otimização 1), reaproveitável por qualquer Onda futura, não exclusiva desta. Nenhuma chave é lida por nenhuma rota nesta fatia — só a coluna nasce, pronta para as fatias 018-020 declararem suas próprias chaves (`staff_levels_enabled`, `sale_commission_enabled`).

Escrita da chave restrita a `owner`/`admin` (mesma allowlist de configuração organizacional sensível já usada por `membership_set`).

## Acceptance criteria

- [x] Migration aditiva adiciona `organizations.settings jsonb not null default '{}'::jsonb` — nenhuma organização existente quebra (default cobre todas as linhas atuais sem backfill explícito). `supabase/migrations/20260728000000_onda3_organizations_settings_feature_flag.sql`
- [x] Pre-flight check (DEC-44): bloco `do $$ begin ... end $$` confere `to_regclass('public.organizations') is not null` e que a coluna `settings` ainda não existe antes do `ALTER TABLE`, com `raise exception` explícito se a pré-condição falhar
- [x] RLS/policy de `organizations` já existente cobre `settings` sem policy nova (é só uma coluna a mais na mesma linha) — confirmado por leitura direta (`organizations_select`/`organizations_update`, `mvp_baseline.sql`, row-level, não column-level) e por teste
- [x] pgTAP: organização nova nasce com `settings = '{}'`; `owner`/`admin` conseguem `UPDATE settings`; papel sem essa allowlist recebe rejeição (mesmo padrão de teste já usado para `membership_set`). `supabase/tests/rls_organizations_settings_test.sql` — 4/4 assertions, suíte completa 579/579 (`supabase test db`, evidência bruta: `Result: PASS`)

## Blocked by

None - can start immediately

## Seções do Blueprint endereçadas

- §3.7 (Feature Flag e Dark Launching, DEC-44)
- §4 (contrato físico — extensão de `organizations`)
- §6 (Pre-flight Check obrigatório por migration, DEC-44)
