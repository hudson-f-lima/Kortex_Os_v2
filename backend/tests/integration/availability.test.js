import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createProfessional, createServiceGroup, localTestEnv, setUpOrgWithRole } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

async function createService(organizationId, overrides = {}) {
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data, error } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name: overrides.name ?? 'Corte',
      price_cents: 5000,
      duration_minutes: overrides.durationMinutes ?? 60,
      service_group_id: serviceGroupId,
    })
    .select('id')
    .single();
  assert.equal(error, null, error?.message);
  return data.id;
}

async function enableAvailabilityResolver(organizationId) {
  const { error } = await supabaseAdmin
    .from('organizations')
    .update({ settings: { availability_resolver_enabled: true } })
    .eq('id', organizationId);
  assert.equal(error, null, error?.message);
}

async function linkProfessionalToUnit(organizationId, professionalId, unitId) {
  const { data: owner } = await supabaseAdmin.from('memberships').select('user_id').eq('organization_id', organizationId).eq('role', 'owner').single();
  const { error } = await supabaseAdmin.rpc('professional_unit_assign', {
    p_organization_id: organizationId,
    p_actor_user_id: owner.user_id,
    p_professional_id: professionalId,
    p_unit_id: unitId,
  });
  assert.equal(error, null, error?.message);
}

async function getDefaultUnit(organizationId) {
  const { data, error } = await supabaseAdmin.from('units').select('id, timezone').eq('organization_id', organizationId).eq('is_default', true).single();
  assert.equal(error, null, error?.message);
  return data;
}

async function setCalendarPolicy(organizationId, unitId, ownerUserId, weeklySchedule, validFrom = '2020-01-01T00:00:00-03:00') {
  const { error } = await supabaseAdmin.from('calendar_policies').insert({
    organization_id: organizationId,
    unit_id: unitId,
    weekly_schedule: weeklySchedule,
    valid_from: validFrom,
    created_by: ownerUserId,
  });
  assert.equal(error, null, error?.message);
}

async function setProfessionalShift(organizationId, professionalId, unitId, ownerUserId, weeklySchedule, validFrom = '2020-01-01T00:00:00-03:00') {
  const { error } = await supabaseAdmin.from('professional_shifts').insert({
    organization_id: organizationId,
    professional_id: professionalId,
    unit_id: unitId,
    weekly_schedule: weeklySchedule,
    valid_from: validFrom,
    created_by: ownerUserId,
  });
  assert.equal(error, null, error?.message);
}

// Fixed future Tuesday so weekday-keyed schedules (dow=2) are deterministic
// regardless of when the test suite runs.
const TUESDAY = '2027-03-02';

test('GET /units/:unitId/availability returns 403 when the feature flag is disabled', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  const unit = await getDefaultUnit(organizationId);

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: '00000000-0000-0000-0000-000000000000', date_from: TUESDAY, date_to: TUESDAY });

  assert.equal(response.status, 403);
  assert.equal(response.body.code, 'feature_disabled');
});

test('GET /units/:unitId/availability returns slots that respect unit hours ∩ shift hours and subtracts a booked appointment', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  await enableAvailabilityResolver(organizationId);
  const unit = await getDefaultUnit(organizationId);
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  await linkProfessionalToUnit(organizationId, professionalId, unit.id);
  const serviceId = await createService(organizationId, { durationMinutes: 60 });

  // Unit open 09:00-18:00, professional shift narrower: 10:00-13:00 (Tuesday, dow=2).
  await setCalendarPolicy(organizationId, unit.id, ownerUserId, { 2: [{ start: '09:00', end: '18:00' }] });
  await setProfessionalShift(organizationId, professionalId, unit.id, ownerUserId, { 2: [{ start: '10:00', end: '13:00' }] });

  // Books 11:00-12:00 local (unit.timezone, America/Sao_Paulo per Onda 0) so the
  // 60-minute-step slot grid should skip straight over it.
  const { error: apptError } = await supabaseAdmin.from('appointments').insert({
    organization_id: organizationId,
    unit_id: unit.id,
    client_id: (
      await supabaseAdmin.from('clients').insert({ organization_id: organizationId, name: 'Cliente Teste', created_by: ownerUserId }).select('id').single()
    ).data.id,
    professional_id: professionalId,
    service_id: serviceId,
    starts_at: `${TUESDAY}T11:00:00-03:00`,
    ends_at: `${TUESDAY}T12:00:00-03:00`,
    status: 'confirmed',
    created_by: ownerUserId,
  });
  assert.equal(apptError, null, apptError?.message);

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: serviceId, professional_id: professionalId, date_from: TUESDAY, date_to: TUESDAY });

  assert.equal(response.status, 200, JSON.stringify(response.body));
  assert.equal(response.body.availability.length, 1);
  const day = response.body.availability[0];
  assert.equal(day.date, TUESDAY);
  assert.equal(day.professional_id, professionalId);

  // Effective window is the shift (10:00-13:00, narrower than the unit's
  // 09:00-18:00). 60-minute slots at a 15-minute step: 10:00 and 12:00 fit;
  // 10:15-11:15 through 11:00-12:00 would overlap the booked appointment.
  const localStarts = day.slots.map((s) => new Date(s.starts_at).toISOString());
  assert.ok(localStarts.includes(`${TUESDAY}T13:00:00.000Z`), 'includes the 10:00 local (13:00 UTC, -03:00) slot');
  assert.ok(localStarts.includes(`${TUESDAY}T15:00:00.000Z`), 'includes the 12:00 local (15:00 UTC, -03:00) slot, right after the booked hour');
  assert.ok(!localStarts.includes(`${TUESDAY}T14:00:00.000Z`), 'excludes the 11:00 local slot, which overlaps the booked appointment');
});

