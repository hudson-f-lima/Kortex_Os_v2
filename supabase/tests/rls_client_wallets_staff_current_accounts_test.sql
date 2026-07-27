BEGIN;
SELECT plan(17);

-- Helpers: simulate Supabase Auth JWT context inside this transaction only.
CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

CREATE FUNCTION pg_temp.login_as(p_user_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  SET LOCAL role authenticated;
END;
$$;

CREATE FUNCTION pg_temp.logout() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  RESET role;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END;
$$;

-- Fixtures (created as postgres/service-role-equivalent, bypassing RLS).
SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('professional_user1@test.local') AS professional_user1 \gset
SELECT pg_temp.mk_user('outsider@test.local') AS outsider \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
SELECT (public.unit_create(:'org1'::uuid, :'owner1'::uuid, 'Filial Dois')).id AS unit1b \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null),
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid),
  (:'org1'::uuid, :'professional_user1'::uuid, 'professional', :'unit1'::uuid);
INSERT INTO public.professionals (organization_id, user_id, name)
  VALUES (:'org1'::uuid, :'professional_user1'::uuid, 'Profissional Autenticado')
  RETURNING id AS professional1 \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Profissional Dois')
  RETURNING id AS professional2 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset
SELECT (SELECT id FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'cash') AS cash1 \gset
SELECT (SELECT id FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1b'::uuid AND kind = 'cash') AS cash1b \gset

-- === Layer 1: grants — no direct table privilege for anon/authenticated ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.client_wallets', 'INSERT'),
  'authenticated has no direct INSERT grant on client_wallets'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.client_wallets', 'UPDATE'),
  'authenticated has no direct UPDATE grant on client_wallets'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.staff_current_accounts', 'INSERT'),
  'authenticated has no direct INSERT grant on staff_current_accounts'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.staff_current_accounts', 'UPDATE'),
  'authenticated has no direct UPDATE grant on staff_current_accounts'
);

-- === Cross-unit aggregation: client1 transacts in both units, wallet sums ===
SELECT public.kortex_ledger_post(
  :'org1'::uuid, :'owner1'::uuid, 'wallet-unit1-001', :'unit1'::uuid,
  jsonb_build_array(
    jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 1000),
    jsonb_build_object('kind', 'client_wallet', 'client_id', :'client1', 'direction', 'credit', 'amount_cents', 1000)
  )
);
SELECT public.kortex_ledger_post(
  :'org1'::uuid, :'owner1'::uuid, 'wallet-unit1b-001', :'unit1b'::uuid,
  jsonb_build_array(
    jsonb_build_object('account_id', :'cash1b', 'direction', 'debit', 'amount_cents', 500),
    jsonb_build_object('kind', 'client_wallet', 'client_id', :'client1', 'direction', 'credit', 'amount_cents', 500)
  )
);
SELECT is(
  (SELECT balance_cents FROM public.client_wallets WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  (-1500)::bigint,
  'client_wallets sums balance_cents across both units for the same client'
);

-- === Cross-unit aggregation: professional1 transacts in both units, staff
-- current account sums too ===
SELECT public.kortex_ledger_post(
  :'org1'::uuid, :'owner1'::uuid, 'staff-unit1-001', :'unit1'::uuid,
  jsonb_build_array(
    jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 300),
    jsonb_build_object('kind', 'staff_current_account', 'professional_id', :'professional1', 'direction', 'credit', 'amount_cents', 300)
  )
);
SELECT public.kortex_ledger_post(
  :'org1'::uuid, :'owner1'::uuid, 'staff-unit1b-001', :'unit1b'::uuid,
  jsonb_build_array(
    jsonb_build_object('account_id', :'cash1b', 'direction', 'debit', 'amount_cents', 200),
    jsonb_build_object('kind', 'staff_current_account', 'professional_id', :'professional1', 'direction', 'credit', 'amount_cents', 200)
  )
);
SELECT is(
  (SELECT balance_cents FROM public.staff_current_accounts WHERE organization_id = :'org1'::uuid AND professional_id = :'professional1'::uuid),
  (-500)::bigint,
  'staff_current_accounts sums balance_cents across both units for the same professional'
);

