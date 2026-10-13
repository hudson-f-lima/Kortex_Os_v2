BEGIN;
SELECT plan(25);

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
SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Um') RETURNING id AS professional1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset
SELECT pg_temp.mk_user('professional_user1@test.local') AS professional_user1 \gset
SELECT pg_temp.mk_user('outsider@test.local') AS outsider \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Two', 'org-two')).id AS org2 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org2'::uuid AND is_default) AS unit2 \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid),
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null),
  (:'org1'::uuid, :'professional_user1'::uuid, 'professional', :'unit1'::uuid);

-- === Seed: a brand-new unit (born from create_organization's default-unit
-- trigger) gets its 7 fixed accounts automatically. ===
SELECT is(
  (SELECT count(*)::integer FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid),
  7,
  'a new unit is seeded with exactly the 7 fixed accounts'
);
SELECT set_eq(
  format('select kind from public.kortex_accounts where organization_id = %L and unit_id = %L', :'org1', :'unit1'),
  ARRAY['cash', 'revenue_service', 'revenue_product', 'commission_expense', 'tip_liability', 'refund_expense', 'benefit_obligation_liability'],
  'the seeded accounts are exactly the 7 fixed chart-of-accounts kinds, no entity accounts'
);

-- === Pair check: client_id/professional_id must be consistent with kind ===
SELECT throws_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind, client_id) values (%L, %L, %L, %L)', :'org1', :'unit1', 'cash', :'client1'),
  '23514',
  NULL,
  'a fixed-kind account rejects a client_id'
);
SELECT throws_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind, professional_id) values (%L, %L, %L, %L)', :'org1', :'unit1', 'revenue_service', :'professional1'),
  '23514',
  NULL,
  'a fixed-kind account rejects a professional_id'
);
SELECT throws_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind) values (%L, %L, %L)', :'org1', :'unit1', 'client_wallet'),
  '23514',
  NULL,
  'a client_wallet account rejects neither client_id nor professional_id set'
);
SELECT throws_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind, client_id, professional_id) values (%L, %L, %L, %L, %L)', :'org1', :'unit1', 'client_wallet', :'client1', :'professional1'),
  '23514',
  NULL,
  'a client_wallet account rejects both client_id and professional_id set'
);
SELECT lives_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind, client_id) values (%L, %L, %L, %L)', :'org1', :'unit1', 'client_wallet', :'client1'),
  'a client_wallet account accepts exactly client_id set'
);

-- === Uniqueness: fixed accounts one per (org, unit, kind); entity accounts
-- one per (org, unit, kind, client_id/professional_id) ===
SELECT throws_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind) values (%L, %L, %L)', :'org1', :'unit1', 'cash'),
  '23505',
  NULL,
  'a duplicate fixed account (same org/unit/kind) is rejected'
);
SELECT throws_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind, client_id) values (%L, %L, %L, %L)', :'org1', :'unit1', 'client_wallet', :'client1'),
  '23505',
  NULL,
  'a duplicate client_wallet for the same client in the same unit is rejected'
);
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Dois') RETURNING id AS professional2 \gset
SELECT lives_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind, professional_id) values (%L, %L, %L, %L)', :'org1', :'unit1', 'staff_current_account', :'professional2'),
  'a staff_current_account for a different professional in the same unit is allowed'
);

-- === Layer 1: grants — no direct table privilege for anon/authenticated ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kortex_accounts', 'SELECT'),
  'authenticated has no direct SELECT grant on kortex_accounts'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kortex_accounts', 'INSERT'),
  'authenticated has no direct INSERT grant on kortex_accounts'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.kortex_accounts', 'UPDATE'),
  'authenticated has no direct UPDATE grant on kortex_accounts'
);
SELECT ok(
  NOT has_table_privilege('anon', 'public.kortex_accounts', 'SELECT'),
  'anon has no direct SELECT grant on kortex_accounts'
);

-- === Layer 2: RLS policies (temporarily grant table privileges within this
-- transaction only, to prove policies isolate roles/tenants even if grants
-- ever change). Granted while still service-role-equivalent — granting while
-- logged in as `authenticated` (non-owner) would silently no-op. ===
GRANT SELECT, INSERT, UPDATE ON public.kortex_accounts TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'cash'),
  'owner can read org1''s cash account'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'cash'),
  'manager can read org1''s cash account'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'cash'),
  'reception cannot read raw financial ledger accounts'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'professional_user1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'cash'),
  'professional cannot read raw financial ledger accounts'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'outsider'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'cash'),
  'a user with no membership cannot read any kortex_accounts row'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'owner2'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND kind = 'cash'),
  'owner2 cannot read org1''s accounts (cross-tenant select denied)'
);
SELECT ok(
  EXISTS(SELECT 1 FROM public.kortex_accounts WHERE organization_id = :'org2'::uuid AND unit_id = :'unit2'::uuid AND kind = 'cash'),
  'owner2 can read org2''s own cash account'
);

SELECT throws_ok(
  format('insert into public.kortex_accounts (organization_id, unit_id, kind) values (%L, %L, %L)', :'org2', :'unit2', 'commission_expense'),
  '42501',
  NULL,
  'owner2 cannot insert into kortex_accounts (no INSERT policy exists — fail-closed by design, no direct write path)'
);
WITH updated AS (
  UPDATE public.kortex_accounts SET kind = kind WHERE organization_id = :'org2'::uuid RETURNING 1
)
SELECT is(
  (SELECT count(*)::integer FROM updated),
  0,
  'owner2 cannot update kortex_accounts even with an RLS policy hole absent — no UPDATE policy exists at all'
);
SELECT pg_temp.logout();

-- === Backfill: the same idempotent statement the migration runs once at
-- apply time must seed the 7 fixed accounts for a unit that predates the
-- seed trigger (simulated here by dropping the trigger before creating it). ===
DROP TRIGGER units_seed_kortex_fixed_accounts ON public.units;
SELECT (public.create_organization(:'owner2'::uuid, 'Org Backfill', 'org-backfill')).id AS org_backfill \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org_backfill'::uuid AND is_default) AS unit_backfill \gset
SELECT is(
  (SELECT count(*)::integer FROM public.kortex_accounts WHERE organization_id = :'org_backfill'::uuid AND unit_id = :'unit_backfill'::uuid),
  0,
  'a unit created without the seed trigger (simulating a pre-existing unit) starts with no accounts'
);
INSERT INTO public.kortex_accounts (organization_id, unit_id, kind)
SELECT u.organization_id, u.id, k.kind
FROM public.units u
CROSS JOIN unnest(ARRAY[
  'cash', 'revenue_service', 'revenue_product', 'commission_expense',
  'tip_liability', 'refund_expense', 'benefit_obligation_liability'
]) AS k(kind)
WHERE NOT EXISTS (
  SELECT 1 FROM public.kortex_accounts ka
  WHERE ka.organization_id = u.organization_id AND ka.unit_id = u.id AND ka.kind = k.kind
);
SELECT is(
  (SELECT count(*)::integer FROM public.kortex_accounts WHERE organization_id = :'org_backfill'::uuid AND unit_id = :'unit_backfill'::uuid),
  7,
  'running the backfill statement fills the 7 fixed accounts for the pre-existing unit'
);

SELECT * FROM finish();
ROLLBACK;
