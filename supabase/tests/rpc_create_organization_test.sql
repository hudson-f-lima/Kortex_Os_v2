BEGIN;
SELECT plan(6);

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
