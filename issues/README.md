# Índice de Issues Executáveis

As issues são o elo entre Blueprint e implementação. Este índice organiza a leitura sem alterar os caminhos estáveis `issues/NNN-...md`, preservando links já registrados em DEC, blueprints, migrations e testes.

## Ciclo de vida

Uma issue só muda de estado por evidência física e decisão registrada. Checklist de aceite concluído não equivale a promoção de ambiente; promoção exige os gates definidos em `AGENTS.md`. Uma issue realmente concluída é movida para [`issues/completed/`](completed/README.md) somente no mesmo turno em que todos os seus links de entrada e o `docs/INDEX.md` forem atualizados; issues sem essa evidência permanecem no caminho estável atual.

| Onda | Issues | Estado documental | Evidência / dependência |
|---|---|---|---|
| Onda 1 — implementação inicial | [001](001-services-deposit-policy.md) · [002](002-payment-intents-webhook-outbox.md) · [003](003-deposit-holds-creation.md) · [004](004-checkout-close-deposit-reconciliation.md) · [005](005-no-show-settlement-rpc.md) | Implementação inicial registrada em `staging`; o contrato completo foi reaberto pela auditoria | DEC-35 a DEC-38; [Blueprint](../docs/waves/onda-1-payment-core/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1.md) |
| Onda 1 — correção forward-only | [PRD corretivo](onda1-payment-integrity-corrective-prd.md) · [006](006-hold-financial-identity.md) · [007](007-appointment-server-owned-checkout.md) · [008](008-hold-release-cancel-reschedule.md) · [009](009-webhook-dead-letter-reprocessing.md) · [010](010-hold-expiration-fail-closed.md) · [011](011-onda1-corrective-redteam-homologation.md) | Em remediação; promoção não autorizada | DEC-38 a DEC-40; ADR 0018 |
| Onda 2 — KortexFlow Ledger | [012](012-kortex-accounts-chart-of-accounts.md) · [013](013-kortex-ledger-post-double-entry.md) · [014](014-client-wallets-staff-current-accounts.md) · [015](015-benefit-obligations-schema.md) · [016](016-payout-batches-schema.md) | Implementada e verificada localmente sob DEC-42; ainda não promovida | [Blueprint](../docs/waves/onda-2-kortexflow-ledger/KORTEXOS_5_1_2_BLUEPRINT_ONDA_2.md); ADR 0019; migrations `2026072712…`–`2026072717…` |
| Onda 3 — Compensation | [017](017-organizations-settings-feature-flag.md) · [018](018-staff-levels-professional-assignment.md) · [019](019-staff-level-service-overrides-pricing-resolution.md) · [020](020-package-sale-commission-records.md) · [021](021-order-items-package-linkage.md) · [022](022-commission-sale-records-immutability.md) | Blueprint aprovado (DEC-46); as 6 fatias implementadas via `$tdd` (661/661 pgTAP) e mescladas em `staging` — 017-020 via PR #24, 021-022 (correção de achados P1/P2/P3 de auditoria pós-merge, DEC-47/DEC-48) via PR #25; `NO-GO` para `main`/produção | [Blueprint](../docs/waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md); ADR 0020 (`Accepted`, emendada por DEC-48); migrations `20260728000000`–`20260728060000` |
| Onda 4 — Calendar Policy, Availability Resolver & Resource Orchestration | [023](023-calendar-policies-professional-shifts.md) · [024](024-calendar-holidays-exceptions-time-off.md) · [025](025-calendar-policy-conflicts-detection.md) · [026](026-resources-resource-locks.md) · [027](027-availability-resolver-functions.md) · [028](028-availability-resolver-express-endpoint.md) | Blueprint aprovado (DEC-49), fundação sem ativação; as 6 fatias implementadas via `$tdd`, Red Team de implementação e auditoria final de fix com gaps reais corrigidos (unit scope, elegibilidade tri-state, isenção conceitualmente errada removida, timezone, validação estrita de data, lint SQL — ver ADR 0022). 764/764 pgTAP, 321/321 backend e `supabase db lint --local` sem erros em ambiente local — ainda não commitadas/mescladas em `staging` | [Blueprint](../docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md); ADR 0022 (`Accepted`); migrations `20260729010000`–`20260729060000` |

## Leitura obrigatória antes de alterar uma issue

1. [Master Briefing](../docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md)
2. [Truth Map](../docs/waves/KORTEXOS_5_1_2_TRUTH_MAP.md) e [Migration Map](../docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md)
3. Blueprint e DEC/ADR da onda correspondente
4. Evidência de código, migration e teste — nunca somente um status textual
