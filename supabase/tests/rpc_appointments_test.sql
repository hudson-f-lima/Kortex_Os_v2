BEGIN;
SELECT plan(32);

CREATE FUNCTION pg_temp.mk_user(p_email text) RETURNS uuid
LANGUAGE sql AS $$
  INSERT INTO auth.users (id, email) VALUES (gen_random_uuid(), p_email) RETURNING id;
$$;

SELECT pg_temp.mk_user('owner1@test.local') AS owner1 \gset
SELECT pg_temp.mk_user('professional1_user@test.local') AS professional1_user \gset
SELECT (public.create_organization(:'owner1'::uuid, 'Org Appointments', 'org-appointments')).id AS org1 \gset
SELECT public.membership_set(:'org1'::uuid, :'owner1'::uuid, :'professional1_user'::uuid, 'professional');

INSERT INTO public.service_groups (organization_id, name, default_commission_type, default_commission_value)
  VALUES (:'org1'::uuid, 'Cabelo', 'percentage', 4500)
  RETURNING id AS group1 \gset
INSERT INTO public.services (organization_id, name, price_cents, duration_minutes, service_group_id)
  VALUES (:'org1'::uuid, 'Corte', 5000, 30, :'group1'::uuid)
  RETURNING id AS service1 \gset
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Ana')
  RETURNING id AS prof1 \gset
INSERT INTO public.clients (organization_id, name, created_by)
  VALUES (:'org1'::uuid, 'Cliente Um', :'owner1'::uuid)
  RETURNING id AS client1 \gset

-- === grant lockdown ===
SELECT ok(
  NOT has_function_privilege('authenticated', 'public.create_appointment(uuid, uuid, text, jsonb)', 'EXECUTE'),
  'authenticated cannot execute create_appointment'
);
SELECT ok(
  NOT has_function_privilege('authenticated', 'public.update_appointment(uuid, uuid, text, uuid, jsonb)', 'EXECUTE'),
  'authenticated cannot execute update_appointment'
);

-- === role gate (ADR 0012): professional is not in the owner/admin/manager/reception allowlist ===
SELECT throws_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-role-0001', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'service_id', %L, 'starts_at', '2026-09-01T10:00:00Z'
    ))$sql$,
    :'org1', :'professional1_user', :'client1', :'prof1', :'service1'
  ),
  '42501',
  NULL,
  'professional1_user cannot call create_appointment (insufficient organization permission)'
);

-- === create_appointment: happy path (ADR 0010 rollout default — ENABLED, no capability row yet) ===
SELECT public.create_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'appt-create-0001',
  jsonb_build_object('client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid, 'starts_at', '2026-09-01T10:00:00Z')
) AS create_response \gset
SELECT is(
  (:'create_response'::jsonb ->> 'status'),
  'applied',
  'create_appointment returns status=applied on success'
);
SELECT ((:'create_response'::jsonb -> 'appointment') ->> 'id') AS appointment1 \gset
SELECT is(
  ((:'create_response'::jsonb -> 'appointment') ->> 'resolved_duration_minutes')::int,
  30,
  'resolved_duration_minutes falls back to the service default (no capability override)'
);
SELECT is(
  ((:'create_response'::jsonb -> 'appointment') ->> 'resolved_eligibility_source'),
  'org_default',
  'resolved_eligibility_source is org_default when no capability/group row exists'
);
SELECT is(
  ((:'create_response'::jsonb -> 'appointment') ->> 'ends_at')::timestamptz,
  '2026-09-01T10:30:00Z'::timestamptz,
  'ends_at is starts_at + resolved duration'
);
SELECT is(
  ((:'create_response'::jsonb -> 'appointment') ->> 'version')::bigint,
  1::bigint,
  'a freshly created appointment starts at version 1'
);

-- Idempotent replay: same key + same payload returns the cached response, no duplicate row.
SELECT public.create_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'appt-create-0001',
  jsonb_build_object('client_id', :'client1'::uuid, 'professional_id', :'prof1'::uuid, 'service_id', :'service1'::uuid, 'starts_at', '2026-09-01T10:00:00Z')
);
SELECT is(
  (SELECT count(*)::int FROM public.appointments WHERE organization_id = :'org1'::uuid),
  1,
  'replaying appt-create-0001 does not create a second appointment'
);

-- Same key, different payload: rejected.
SELECT throws_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-create-0001', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'service_id', %L, 'starts_at', '2026-09-02T10:00:00Z'
    ))$sql$,
    :'org1', :'owner1', :'client1', :'prof1', :'service1'
  ),
  '22023',
  NULL,
  'reusing an idempotency key with a different payload is rejected'
);

-- Missing required field.
SELECT throws_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-missing-field-0001', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'starts_at', '2026-09-01T11:00:00Z'
    ))$sql$,
    :'org1', :'owner1', :'client1', :'prof1'
  ),
  '22023',
  NULL,
  'create_appointment rejects a payload missing service_id'
);

