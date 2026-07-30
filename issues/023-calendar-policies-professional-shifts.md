---
title: "Issue 023 - Calendar Policies & Professional Shifts"
status: "IMPLEMENTED_LOCAL"
stage: "ISSUE"
governance_ref: ["DEC-49"]
upstream_doc: "docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md"
last_updated: "2026-07-29"
---

## Parent Blueprint

`docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md` (APROVADO, DEC-49), §2, §3.1, §3.8, §4.

## What to build

`calendar_policies` (horário padrão semanal da unidade) e `professional_shifts` (turno semanal do profissional numa unidade), ambas versionadas com vigência (`valid_from`/`valid_to`, linha fechada imutável) — não ponteiro simples, diferente de `staff_levels` (Onda 3). Inclui:

- Trigger `BEFORE INSERT` (`private.close_previous_calendar_policy_version()` / `private.close_previous_professional_shift_version()`) que fecha a versão anterior e valida ordem cronológica (`raise exception 'calendar policy version out of order'` se `new.valid_from` não for estritamente posterior à versão aberta).
- Exclusion constraint GiST anti-sobreposição de vigência em ambas as tabelas.
- Trigger de `professional_shifts` valida também a regra CRÍTICO "turno ⊆ horário da unidade" (Master §2.4): cada bloco do turno precisa caber nos blocos de `calendar_policies` vigentes para o mesmo dia.
- RLS unit-aware via `private.can_access_fact_unit` (não `is_member` — achado do Red Team de desenho, Blueprint §3.8).

**Ajustes feitos durante a implementação (Etapa 8), registrados aqui:**
1. `private.resolve_calendar_policy(p_organization_id, p_unit_id, p_date)` nasce **nesta fatia**, não na 027 — o trigger de turno ⊆ horário desta própria fatia já precisa da lógica de resolução de política efetiva por data. A fatia 027 passa a só adicionar `resolve_professional_shift`/`resolve_calendar_overrides` (issue 027 atualizada).
2. A isenção por `calendar_exceptions.exceptional_opening` foi removida definitivamente após a auditoria de implementação: uma exceção de uma data única não pode autorizar um turno recorrente semanal. O trigger desta fatia rejeita qualquer bloco recorrente fora do horário da unidade; aberturas excepcionais só influenciam ocorrências pontuais no Resolver.
3. FK composta para `professional_units` garante apenas que uma linha de vínculo já existiu — não filtra por `active` (FK não expressa isso). Adicionado um segundo guard explícito no trigger (`not exists (... and active)`) que cobre tanto "nunca vinculado" quanto "vinculado mas desativado" com o mesmo erro de domínio — a FK composta permanece como rede de segurança de schema, mas não é o caminho de erro alcançado na prática (o trigger sempre roda primeiro).

## Acceptance criteria

- [x] Migration aditiva cria `calendar_policies` (`id`, `organization_id`, `unit_id`, `weekly_schedule jsonb`, `valid_from`, `valid_to`, `created_by`, `created_at`) com FK composta `(organization_id, unit_id) references units(organization_id, id) on delete restrict`, `check (private.valid_weekly_schedule(weekly_schedule))`, exclusion `EXCLUDE USING gist (organization_id with =, unit_id with =, tstzrange(valid_from, coalesce(valid_to,'infinity'),'[)') with &&)`. `supabase/migrations/20260729010000_onda4_calendar_policies_professional_shifts.sql`
- [x] Migration aditiva cria `professional_shifts` na mesma estrutura, com `professional_id` adicional e FK composta `(organization_id, professional_id, unit_id) references professional_units(organization_id, professional_id, unit_id) on delete restrict`. Mesma migration
- [x] Pre-flight check (DEC-44): confere `to_regclass('public.units')`/`to_regclass('public.professional_units')` (e que `calendar_policies` ainda não existe) antes de criar as tabelas/FKs
- [x] Trigger de vigência fecha a versão anterior e rejeita `INSERT` fora de ordem cronológica com erro de domínio (`errcode = '22023'`), não o erro genérico de exclusion constraint
- [x] Trigger de `professional_shifts` rejeita bloco recorrente fora do horário da unidade — sem isenção por abertura excepcional, removida definitivamente na correção pós-implementação
- [x] Linha fechada (`valid_to is not null`) é imutável — nenhuma policy de `UPDATE`/`DELETE` para `authenticated` em nenhuma das duas tabelas (confirmado por teste: `owner1` não consegue alterar linha fechada)
- [x] RLS: SELECT via `private.can_access_fact_unit(org: owner/admin/manager; unit: reception/professional)`; INSERT `owner`/`admin`/`manager`; nenhum grant de UPDATE/DELETE
- [x] pgTAP: agendar mudança futura não afeta a política vigente hoje; segunda versão fecha a primeira; `INSERT` com `valid_from` anterior/igual à versão aberta é rejeitado; weekly_schedule malformado (chave de dia inválida, `start >= end`, blocos sobrepostos) é rejeitado pelo `CHECK`; turno dentro do horário passa; turno fora do horário é rejeitado; turno para profissional nunca vinculado ou com vínculo desativado é rejeitado; segunda versão de turno fecha a primeira; `resolve_calendar_policy` retorna os blocos corretos e vazio fora da vigência; profissional de unidade A não lê política/turno da unidade B na mesma organização (teste direto do achado do Red Team); cross-tenant (org2 não lê dados de org1). `supabase/tests/rls_calendar_policies_professional_shifts_test.sql` — 22/22 assertions, suíte completa 683/683 (`supabase test db --local supabase/tests`, evidência bruta: `Result: PASS`), sem regressão nos 39 arquivos pré-existentes

## Blocked by

None - can start immediately (depende só de `units`/`professional_units`, já em `staging` desde a Onda 0)

## Seções do Blueprint endereçadas

- §2 (escopo de dados)
- §3.1 (vigência, validação de ordem, turno ⊆ horário)
- §3.8 (matriz RLS — correção do achado de vazamento entre unidades)
- §4 (contrato físico, timezone)

## Correção pós-implementação (2026-07-29, Red Team de implementação)

A nota "isenção adicionada na fatia 025" (ajuste 2, acima) ficou desatualizada: a fatia 025 tentou adicionar essa isenção, mas era conceitualmente errada (uma `calendar_exceptions.exceptional_opening` de UMA data não pode autorizar um `professional_shifts.weekly_schedule` RECORRENTE semanal — comparava só `HH:MI`, ignorando a data por completo). A isenção foi **removida**, não corrigida — `private.close_previous_professional_shift_version()` permanece exatamente a versão desta fatia (containment estrito contra `calendar_policies`, sem isenção), hoje e para sempre, não só "até a fatia 025". Ver ADR 0022 para o relato completo do achado.
