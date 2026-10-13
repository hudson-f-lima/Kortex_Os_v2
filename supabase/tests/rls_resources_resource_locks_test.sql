BEGIN;
SELECT plan(20);

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
SELECT pg_temp.mk_user('outsider@test.local') AS outsider \gset

SELECT (public.create_organization(:'owner1'::uuid, 'Org Resources', 'org-resources')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset
SELECT (public.unit_create(:'org1'::uuid, :'owner1'::uuid, 'Unit Two')).id AS unit2 \gset

INSERT INTO public.memberships (organization_id, user_id, role, unit_id)
VALUES (:'org1'::uuid, :'reception1'::uuid, 'reception', :'unit1'::uuid);

INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Profissional Um') RETURNING id AS professional1 \gset
INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Grupo Um', 'percentage', 1000) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 60, :'group1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset
INSERT INTO public.appointments (organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, status, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, :'client1'::uuid, :'professional1'::uuid, :'service1'::uuid, '2026-09-01 10:00:00-03'::timestamptz, '2026-09-01 11:00:00-03'::timestamptz, 'confirmed', :'owner1'::uuid)
  RETURNING id AS appt1 \gset

GRANT SELECT, INSERT, UPDATE ON public.resources TO authenticated;
GRANT SELECT ON public.resource_locks TO authenticated;

SELECT pg_temp.login_as(:'owner1'::uuid);

-- === resources ===
SELECT lives_ok(
  format('insert into public.resources (organization_id, unit_id, name, resource_type, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', 'Sala 1', 'room', :'owner1'),
  'owner1 creates a resource in unit1'
);
INSERT INTO public.resources (organization_id, unit_id, name, resource_type, created_by)
  VALUES (:'org1'::uuid, :'unit2'::uuid, 'Sala 2', 'room', :'owner1'::uuid) RETURNING id AS resource2 \gset

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT throws_ok(
  format('insert into public.resources (organization_id, unit_id, name, resource_type, created_by) values (%L, %L, %L, %L, %L)',
    :'org1', :'unit1', 'Sala Nao Autorizada', 'room', :'reception1'),
  '42501',
  null,
  'reception1 (insufficient role) cannot insert a resource'
);
SELECT pg_temp.login_as(:'owner1'::uuid);

SELECT id AS resource1 FROM public.resources WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid \gset

SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.resources WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid)::int,
  1,
  'reception1 (unit1) sees unit1''s resource'
);
SELECT is(
  (SELECT count(*) FROM public.resources WHERE organization_id = :'org1'::uuid AND unit_id = :'unit2'::uuid)::int,
  0,
  'reception1 (unit1 only) cannot see unit2''s resource'
);

-- resource_locks has no direct grant for authenticated — even owner1 cannot bypass the RPC.
SELECT pg_temp.login_as(:'owner1'::uuid);
SELECT throws_ok(
  format('insert into public.resource_locks (organization_id, unit_id, resource_id, lock_reason, starts_at, ends_at, created_by) values (%L, %L, %L, %L, %L, %L, %L)',
    :'org1', :'unit1', :'resource1', 'maintenance', '2026-09-05 09:00:00-03'::timestamptz, '2026-09-05 10:00:00-03'::timestamptz, :'owner1'),
  '42501',
  null,
  'even owner1 cannot INSERT resource_locks directly — no table grant, only RPCs'
);

-- === resource_lock_create ===
SELECT pg_temp.logout();

SELECT lives_ok(
  format('select public.resource_lock_create(%L, %L, %L, %L, %L, %L, null, %L, %L, %L)',
    :'org1', :'unit1', :'owner1', 'lock-maint-001', :'resource1', 'maintenance', '2026-09-05 09:00:00-03'::timestamptz, '2026-09-05 10:00:00-03'::timestamptz, 'Manutencao preventiva'),
  'owner1 creates a manual maintenance lock via the RPC'
);

SELECT lives_ok(
  format('select public.resource_lock_create(%L, %L, %L, %L, %L, %L, %L, %L, %L, null)',
    :'org1', :'unit1', :'owner1', 'lock-appt-001', :'resource1', 'appointment', :'appt1', '2026-09-01 10:00:00-03'::timestamptz, '2026-09-01 11:00:00-03'::timestamptz),
  'owner1 creates an appointment-linked lock via the RPC'
);

SELECT throws_ok(
  format('select public.resource_lock_create(%L, %L, %L, %L, %L, %L, null, %L, %L, null)',
    :'org1', :'unit1', :'owner1', 'lock-appt-002', :'resource1', 'appointment', '2026-09-06 09:00:00-03'::timestamptz, '2026-09-06 10:00:00-03'::timestamptz),
  '22023',
  null,
  'lock_reason = appointment without appointment_id is rejected'
);

SELECT throws_ok(
  format('select public.resource_lock_create(%L, %L, %L, %L, %L, %L, null, %L, %L, %L)',
    :'org1', :'unit1', :'owner1', 'lock-overlap-001', :'resource1', 'maintenance', '2026-09-05 09:30:00-03'::timestamptz, '2026-09-05 10:30:00-03'::timestamptz, 'Sobreposto'),
  '23P01',
  null,
  'overlapping resource_lock for the same resource/time range is rejected'
);

