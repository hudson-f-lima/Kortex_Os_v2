BEGIN;
SELECT plan(7);

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
SELECT pg_temp.mk_user('pro1_user@test.local') AS pro1_user \gset
SELECT pg_temp.mk_user('pro2_user@test.local') AS pro2_user \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org SelfView', 'org-selfview')).id AS org1 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'reception1'::uuid, 'reception');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'pro1_user'::uuid, 'professional');
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'pro2_user'::uuid, 'professional');

INSERT INTO public.professionals (organization_id, user_id, name)
  VALUES (:'org1'::uuid, :'pro1_user'::uuid, 'Profissional Um')
  RETURNING id AS professional1 \gset
INSERT INTO public.professionals (organization_id, user_id, name)
  VALUES (:'org1'::uuid, :'pro2_user'::uuid, 'Profissional Dois')
  RETURNING id AS professional2 \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Sem login')
  RETURNING id AS professional3 \gset

-- Grant local à transação (padrão de rls_professional_service_capabilities_test.sql):
-- authenticated não recebe grant direto de tabela em produção (só service_role
-- consulta tabelas; a PWA nunca conecta como authenticated), então o pgTAP
-- precisa concedê-lo aqui para exercitar as policies via SET LOCAL role.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.professionals TO authenticated;

-- owner/admin/manager/reception continuam vendo todos os profissionais
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT set_eq(
  format($sql$select id from public.professionals where organization_id = %L$sql$, :'org1'),
  ARRAY[:'professional1'::uuid, :'professional2'::uuid, :'professional3'::uuid],
  'owner sees all 3 professionals in the org'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT set_eq(
  format($sql$select id from public.professionals where organization_id = %L$sql$, :'org1'),
  ARRAY[:'professional1'::uuid, :'professional2'::uuid, :'professional3'::uuid],
  'reception sees all professionals in the org'
);

-- professional role só enxerga a própria linha (self-view)
SELECT pg_temp.login_as(:'pro1_user'::uuid);
SELECT set_eq(
  format($sql$select id from public.professionals where organization_id = %L$sql$, :'org1'),
  ARRAY[:'professional1'::uuid],
  'professional1 only sees its own professionals row'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.professionals WHERE id = :'professional2'::uuid),
  'professional1 cannot see professional2 row directly by id'
);
SELECT ok(
  NOT EXISTS(SELECT 1 FROM public.professionals WHERE id = :'professional3'::uuid),
  'professional1 cannot see the unlinked professional3 row'
);

SELECT pg_temp.login_as(:'pro2_user'::uuid);
SELECT set_eq(
  format($sql$select id from public.professionals where organization_id = %L$sql$, :'org1'),
  ARRAY[:'professional2'::uuid],
  'professional2 only sees its own professionals row'
);

SELECT pg_temp.logout();

-- insert/update/delete permissions unchanged by this migration
SELECT pg_temp.login_as(:'pro1_user'::uuid);
SELECT throws_ok(
  format(
    $sql$insert into public.professionals (organization_id, name) values (%L, 'Nao autorizado')$sql$,
    :'org1'
  ),
  '42501',
  NULL,
  'professional role still cannot insert professionals (unchanged by self-view policy)'
);

SELECT pg_temp.logout();
SELECT * FROM finish();
ROLLBACK;
