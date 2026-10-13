-- Onda 6, fatia 055: contratos de RLS, grants, tenant/unit FKs e append-only.
BEGIN;
SELECT plan(14);

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

SELECT pg_temp.mk_user('onda6-rls-owner-1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('onda6-rls-manager-1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('onda6-rls-reception-1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('onda6-rls-owner-2@test.local') AS owner2 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Onda6 RLS One', 'org-onda6-rls-one')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Onda6 RLS Two', 'org-onda6-rls-two')).id AS org2 \gset
SELECT id AS unit1 FROM public.units WHERE organization_id = :'org1'::uuid AND is_default \gset
INSERT INTO public.units (organization_id, name, timezone, active, is_default)
  VALUES (:'org1'::uuid, 'Unidade Dois', 'America/Sao_Paulo', true, false)
  RETURNING id AS unit2 \gset

INSERT INTO public.memberships (organization_id, user_id, role, unit_id) VALUES
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null),
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid);

INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente Onda6 RLS', :'owner1'::uuid) RETURNING id AS client1 \gset
INSERT INTO public.orders (organization_id, unit_id, client_id, status, subtotal_cents, total_cents, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'client1'::uuid, 'closed', 0, 0, :'owner1'::uuid)
  RETURNING id AS order1 \gset
INSERT INTO public.order_revisions (organization_id, unit_id, order_id, revision_number, snapshot, closed_by, closed_at)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'order1'::uuid, 1, '{"total_cents":0}'::jsonb, :'owner1'::uuid, now())
  RETURNING id AS revision1 \gset
INSERT INTO public.order_reopen_attempts (organization_id, unit_id, order_id, base_revision_number, reason_code, reason_detail, requested_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'order1'::uuid, 1, 'other', 'fixture RLS', :'owner1'::uuid)
  RETURNING id AS attempt1 \gset
INSERT INTO public.order_reopen_attempt_events (organization_id, unit_id, reopen_attempt_id, event_type, actor_id)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'attempt1'::uuid, 'requested', :'owner1'::uuid)
  RETURNING id AS event1 \gset
INSERT INTO public.kortex_ledger_transactions (organization_id, unit_id, description, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, 'Fixture Onda6', :'owner1'::uuid)
  RETURNING id AS ledger1 \gset
INSERT INTO public.kortex_ledger_transactions (organization_id, unit_id, description, created_by)
  VALUES (:'org1'::uuid, :'unit2'::uuid, 'Fixture outra unidade', :'owner1'::uuid)
  RETURNING id AS ledger2 \gset
INSERT INTO public.payments (organization_id, unit_id, order_id, method, amount_cents)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'order1'::uuid, 'cash', 100)
  RETURNING id AS payment1 \gset
INSERT INTO public.cash_entries (organization_id, unit_id, order_id, kind, amount_cents, description, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'order1'::uuid, 'sale', 100, 'Fixture Onda6', :'owner1'::uuid)
  RETURNING id AS cash_entry1 \gset
INSERT INTO public.order_ledger_links (organization_id, unit_id, order_id, revision_number, ledger_transaction_id, kind)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'order1'::uuid, 1, :'ledger1'::uuid, 'closure')
  RETURNING id AS ledger_link1 \gset
INSERT INTO public.order_financial_locks (organization_id, unit_id, order_id, revision_number, source_type, source_id, enforcement, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'order1'::uuid, 1, 'cash_close', gen_random_uuid(), 'action_request_required', :'owner1'::uuid)
  RETURNING id AS lock1 \gset
INSERT INTO public.order_payment_adjustments (organization_id, unit_id, order_id, revision_number, payment_id, cash_entry_id, reopen_attempt_id, kind, amount_cents, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'order1'::uuid, 1, :'payment1'::uuid, :'cash_entry1'::uuid, :'attempt1'::uuid, 'reversal', 100, :'owner1'::uuid)
  RETURNING id AS adjustment1 \gset

