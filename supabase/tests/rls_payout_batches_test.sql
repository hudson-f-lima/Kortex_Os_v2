BEGIN;
SELECT plan(13);

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
SELECT pg_temp.mk_user('outsider@test.local') AS outsider \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org One', 'org-one')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null),
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid);
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Um') RETURNING id AS professional1 \gset
INSERT INTO public.staff_current_accounts (organization_id, professional_id, balance_cents)
  VALUES (:'org1'::uuid, :'professional1'::uuid, 5000) RETURNING id AS staff_account1 \gset

-- === Constraints: payout_batches ===
SELECT lives_ok(
  format(
    'insert into public.payout_batches (organization_id, unit_id, period_start, period_end) values (%L, %L, %L, %L)',
    :'org1', :'unit1', '2026-07-01', '2026-07-31'
  ),
  'a valid payout_batch can be created'
);
SELECT throws_ok(
  format(
    'insert into public.payout_batches (organization_id, unit_id, period_start, period_end) values (%L, %L, %L, %L)',
    :'org1', :'unit1', '2026-07-31', '2026-07-01'
  ),
  '23514',
  NULL,
  'period_end before period_start is rejected'
);
SELECT throws_ok(
  format(
    'insert into public.payout_batches (organization_id, unit_id, period_start, period_end, status) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '2026-07-01', '2026-07-31', 'cancelled'
  ),
  '23514',
  NULL,
  'payout_batches.status outside the allowlist is rejected'
);
SELECT (SELECT id FROM public.payout_batches WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid LIMIT 1) AS batch1 \gset

-- === Constraints: payout_batch_items ===
SELECT lives_ok(
  format(
    'insert into public.payout_batch_items (organization_id, payout_batch_id, professional_id, amount_cents) values (%L, %L, %L, %s)',
    :'org1', :'batch1', :'professional1', 3000
  ),
  'a valid payout_batch_item can be created'
);
SELECT throws_ok(
  format(
    'insert into public.payout_batch_items (organization_id, payout_batch_id, professional_id, amount_cents) values (%L, %L, %L, %s)',
    :'org1', :'batch1', :'professional1', 0
  ),
  '23514',
  NULL,
  'amount_cents must be strictly positive'
);
SELECT throws_ok(
  format(
    'insert into public.payout_batch_items (organization_id, payout_batch_id, professional_id, amount_cents, status) values (%L, %L, %L, %s, %L)',
    :'org1', :'batch1', :'professional1', 1000, 'refunded'
  ),
  '23514',
  NULL,
  'payout_batch_items.status outside the allowlist is rejected'
);
SELECT throws_ok(
  format(
    'insert into public.payout_batch_items (organization_id, payout_batch_id, professional_id, amount_cents) values (%L, %L, %L, %s)',
    :'org1', :'batch1', gen_random_uuid(), 1000
  ),
  '23503',
  NULL,
  'professional_id must reference an existing staff_current_accounts row (tenant-safe composite FK)'
);

-- === Layer 1: grants — no direct table privilege for anon/authenticated ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.payout_batches', 'INSERT'),
  'authenticated has no direct INSERT grant on payout_batches'
);
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.payout_batch_items', 'INSERT'),
  'authenticated has no direct INSERT grant on payout_batch_items'
);

-- === Layer 2: RLS policies ===
GRANT SELECT ON public.payout_batches, public.payout_batch_items TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.payout_batches WHERE id = :'batch1'::uuid)
    AND EXISTS(SELECT 1 FROM public.payout_batch_items WHERE payout_batch_id = :'batch1'::uuid),
  'owner can read payout_batches and payout_batch_items'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT ok(
  EXISTS(SELECT 1 FROM public.payout_batches WHERE id = :'batch1'::uuid)
    AND EXISTS(SELECT 1 FROM public.payout_batch_items WHERE payout_batch_id = :'batch1'::uuid),
  'manager can read payout_batches and payout_batch_items'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.payout_batches WHERE id = :'batch1'::uuid)
    AND NOT EXISTS(SELECT 1 FROM public.payout_batch_items WHERE payout_batch_id = :'batch1'::uuid),
  'reception cannot read payout_batches nor payout_batch_items'
);
SELECT pg_temp.logout();

SELECT pg_temp.login_as(:'outsider'::uuid);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.payout_batches WHERE id = :'batch1'::uuid)
    AND NOT EXISTS(SELECT 1 FROM public.payout_batch_items WHERE payout_batch_id = :'batch1'::uuid),
  'a user with no membership cannot read either table'
);
SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
