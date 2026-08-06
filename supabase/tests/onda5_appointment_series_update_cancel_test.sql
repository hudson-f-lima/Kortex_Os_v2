BEGIN;
SELECT plan(9);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Series Update', 'org-series-update')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Ana') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Outro Cliente', :'owner1'::uuid) RETURNING id AS client2 \gset

INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'prof1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);

SELECT public.appointment_series_create(
  :'org1'::uuid, :'owner1'::uuid, 'series-updcxl-0001',
  jsonb_build_object(
    'client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'unit_id', :'unit1'::uuid, 'anchor_date', '2026-09-07', 'local_start_time', '10:00',
    'recurrence_days', array[1], 'recurrence_interval_weeks', 1,
    'duration_minutes', 30, 'valid_from', '2026-09-07'
  )
) AS series_response \gset
SELECT ((:'series_response'::jsonb -> 'series') ->> 'id') AS series1 \gset

-- Behavior 1 (issue 030, "edição", escopo THIS_OCCURRENCE): reschedule a
-- single materialized occurrence — only that one appointment changes.
SELECT a.id AS occ1_id FROM public.appointments a WHERE a.series_id = :'series1'::uuid AND a.starts_at = '2026-09-07T13:00:00Z'::timestamptz \gset
SELECT public.appointment_series_update(
  :'org1'::uuid, :'owner1'::uuid, 'series-updcxl-0002',
  jsonb_build_object(
    'series_id', :'series1'::uuid, 'scope', 'THIS_OCCURRENCE', 'occurrence_date', '2026-09-07',
    'starts_at', '2026-09-07T14:00:00Z', 'version', 1
  )
) AS update_response \gset
SELECT is(
  (SELECT starts_at FROM public.appointments WHERE id = :'occ1_id'::uuid),
  '2026-09-07T14:00:00Z'::timestamptz,
  'THIS_OCCURRENCE update reschedules only the targeted occurrence'
);
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = :'series1'::uuid AND starts_at = '2026-09-14T13:00:00Z'::timestamptz),
  1::bigint,
  'THIS_OCCURRENCE update leaves the other occurrences of the series untouched'
);

-- Behavior 2 (issue 030, "titular imutável" escopado a esta RPC):
-- appointment_series_update never accepts client_id, in either scope.
SELECT throws_ok(
  format(
    $sql$select public.appointment_series_update(%L, %L, 'series-updcxl-0003', jsonb_build_object(
      'series_id', %L, 'scope', 'THIS_OCCURRENCE', 'occurrence_date', '2026-09-21', 'client_id', %L, 'version', 1
    ))$sql$,
    :'org1', :'owner1', :'series1', :'client2'
  ),
  '22023', null,
  'appointment_series_update rejects any attempt to pass client_id'
);

-- Behavior 3 (issue 030, "pausa"): THIS_AND_FUTURE with status=paused
-- cancels every not-yet-started future occurrence and stops new
-- materialization (series.status = paused).
SELECT public.appointment_series_update(
  :'org1'::uuid, :'owner1'::uuid, 'series-updcxl-0004',
  jsonb_build_object('series_id', :'series1'::uuid, 'scope', 'THIS_AND_FUTURE', 'status', 'paused')
) AS pause_response \gset
SELECT is(
  (SELECT status FROM public.appointment_series WHERE id = :'series1'::uuid),
  'paused',
  'THIS_AND_FUTURE status=paused pauses the series'
);
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = :'series1'::uuid AND status = 'scheduled'),
  0::bigint,
  'pausing the series cancels every future not-yet-started occurrence'
);

-- Behavior 4 (issue 030, "retomada"): THIS_AND_FUTURE with status=active
-- and a fresh valid_from re-materializes the window from that date.
SELECT public.appointment_series_update(
  :'org1'::uuid, :'owner1'::uuid, 'series-updcxl-0005',
  jsonb_build_object('series_id', :'series1'::uuid, 'scope', 'THIS_AND_FUTURE', 'status', 'active', 'valid_from', '2026-12-07')
) AS resume_response \gset
SELECT is(
  (SELECT status FROM public.appointment_series WHERE id = :'series1'::uuid),
  'active',
  'THIS_AND_FUTURE status=active resumes the series'
);
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = :'series1'::uuid AND status = 'scheduled' AND starts_at >= '2026-12-07T00:00:00Z'::timestamptz),
  8::bigint,
  'resuming from a fresh valid_from re-materializes a full 8-week window'
);

-- Behavior 5 (issue 030, "cancelamento", escopo THIS_OCCURRENCE): cancels
-- exactly one occurrence, others remain scheduled.
SELECT (a.id) AS occ_to_cancel FROM public.appointments a WHERE a.series_id = :'series1'::uuid AND a.starts_at = '2026-12-07T13:00:00Z'::timestamptz \gset
SELECT public.appointment_series_cancel(
  :'org1'::uuid, :'owner1'::uuid, 'series-updcxl-0006',
  jsonb_build_object('series_id', :'series1'::uuid, 'scope', 'THIS_OCCURRENCE', 'occurrence_date', '2026-12-07', 'version', 1)
) AS cancel_occ_response \gset
SELECT is(
  (SELECT status FROM public.appointments WHERE id = :'occ_to_cancel'::uuid),
  'cancelled',
  'THIS_OCCURRENCE cancel cancels exactly the targeted occurrence'
);

-- Behavior 6 (issue 030, "cancelamento", escopo THIS_AND_FUTURE): cancels
-- every future not-yet-started occurrence and terminates the series
-- (status=cancelled, never resumable, distinct from paused).
SELECT public.appointment_series_cancel(
  :'org1'::uuid, :'owner1'::uuid, 'series-updcxl-0007',
  jsonb_build_object('series_id', :'series1'::uuid, 'scope', 'THIS_AND_FUTURE')
) AS cancel_series_response \gset
SELECT is(
  (SELECT (status, (SELECT count(*) FROM public.appointments WHERE series_id = :'series1'::uuid AND status = 'scheduled')) FROM public.appointment_series WHERE id = :'series1'::uuid),
  ('cancelled'::text, 0::bigint),
  'THIS_AND_FUTURE cancel terminates the series and cancels every remaining future occurrence'
);

SELECT * FROM finish();
ROLLBACK;
