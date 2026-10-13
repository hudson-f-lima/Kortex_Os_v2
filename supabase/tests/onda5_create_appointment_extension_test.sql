BEGIN;
SELECT plan(4);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('onda5-owner1@test.local') AS owner1 \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Series Ext', 'org-series-ext')).id AS org1 \gset
SELECT (SELECT id FROM public.units WHERE organization_id = :'org1'::uuid AND is_default) AS unit1 \gset

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500) RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid) RETURNING id AS service1 \gset
-- professionals_link_default_unit (Onda 0) already inserts the
-- professional_units row for the org's default unit automatically.
INSERT INTO public.professionals (organization_id, name) VALUES (:'org1'::uuid, 'Ana') RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by) VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid) RETURNING id AS client1 \gset

-- 2026-09-07 is a Monday (dow=1). Policy/shift both open 09:00-18:00.
INSERT INTO public.calendar_policies (organization_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);
INSERT INTO public.professional_shifts (organization_id, professional_id, unit_id, weekly_schedule, valid_from, created_by)
  VALUES (:'org1'::uuid, :'prof1'::uuid, :'unit1'::uuid, '{"1": [{"start":"09:00","end":"18:00"}]}'::jsonb, '2026-01-01 00:00:00-03'::timestamptz, :'owner1'::uuid);

INSERT INTO public.appointment_series (
  organization_id, unit_id, client_id, professional_id, service_id,
  anchor_date, local_start_time, recurrence_days, duration_minutes, valid_from, created_by
) VALUES (
  :'org1'::uuid, :'unit1'::uuid, :'client1'::uuid, :'prof1'::uuid, :'service1'::uuid,
  '2026-09-07'::date, '10:00', array[1]::smallint[], 30, '2026-09-07'::date, :'owner1'::uuid
) RETURNING id AS series1 \gset

-- Behavior 1 (issue 030): create_appointment with origin='series' inside an
-- open calendar window persists unit_id and series_id on the appointment
-- row — the first slice of "estender create_appointment com metadados
-- server-owned e consulta obrigatória ao Availability Resolver".
SELECT public.create_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'appt-series-ext-0001',
  jsonb_build_object(
    'client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid,
    'starts_at', '2026-09-07T13:00:00Z',
    'origin', 'series', 'unit_id', :'unit1'::uuid, 'series_id', :'series1'::uuid, 'duration_minutes', 30
  )
) AS create_response \gset

SELECT is(
  (SELECT row(a.unit_id, a.series_id) FROM public.appointments a WHERE a.id = ((:'create_response'::jsonb -> 'appointment') ->> 'id')::uuid),
  row(:'unit1'::uuid, :'series1'::uuid),
  'create_appointment with origin=series persists unit_id and series_id on the appointment row'
);

-- Behavior 2 (issue 030): origin <> direct without unit_id is a domain
-- error, never a silent default-fill.
SELECT throws_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-series-ext-0002', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'service_id', %L, 'starts_at', '2026-09-07T13:00:00Z', 'origin', 'series'
    ))$sql$,
    :'org1', :'owner1', :'client1', :'prof1', :'service1'
  ),
  '22023',
  'unit_id is required for origin <> direct',
  'origin=series without unit_id is rejected'
);

-- Behavior 3 (issue 030): a candidate outside the professional's shift
-- (shift ends 18:00 local, candidate starts 19:00 local = 22:00Z) is
-- rejected by the mandatory Resolver check — never silently created.
SELECT throws_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-series-ext-0003', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'service_id', %L, 'starts_at', '2026-09-07T22:00:00Z',
      'origin', 'series', 'unit_id', %L, 'series_id', %L, 'duration_minutes', 30
    ))$sql$,
    :'org1', :'owner1', :'client1', :'prof1', :'service1', :'unit1', :'series1'
  ),
  'P0006',
  null,
  'a candidate outside the professional shift is rejected by the mandatory Resolver check'
);

-- Behavior 4 (issue 030): legacy origin=direct callers are entirely
-- unaffected — no unit_id/series_id metadata, appointment is created with
-- both columns null (besides the trigger''s own default-fill of unit_id,
-- which is a pre-existing behavior, not part of this fatia).
SELECT public.create_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'appt-series-ext-0004',
  jsonb_build_object('client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid, 'starts_at', '2026-09-08T13:00:00Z')
) AS legacy_response \gset
SELECT is(
  ((:'legacy_response'::jsonb -> 'appointment') ->> 'series_id'),
  null::text,
  'legacy origin=direct call (no metadata) leaves series_id null, unaffected by the Onda 5 extension'
);

-- "Titular imutável" (issue 030, Blueprint §3.1.9) NÃO é testado aqui —
-- decisão fechada por interview (2026-08-04): update_appointment
-- permanece intocado (appointment_replan_with_hold, Onda 1, já é o
-- caminho explícito/auditado de troca de titular e não pode quebrar). A
-- regra fica escopada a appointment_series_update (RPC futura desta mesma
-- fatia), testada quando essa RPC existir.

SELECT * FROM finish();
ROLLBACK;