-- Unknown reference.
SELECT throws_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-badref-0001', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'service_id', %L, 'starts_at', '2026-09-01T11:00:00Z'
    ))$sql$,
    :'org1', :'owner1', :'client1', :'prof1', gen_random_uuid()
  ),
  'P0002',
  NULL,
  'create_appointment rejects a service_id that does not exist'
);

-- === eligibility gate (ADR 0010) ===
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Beatriz')
  RETURNING id AS prof2 \gset
INSERT INTO public.professional_service_capabilities (organization_id, professional_id, service_id, eligibility)
  VALUES (:'org1'::uuid, :'prof2'::uuid, :'service1'::uuid, 'DISABLED');
SELECT throws_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-ineligible-0001', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'service_id', %L, 'starts_at', '2026-09-01T12:00:00Z'
    ))$sql$,
    :'org1', :'owner1', :'client1', :'prof2', :'service1'
  ),
  'P0003',
  NULL,
  'create_appointment rejects a professional explicitly DISABLED for the service (capability level)'
);

-- Capability ENABLED wins over a DISABLED group assignment (more specific wins).
INSERT INTO public.professional_service_capabilities (organization_id, professional_id, service_id, eligibility)
  VALUES (:'org1'::uuid, :'prof2'::uuid, :'service1'::uuid, 'ENABLED')
  ON CONFLICT (organization_id, professional_id, service_id) DO UPDATE SET eligibility = 'ENABLED';
INSERT INTO public.professional_service_group_eligibility (organization_id, professional_id, service_group_id, eligibility)
  VALUES (:'org1'::uuid, :'prof2'::uuid, :'group1'::uuid, 'DISABLED');
SELECT lives_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-capability-wins-0001', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'service_id', %L, 'starts_at', '2026-09-01T13:00:00Z'
    ))$sql$,
    :'org1', :'owner1', :'client1', :'prof2', :'service1'
  ),
  'a capability-level ENABLED overrides a group-level DISABLED (capability wins)'
);

-- === resolve_eligibility cascade — direct unit tests (runs as superuser, function is internal-only) ===
INSERT INTO public.professionals (organization_id, name)
  VALUES (:'org1'::uuid, 'Carla')
  RETURNING id AS prof3 \gset
SELECT is(
  (SELECT eligible FROM private.resolve_eligibility(:'org1'::uuid, :'prof3'::uuid, :'service1'::uuid)),
  true,
  'resolve_eligibility: no capability/group row falls back to org default (ENABLED)'
);
SELECT is(
  (SELECT source FROM private.resolve_eligibility(:'org1'::uuid, :'prof3'::uuid, :'service1'::uuid)),
  'org_default',
  'resolve_eligibility: source is org_default when nothing else is configured'
);

UPDATE public.organizations SET default_service_eligibility = 'DISABLED' WHERE id = :'org1'::uuid;
SELECT is(
  (SELECT eligible FROM private.resolve_eligibility(:'org1'::uuid, :'prof3'::uuid, :'service1'::uuid)),
  false,
  'resolve_eligibility: flipping the org default to DISABLED blocks an unconfigured professional'
);

INSERT INTO public.professional_service_group_eligibility (organization_id, professional_id, service_group_id, eligibility)
  VALUES (:'org1'::uuid, :'prof3'::uuid, :'group1'::uuid, 'ENABLED');
SELECT is(
  (SELECT eligible FROM private.resolve_eligibility(:'org1'::uuid, :'prof3'::uuid, :'service1'::uuid)),
  true,
  'resolve_eligibility: a group-level ENABLED overrides the org DISABLED default'
);
SELECT is(
  (SELECT source FROM private.resolve_eligibility(:'org1'::uuid, :'prof3'::uuid, :'service1'::uuid)),
  'group',
  'resolve_eligibility: source is group when only the group row decides'
);

UPDATE public.organizations SET default_service_eligibility = 'ENABLED' WHERE id = :'org1'::uuid;

-- === update_appointment: version required and checked (ADR 0012) ===
SELECT throws_ok(
  format(
    $sql$select public.update_appointment(%L, %L, 'appt-update-noversion-0001', %L, jsonb_build_object('starts_at', '2026-09-01T14:00:00Z'))$sql$,
    :'org1', :'owner1', :'appointment1'
  ),
  '22023',
  NULL,
  'update_appointment requires version in the payload'
);
-- Regression: an explicit JSON null must not bypass the check the way a
-- bare `?` key-presence test would (v_current.version <> NULL is NULL, not
-- TRUE, so `if ... then` silently skips the raise unless null is rejected
-- up front).
SELECT throws_ok(
  format(
    $sql$select public.update_appointment(%L, %L, 'appt-update-nullversion-0001', %L, jsonb_build_object('starts_at', '2026-09-01T14:00:00Z', 'version', null))$sql$,
    :'org1', :'owner1', :'appointment1'
  ),
  '22023',
  NULL,
  'update_appointment rejects an explicit null version, not just a missing key'
);
SELECT throws_ok(
  format(
    $sql$select public.update_appointment(%L, %L, 'appt-update-badversion-0001', %L, jsonb_build_object('starts_at', '2026-09-01T14:00:00Z', 'version', 999))$sql$,
    :'org1', :'owner1', :'appointment1'
  ),
  'P0004',
  NULL,
  'update_appointment rejects a stale version'
);

