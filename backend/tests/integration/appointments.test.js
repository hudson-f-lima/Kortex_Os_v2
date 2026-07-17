import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createServiceGroup, localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);
const idemKey = () => `appt-${randomUUID()}`;

async function seedCatalog(organizationId, ownerUserId) {
  const { data: client, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({ organization_id: organizationId, name: 'Cliente Teste', created_by: ownerUserId })
    .select('id')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const { data: professional, error: professionalError } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: organizationId, name: 'Prof Teste' })
    .select('id')
    .single();
  assert.equal(professionalError, null, professionalError?.message);

  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name: 'Corte',
      price_cents: 5000,
      duration_minutes: 30,
      service_group_id: serviceGroupId,
    })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);

  return { clientId: client.id, professionalId: professional.id, serviceId: service.id, serviceGroupId };
}

test('owner can create, list, update and delete an appointment', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-10T10:00:00Z',
    });
  assert.equal(created.status, 201);
  assert.equal(created.body.appointment.status, 'scheduled');
  assert.equal(
    created.body.appointment.ends_at,
    '2026-08-10T10:30:00+00:00',
    'ends_at is computed server-side from the service duration (30min)',
  );
  assert.equal(created.body.appointment.version, 1, 'a freshly created appointment starts at version 1');
  assert.equal(
    created.body.appointment.resolved_eligibility_source,
    'org_default',
    'no capability/group row exists yet — eligibility falls back to the organization default',
  );
  const appointmentId = created.body.appointment.id;

  const listed = await request(app)
    .get('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.appointments.length, 1);

  const updated = await request(app)
    .patch(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ status: 'confirmed', version: created.body.appointment.version });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.appointment.status, 'confirmed');
  assert.equal(updated.body.appointment.client_id, clientId, 'unrelated fields are preserved');
  assert.equal(updated.body.appointment.version, 2, 'a successful update increments version');

  const deleted = await request(app)
    .delete(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'appointment_not_found');
});

test('create and update require an Idempotency-Key header', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ client_id: clientId, professional_id: professionalId, service_id: serviceId, starts_at: '2026-08-10T10:00:00Z' });
  assert.equal(created.status, 400);
  assert.equal(created.body.code, 'missing_idempotency_key');

  const withCreate = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ client_id: clientId, professional_id: professionalId, service_id: serviceId, starts_at: '2026-08-10T10:00:00Z' });

  const updated = await request(app)
    .patch(`/api/v1/appointments/${withCreate.body.appointment.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ status: 'confirmed', version: 1 });
  assert.equal(updated.status, 400);
  assert.equal(updated.body.code, 'missing_idempotency_key');
});

test('replaying the same Idempotency-Key does not create a duplicate appointment', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);
  const key = idemKey();
  const payload = {
    client_id: clientId,
    professional_id: professionalId,
    service_id: serviceId,
    starts_at: '2026-08-10T10:00:00Z',
  };

  const first = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', key)
    .send(payload);
  assert.equal(first.status, 201);

  const replay = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', key)
    .send(payload);
  assert.equal(replay.status, 201);
  assert.equal(replay.body.appointment.id, first.body.appointment.id, 'the cached response is returned, not a new appointment');

  const listed = await request(app)
    .get('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.body.appointments.length, 1, 'no duplicate was created');
});

test('reception can create/update/delete appointments, but professional role cannot write', async () => {
  const reception = await setUpOrgWithRole('reception');
  const { clientId, professionalId, serviceId } = await seedCatalog(reception.organizationId, reception.ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-11T10:00:00Z',
    });
  assert.equal(created.status, 201, 'reception is allowed to create appointments');

  const updated = await request(app)
    .patch(`/api/v1/appointments/${created.body.appointment.id}`)
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ status: 'confirmed', version: created.body.appointment.version });
  assert.equal(updated.status, 200);

  const deleted = await request(app)
    .delete(`/api/v1/appointments/${created.body.appointment.id}`)
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(deleted.status, 204, 'reception is also allowed to delete appointments');

  const professionalMember = await setUpOrgWithRole('professional');
  const seeded = await seedCatalog(professionalMember.organizationId, professionalMember.ownerUserId);
  const writeAsProfessional = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${professionalMember.accessToken}`)
    .set('X-Organization-Id', professionalMember.organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: seeded.clientId,
      professional_id: seeded.professionalId,
      service_id: seeded.serviceId,
      starts_at: '2026-08-12T10:00:00Z',
    });
  assert.equal(writeAsProfessional.status, 403);
  assert.equal(writeAsProfessional.body.code, 'insufficient_role');
});

