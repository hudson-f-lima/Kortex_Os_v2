# Índice de Issues Executáveis

As issues são o elo entre Blueprint e implementação. Este índice organiza a leitura sem alterar os caminhos estáveis `issues/NNN-...md`, preservando links já registrados em DEC, blueprints, migrations e testes.

## Ciclo de vida

Uma issue só muda de estado por evidência física e decisão registrada. Checklist de aceite concluído não equivale a promoção de ambiente; promoção exige os gates definidos em `AGENTS.md`. Issues históricas não são apagadas nem arquivadas automaticamente.

| Onda | Issues | Estado documental | Evidência / dependência |
|---|---|---|---|
| Onda 1 — implementação inicial | [001](001-services-deposit-policy.md) · [002](002-payment-intents-webhook-outbox.md) · [003](003-deposit-holds-creation.md) · [004](004-checkout-close-deposit-reconciliation.md) · [005](005-no-show-settlement-rpc.md) | Implementação inicial registrada em `staging`; o contrato completo foi reaberto pela auditoria | DEC-35 a DEC-38; [Blueprint](../docs/waves/onda-1-payment-core/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1.md) |
| Onda 1 — correção forward-only | [PRD corretivo](onda1-payment-integrity-corrective-prd.md) · [006](006-hold-financial-identity.md) · [007](007-appointment-server-owned-checkout.md) · [008](008-hold-release-cancel-reschedule.md) · [009](009-webhook-dead-letter-reprocessing.md) · [010](010-hold-expiration-fail-closed.md) · [011](011-onda1-corrective-redteam-homologation.md) | Em remediação; promoção não autorizada | DEC-38 a DEC-40; ADR 0018 |
| Onda 2 — KortexFlow Ledger | [012](012-kortex-accounts-chart-of-accounts.md) · [013](013-kortex-ledger-post-double-entry.md) · [014](014-client-wallets-staff-current-accounts.md) · [015](015-benefit-obligations-schema.md) · [016](016-payout-batches-schema.md) | Implementada e verificada localmente sob DEC-42; ainda não promovida | [Blueprint](../docs/waves/onda-2-kortexflow-ledger/KORTEXOS_5_1_2_BLUEPRINT_ONDA_2.md); ADR 0019; migrations `2026072712…`–`2026072717…` |

## Leitura obrigatória antes de alterar uma issue

1. [Master Briefing](../docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md)
2. [Truth Map](../docs/waves/KORTEXOS_5_1_2_TRUTH_MAP.md) e [Migration Map](../docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md)
3. Blueprint e DEC/ADR da onda correspondente
4. Evidência de código, migration e teste — nunca somente um status textual