-- Nenhuma das seis tabelas recebe DML direto de authenticated.
SELECT ok(NOT has_table_privilege('authenticated', 'public.order_revisions', 'INSERT, UPDATE, DELETE'), 'authenticated has no direct DML grant on order_revisions');
SELECT ok(NOT has_table_privilege('authenticated', 'public.order_reopen_attempts', 'INSERT, UPDATE, DELETE'), 'authenticated has no direct DML grant on order_reopen_attempts');
SELECT ok(NOT has_table_privilege('authenticated', 'public.order_reopen_attempt_events', 'INSERT, UPDATE, DELETE'), 'authenticated has no direct DML grant on order_reopen_attempt_events');
SELECT ok(NOT has_table_privilege('authenticated', 'public.order_ledger_links', 'INSERT, UPDATE, DELETE'), 'authenticated has no direct DML grant on order_ledger_links');
SELECT ok(NOT has_table_privilege('authenticated', 'public.order_financial_locks', 'INSERT, UPDATE, DELETE'), 'authenticated has no direct DML grant on order_financial_locks');
SELECT ok(NOT has_table_privilege('authenticated', 'public.order_payment_adjustments', 'INSERT, UPDATE, DELETE'), 'authenticated has no direct DML grant on order_payment_adjustments');

-- A FK composta liga pedido da unidade 1 somente a lancamento da unidade 1.
SELECT throws_ok(
  format(
    'insert into public.order_ledger_links (organization_id, unit_id, order_id, revision_number, ledger_transaction_id, kind) values (%L, %L, %L, 1, %L, ''restore'')',
    :'org1', :'unit1', :'order1', :'ledger2'
  ),
  '23503', NULL,
  'a ledger transaction from another unit cannot be linked to this order revision'
);

SELECT throws_ok(
  format(
    'insert into public.order_financial_locks (organization_id, unit_id, order_id, revision_number, source_type, source_id, enforcement, created_by) values (%L, %L, %L, 1, ''cash_close'', (select source_id from public.order_financial_locks where id = %L::uuid), ''action_request_required'', %L)',
    :'org1', :'unit1', :'order1', :'lock1', :'owner1'
  ),
  '23505', NULL,
  'the same financial lock source cannot be recorded twice for an order revision'
);

SELECT throws_ok(
  format('update public.order_financial_locks set enforcement = ''terminal'' where id = %L::uuid', :'lock1'),
  '55000', 'Onda 6 financial facts are append-only',
  'financial locks are append-only even for privileged writers'
);
SELECT throws_ok(
  format('delete from public.order_reopen_attempt_events where id = %L::uuid', :'event1'),
  '55000', 'Onda 6 financial facts are append-only',
  'reopen lifecycle events are append-only even for privileged writers'
);

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT is(
  (select (select count(*) from public.order_revisions) + (select count(*) from public.order_reopen_attempts) +
          (select count(*) from public.order_reopen_attempt_events) + (select count(*) from public.order_ledger_links) +
          (select count(*) from public.order_financial_locks) + (select count(*) from public.order_payment_adjustments))::int,
  6,
  'owner can read the six Onda 6 facts in its tenant and unit'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT is(
  (select (select count(*) from public.order_revisions) + (select count(*) from public.order_reopen_attempts) +
          (select count(*) from public.order_reopen_attempt_events) + (select count(*) from public.order_ledger_links) +
          (select count(*) from public.order_financial_locks) + (select count(*) from public.order_payment_adjustments))::int,
  6,
  'manager can read the six Onda 6 facts under the management policy'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (select (select count(*) from public.order_revisions) + (select count(*) from public.order_reopen_attempts) +
          (select count(*) from public.order_reopen_attempt_events) + (select count(*) from public.order_ledger_links) +
          (select count(*) from public.order_financial_locks) + (select count(*) from public.order_payment_adjustments))::int,
  0,
  'reception has no visibility into management-only Onda 6 financial facts'
);

SELECT pg_temp.login_as(:'owner2'::uuid);
SELECT is(
  (select (select count(*) from public.order_revisions where organization_id = :'org1'::uuid) +
          (select count(*) from public.order_reopen_attempts where organization_id = :'org1'::uuid) +
          (select count(*) from public.order_reopen_attempt_events where organization_id = :'org1'::uuid) +
          (select count(*) from public.order_ledger_links where organization_id = :'org1'::uuid) +
          (select count(*) from public.order_financial_locks where organization_id = :'org1'::uuid) +
          (select count(*) from public.order_payment_adjustments where organization_id = :'org1'::uuid))::int,
  0,
  'an owner in another tenant cannot read any Onda 6 fact'
);

SELECT pg_temp.logout();
SELECT * FROM finish();
ROLLBACK;
