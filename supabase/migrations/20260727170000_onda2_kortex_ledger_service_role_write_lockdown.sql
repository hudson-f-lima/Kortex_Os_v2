-- KortexOS 5.1.2 — Onda 2, correção pós-auditoria (DEC-42): fecha o bypass
-- de escrita direta por service_role no ledger double-entry.
--
-- Achado: service_role tem INSERT/UPDATE/DELETE diretos em
-- kortex_ledger_transactions/kortex_ledger_entries/kortex_account_balances
-- por grant padrão da plataforma Supabase (mesmo padrão de todo o resto do
-- schema, existe desde mvp_baseline — não é uma regressão desta Onda). O
-- Platform Owner decidiu fechar esse bypass especificamente para o ledger
-- financeiro double-entry, mais rígido que o resto do schema: toda escrita
-- passa a exigir kortex_ledger_post.
--
-- kortex_ledger_post continua funcionando: SECURITY DEFINER executa com o
-- privilégio do DONO da função (postgres, dono de toda tabela criada por
-- migration), não do chamador — revogar o grant direto de service_role não
-- quebra a RPC nem os triggers de projeção (private.project_kortex_account_balance,
-- private.project_client_staff_aggregate_balance), também SECURITY DEFINER.
--
-- Escopo deliberadamente restrito a estas 3 tabelas — deposit_holds,
-- payment_intents, cash_entries e o resto do schema mantêm o grant padrão
-- de service_role; não é uma mudança de política geral do projeto.

revoke insert, update, delete on public.kortex_ledger_transactions from service_role;
revoke insert, update, delete on public.kortex_ledger_entries from service_role;
revoke insert, update, delete on public.kortex_account_balances from service_role;
