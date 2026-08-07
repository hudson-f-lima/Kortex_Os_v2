BEGIN;
SELECT plan(33);

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
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Two', 'org-two')).id AS org2 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org2'::uuid AND is_default) AS unit2 \gset
SELECT (SELECT id FROM public.kortex_accounts WHERE organization_id = :'org2'::uuid AND unit_id = :'unit2'::uuid AND kind = 'cash') AS cash2 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
  VALUES (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid);
SELECT (SELECT id FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'cash') AS cash1 \gset
SELECT (SELECT id FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'revenue_service') AS revenue1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset
SELECT (public.unit_create(:'org1'::uuid, :'owner1'::uuid, 'Filial Dois')).id AS unit1b \gset
SELECT (SELECT id FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1b'::uuid AND kind = 'cash') AS cash1b \gset

-- === Layer 1: grants — no direct table privilege for anon/authenticated ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kortex_ledger_transactions', 'INSERT'),
  'authenticated has no direct INSERT grant on kortex_ledger_transactions'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kortex_ledger_entries', 'INSERT'),
  'authenticated has no direct INSERT grant on kortex_ledger_entries'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kortex_account_balances', 'INSERT'),
  'authenticated has no direct INSERT grant on kortex_account_balances'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kortex_account_balances', 'UPDATE'),
  'authenticated has no direct UPDATE grant on kortex_account_balances'
);

-- === Authorization (achado #3): only owner/admin/manager may post ===
SELECT throws_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'reception1', 'auth-check-001', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 1000),
      jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 1000)
    )::text
  ),
  '42501',
  NULL,
  'reception cannot call kortex_ledger_post (insufficient role)'
);
SELECT lives_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'owner1', 'auth-check-002', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 1000),
      jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 1000)
    )::text
  ),
  'owner can call kortex_ledger_post'
);
SELECT (public.kortex_ledger_post(
  :'org1'::uuid, :'owner1'::uuid, 'happy-path-001', :'unit1'::uuid,
  jsonb_build_array(
    jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 2500),
    jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 2500)
  )
) ->> 'transaction_id')::uuid AS happy_path_transaction \gset
SELECT ok(
  EXISTS(SELECT 1 FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid AND id = :'happy_path_transaction'::uuid AND unit_id = :'unit1'::uuid),
  'kortex_ledger_post creates the transaction header scoped to the right org/unit'
);
SELECT set_eq(
  format(
    'select direction, account_id, amount_cents from public.kortex_ledger_entries where transaction_id = %L',
    :'happy_path_transaction'
  ),
  format(
    'values (%L::text, %L::uuid, %L::bigint), (%L::text, %L::uuid, %L::bigint)',
    'debit', :'cash1', 2500, 'credit', :'revenue1', 2500
  ),
  'kortex_ledger_post inserts exactly the two balanced entries against the right accounts'
);

-- === Double-entry validation: SUM(debit) must equal SUM(credit), nothing
-- inserted otherwise ===
SELECT count(*)::integer AS transactions_before_unbalanced FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid \gset
SELECT throws_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'owner1', 'unbalanced-001', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 1500),
      jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 1000)
    )::text
  ),
  '22023',
  NULL,
  'kortex_ledger_post rejects an unbalanced set of entries'
);
SELECT is(
  (SELECT count(*)::integer FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid),
  :'transactions_before_unbalanced'::integer,
  'the unbalanced attempt inserted no transaction at all'
);
SELECT throws_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'owner1', 'zero-total-001', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 0)
    )::text
  ),
  '22023',
  NULL,
  'kortex_ledger_post rejects an all-zero entry set'
);

-- === Tenant validation per row (achado #2): a foreign account_id aborts the
-- whole call, nothing inserted ===
SELECT count(*)::integer AS transactions_before_cross_tenant FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid \gset
SELECT throws_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'owner1', 'cross-tenant-001', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash2', 'direction', 'debit', 'amount_cents', 1000),
      jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 1000)
    )::text
  ),
  'P0002',
  NULL,
  'kortex_ledger_post rejects an account_id belonging to another organization'
);
SELECT is(
  (SELECT count(*)::integer FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid),
  :'transactions_before_cross_tenant'::integer,
  'the cross-tenant attempt inserted no transaction at all'
);

