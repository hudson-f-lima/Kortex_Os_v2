BEGIN;
SELECT plan(23);

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

SELECT (public.create_organization(:'owner1'::uuid, 'Org Holidays', 'org-holidays')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
SELECT (public.unit_create(:'org1'::uuid, :'owner1'::uuid, 'Unit Two')).id AS unit2 \gset

INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES
  (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid),
  (:'org1'::uuid, :'manager1'::uuid, 'manager', null);

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Unit1') RETURNING id AS professional1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Unit2') RETURNING id AS professional2 \gset
SELECT public.professional_unit_assign(:'org1'::uuid, :'owner1'::uuid, :'professional2'::uuid, :'unit2'::uuid);
SELECT public.professional_unit_revoke(:'org1'::uuid, :'owner1'::uuid, :'professional2'::uuid, :'unit1'::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.calendar_holidays TO authenticated;
GRANT SELECT, INSERT ON public.calendar_exceptions TO authenticated;
GRANT SELECT, INSERT ON public.calendar_time_off TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);

-- === calendar_holidays ===

SELECT lives_ok(
  format('insert into public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, created_by) values (%L, null, %L, %L, %L, %L)',
    :'org1', '2026-12-25'::date, 'Natal', 'national', :'owner1'),
  'owner1 creates an org-wide holiday (unit_id null)'
);
SELECT lives_ok(
  format('insert into public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, unit_opens, created_by) values (%L, %L, %L, %L, %L, %L, %L)',
    :'org1', :'unit1', '2026-12-25'::date, 'Natal (unit1 abre)', 'national', true, :'owner1'),
  'org-wide and unit-specific holidays coexist for the same date without violating uniqueness'
);
SELECT throws_ok(
  format('insert into public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, created_by) values (%L, null, %L, %L, %L, %L)',
    :'org1', '2026-12-25'::date, 'Natal Duplicado', 'national', :'owner1'),
  '23505',
  null,
  'a second org-wide holiday on the same date is rejected by the partial unique index'
);
SELECT lives_ok(
  format('insert into public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'unit2', '2026-11-15'::date, 'Feriado so unit2', 'custom', :'owner1'),
  'owner1 creates a unit2-only holiday'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.calendar_holidays WHERE organization_id = :'org1'::uuid AND holiday_date = '2026-12-25'::date)::int,
  2,
  'reception1 (unit1) sees both the org-wide and the unit1-specific holiday'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_holidays WHERE organization_id = :'org1'::uuid AND unit_id = :'unit2'::uuid)::int,
  0,
  'reception1 (unit1 only) cannot see unit2''s holiday'
);
SELECT throws_ok(
  format('insert into public.calendar_holidays (organization_id, unit_id, holiday_date, name, holiday_type, created_by) values (%L, null, %L, %L, %L, %L)',
    :'org1', '2027-01-01'::date, 'Ano Novo', 'national', :'reception1'),
  '42501',
  null,
  'reception1 (insufficient role) cannot insert a holiday'
);
WITH u AS (
  UPDATE public.calendar_holidays SET unit_opens = true
  WHERE organization_id = :'org1'::uuid AND holiday_date = '2026-11-15'::date
  RETURNING id
)
SELECT is((SELECT count(*) FROM u), 0::bigint, 'reception1 cannot update a holiday');

SELECT pg_temp.login_as(:'manager1'::uuid);
WITH d AS (
  DELETE FROM public.calendar_holidays
  WHERE organization_id = :'org1'::uuid AND holiday_date = '2026-11-15'::date
  RETURNING id
)
SELECT is((SELECT count(*) FROM d), 0::bigint, 'manager1 cannot delete a holiday (owner/admin only)');

SELECT pg_temp.login_as(:'owner1'::uuid);
WITH d AS (
  DELETE FROM public.calendar_holidays
  WHERE organization_id = :'org1'::uuid AND holiday_date = '2026-11-15'::date AND unit_id = :'unit2'::uuid
  RETURNING id
)
SELECT is((SELECT count(*) FROM d), 1::bigint, 'owner1 can delete a holiday');

-- === calendar_exceptions ===

