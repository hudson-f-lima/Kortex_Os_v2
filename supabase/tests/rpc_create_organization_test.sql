BEGIN;
SELECT plan(10);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('founder@test.local') AS founder \gset

-- Grant lockdown: only service_role (and superuser) may execute this RPC.
SELECT ok(
  NOT has_function_privilege('authenticated', 'public.create_organization(uuid, text, text)', 'EXECUTE'),
  'authenticated cannot execute create_organization'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.create_organization(uuid, text, text)', 'EXECUTE'),
  'anon cannot execute create_organization'
);

-- Happy path
SELECT (public.create_organization(:'founder'::uuid, 'Studio Bela', 'studio-bela')).id AS org1 \gset
SELECT ok(:'org1'::uuid IS NOT NULL, 'create_organization returns a new organization id');
SELECT ok(
  EXISTS(
    SELECT 1 FROM public.memberships
    WHERE organization_id = :'org1'::uuid AND user_id = :'founder'::uuid AND role = 'owner' AND active
  ),
  'the actor becomes an active owner membership of the new organization'
);

-- Onda 0: inserting into organizations (whichever the caller — this RPC,
-- or any direct insert elsewhere, e.g. rpc_fase9_foundation_test.sql's fixture)
-- always creates a default unit via an AFTER INSERT trigger on organizations
-- itself, not via create_organization-specific logic (DEC-31). Fixed timezone,
-- no per-org input in this onda. The owner membership stays org-wide (unit_id null).
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default AND active) AS unit1 \gset
SELECT ok(:'unit1'::uuid IS NOT NULL, 'create_organization creates exactly one default active unit');
SELECT is(
  (SELECT timezone FROM public.units WHERE id = :'unit1'::uuid),
  'America/Sao_Paulo',
  'the default unit gets the fixed timezone (no per-organization input in Onda 0)'
);
SELECT ok(
  EXISTS(
    SELECT 1 FROM public.unit_access_audit_events
    WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid
      AND event_type = 'unit_created' AND actor_kind = 'system'
  ),
  'inserting the organization records a system-attributed unit_created audit event (the trigger has no user actor to attribute it to)'
);
SELECT ok(
  (SELECT unit_id FROM public.memberships WHERE organization_id = :'org1'::uuid AND user_id = :'founder'::uuid) IS NULL,
  'the owner membership remains org-wide (unit_id null) even though a unit now exists'
);

-- Invalid actor
SELECT throws_ok(
  format('select public.create_organization(%L, %L, %L)', gen_random_uuid(), 'Sem Ator', 'sem-ator'),
  '28000',
  NULL,
  'create_organization rejects an actor that is not a real auth.users row'
);

-- Duplicate slug
SELECT throws_ok(
  format('select public.create_organization(%L, %L, %L)', :'founder', 'Studio Duplicado', 'studio-bela'),
  '23505',
  NULL,
  'create_organization rejects a duplicate slug'
);

SELECT * FROM finish();
ROLLBACK;
