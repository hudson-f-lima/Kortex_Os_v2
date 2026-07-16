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

  return { clientId: client.id, professionalId: professional.id, serviceId: service.id };
}

test('owner can create, list, update and delete an appointment', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
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
    .send({ status: 'confirmed' });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.appointment.status, 'confirmed');
  assert.equal(updated.body.appointment.client_id, clientId, 'unrelated fields are preserved');

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

test('reception can create/update/delete appointments, but professional role cannot write', async () => {
  const reception = await setUpOrgWithRole('reception');
  const { clientId, professionalId, serviceId } = await seedCatalog(reception.organizationId, reception.ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
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
    .send({ status: 'confirmed' });
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
    .send({
      client_id: clientId,
      professional_id: otherSeed.professionalId,
      service_id: serviceId,
      starts_at: '2026-08-10T11:00:00Z',
    });
  assert.equal(crossOrgReference.status, 400);
  assert.equal(crossOrgReference.body.code, 'invalid_professional_id');
});

test('overlapping appointments for the same professional are rejected with 409', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedCatalog(organizationId, ownerUserId);

  const first = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
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
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-13T10:30:00Z',
    });
  assert.equal(backToBack.status, 201, 'a non-overlapping, back-to-back appointment is accepted');
});

test('a professional×service capability override changes the resolved ends_at', async () => {
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

  const moved = await request(app)
    .patch(`/api/v1/appointments/${created.body.appointment.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ starts_at: '2026-08-15T14:00:00Z' });
  assert.equal(moved.status, 200);
  assert.equal(
    moved.body.appointment.ends_at,
    '2026-08-15T15:00:00+00:00',
    'moving starts_at recomputes ends_at using the same resolved duration',
  );
});

test('an appointment from another organization is invisible and cannot be mutated (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const seedA = await seedCatalog(orgA.organizationId, orgA.ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
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
    .send({ status: 'completed' });
  assert.equal(completed.status, 200);

  const reverted = await request(app)
    .patch(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ status: 'scheduled' });
  assert.equal(reverted.status, 400);
  assert.equal(reverted.body.code, 'constraint_violation');
});