SELECT throws_ok(
  format('insert into public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by) values (%L, %L, %L, %L, %L, %L, %L, %L, %L)',
    :'org1', 'punctual_override', 'unit', :'unit1', '2026-12-24 18:00-03'::timestamptz, '2026-12-24 22:00-03'::timestamptz, true, 'Evento especial', :'owner1'),
  '23514',
  null,
  'punctual_override without authorized_by is rejected'
);
SELECT lives_ok(
  format('insert into public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by, authorized_by) values (%L, %L, %L, %L, %L, %L, %L, %L, %L, %L)',
    :'org1', 'punctual_override', 'unit', :'unit1', '2026-12-24 18:00-03'::timestamptz, '2026-12-24 22:00-03'::timestamptz, true, 'Evento especial', :'owner1', :'owner1'),
  'punctual_override with authorized_by is accepted'
);
SELECT throws_ok(
  format('insert into public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by) values (%L, %L, %L, %L, %L, %L, %L, %L, %L)',
    :'org1', 'exceptional_closure', 'unit', :'unit1', '2026-12-26 00:00-03'::timestamptz, '2026-12-27 00:00-03'::timestamptz, true, 'Reforma', :'owner1'),
  '23514',
  null,
  'exceptional_closure with is_open = true is rejected (mismatched pair)'
);
SELECT throws_ok(
  format('insert into public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by) values (%L, %L, %L, %L, %L, %L, %L, %L, %L)',
    :'org1', 'exceptional_opening', 'professional', :'unit1', '2026-12-26 00:00-03'::timestamptz, '2026-12-27 00:00-03'::timestamptz, true, 'Sem professional_id', :'owner1'),
  '23514',
  null,
  'scope = professional without professional_id is rejected'
);
SELECT lives_ok(
  format('insert into public.calendar_exceptions (organization_id, exception_type, scope, unit_id, starts_at, ends_at, is_open, reason, authored_by) values (%L, %L, %L, %L, %L, %L, %L, %L, %L)',
    :'org1', 'exceptional_opening', 'unit', :'unit2', '2026-12-26 09:00-03'::timestamptz, '2026-12-26 13:00-03'::timestamptz, true, 'Vespera de festa', :'owner1'),
  'owner1 creates an exceptional_opening for unit2'
);

-- Achado de auditoria pós-implementação (2026-07-29): a FK original só
-- confirmava que o profissional existe na organização, não que ele tem
-- vínculo com a unit_id desta exceção. professional2 está vinculado só a
-- unit2 (revogado de unit1 na fixture acima) — uma exceção scope='professional'
-- para professional2 em unit1 agora é rejeitada pela FK composta.
SELECT throws_ok(
  format('insert into public.calendar_exceptions (organization_id, exception_type, scope, unit_id, professional_id, starts_at, ends_at, is_open, reason, authored_by) values (%L, %L, %L, %L, %L, %L, %L, %L, %L, %L)',
    :'org1', 'exceptional_opening', 'professional', :'unit1', :'professional2', '2026-12-28 09:00-03'::timestamptz, '2026-12-28 13:00-03'::timestamptz, true, 'Profissional sem vinculo', :'owner1'),
  '23503',
  null,
  'a scope=professional exception for a professional not linked to that unit is rejected by the composite FK'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.calendar_exceptions WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid)::int,
  1,
  'reception1 (unit1) sees unit1''s exception'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_exceptions WHERE organization_id = :'org1'::uuid AND unit_id = :'unit2'::uuid)::int,
  0,
  'reception1 (unit1 only) cannot see unit2''s exception'
);

-- === calendar_time_off ===

SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT lives_ok(
  format('insert into public.calendar_time_off (organization_id, professional_id, starts_at, ends_at, reason, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', '2026-08-10 00:00-03'::timestamptz, '2026-08-20 00:00-03'::timestamptz, 'Ferias', :'owner1'),
  'owner1 creates time_off for professional1'
);
SELECT throws_ok(
  format('insert into public.calendar_time_off (organization_id, professional_id, starts_at, ends_at, reason, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional1', '2026-08-15 00:00-03'::timestamptz, '2026-08-25 00:00-03'::timestamptz, 'Sobreposta', :'owner1'),
  '23P01',
  null,
  'overlapping time_off for the same professional is rejected by the exclusion constraint'
);
SELECT lives_ok(
  format('insert into public.calendar_time_off (organization_id, professional_id, starts_at, ends_at, reason, created_by) values (%L, %L, %L, %L, %L, %L)',
    :'org1', :'professional2', '2026-08-10 00:00-03'::timestamptz, '2026-08-20 00:00-03'::timestamptz, 'Ferias P2', :'owner1'),
  'owner1 creates time_off for professional2 (linked only to unit2)'
);

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.calendar_time_off WHERE organization_id = :'org1'::uuid AND professional_id = :'professional1'::uuid)::int,
  1,
  'reception1 (unit1) sees time_off of professional1 (linked to unit1)'
);
SELECT is(
  (SELECT count(*) FROM public.calendar_time_off WHERE organization_id = :'org1'::uuid AND professional_id = :'professional2'::uuid)::int,
  0,
  'reception1 (unit1 only) cannot see time_off of professional2 (linked only to unit2)'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
