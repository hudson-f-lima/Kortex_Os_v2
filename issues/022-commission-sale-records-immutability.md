## Parent Blueprint

`docs/waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md` (APROVADO, DEC-46), Blueprint §3.6/§3.8/§4, regularizado por **DEC-47** (Decision Log SEÇÃO 13, achados P2/P3).

## What to build

Fecha os achados P2 e P3 de uma auditoria pós-merge da Onda 3:

**P2 — `commission_sale_records` sem proteção de mutação.** RLS bloqueia `authenticated`, mas `service_role` herda `INSERT`/`UPDATE`/`DELETE` completos via `alter default privileges` (`supabase/migrations/20260713034222_grant_service_role_tables.sql:11`) — nenhuma migration da fatia 020 fecha esse grant nem adiciona guard de coluna. O projeto tem dois padrões estabelecidos e nunca aplicou os dois juntos numa mesma tabela: trigger guard de imutabilidade (`private.guard_deposit_hold_financial_identity`, `20260726200000_onda1_hold_financial_identity.sql:38-68` — congela colunas financeiras, libera só `status`/`updated_at`) e revoke de grant (`20260727170000_onda2_kortex_ledger_service_role_write_lockdown.sql:22-24` — fecha `service_role` no ledger). O guard sozinho não cobre `DELETE`; o revoke sozinho não impede que a própria RPC `SECURITY DEFINER` altere `commission_cents` junto com uma transição de `status`.

**P3 — pre-flight incompleto.** A migration da fatia 020 (`20260728030000_onda3_package_sale_commission_records.sql`) confere `packages`, `orders_org_id_unit_unique` e `kortex_ledger_transactions`, mas não `organizations`/`professionals` — inconsistente com o padrão das fatias 018/019, que conferem toda tabela referenciada por FK antes do `CREATE TABLE`.

## Acceptance criteria

- [ ] Migration nova (não edita `20260728030000` já aplicada) adiciona trigger `before update on public.commission_sale_records`, mesmo padrão de `guard_deposit_hold_financial_identity`: congela `organization_id`, `unit_id`, `order_id`, `package_id`, `professional_id`, `commission_type`, `commission_value`, `commission_cents`; libera apenas `status` e `updated_at`. Usa `is distinct from` (não `<>`) e `errcode = '55000'`, mesmo padrão do precedente
- [ ] Mesma migration: `revoke insert, update, delete on public.commission_sale_records from service_role` (mesmo padrão de `20260727170000`) — `select` não é revogado
- [ ] Confirma que `commission_sale_record_create` continua gravando normalmente (é `security definer`, roda com o privilégio do dono da função, não do chamador — mesmo racional já documentado para o ledger)
- [ ] Mesma migration ou uma companion: completa o pre-flight check da fatia 020 (adiciona a checagem de `to_regclass('public.organizations')`/`to_regclass('public.professionals')`), sem editar `20260728030000`
- [ ] pgTAP: impersonar `service_role` (`SET LOCAL role service_role`, mesmo padrão de `rpc_kortex_ledger_post_test.sql`) e confirmar `INSERT`/`UPDATE`/`DELETE` diretos rejeitados com `42501`
- [ ] pgTAP: `UPDATE ... SET status = 'clawed_back'` (só a coluna liberada) funciona sem erro
- [ ] pgTAP: `UPDATE ... SET status = 'clawed_back', commission_cents = 0` (coluna liberada + coluna congelada na mesma instrução) falha com `55000` — a tentativa de mudar o valor não passa escondida atrás de uma transição de status legítima
- [ ] pgTAP: `DELETE` direto (mesmo via `service_role`) é rejeitado

## Blocked by

None — depende só da fatia 020 (`commission_sale_records`) já mesclada.

## Seções do Blueprint endereçadas

- §3.6 (clawback via `status`, não automatizado — a coluna precisa continuar mutável, o resto não)
- §3.8 (matriz RLS)
- Achados P2/P3 de DEC-47 (Decision Log SEÇÃO 13)