-- === RLS: client_wallets — owner/admin/manager/reception see, others don't ===
-- Grants are transaction-local, solely to exercise RLS in this API-only
-- architecture (real callers always use service_role) — same pattern as
-- rls_units_test.sql. staff_current_accounts_select's self-view subquery
-- touches public.professionals, so authenticated needs that grant too.
GRANT SELECT ON public.client_wallets, public.staff_current_accounts, public.professionals TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.client_wallets WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'owner can read client1''s wallet'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.client_wallets WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'manager can read client1''s wallet'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.client_wallets WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'reception can read client1''s wallet (same list as clients_select)'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'professional_user1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.client_wallets WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'professional cannot read client wallets'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'outsider'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.client_wallets WHERE organization_id = :'org1'::uuid AND client_id = :'client1'::uuid),
  'a user with no membership cannot read any client_wallets row'
);
SELECT pg_temp.logout();

-- === RLS: staff_current_accounts — owner/admin/manager see all; professional
-- self-view only; reception sees none ===
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.staff_current_accounts WHERE organization_id = :'org1'::uuid AND professional_id = :'professional1'::uuid),
  'owner can read professional1''s current account'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.staff_current_accounts WHERE organization_id = :'org1'::uuid AND professional_id = :'professional1'::uuid),
  'reception cannot read any staff_current_accounts row'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'professional_user1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.staff_current_accounts WHERE organization_id = :'org1'::uuid AND professional_id = :'professional1'::uuid),
  'professional can read its own current account (self-view, Gate 02)'
);
SELECT pg_temp.logout();

-- professional2 has no user linked yet; post to create its current account too
SELECT public.kortex_ledger_post(
  :'org1'::uuid, :'owner1'::uuid, 'staff-professional2-001', :'unit1'::uuid,
  jsonb_build_array(
    jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 100),
    jsonb_build_object('kind', 'staff_current_account', 'professional_id', :'professional2', 'direction', 'credit', 'amount_cents', 100)
  )
);
SELECT pg_temp.login_as(:'professional_user1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.staff_current_accounts WHERE organization_id = :'org1'::uuid AND professional_id = :'professional2'::uuid),
  'professional cannot read another professional''s current account (Staff Privacy, Gate 02)'
);
SELECT pg_temp.logout();

-- === Gate 13 (two levels): recompute both from kortex_ledger_entries from
-- scratch and compare ===
SELECT set_eq(
  format(
    'select client_id, balance_cents from public.client_wallets where organization_id = %L',
    :'org1'
  ),
  format(
    $q$
    select ka.client_id, coalesce(sum(case when kle.direction = 'debit' then kle.amount_cents else -kle.amount_cents end), 0)
    from public.kortex_accounts ka
    join public.kortex_ledger_entries kle on kle.account_id = ka.id
    where ka.organization_id = %L and ka.kind = 'client_wallet'
    group by ka.client_id
    $q$,
    :'org1'
  ),
  'Gate 13: recomputing client_wallets from kortex_ledger_entries from scratch matches exactly'
);
SELECT set_eq(
  format(
    'select professional_id, balance_cents from public.staff_current_accounts where organization_id = %L',
    :'org1'
  ),
  format(
    $q$
    select ka.professional_id, coalesce(sum(case when kle.direction = 'debit' then kle.amount_cents else -kle.amount_cents end), 0)
    from public.kortex_accounts ka
    join public.kortex_ledger_entries kle on kle.account_id = ka.id
    where ka.organization_id = %L and ka.kind = 'staff_current_account'
    group by ka.professional_id
    $q$,
    :'org1'
  ),
  'Gate 13: recomputing staff_current_accounts from kortex_ledger_entries from scratch matches exactly'
);

SELECT * FROM finish();
ROLLBACK;
