BEGIN;
SELECT plan(8);

-- Helpers: simulate Supabase Auth JWT context inside this transaction only.
-- Same pattern as rls_organizations_settings_test.sql (issue 017).
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

SELECT pg_temp.mk_user('onda5-owner1@test.local') AS owner1 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org Onda5 Settings', 'org-onda5-settings')).id AS org1 \gset

SELECT pg_temp.mk_user('onda5-owner2@test.local') AS owner2 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Onda5 Settings B', 'org-onda5-settings-b')).id AS org2 \gset

-- Granted once, up front, while still running as the test-runner role —
-- authenticated cannot GRANT once SET LOCAL role authenticated is active.
GRANT SELECT, UPDATE ON public.organizations TO authenticated;

-- Behavior 1 (issue 029): organization born with settings = '{}' resolves
-- to the safe defaults (flag off, 30 min TTL, 6h cooldown) via the
-- fatia-029 resolver function, not raw NULLs.
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT is(
  (SELECT row(waitlist_enabled, offer_ttl_minutes, offer_cooldown_hours)
     FROM private.onda5_waitlist_settings(:'org1'::uuid)),
  row(false, 30, 6),
  'defaults resolve to disabled / 30min TTL / 6h cooldown when settings is {}'
);

-- Behavior 2 (issue 029): explicit override is read through, not masked
-- by the defaults — proves the resolver actually reads configured values
-- (coalesce path) rather than always returning the hardcoded defaults.
SELECT pg_temp.login_as(:'owner1'::uuid);
UPDATE public.organizations
   SET settings = '{"recurring_group_waitlist_enabled": true, "waitlist_offer_ttl_minutes": 45, "waitlist_offer_cooldown_hours": 12}'::jsonb
 WHERE id = :'org1'::uuid;

SELECT is(
  (SELECT row(waitlist_enabled, offer_ttl_minutes, offer_cooldown_hours)
     FROM private.onda5_waitlist_settings(:'org1'::uuid)),
  row(true, 45, 12),
  'explicit override (enabled/45min/12h) is read through instead of defaults'
);

-- Behavior 2b (issue 029): explicitly-false is distinct from
-- absent-key-defaults-to-false — both resolve to false, but this proves
-- the coalesce path reads the explicit value rather than accidentally
-- depending on the key being absent to reach the default branch.
UPDATE public.organizations
   SET settings = '{"recurring_group_waitlist_enabled": false, "waitlist_offer_ttl_minutes": 20, "waitlist_offer_cooldown_hours": 3}'::jsonb
 WHERE id = :'org1'::uuid;

SELECT is(
  (SELECT row(waitlist_enabled, offer_ttl_minutes, offer_cooldown_hours)
     FROM private.onda5_waitlist_settings(:'org1'::uuid)),
  row(false, 20, 3),
  'explicit false flag is honored, sibling non-default TTL/cooldown still read through'
);

-- Behavior 3 (issue 029): tenant isolation — owner1 (member of org1 only)
-- cannot read org2's waitlist settings through the resolver, even though
-- the function is security definer. private.is_member() must fail-closed
-- for a non-member caller, not just rely on RLS of organizations.
SELECT throws_ok(
  format('select * from private.onda5_waitlist_settings(%L::uuid)', :'org2'),
  '42501',
  'insufficient organization permission',
  'owner1 cannot read org2 settings (not a member) — fails closed with 42501'
);

-- Behavior 4 (issue 029): invalid shape is rejected by the CHECK
-- constraint at write time — a negative TTL never reaches a caller as a
-- silently-coerced value.
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT throws_ok(
  format(
    'update public.organizations set settings = %L where id = %L',
    '{"waitlist_offer_ttl_minutes": -5}'::jsonb,
    :'org1'
  ),
  '23514',
  null,
  'negative waitlist_offer_ttl_minutes is rejected by the shape constraint'
);

SELECT throws_ok(
  format(
    'update public.organizations set settings = %L where id = %L',
    '{"recurring_group_waitlist_enabled": "yes"}'::jsonb,
    :'org1'
  ),
  '23514',
  null,
  'non-boolean recurring_group_waitlist_enabled is rejected by the shape constraint'
);

SELECT throws_ok(
  format(
    'update public.organizations set settings = %L where id = %L',
    '{"waitlist_offer_ttl_minutes": 12.5}'::jsonb,
    :'org1'
  ),
  '23514',
  null,
  'non-integer waitlist_offer_ttl_minutes is rejected by the shape constraint'
);

-- Behavior 4b (issue 029, achado do Red Team de implementação 2026-08-04):
-- sem limite superior, um valor absurdo (ex.: 999999999 minutos) seria
-- aceito e chegaria intacto às fatias 034/035, que usam este TTL como
-- janela de hold real — equivalente a um hold que nunca expira. Bound
-- superior sao: TTL <= 1440min (24h) e cooldown <= 168h (7 dias), bem
-- acima dos defaults (30min/6h) mas sem permitir absurdo.
SELECT throws_ok(
  format(
    'update public.organizations set settings = %L where id = %L',
    '{"waitlist_offer_ttl_minutes": 999999999}'::jsonb,
    :'org1'
  ),
  '23514',
  null,
  'absurdly large waitlist_offer_ttl_minutes is rejected by the shape constraint upper bound'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