SELECT throws_ok(
  format('select public.resource_lock_create(%L, %L, %L, %L, %L, %L, null, %L, %L, %L)',
    :'org1', :'unit1', :'outsider', 'lock-unauth-001', :'resource1', 'maintenance', '2026-09-07 09:00:00-03'::timestamptz, '2026-09-07 10:00:00-03'::timestamptz, 'Nao autorizado'),
  '42501',
  null,
  'an actor with no active membership in the organization cannot create a lock (fails closed)'
);

SELECT throws_ok(
  format('select public.resource_lock_create(%L, %L, %L, %L, %L, %L, null, %L, %L, %L)',
    :'org1', :'unit1', :'owner1', 'lock-reason-too-long-001', :'resource1', 'maintenance', '2026-09-08 09:00:00-03'::timestamptz, '2026-09-08 10:00:00-03'::timestamptz, repeat('x', 501)),
  '22023',
  'resource lock reason is too long',
  'resource_lock_create rejects oversized descriptive reasons'
);

-- Idempotência: mesma chave + mesmo payload retorna o mesmo lock, sem duplicar.
SELECT is(
  (SELECT (public.resource_lock_create(:'org1'::uuid, :'unit1'::uuid, :'owner1'::uuid, 'lock-maint-001', :'resource1'::uuid, 'maintenance', null, '2026-09-05 09:00:00-03'::timestamptz, '2026-09-05 10:00:00-03'::timestamptz, 'Manutencao preventiva')).id),
  (SELECT id FROM public.resource_locks WHERE organization_id = :'org1'::uuid AND created_by = :'owner1'::uuid AND starts_at = '2026-09-05 09:00:00-03'::timestamptz AND lock_reason = 'maintenance'),
  'repeating the same idempotency key with the same payload returns the same lock, not a new one'
);
-- Muda starts_at/ends_at (parte do hash de idempotência) — reason sozinho não
-- conta como "payload diferente" de propósito (é nota descritiva, não parâmetro
-- estrutural do lock).
SELECT throws_ok(
  format('select public.resource_lock_create(%L, %L, %L, %L, %L, %L, null, %L, %L, %L)',
    :'org1', :'unit1', :'owner1', 'lock-maint-001', :'resource1', 'maintenance', '2026-09-05 11:00:00-03'::timestamptz, '2026-09-05 12:00:00-03'::timestamptz, 'Manutencao preventiva'),
  '22023',
  'idempotency key reused with a different payload',
  'reusing the same idempotency key with a different time range is rejected'
);

-- === resource_lock_release ===
SELECT (SELECT id FROM public.resource_locks WHERE organization_id = :'org1'::uuid AND lock_reason = 'appointment') AS appt_lock_id \gset
SELECT (SELECT version FROM public.resource_locks WHERE id = :'appt_lock_id'::uuid) AS appt_lock_version \gset

SELECT throws_ok(
  format('select public.resource_lock_release(%L, %L, %L, %L, %L)',
    :'org1', :'unit1', :'owner1', :'appt_lock_id', (:'appt_lock_version'::bigint + 1)),
  'P0004',
  'resource lock version conflict',
  'releasing with a stale version is rejected'
);
SELECT lives_ok(
  format('select public.resource_lock_release(%L, %L, %L, %L, %L)',
    :'org1', :'unit1', :'owner1', :'appt_lock_id', :'appt_lock_version'),
  'releasing with the correct version succeeds'
);
SELECT is(
  (SELECT status FROM public.resource_locks WHERE id = :'appt_lock_id'::uuid),
  'released',
  'the released lock is persisted as released'
);
SELECT is(
  (SELECT version FROM public.resource_locks WHERE id = :'appt_lock_id'::uuid),
  (:'appt_lock_version'::bigint + 1),
  'version is incremented automatically by the trigger on release'
);

-- Achado de auditoria pós-implementação (2026-07-29): a versão original só
-- comparava version, então uma segunda release com a version JÁ atualizada
-- (devolvida pela primeira chamada) passava sem erro.
SELECT (SELECT version FROM public.resource_locks WHERE id = :'appt_lock_id'::uuid) AS released_lock_version \gset
SELECT throws_ok(
  format('select public.resource_lock_release(%L, %L, %L, %L, %L)',
    :'org1', :'unit1', :'owner1', :'appt_lock_id', :'released_lock_version'),
  '22023',
  'resource lock is not active',
  'releasing an already-released lock is rejected even with the correct current version'
);

-- === RLS de resource_locks (leitura) ===
SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.resource_locks WHERE organization_id = :'org1'::uuid AND unit_id = :'unit1'::uuid)::int,
  2,
  'reception1 (unit1) sees unit1''s resource_locks'
);

SELECT pg_temp.logout();
SELECT public.resource_lock_create(:'org1'::uuid, :'unit2'::uuid, :'owner1'::uuid, 'lock-unit2-001', :'resource2'::uuid, 'maintenance', null, '2026-09-05 09:00:00-03'::timestamptz, '2026-09-05 10:00:00-03'::timestamptz, 'Manutencao unit2');
SELECT pg_temp.login_as(:'reception1'::uuid);
SELECT is(
  (SELECT count(*) FROM public.resource_locks WHERE organization_id = :'org1'::uuid AND unit_id = :'unit2'::uuid)::int,
  0,
  'reception1 (unit1 only) cannot see unit2''s resource_locks'
);

SELECT pg_temp.logout();

SELECT * FROM finish();
ROLLBACK;