test('GET /units/:unitId/availability returns no slots for a day the professional has no shift on', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  await enableAvailabilityResolver(organizationId);
  const unit = await getDefaultUnit(organizationId);
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  await linkProfessionalToUnit(organizationId, professionalId, unit.id);
  const serviceId = await createService(organizationId);

  await setCalendarPolicy(organizationId, unit.id, ownerUserId, { 2: [{ start: '09:00', end: '18:00' }] });
  // No professional_shifts row at all for this professional/unit — fail-closed.

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: serviceId, professional_id: professionalId, date_from: TUESDAY, date_to: TUESDAY });

  assert.equal(response.status, 200);
  assert.deepEqual(response.body.availability, []);
});

test('GET /units/:unitId/availability rejects a date range wider than 31 days', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  await enableAvailabilityResolver(organizationId);
  const unit = await getDefaultUnit(organizationId);

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: '00000000-0000-0000-0000-000000000000', date_from: '2027-01-01', date_to: '2027-03-01' });

  assert.equal(response.status, 400);
  assert.equal(response.body.code, 'date_range_too_large');
});

test('GET /units/:unitId/availability rejects impossible calendar dates', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  await enableAvailabilityResolver(organizationId);
  const unit = await getDefaultUnit(organizationId);
  const serviceId = await createService(organizationId);

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: serviceId, date_from: '2027-02-31', date_to: '2027-02-31' });

  assert.equal(response.status, 400);
  assert.equal(response.body.code, 'invalid_date_from');
});

test('GET /units/:unitId/availability rejects professional_id without an active link to the unit', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  await enableAvailabilityResolver(organizationId);
  const unit = await getDefaultUnit(organizationId);
  const serviceId = await createService(organizationId);
  const unlinkedProfessionalId = '00000000-0000-0000-0000-000000000001';

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: serviceId, professional_id: unlinkedProfessionalId, date_from: TUESDAY, date_to: TUESDAY });

  assert.equal(response.status, 400);
  assert.equal(response.body.code, 'invalid_professional_id');
});

test('GET /units/:unitId/availability subtracts late local appointments whose UTC date is the next day', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  await enableAvailabilityResolver(organizationId);
  const unit = await getDefaultUnit(organizationId);
  const { error: timezoneError } = await supabaseAdmin
    .from('units')
    .update({ timezone: 'America/New_York' })
    .eq('organization_id', organizationId)
    .eq('id', unit.id);
  assert.equal(timezoneError, null, timezoneError?.message);

  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  await linkProfessionalToUnit(organizationId, professionalId, unit.id);
  const serviceId = await createService(organizationId, { durationMinutes: 30 });
  await setCalendarPolicy(organizationId, unit.id, ownerUserId, { 2: [{ start: '22:00', end: '23:59' }] }, '2020-01-01T00:00:00-05:00');
  await setProfessionalShift(
    organizationId,
    professionalId,
    unit.id,
    ownerUserId,
    { 2: [{ start: '22:00', end: '23:59' }] },
    '2020-01-01T00:00:00-05:00',
  );

  const { data: client, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({ organization_id: organizationId, name: 'Cliente NY', created_by: ownerUserId })
    .select('id')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const { error: apptError } = await supabaseAdmin.from('appointments').insert({
    organization_id: organizationId,
    unit_id: unit.id,
    client_id: client.id,
    professional_id: professionalId,
    service_id: serviceId,
    starts_at: `${TUESDAY}T22:30:00-05:00`,
    ends_at: `${TUESDAY}T23:00:00-05:00`,
    status: 'confirmed',
    created_by: ownerUserId,
  });
  assert.equal(apptError, null, apptError?.message);

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: serviceId, professional_id: professionalId, date_from: TUESDAY, date_to: TUESDAY });

  assert.equal(response.status, 200, JSON.stringify(response.body));
  const slotStarts = response.body.availability.flatMap((day) => day.slots.map((slot) => slot.starts_at));
  assert.ok(slotStarts.includes('2027-03-03T03:00:00.000Z'), 'keeps the 22:00 local slot before the appointment');
  assert.ok(!slotStarts.includes('2027-03-03T03:15:00.000Z'), 'removes the 22:15 local slot overlapping the appointment');
  assert.ok(!slotStarts.includes('2027-03-03T03:30:00.000Z'), 'removes the exact 22:30 local appointment slot');
  assert.ok(!slotStarts.includes('2027-03-03T03:45:00.000Z'), 'removes the 22:45 local slot overlapping the appointment');
  assert.ok(slotStarts.includes('2027-03-03T04:00:00.000Z'), 'keeps the 23:00 local slot after the appointment');
});

