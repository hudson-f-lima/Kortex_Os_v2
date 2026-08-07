-- Onda 1, fatia 001 (issues/001-services-deposit-policy.md): the deposit/
-- no-show columns added to `services` are purely additive — no new RLS
-- policy, same owner/admin/manager write gate that already governs the rest
-- of the catalog (services_insert/services_update).
BEGIN;
SELECT plan(10);

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

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('reception1@test.local') AS reception1 \gset
SELECT pg_temp.mk_user('manager1@test.local') AS manager1 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org Deposit', 'org-deposit')).id AS org1 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'manager1'::uuid, 'manager');

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset

-- === schema-level invariants: additive columns, both-or-neither pairs, percentage cap ===
SELECT throws_ok(
  format(
    $sql$insert into public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_type)
    values (%L, 'Sem Par Depósito', 5000, 30, %L, 'percentage')$sql$,
    :'org1', :'group1'
  ),
  '23514',
  NULL,
  'deposit_type without deposit_value is rejected (both-or-neither pair)'
);
SELECT throws_ok(
  format(
    $sql$insert into public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_type, deposit_value)
    values (%L, 'Depósito Acima De 100%%', 5000, 30, %L, 'percentage', 10001)$sql$,
    :'org1', :'group1'
  ),
  '23514',
  NULL,
  'a percentage deposit_value above 10000 basis points is rejected'
);
SELECT throws_ok(
  format(
    $sql$insert into public.services (organization_id, name, price_cents, duration_minutes, service_group_id, no_show_commission_value)
    values (%L, 'Sem Par No-Show', 5000, 30, %L, 1000)$sql$,
    :'org1', :'group1'
  ),
  '23514',
  NULL,
  'no_show_commission_value without no_show_commission_type is rejected (both-or-neither pair)'
);
SELECT lives_ok(
  format(
    $sql$insert into public.services (organization_id, name, price_cents, duration_minutes, service_group_id, deposit_mechanic, deposit_type, deposit_value, no_show_commission_type, no_show_commission_value)
    values (%L, 'Corte Com Depósito', 5000, 30, %L, 'hold', 'percentage', 2000, 'fixed', 999999)$sql$,
    :'org1', :'group1'
  ),
  'a full deposit/no-show policy with an unbounded fixed no_show_commission_value is accepted'
);
SELECT (id) AS service1 FROM public.services WHERE organization_id = :'org1'::uuid AND name = 'Corte Com Depósito' \gset

-- === existing services (created before this fatia) are untouched: NULL, no behavior change ===
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte Simples', 4000, 20, :'group1'::uuid)
  RETURNING id AS service2 \gset
SELECT ok(
  (SELECT deposit_mechanic IS NULL AND deposit_type IS NULL AND deposit_value IS NULL
     AND no_show_commission_type IS NULL AND no_show_commission_value IS NULL
   FROM public.services WHERE id = :'service2'::uuid),
  'a service created without the new fields has all five columns NULL'
);

-- === RLS: no new policy was created for these columns — same 4 named policies as before ===
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.services', 'INSERT'),
  'authenticated has no direct INSERT grant on services'
);
SELECT set_eq(
  $sql$select policyname from pg_policies where schemaname = 'public' and tablename = 'services'$sql$,
  ARRAY['services_select', 'services_insert', 'services_update', 'services_delete'],
  'services still has exactly the 4 pre-existing policies — no new policy for the deposit columns'
);

-- === write gate on the new columns matches the existing catalog edit rule (owner/admin/manager) ===
GRANT SELECT, INSERT, UPDATE, DELETE ON public.services TO authenticated;

-- RLS-filtered UPDATE does not raise (USING just hides the row from the
-- statement), it silently affects zero rows — same pattern as the
-- manager1-cannot-delete-a-service_group check in rls_service_groups_packages_test.sql.
SELECT pg_temp.login_as(:'reception1'::uuid);
WITH u AS (
  UPDATE public.services SET deposit_mechanic = 'hold', deposit_type = 'fixed', deposit_value = 500
  WHERE id = :'service2'::uuid
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM u),
  0::bigint,
  'reception1 cannot write the deposit columns (insufficient role, same as any other services field)'
);

SELECT pg_temp.login_as(:'manager1'::uuid);
SELECT lives_ok(
  format(
    $sql$update public.services set deposit_mechanic = 'immediate_charge', deposit_type = 'fixed', deposit_value = 500
    where id = %L$sql$,
    :'service2'
  ),
  'manager1 can write the deposit columns (same rule as the rest of the catalog)'
);
SELECT ok(
  (SELECT deposit_mechanic = 'immediate_charge' FROM public.services WHERE id = :'service2'::uuid),
  'the update by manager1 persisted'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
