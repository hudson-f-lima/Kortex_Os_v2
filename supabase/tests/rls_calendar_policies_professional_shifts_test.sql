BEGIN;
SELECT plan(22);

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
SELECT pg_temp.mk_user('professional1_user@test.local') AS professional1_user \gset
SELECT pg_temp.mk_user('owner2@test.local') AS owner2 \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org Calendar', 'org-calendar')).id AS org1 \gset
SELECT (public.create_organization(:'owner2'::uuid, 'Org Calendar Two', 'org-calendar-two')).id AS org2 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
SELECT (public.unit_create(:'org1'::uuid, :'owner1'::uuid, 'Unit Two')).id AS unit2 \gset

INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid),
  (:'org1'::uuid, :'professional1_user'::uuid, 'professional', :'unit1'::uuid);

INSERT INTO public.professionals (organization_id, user_id, name)
  VALUES (:'org1'::uuid, :'professional1_user'::uuid, 'Profissional Um')
  RETURNING id AS professional1 \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Profissional Sem Vinculo Unit1')
  RETURNING id AS professional2 \gset
SELECT public.professional_unit_assign(:'org1'::uuid, :'owner1'::uuid, :'professional2'::uuid, :'unit2'::uuid);

GRANT SELECT, INSERT, UPDATE ON public.calendar_policies TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.professional_shifts TO authenticated;

-- === calendar_policies: forma do weekly_schedule ===

SELECT pg_temp.login_as(:'owner1'::uuid);

-- Behavior 1: owner insere a 1ª versão da política com sucesso.
SELECT lives_ok(
  format(
    'insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-07-01 00:00:00-03'::timestamptz, :'owner1'
  ),
  'owner1 creates the first calendar_policies version for unit1'
);

-- Behavior 2: chave de dia inválida (fora de 0-6) é rejeitada pelo CHECK.
SELECT throws_ok(
  format(
    'insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"7": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-08-01 00:00:00-03'::timestamptz, :'owner1'
  ),
  '23514',
  null,
  'weekly_schedule with day key "7" is rejected'
);

-- Behavior 3: bloco com start >= end é rejeitado.
SELECT throws_ok(
  format(
    'insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"1": [{"start":"18:00","end":"09:00"}]}'::jsonb, '2026-08-01 00:00:00-03'::timestamptz, :'owner1'
  ),
  '23514',
  null,
  'weekly_schedule block with start >= end is rejected'
);

-- Behavior 4: blocos sobrepostos no mesmo dia são rejeitados.
SELECT throws_ok(
  format(
    'insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"1": [{"start":"09:00","end":"14:00"},{"start":"13:00","end":"18:00"}]}'::jsonb, '2026-08-01 00:00:00-03'::timestamptz, :'owner1'
  ),
  '23514',
  null,
  'weekly_schedule with overlapping blocks on the same day is rejected'
);

-- Behavior 5: 2ª versão (valid_from posterior) fecha a 1ª automaticamente.
SELECT lives_ok(
  format(
    'insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"1": [{"start":"08:00","end":"20:00"}]}'::jsonb, '2026-09-01 00:00:00-03'::timestamptz, :'owner1'
  ),
  'owner1 creates the second calendar_policies version for unit1'
);
SELECT is(
  (SELECT valid_to FROM public.calendar_policies WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND valid_from = '2026-07-01 00:00:00-03'::timestamptz),
  '2026-09-01 00:00:00-03'::timestamptz,
  'first version is closed exactly when the second version starts'
);
SELECT is(
  (SELECT valid_to FROM public.calendar_policies WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND valid_from = '2026-09-01 00:00:00-03'::timestamptz),
  null::timestamptz,
  'second version remains open (valid_to is null)'
);

-- Behavior 6: INSERT fora de ordem cronológica é rejeitado com erro de domínio (22023), não o erro genérico da exclusion constraint.
SELECT throws_ok(
  format(
    'insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"1": [{"start":"08:00","end":"20:00"}]}'::jsonb, '2026-08-15 00:00:00-03'::timestamptz, :'owner1'
  ),
  '22023',
  'calendar policy version out of order',
  'out-of-order valid_from is rejected with a domain error, not the generic exclusion constraint error'
);

-- Behavior 7: linha fechada é imutável — mesmo owner1 não consegue alterar (nenhuma policy de UPDATE existe).
WITH u AS (
  UPDATE public.calendar_policies
  SET weekly_schedule = '{"2": [{"start":"09:00","end":"18:00"}]}'::jsonb
  WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid AND valid_to IS NOT NULL
  RETURNING id
)
SELECT is(
  (SELECT count(*) FROM u),
  0::bigint,
  'owner1 cannot update a closed (immutable) calendar_policies row'
);

-- === RLS unit-aware: achado do Red Team de desenho ===

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.calendar_policies WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid)::int,
  2,
  'reception1 (unit1) reads unit1''s calendar_policies'
);

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT lives_ok(
  format(
    'insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit2', '{"1": [{"start":"10:00","end":"16:00"}]}'::jsonb, '2026-07-01 00:00:00-03'::timestamptz, :'owner1'
  ),
  'owner1 creates a calendar_policies version for unit2'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.calendar_policies WHERE organization_id = :'org1'::uuid AND unit_id = :'unit2'::uuid)::int,
  0,
  'reception1 (unit1 only) cannot read unit2''s calendar_policies (Red Team finding, corrected)'
);
SELECT throws_ok(
  format(
    'insert into public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', '{"3": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-10-01 00:00:00-03'::timestamptz, :'reception1'
  ),
  '42501',
  null,
  'reception1 (insufficient role) cannot insert calendar_policies'
);