-- === MOVE_TIME_ONLY (ADR 0011): preserves the frozen snapshot ===
SELECT public.update_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'appt-move-0001', :'appointment1'::uuid,
  jsonb_build_object('starts_at', '2026-09-01T15:00:00Z', 'version', 1)
) AS move_response \gset
SELECT is(
  ((:'move_response'::jsonb -> 'appointment') ->> 'resolved_duration_minutes')::int,
  30,
  'MOVE_TIME_ONLY preserves resolved_duration_minutes (does not re-resolve)'
);
SELECT is(
  ((:'move_response'::jsonb -> 'appointment') ->> 'ends_at')::timestamptz,
  '2026-09-01T15:30:00Z'::timestamptz,
  'MOVE_TIME_ONLY shifts ends_at by the frozen duration, not a re-resolved one'
);
SELECT is(
  ((:'move_response'::jsonb -> 'appointment') ->> 'version')::bigint,
  2::bigint,
  'MOVE_TIME_ONLY still increments version'
);

-- === Change Plan (ADR 0013): reconfiguring requires confirmation ===
SELECT public.update_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'appt-reconfig-preview-0001', :'appointment1'::uuid,
  jsonb_build_object('professional_id', :'prof2'::uuid, 'version', 2)
) AS preview_response \gset
SELECT is(
  (:'preview_response'::jsonb ->> 'status'),
  'confirmation_required',
  'changing professional_id without confirm returns confirmation_required, not applied'
);
SELECT is(
  (SELECT professional_id FROM public.appointments WHERE id = :'appointment1'::uuid),
  :'prof1'::uuid,
  'an unconfirmed reconfiguration does not mutate the row'
);
SELECT is(
  (SELECT version FROM public.appointments WHERE id = :'appointment1'::uuid),
  2::bigint,
  'an unconfirmed reconfiguration does not increment version'
);

SELECT public.update_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'appt-reconfig-confirm-0001', :'appointment1'::uuid,
  jsonb_build_object('professional_id', :'prof2'::uuid, 'version', 2, 'confirm', true)
) AS confirm_response \gset
SELECT is(
  (:'confirm_response'::jsonb ->> 'status'),
  'applied',
  'the same reconfiguration with confirm=true is applied'
);
SELECT is(
  (SELECT professional_id FROM public.appointments WHERE id = :'appointment1'::uuid),
  :'prof2'::uuid,
  'the confirmed reconfiguration updates professional_id'
);

-- Reconfiguring into an ineligible pairing is rejected even with confirm=true.
INSERT INTO public.professional_service_capabilities (organization_id, professional_id, service_id, eligibility)
  VALUES (:'org1'::uuid, :'prof3'::uuid, :'service1'::uuid, 'DISABLED')
  ON CONFLICT (organization_id, professional_id, service_id) DO UPDATE SET eligibility = 'DISABLED';
SELECT throws_ok(
  format(
    $sql$select public.update_appointment(%L, %L, 'appt-reconfig-ineligible-0001', %L, jsonb_build_object('professional_id', %L, 'version', 3, 'confirm', true))$sql$,
    :'org1', :'owner1', :'appointment1', :'prof3'
  ),
  'P0003',
  NULL,
  'confirm=true does not bypass the eligibility gate'
);

-- === double-booking still enforced through the RPC (exclusion constraint, ADR 0002-era invariant) ===
SELECT public.create_appointment(
  :'org1'::uuid, :'owner1'::uuid, 'appt-second-0001',
  jsonb_build_object('client_id', :'client1'::uuid, 'professional_id', :'prof2'::uuid, 'service_id', :'service1'::uuid, 'starts_at', '2026-09-05T09:00:00Z')
);
SELECT throws_ok(
  format(
    $sql$select public.create_appointment(%L, %L, 'appt-overlap-0001', jsonb_build_object(
      'client_id', %L, 'professional_id', %L, 'service_id', %L, 'starts_at', '2026-09-05T09:15:00Z'
    ))$sql$,
    :'org1', :'owner1', :'client1', :'prof2', :'service1'
  ),
  '23P01',
  NULL,
  'create_appointment still enforces the anti-double-booking exclusion constraint'
);

SELECT * FROM finish();
ROLLBACK;