-- === On-demand entity account creation (achado #1): client_wallet is
-- created on first reference via ON CONFLICT DO NOTHING + SELECT; a second
-- call referencing the same client in the same unit reuses it, no duplicate ===
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'client_wallet' AND client_id = :'client1'::uuid),
  'client1 has no wallet account yet before its first ledger posting'
);
SELECT (public.kortex_ledger_post(
  :'org1'::uuid, :'owner1'::uuid, 'wallet-first-001', :'unit1'::uuid,
  jsonb_build_array(
    jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 500),
    jsonb_build_object('kind', 'client_wallet', 'client_id', :'client1', 'direction', 'credit', 'amount_cents', 500)
  )
) ->> 'transaction_id')::uuid AS wallet_first_transaction \gset
SELECT ok(
  EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'client_wallet' AND client_id = :'client1'::uuid),
  'the first posting referencing client1''s wallet creates the account on demand'
);
SELECT (SELECT id FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'client_wallet' AND client_id = :'client1'::uuid) AS wallet1 \gset
SELECT lives_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'owner1', 'wallet-second-001', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 300),
      jsonb_build_object('kind', 'client_wallet', 'client_id', :'client1', 'direction', 'credit', 'amount_cents', 300)
    )::text
  ),
  'a second posting referencing the same client wallet succeeds without erroring'
);
SELECT is(
  (SELECT count(*)::integer FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'client_wallet' AND client_id = :'client1'::uuid),
  1,
  'no duplicate client_wallet account was created by the second posting'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.kortex_ledger_entries WHERE account_id = :'wallet1'::uuid AND direction = 'credit' AND amount_cents = 300),
  'the second posting resolved to the exact same wallet account created by the first'
);

-- === Idempotency: replaying the same key returns the cached response,
-- never reprocesses (no new transaction, no new entries) ===
SELECT count(*)::integer AS transactions_before_replay FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid \gset
SELECT (public.kortex_ledger_post(
  :'org1'::uuid, :'owner1'::uuid, 'happy-path-001', :'unit1'::uuid,
  jsonb_build_array(
    jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 2500),
    jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 2500)
  )
) ->> 'transaction_id')::uuid AS replayed_transaction \gset
SELECT is(
  :'replayed_transaction'::uuid,
  :'happy_path_transaction'::uuid,
  'replaying the same idempotency key with the same payload returns the original cached transaction_id'
);
SELECT is(
  (SELECT count(*)::integer FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid),
  :'transactions_before_replay'::integer,
  'the replay created no new transaction'
);
SELECT throws_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'owner1', 'happy-path-001', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 9999),
      jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 9999)
    )::text
  ),
  '22023',
  NULL,
  'reusing the same idempotency key with a different payload is rejected'
);