test('validation errors surface as 400, including cross-org references and a client-supplied ends_at', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  // Fase 10 hardening: ends_at is never accepted from the client, even if it
  // would otherwise be a plausible value — this is a loud 400, not a silent
  // override, so an API consumer relying on the old contract notices.
  const clientSuppliedEndsAt = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-10T10:30:00Z',
      ends_at: '2026-08-10T11:00:00Z',
    });
  assert.equal(clientSuppliedEndsAt.status, 400);
  assert.equal(clientSuppliedEndsAt.body.code, 'unknown_fields');

  const otherOrg = await setUpOrgWithRole('owner');
  const otherSeed = await seedCatalog(otherOrg.organizationId, otherOrg.ownerUserId);
  const crossOrgReference = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: otherSeed.professionalId,
      service_id: serviceId,
      starts_at: '2026-08-10T11:00:00Z',
    });
  assert.equal(crossOrgReference.status, 400);
  // Rota B (ADR 0012): create_appointment reports bad references the same
  // way checkout_close/inventory_adjust already do — a shared RPC-wide code,
  // not a field-specific one.
  assert.equal(crossOrgReference.body.code, 'reference_not_found');
});

test('overlapping appointments for the same professional are rejected with 409', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const first = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-13T10:00:00Z',
    });
  assert.equal(first.status, 201);
  assert.equal(first.body.appointment.ends_at, '2026-08-13T10:30:00+00:00');

  const overlapping = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-13T10:15:00Z',
    });
  assert.equal(overlapping.status, 409);
  assert.equal(overlapping.body.code, 'professional_double_booked');

  const backToBack = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-13T10:30:00Z',
    });
  assert.equal(backToBack.status, 201, 'a non-overlapping, back-to-back appointment is accepted');
});