SELECT pg_temp.login_as(:'owner2'::uuid);
SELECT is(
  (SELECT count(*) FROM public.calendar_policies WHERE organization_id = :'org1'::uuid)::int,
  0,
  'owner2 (different organization) cannot read org1''s calendar_policies'
);

-- === professional_shifts: turno ⊆ horário, FK a professional_units, vigência ===

SELECT pg_temp.login_as(:'owner1'::uuid);

-- Behavior: turno dentro do horário da unidade (08:00-20:00, vigente desde 2026-09-01) é aceito.
SELECT lives_ok(
  format(
    'insert into public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', :'unit1', '{"1": [{"start":"09:00","end":"17:00"}]}'::jsonb, '2026-09-05 00:00:00-03'::timestamptz, :'owner1'
  ),
  'owner1 creates a professional_shifts version inside unit1 hours'
);

-- Behavior: turno fora do horário da unidade é rejeitado.
SELECT throws_ok(
  format(
    'insert into public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', :'unit1', '{"2": [{"start":"06:00","end":"10:00"}]}'::jsonb, '2026-09-06 00:00:00-03'::timestamptz, :'owner1'
  ),
  '22023',
  'shift outside unit hours without exceptional opening',
  'shift block outside unit hours is rejected'
);

-- Behavior: professional1 nunca foi vinculado a unit3, não pode ter turno lá.
-- (unit3 é nova de propósito: todo profissional nasce auto-vinculado à unidade
-- default (unit1), então "nunca vinculado" só é reproduzível numa 3ª unidade.)
-- O trigger de active-link (seção acima) roda antes da FK e já cobre "nunca
-- vinculado" com o mesmo 22023 do caso "vinculado mas inativo" abaixo — a FK
-- composta continua no schema como rede de segurança caso o trigger seja
-- removido no futuro, mas não é o caminho de erro alcançado por este teste.
SELECT pg_temp.logout();
SELECT (public.unit_create(:'org1'::uuid, :'owner1'::uuid, 'Unit Three')).id AS unit3 \gset
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT throws_ok(
  format(
    'insert into public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', :'unit3', '{"1": [{"start":"09:00","end":"17:00"}]}'::jsonb, '2026-09-05 00:00:00-03'::timestamptz, :'owner1'
  ),
  '22023',
  'professional has no active link to this unit',
  'shift for a professional never linked to the unit is rejected'
);

-- Behavior: vínculo existe mas está desativado — FK sozinha não pega isso (não filtra por active),
-- o trigger precisa checar explicitamente. professional2 não tem membership de
-- login associada (só cadastro), então seu vínculo auto-criado com a unidade
-- default (unit1) pode ser revogado sem esbarrar no guard "vínculo exigido por
-- membership ativa" que protege professional1 (tem membership 'professional').
-- Usa as RPCs canônicas (mesmo comando que a aplicação real usaria), grant
-- service_role apenas — chamadas fora do contexto authenticated.
SELECT pg_temp.logout();
SELECT public.professional_unit_revoke(:'org1'::uuid, :'owner1'::uuid, :'professional2'::uuid, :'unit1'::uuid);
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT throws_ok(
  format(
    'insert into public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional2', :'unit1', '{"1": [{"start":"09:00","end":"17:00"}]}'::jsonb, '2026-09-05 00:00:00-03'::timestamptz, :'owner1'
  ),
  '22023',
  'professional has no active link to this unit',
  'shift for a professional with a deactivated (not deleted) unit link is rejected'
);
SELECT pg_temp.logout();
SELECT public.professional_unit_assign(:'org1'::uuid, :'owner1'::uuid, :'professional2'::uuid, :'unit1'::uuid);
SELECT pg_temp.login_as(:'owner1'::uuid);

-- Behavior: 2ª versão de turno fecha a 1ª (mesma mecânica de calendar_policies).
SELECT lives_ok(
  format(
    'insert into public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', :'unit1', '{"1": [{"start":"10:00","end":"16:00"}]}'::jsonb, '2026-10-01 00:00:00-03'::timestamptz, :'owner1'
  ),
  'owner1 creates a second professional_shifts version for professional1'
);
SELECT is(
  (SELECT valid_to FROM public.professional_shifts WHERE organization_id = :'org1'::uuid AND professional_id = :'professional1'::uuid AND valid_from = '2026-09-05 00:00:00-03'::timestamptz),
  '2026-10-01 00:00:00-03'::timestamptz,
  'first shift version is closed exactly when the second version starts'
);

-- Behavior: private.resolve_calendar_policy retorna os blocos corretos e vazio fora da vigência.
-- Chamada como o role de teste (não authenticated) — a função é revoke all from
-- authenticated de propósito (Blueprint §4), só é chamada por outras funções
-- security definer, nunca diretamente pelo usuário final.
SELECT pg_temp.logout();
SELECT is(
  (SELECT blocks FROM private.resolve_calendar_policy(:'org1'::uuid, :'unit1'::uuid, '2026-09-07'::date)),
  '[{"start":"08:00","end":"20:00"}]'::jsonb,
  'resolve_calendar_policy returns the blocks of the version in effect on that date'
);
SELECT is(
  (SELECT blocks FROM private.resolve_calendar_policy(:'org1'::uuid, :'unit1'::uuid, '2026-06-01'::date)),
  null::jsonb,
  'resolve_calendar_policy returns no row before any version existed'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
