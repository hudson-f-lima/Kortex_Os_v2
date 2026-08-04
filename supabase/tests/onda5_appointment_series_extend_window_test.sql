BEGIN;
SELECT plan(3);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Extend Window', 'org-extend-window')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid) RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Ana') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset

-- 2026-09-07 is a Monday. Policy/shift open every Monday, no expiry, wide
-- enough to cover both the initial window and the extended one.
INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'prof1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);

SELECT public.appointment_series_create(
  :'org1'::uuid, :'owner1'::uuid, 'series-extend-0001',
  jsonb_build_object(
    'client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'unit_id', :'unit1'::uuid, 'anchor_date', '2026-09-07', 'local_start_time', '10:00',
    'recurrence_days', array[1], 'recurrence_interval_weeks', 1,
    'duration_minutes', 30, 'valid_from', '2026-09-07'
  )
) AS series_response \gset
SELECT ((:'series_response'::jsonb -> 'series') ->> 'id') AS series1 \gset

-- Behavior 1 (issue 030, "idempotência por ocorrência"): calling
-- extend_window with as_of_date still inside the already-materialized
-- window re-processes the same 8 dates but creates nothing new — the
-- per-occurrence idempotency keys make every one of them a no-op.
SELECT public.appointment_series_extend_window(
  :'org1'::uuid, :'owner1'::uuid, 'series-extend-window-0001',
  jsonb_build_object('series_id', :'series1'::uuid, 'as_of_date', '2026-09-07')
) AS extend_response_1 \gset
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = :'series1'::uuid),
  8::bigint,
  'extend_window with as_of_date inside the current window does not duplicate occurrences'
);

-- Behavior 2 (issue 030, "janela rolante"): as_of_date past the original
-- window materializes the NEW Mondays that just entered the 8-week
-- horizon, without touching the ones already there.
SELECT public.appointment_series_extend_window(
  :'org1'::uuid, :'owner1'::uuid, 'series-extend-window-0002',
  jsonb_build_object('series_id', :'series1'::uuid, 'as_of_date', '2026-10-05')
) AS extend_response_2 \gset
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = :'series1'::uuid),
  12::bigint,
  'extend_window with a later as_of_date materializes the new Mondays that entered the rolling horizon (8 original + 4 new)'
);

-- Behavior 3 (issue 030): extend_window on a paused series is a safe
-- no-op, never an error — a periodic job must not crash on a paused
-- series, it just skips it (Blueprint §3.1.8: "pausar a série impede
-- novas materializações").
UPDATE public.appointment_series SET status = 'paused' WHERE id = :'series1'::uuid;
SELECT public.appointment_series_extend_window(
  :'org1'::uuid, :'owner1'::uuid, 'series-extend-window-0003',
  jsonb_build_object('series_id', :'series1'::uuid, 'as_of_date', '2026-11-02')
) AS extend_response_3 \gset
SELECT is(
  (SELECT count(*) FROM public.appointments WHERE series_id = :'series1'::uuid),
  12::bigint,
  'extend_window on a paused series never materializes new occurrences'
);

SELECT * FROM finish();
ROLLBACK;