-- === Trigger nível 1: kortex_account_balances is maintained automatically,
-- convention balance_cents = SUM(debit) - SUM(credit) per account. Postings
-- so far on cash1: +1000 (auth-check-002) +2500 (happy-path-001, only once,
-- replay didn't reprocess) +500 (wallet-first-001) +300 (wallet-second-001)
-- = 4300 debit, 0 credit. revenue1: -1000 -2500 = -3500 (all credit). wallet1:
-- -500 -300 = -800 (all credit). ===
SELECT is(
  (SELECT balance_cents FROM public.kortex_account_balances WHERE account_id = :'cash1'::uuid),
  4300::bigint,
  'kortex_account_balances tracks cash1''s net debit balance across every posting'
);
SELECT is(
  (SELECT balance_cents FROM public.kortex_account_balances WHERE account_id = :'revenue1'::uuid),
  (-3500)::bigint,
  'kortex_account_balances tracks revenue1''s net credit balance (negative under the debit-positive convention)'
);
SELECT is(
  (SELECT balance_cents FROM public.kortex_account_balances WHERE account_id = :'wallet1'::uuid),
  (-800)::bigint,
  'kortex_account_balances tracks the on-demand wallet account too'
);

-- === Gate 13: kortex_account_balances is always reconstructible from
-- scratch, matching every row kortex_ledger_entries actually produced ===
SELECT set_eq(
  format(
    'select account_id, balance_cents from public.kortex_account_balances where organization_id = %L',
    :'org1'
  ),
  format(
    $q$
    select account_id, coalesce(sum(case when direction = 'debit' then amount_cents else -amount_cents end), 0)
    from public.kortex_ledger_entries
    where organization_id = %L
    group by account_id
    $q$,
    :'org1'
  ),
  'Gate 13: recomputing every balance from kortex_ledger_entries from scratch matches kortex_account_balances exactly'
);

-- === Tenant/unit validation (Blueprint §3, achado #2, 2ª frase): an
-- account_id from a DIFFERENT unit in the SAME organization is also rejected
-- — not just an account_id from another org ===
SELECT count(*)::integer AS transactions_before_cross_unit FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid \gset
SELECT throws_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'owner1', 'cross-unit-001', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash1b', 'direction', 'debit', 'amount_cents', 1000),
      jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 1000)
    )::text
  ),
  'P0002',
  NULL,
  'kortex_ledger_post rejects an account_id from a different unit in the same organization'
);
SELECT is(
  (SELECT count(*)::integer FROM public.kortex_ledger_transactions WHERE organization_id = :'org1'::uuid),
  :'transactions_before_cross_unit'::integer,
  'the cross-unit attempt inserted no transaction at all'
);

-- === Post-audit hardening (DEC-42): service_role has no direct DML on the
-- ledger either — the only door, even for the trusted backend credential, is
-- kortex_ledger_post. Stricter than the rest of the schema (deposit_holds/
-- payment_intents/cash_entries keep the platform-default service_role grant)
-- — a deliberate, scoped exception for the double-entry ledger specifically. ===
SELECT ok(
  NOT has_table_privilege('service_role', 'public.kortex_ledger_transactions', 'INSERT'),
  'service_role has no direct INSERT grant on kortex_ledger_transactions (write-lockdown, DEC-42)'
);
SELECT ok(
  NOT has_table_privilege('service_role', 'public.kortex_ledger_entries', 'INSERT'),
  'service_role has no direct INSERT grant on kortex_ledger_entries (write-lockdown, DEC-42)'
);
SELECT ok(
  NOT has_table_privilege('service_role', 'public.kortex_account_balances', 'UPDATE'),
  'service_role has no direct UPDATE grant on kortex_account_balances (write-lockdown, DEC-42)'
);
SELECT ok(
  NOT has_table_privilege('service_role', 'public.kortex_ledger_entries', 'DELETE'),
  'service_role has no direct DELETE grant on kortex_ledger_entries (write-lockdown, DEC-42)'
);

SET LOCAL role service_role;
SELECT throws_ok(
  format(
    'insert into public.kortex_ledger_transactions (organization_id, unit_id) values (%L, %L)',
    :'org1', :'unit1'
  ),
  '42501',
  NULL,
  'service_role cannot insert directly into kortex_ledger_transactions, even authenticated as itself'
);
SELECT lives_ok(
  format(
    'select public.kortex_ledger_post(%L, %L, %L, %L, %L::jsonb)',
    :'org1', :'owner1', 'post-lockdown-001', :'unit1',
    jsonb_build_array(
      jsonb_build_object('account_id', :'cash1', 'direction', 'debit', 'amount_cents', 700),
      jsonb_build_object('account_id', :'revenue1', 'direction', 'credit', 'amount_cents', 700)
    )::text
  ),
  'kortex_ledger_post still works when called as service_role, even after the write-lockdown (SECURITY DEFINER bypasses via function owner, not caller)'
);
RESET role;

SELECT * FROM finish();
ROLLBACK;
