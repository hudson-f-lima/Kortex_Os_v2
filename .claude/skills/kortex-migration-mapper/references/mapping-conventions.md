# Convenções de mapeamento — Migration Map 5.1.2

## Prefixo canônico
Objetos novos do produto final usam prefixo `kortex_` quando pertencem ao núcleo financeiro (KortexFlow, D15/D16). Objetos de outros domínios seguem o nome de domínio em snake_case sem prefixo redundante, salvo colisão com tabela MVP existente.

## Grade de domínios (Master §5, D00–D31) — não renumerar, não criar domínio novo
D00 Platform Owner · D01 Identity & Tenant · D02 Business Configuration & Policy (inclui Calendar Policy & Availability) · D03 Onboarding SaaS · D04 SaaS Billing · D05 People Hub · D06 Catalog & Offer Hub · D07 Capacity Scheduling Engine (Availability/Smart Gap/Slot Score) · D08 Agenda Core · D09 Recurring Appointment Engine · D10 Group Booking · D11 Resource Orchestration · D12 Checkout Core · D13 Payment Core (PSP/depósito/COF) · D14 Cash & Register · D15 KortexFlow Ledger · D16 Wallet & Current Accounts · D17 Compensation & Payout · D18 Subscription/Packages/Corporate/Partner · D19 Client Experience Hub · D20 Public Web · D21 KortexLink Messaging · D22 Kortex.ai Receptionist · D23 Revenue CoPilot · D24 Trust/Retention/Lifecycle · D25 Analytics/Experimentation · D26 Fiscal & LGPD · D27 Marketplace & Partner Network · D28 Multiunit · D29 White-Label · D30 Integration Platform · D31 Gate/QA/Governance.

## Objetos financeiros mínimos (Master §7.4) — nomes de referência, não finais até o Migration Map aprovar
`kortex_accounts` (plano de contas) · `kortex_ledger_transactions` (cabeçalho) · `kortex_ledger_entries` (lançamentos double-entry append-only) · `kortex_account_balances` (projeção reconstruível) · `client_wallets` · `staff_current_accounts` · `benefit_obligations` · `payout_batches`.

## Tabelas MVP existentes que domínios do produto final vão tocar (checar schema real antes de propor)
- `appointments` (D08) — base para D09 (recorrência) e D07 (candidate/slot); não recriar, estender.
- `professional_service_commissions` / `private.resolve_commission()` (D17) — base para comissão de venda (DEC-15) e níveis (DEC-04); não recriar.
- `cash_entries` (D14) — permanece como está; NÃO vira ledger por extensão de campos. D15 é tabela nova, paralela, não substituição in-place até o Blueprint decidir a transição.
- `order_refund` / `orders` (D12/D13) — base para Payment Core; reabertura de comanda (DEC-03/11) é capability nova sobre esse domínio, não reescrita.
- `professional_service_capabilities` / `professional_service_group_eligibility` (D02/D06) — já resolvem elegibilidade; níveis (DEC-04) estendem, não substituem.

## Regra de ordem de dependência
Fundação financeira (`kortex_accounts` → `kortex_ledger_transactions`/`entries` → `kortex_account_balances`) sempre antes de `client_wallets`/`staff_current_accounts`/`payout_batches`, que por sua vez vêm antes de qualquer domínio que consome benefício (D18 Subscription/Packages/Corporate/Partner). Availability (D07) e Resource Orchestration (D11) vêm antes de Recurring (D09) e Group Booking (D10), que vêm antes de Waitlist (parte de D07/D08 conforme §5.1 do Master).

## Risco alto — sempre marcar para decisão explícita do Platform Owner
Qualquer proposta que renomeie coluna/tabela MVP em uso por RLS policy, RPC `security definer` ou índice existente. Qualquer proposta que altere o contrato de `create_appointment`/`update_appointment`/`checkout_close` (idempotência, `version`, elegibilidade fail-closed) em vez de estendê-lo.