test('GET /units/:unitId/availability rejects a unit-scoped role querying a different unit (achado de auditoria, 2026-07-29)', async () => {
  const { organizationId, ownerAccessToken, ownerUserId, accessToken } = await setUpOrgWithRole(supabaseAdmin, 'reception');
  await enableAvailabilityResolver(organizationId);

  const { data: otherUnit, error: unitError } = await supabaseAdmin.rpc('unit_create', {
    p_organization_id: organizationId,
    p_actor_user_id: ownerUserId,
    p_name: 'Other Unit',
  });
  assert.equal(unitError, null, unitError?.message);

  const response = await request(app)
    .get(`/api/v1/units/${otherUnit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: '00000000-0000-0000-0000-000000000000', date_from: TUESDAY, date_to: TUESDAY });

  assert.equal(response.status, 403);
  assert.equal(response.body.code, 'unit_scope_mismatch');

  // Sanity check: the same reception membership CAN query its own unit
  // (proves the fix rejects cross-unit access specifically, not all access).
  const ownUnit = await getDefaultUnit(organizationId);
  const ownUnitResponse = await request(app)
    .get(`/api/v1/units/${ownUnit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: '00000000-0000-0000-0000-000000000000', date_from: TUESDAY, date_to: TUESDAY });
  assert.notEqual(ownUnitResponse.status, 403);

  // Owner (org-wide role) can still query any unit, including the new one.
  const ownerResponse = await request(app)
    .get(`/api/v1/units/${otherUnit.id}/availability`)
    .set('Authorization', `Bearer ${ownerAccessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: '00000000-0000-0000-0000-000000000000', date_from: TUESDAY, date_to: TUESDAY });
  assert.notEqual(ownerResponse.status, 403);
});

test('GET /units/:unitId/availability rejects an explicit professional_id disabled for the service (ADR 0010 tri-state, achado de auditoria)', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  await enableAvailabilityResolver(organizationId);
  const unit = await getDefaultUnit(organizationId);
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  await linkProfessionalToUnit(organizationId, professionalId, unit.id);
  const serviceId = await createService(organizationId);
  await setCalendarPolicy(organizationId, unit.id, ownerUserId, { 2: [{ start: '09:00', end: '18:00' }] });
  await setProfessionalShift(organizationId, professionalId, unit.id, ownerUserId, { 2: [{ start: '09:00', end: '18:00' }] });

  const { error: capabilityError } = await supabaseAdmin.from('professional_service_capabilities').insert({
    organization_id: organizationId,
    professional_id: professionalId,
    service_id: serviceId,
    eligibility: 'DISABLED',
  });
  assert.equal(capabilityError, null, capabilityError?.message);

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: serviceId, professional_id: professionalId, date_from: TUESDAY, date_to: TUESDAY });

  assert.equal(response.status, 400);
  assert.equal(response.body.code, 'professional_not_eligible');
});

test('GET /units/:unitId/availability omits a DISABLED professional from the unfiltered (no professional_id) listing', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  await enableAvailabilityResolver(organizationId);
  const unit = await getDefaultUnit(organizationId);
  const eligibleProfessionalId = await createProfessional(supabaseAdmin, organizationId);
  const disabledProfessionalId = await createProfessional(supabaseAdmin, organizationId);
  await linkProfessionalToUnit(organizationId, eligibleProfessionalId, unit.id);
  await linkProfessionalToUnit(organizationId, disabledProfessionalId, unit.id);
  const serviceId = await createService(organizationId);
  await setCalendarPolicy(organizationId, unit.id, ownerUserId, { 2: [{ start: '09:00', end: '18:00' }] });
  await setProfessionalShift(organizationId, eligibleProfessionalId, unit.id, ownerUserId, { 2: [{ start: '09:00', end: '18:00' }] });
  await setProfessionalShift(organizationId, disabledProfessionalId, unit.id, ownerUserId, { 2: [{ start: '09:00', end: '18:00' }] });

  const { error: capabilityError } = await supabaseAdmin.from('professional_service_capabilities').insert({
    organization_id: organizationId,
    professional_id: disabledProfessionalId,
    service_id: serviceId,
    eligibility: 'DISABLED',
  });
  assert.equal(capabilityError, null, capabilityError?.message);

  const response = await request(app)
    .get(`/api/v1/units/${unit.id}/availability`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .query({ service_id: serviceId, date_from: TUESDAY, date_to: TUESDAY });

  assert.equal(response.status, 200, JSON.stringify(response.body));
  const professionalIdsReturned = response.body.availability.map((day) => day.professional_id);
  assert.ok(professionalIdsReturned.includes(eligibleProfessionalId), 'eligible professional appears');
  assert.ok(!professionalIdsReturned.includes(disabledProfessionalId), 'disabled professional is filtered out');
});
