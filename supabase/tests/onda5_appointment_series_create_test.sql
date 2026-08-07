BEGIN;
SELECT plan(10);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Series Create', 'org-series-create')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Ana') RETURNING id AS prof1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Beto') RETURNING id AS prof2 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset

-- 2026-09-07 is a Monday (dow=1). Policy/shift both open 09:00-18:00, every
-- Monday, no expiry — covers the whole 8-week materialization window.
-- prof2 exists only for Behavior 3 (collision test), kept isolated from
-- prof1's own 8 Mondays so the collision setup itself never conflicts with
-- what Behaviors 1/2 already materialized.
INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'prof1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'prof2'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);

-- Behavior 1 (issue 030): appointment_series_create materializes exactly
-- the 8 weekly Mondays of the rolling window as real, series-linked
-- appointments — tying together the pure occurrence-dates function and the
-- extended create_appointment in one transactional RPC.
SELECT public.appointment_series_create(
  :'org1'::uuid, :'owner1'::uuid, 'series-create-0001',
  jsonb_build_object(
    'client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'unit_id', :'unit1'::uuid, 'anchor_date', '2026-09-07', 'local_start_time', '10:00',
    'recurrence_days', array[1], 'recurrence_interval_weeks', 1,
    'duration_minutes', 30, 'valid_from', '2026-09-07'
  )
) AS series_response \gset

SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = ((:'series_response'::jsonb -> 'series') ->> 'id')::uuid),
  8::bigint,
  'appointment_series_create materializes exactly the 8 weekly Mondays of the rolling window'
);

-- Behavior 2 (issue 030): retrying with the SAME series-level idempotency
-- key never duplicates materialized occurrences — the top-level RPC's own
-- idempotency_keys short-circuit handles it (returns the persisted
-- response), independent of the per-occurrence keys underneath.
SELECT public.appointment_series_create(
  :'org1'::uuid, :'owner1'::uuid, 'series-create-0001',
  jsonb_build_object(
    'client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'unit_id', :'unit1'::uuid, 'anchor_date', '2026-09-07', 'local_start_time', '10:00',
    'recurrence_days', array[1], 'recurrence_interval_weeks', 1,
    'duration_minutes', 30, 'valid_from', '2026-09-07'
  )
) AS series_response_retry \gset
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = ((:'series_response'::jsonb -> 'series') ->> 'id')::uuid),
  8::bigint,
  'retrying appointment_series_create with the same idempotency key does not duplicate occurrences'
);

-- Behavior 3 (issue 030, "tudo-ou-nada" desta fatia): a pre-existing
-- appointment already occupying one of the 8 candidate Monday slots makes
-- the WHOLE series creation fail — including the appointment_series row
-- itself, which must not persist as an orphaned, partially-materialized
-- series.
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Dois', :'owner1'::uuid) RETURNING id AS client2 \gset
INSERT INTO public.appointments (organization_id, client_id, professional_id, service_id, starts_at, ends_at, created_by, unit_id)
  VALUES (:'org1'::uuid, :'client2'::uuid, :'prof2'::uuid, :'service1'::uuid, '2026-10-05T13:00:00Z', '2026-10-05T13:30:00Z', :'owner1'::uuid, :'unit1'::uuid);

SELECT public.appointment_series_create(
  :'org1'::uuid, :'owner1'::uuid, 'series-create-collision-0001',
  jsonb_build_object(
    'client_id', :'client1'::uuid, 'professional_id', :'prof2'::uuid, 'service_id', :'service1'::uuid,
    'unit_id', :'unit1'::uuid, 'anchor_date', '2026-09-07', 'local_start_time', '10:00',
    'recurrence_days', array[1], 'recurrence_interval_weeks', 1,
    'duration_minutes', 30, 'valid_from', '2026-09-07'
  )
) AS partial_series_response \gset
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = ((:'partial_series_response'::jsonb -> 'series') ->> 'id')::uuid),
  7::bigint,
  'a collision leaves the seven valid occurrences materialized'
);
SELECT is(
  (SELECT count(*) FROM public.appointment_series_conflicts
    WHERE series_id = ((:'partial_series_response'::jsonb -> 'series') ->> 'id')::uuid
      AND occurrence_date = '2026-10-05'::date AND status = 'OPEN'),
  1::bigint,
  'the conflicting occurrence is durably recorded as OPEN'
);
SELECT is(
  jsonb_array_length(:'partial_series_response'::jsonb -> 'conflicts'),
  1,
  'the series response exposes the durable conflict without hiding the partial outcome'
);

SELECT id AS conflict1 FROM public.appointment_series_conflicts
WHERE series_id = ((:'partial_series_response'::jsonb -> 'series') ->> 'id')::uuid
  AND occurrence_date = '2026-10-05'::date \gset
DELETE FROM public.appointments
WHERE organization_id = :'org1'::uuid AND professional_id = :'prof2'::uuid
  AND starts_at = '2026-10-05T13:00:00Z'::timestamptz;

SELECT public.appointment_series_conflict_retry(
  :'org1'::uuid, :'owner1'::uuid, 'series-conflict-retry-0001',
  jsonb_build_object('conflict_id', :'conflict1'::uuid)
) AS conflict_retry_response \gset
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = ((:'partial_series_response'::jsonb -> 'series') ->> 'id')::uuid),
  8::bigint,
  'retry materializes only the formerly conflicting occurrence'
);
SELECT is(
  (SELECT status FROM public.appointment_series_conflicts WHERE id = :'conflict1'::uuid),
  'RESOLVED',
  'retry resolves the conflict only after the appointment exists'
);
SELECT public.appointment_series_conflict_retry(
  :'org1'::uuid, :'owner1'::uuid, 'series-conflict-retry-0001',
  jsonb_build_object('conflict_id', :'conflict1'::uuid)
) AS conflict_retry_response_repeat \gset
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = ((:'partial_series_response'::jsonb -> 'series') ->> 'id')::uuid),
  8::bigint,
  'retrying the same conflict command is idempotent and does not duplicate the occurrence'
);
SELECT throws_ok(
  format(
    'select public.appointment_series_conflict_retry(%L, %L, %L, jsonb_build_object(''conflict_id'', %L::uuid))',
    :'org1', :'owner1', 'series-conflict-retry-0002', :'conflict1'
  ),
  'P0020', 'series conflict is not open',
  'a resolved conflict cannot be retried with a new command'
);

-- Behavior 5 (issue 030, "ausência de inserção direta em appointments"):
-- authenticated has no direct INSERT grant — every occurrence, of every
-- origin, must pass through create_appointment (or its Onda-5 callers).
SELECT ok(
  NOT has_table_privilege('authenticated', 'public.appointments', 'INSERT'),
  'authenticated has no direct INSERT privilege on appointments'
);

SELECT * FROM finish();
ROLLBACK;
