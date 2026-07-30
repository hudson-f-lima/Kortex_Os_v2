---
title: "Issue 024 - Calendar Holidays, Exceptions & Time Off"
status: "IMPLEMENTED_LOCAL"
stage: "ISSUE"
governance_ref: ["DEC-49"]
upstream_doc: "docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md"
last_updated: "2026-07-29"
---

## Parent Blueprint

`docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md` (APROVADO, DEC-49), §2, §3.5, §3.8, §4.

## What to build

`calendar_holidays` (feriado nacional/estadual/municipal/custom, escopo empresa ou unidade, flag `unit_opens`), `calendar_exceptions` (consolida 3 dos 8 objetos de política do Master §2.2 — exceção pontual autorizada, fechamento excepcional não-feriado, abertura excepcional — via discriminador `exception_type`) e `calendar_time_off` (folga/férias do profissional, escopo profissional-wide, também cobre "bloqueios pontuais" do lado profissional).

`calendar_holidays` nasce vazia, sem seed de calendário nacional — cadastro 100% manual (decisão fechada por interview, Blueprint §3.5).

**Ajuste feito durante a implementação:** `calendar_time_off` não tem `unit_id` próprio (profissional pode atuar em mais de uma unidade), então `private.can_access_fact_unit` não serve para o RLS dela — comparação com `unit_id` nulo nunca é verdadeira. Criada `private.can_access_professional_time_off(p_organization_id, p_professional_id)`, mesmo padrão `security definer` de `can_access_fact_unit`, checando se o profissional tem vínculo ativo com a mesma unidade da membership de quem consulta. Mesmo cuidado aplicado a `calendar_holidays`: `unit_id` nullable (feriado org-wide) quebraria `can_access_fact_unit` do mesmo jeito, então o RLS usa uma condição própria (`unit_id is null and is_member(...)` OR `can_access_fact_unit(...)`).

## Acceptance criteria

- [x] Migration aditiva cria `calendar_holidays` (`id`, `organization_id`, `unit_id` nullable, `holiday_date`, `name`, `holiday_type`, `unit_opens`, `created_by`/`created_at`, `updated_by`/`updated_at`) com 2 índices únicos parciais (`(organization_id, holiday_date) where unit_id is null` e `(organization_id, unit_id, holiday_date) where unit_id is not null`) — não sentinela mágico. `supabase/migrations/20260729020000_onda4_calendar_holidays_exceptions_time_off.sql`
- [x] Migration aditiva cria `calendar_exceptions` (`id`, `organization_id`, `exception_type`, `scope`, `unit_id`, `professional_id` nullable, `starts_at`/`ends_at`, `is_open`, `reason`, `authored_by`, `authorized_by` nullable) com `check (scope = 'professional') = (professional_id is not null)`, `check (exception_type <> 'punctual_override') or (authorized_by is not null)`, e checks adicionais de par `exception_type`/`is_open` (achado próprio: `exceptional_closure` sempre `is_open=false`, `exceptional_opening` sempre `is_open=true`, não confiar em input livre). Mesma migration
- [x] Migration aditiva cria `calendar_time_off` (`id`, `organization_id`, `professional_id`, `starts_at`/`ends_at`, `reason` nullable, `created_by`/`created_at`) com exclusion `EXCLUDE USING gist (organization_id with =, professional_id with =, tstzrange(starts_at, ends_at, '[)') with &&)`. Mesma migration
- [x] Pre-flight check (DEC-44) na migration
- [x] RLS das 3 tabelas: papéis org-wide sempre veem; papéis unit-scoped veem por unidade (via `can_access_fact_unit` em `calendar_exceptions`; via condições próprias — `security definer` dedicada — em `calendar_holidays`/`calendar_time_off`, que não têm `unit_id` obrigatório na linha); INSERT `owner`/`admin`/`manager`; `calendar_holidays` aceita UPDATE (`owner`/`admin`/`manager`)/DELETE (`owner`/`admin`); `calendar_exceptions`/`calendar_time_off` sem grant de UPDATE/DELETE
- [x] Nenhuma linha nasce pré-carregada em `calendar_holidays` (migration não faz nenhum `INSERT`)
- [x] pgTAP: feriado org-wide e feriado por unidade coexistem sem violar unicidade; segundo feriado org-wide na mesma data é rejeitado (`23505`); `punctual_override` sem `authorized_by` é rejeitado; par `exception_type`/`is_open` incoerente é rejeitado; `scope = professional` sem `professional_id` é rejeitado; duas folgas sobrepostas do mesmo profissional são rejeitadas pela exclusion constraint (`23P01`); profissional de unidade A não lê feriado/exceção/folga da unidade B (ou de profissional só vinculado à unidade B); reception não insere/atualiza/deleta feriado; manager não deleta feriado (só owner/admin). `supabase/tests/rls_calendar_holidays_exceptions_time_off_test.sql` — 22/22 assertions, suíte completa 705/705 (`supabase test db --local supabase/tests`, evidência bruta: `Result: PASS`), sem regressão

## Blocked by

None - can start immediately (independente da fatia 023)

## Seções do Blueprint endereçadas

- §2 (escopo de dados)
- §3.5 (feriados manuais, sem seed)
- §3.8 (matriz RLS)
- §4 (contrato físico)

## Correção pós-implementação (2026-07-29, Red Team de implementação)

`calendar_exceptions.professional_id` tinha FK só para `professionals(organization_id, id)` — confirmava que o profissional existe na organização, mas não que ele tem vínculo com a `unit_id` daquela exceção específica. Corrigido com FK composta adicional `(organization_id, professional_id, unit_id) references professional_units(...)` — como `professional_id` é nullable e o padrão de FK é MATCH SIMPLE, ela só é avaliada quando `professional_id` não é nulo (`scope='professional'`), não afetando linhas `scope='unit'`. Novo teste cobrindo a rejeição. Evidência atualizada: **23/23** assertions, suíte completa **764/764**.