test('a professional×service capability override changes the resolved ends_at, preserved when only the time moves', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const { error: capabilityError } = await supabaseAdmin.from('professional_service_capabilities').insert({
    organization_id: organizationId,
    professional_id: professionalId,
    service_id: serviceId,
    duration_override_minutes: 60,
  });
  assert.equal(capabilityError, null, capabilityError?.message);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-15T10:00:00Z',
    });
  assert.equal(created.status, 201);
  assert.equal(
    created.body.appointment.ends_at,
    '2026-08-15T11:00:00+00:00',
    'the 60min capability override wins over the service default of 30min',
  );
  assert.equal(created.body.appointment.resolved_duration_minutes, 60);
  assert.equal(created.body.appointment.resolved_eligibility_source, 'capability');

  // MOVE_TIME_ONLY (ADR 0011): moving starts_at must reuse the frozen
  // resolved_duration_minutes, not re-resolve it from the capability again.
  const moved = await request(app)
    .patch(`/api/v1/appointments/${created.body.appointment.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ starts_at: '2026-08-15T14:00:00Z', version: created.body.appointment.version });
  assert.equal(moved.status, 200);
  assert.equal(
    moved.body.appointment.ends_at,
    '2026-08-15T15:00:00+00:00',
    'moving starts_at recomputes ends_at using the same resolved (frozen) duration',
  );
  assert.equal(moved.body.appointment.resolved_duration_minutes, 60, 'the snapshot is preserved, not re-resolved');
});

test('an appointment from another organization is invisible and cannot be mutated (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const seedA = await seedCatalog(orgA.organizationId, orgA.ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: seedA.clientId,
      professional_id: seedA.professionalId,
      service_id: seedA.serviceId,
      starts_at: '2026-08-14T10:00:00Z',
    });
  const appointmentId = created.body.appointment.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);

  const deleteFromOrgB = await request(app)
    .delete(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(deleteFromOrgB.status, 404);
});

test('list supports filtering by professional_id, status and date range', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const inRange = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-20T10:00:00Z',
    });
  assert.equal(inRange.status, 201);

  const outOfRange = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-09-01T10:00:00Z',
    });
  assert.equal(outOfRange.status, 201);

  const filteredByRange = await request(app)
    .get('/api/v1/appointments?from=2026-08-01T00:00:00Z&to=2026-08-31T00:00:00Z')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(filteredByRange.status, 200);
  assert.equal(filteredByRange.body.appointments.length, 1);
  assert.equal(filteredByRange.body.appointments[0].id, inRange.body.appointment.id);

  const filteredByProfessional = await request(app)
    .get(`/api/v1/appointments?professional_id=${professionalId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(filteredByProfessional.body.appointments.length, 2);

  const filteredByRandomProfessional = await request(app)
    .get(`/api/v1/appointments?professional_id=${randomUUID()}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(filteredByRandomProfessional.body.appointments.length, 0);

  const invalidStatus = await request(app)
    .get('/api/v1/appointments?status=bogus')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(invalidStatus.status, 400);
  assert.equal(invalidStatus.body.code, 'invalid_status');
});

test('a completed appointment cannot transition to any other status (Fase 10 FSM guard)', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-22T10:00:00Z',
    });
  const appointmentId = created.body.appointment.id;

  const completed = await request(app)
    .patch(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ status: 'completed', version: created.body.appointment.version });
  assert.equal(completed.status, 200);

  const reverted = await request(app)
    .patch(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ status: 'scheduled', version: completed.body.appointment.version });
  assert.equal(reverted.status, 400);
  assert.equal(reverted.body.code, 'constraint_violation');
});

test('update rejects a stale version with 409 (ADR 0012 optimistic concurrency)', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-23T10:00:00Z',
    });

  const stale = await request(app)
    .patch(`/api/v1/appointments/${created.body.appointment.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ status: 'confirmed', version: 999 });
  assert.equal(stale.status, 409);
  assert.equal(stale.body.code, 'version_conflict');
});

test('reconfiguring professional_id requires confirmation, then applies with confirm=true (ADR 0013 change plan)', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);
  const { data: secondProfessional } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: organizationId, name: 'Prof Dois' })
    .select('id')
    .single();

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-24T10:00:00Z',
    });

  const preview = await request(app)
    .patch(`/api/v1/appointments/${created.body.appointment.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ professional_id: secondProfessional.id, version: created.body.appointment.version });
  assert.equal(preview.status, 409);
  assert.equal(preview.body.code, 'confirmation_required');
  assert.equal(preview.body.details.proposed.professional_id, secondProfessional.id);

  const unchanged = await request(app)
    .get(`/api/v1/appointments/${created.body.appointment.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(unchanged.body.appointment.professional_id, professionalId, 'preview does not mutate the appointment');
  assert.equal(unchanged.body.appointment.version, created.body.appointment.version, 'preview does not bump version');

  const confirmed = await request(app)
    .patch(`/api/v1/appointments/${created.body.appointment.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({ professional_id: secondProfessional.id, version: created.body.appointment.version, confirm: true });
  assert.equal(confirmed.status, 200);
  assert.equal(confirmed.body.appointment.professional_id, secondProfessional.id);
});

test('the eligibility gate rejects a professional explicitly disabled for the service (ADR 0010)', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const { error: capabilityError } = await supabaseAdmin.from('professional_service_capabilities').insert({
    organization_id: organizationId,
    professional_id: professionalId,
    service_id: serviceId,
    eligibility: 'DISABLED',
  });
  assert.equal(capabilityError, null, capabilityError?.message);

  const blocked = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-25T10:00:00Z',
    });
  assert.equal(blocked.status, 400);
  assert.equal(blocked.body.code, 'professional_not_eligible_for_service');
});
