import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createProfessional, createServiceGroup, localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

async function createService(organizationId, overrides = {}) {
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data, error } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name: overrides.name ?? 'Corte',
      price_cents: overrides.price_cents ?? 5000,
      duration_minutes: 30,
      service_group_id: serviceGroupId,
    })
    .select('id')
    .single();
  assert.equal(error, null, error?.message);
  return data.id;
}

test('owner can create, list, get, update and delete a professional service capability', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceId = await createService(organizationId);

  const created = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({
      professional_id: professionalId,
      service_id: serviceId,
      duration_override_minutes: 45,
      buffer_before_min: 10,
      buffer_after_min: 5,
      price_override_cents: 6000,
    });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  assert.equal(created.body.professional_service_capability.professional_id, professionalId);
  assert.equal(created.body.professional_service_capability.service_id, serviceId);
  assert.equal(created.body.professional_service_capability.duration_override_minutes, 45);
  assert.equal(created.body.professional_service_capability.buffer_before_min, 10);
  assert.equal(created.body.professional_service_capability.buffer_after_min, 5);
  assert.equal(created.body.professional_service_capability.price_override_cents, 6000);
  const id = created.body.professional_service_capability.id;

  const listed = await request(app)
    .get('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.professional_service_capabilities.length, 1);

  const fetched = await request(app)
    .get(`/api/v1/professional-service-capabilities/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(fetched.status, 200);
  assert.equal(fetched.body.professional_service_capability.id, id);

  const updated = await request(app)
    .patch(`/api/v1/professional-service-capabilities/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ duration_override_minutes: 60, buffer_before_min: 20 });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.professional_service_capability.duration_override_minutes, 60);
  assert.equal(updated.body.professional_service_capability.buffer_before_min, 20);
  assert.equal(updated.body.professional_service_capability.professional_id, professionalId, 'identity fields are preserved');

  const deleted = await request(app)
    .delete(`/api/v1/professional-service-capabilities/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/professional-service-capabilities/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'capability_not_found');
});

test('list can be filtered by professional_id and service_id', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalA = await createProfessional(supabaseAdmin, organizationId);
  const professionalB = await createProfessional(supabaseAdmin, organizationId);
  const serviceA = await createService(organizationId, { name: 'Corte' });
  const serviceB = await createService(organizationId, { name: 'Escova' });

  await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalA, service_id: serviceA, duration_override_minutes: 40 });
  await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalA, service_id: serviceB, duration_override_minutes: 50 });
  await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalB, service_id: serviceA, duration_override_minutes: 60 });

  const byProfessional = await request(app)
    .get(`/api/v1/professional-service-capabilities?professional_id=${professionalA}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(byProfessional.status, 200);
  assert.equal(byProfessional.body.professional_service_capabilities.length, 2);

  const byService = await request(app)
    .get(`/api/v1/professional-service-capabilities?service_id=${serviceA}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(byService.status, 200);
  assert.equal(byService.body.professional_service_capabilities.length, 2);
});

test('create validates duration/buffer/price bounds', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceId = await createService(organizationId);

  const invalidDuration = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, duration_override_minutes: 2 });
  assert.equal(invalidDuration.status, 400);
  assert.equal(invalidDuration.body.code, 'invalid_duration_override_minutes');

  const invalidBuffer = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, buffer_before_min: 500 });
  assert.equal(invalidBuffer.status, 400);
  assert.equal(invalidBuffer.body.code, 'invalid_buffer_before_min');

  const invalidPrice = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, price_override_cents: -100 });
  assert.equal(invalidPrice.status, 400);
  assert.equal(invalidPrice.body.code, 'invalid_price_override_cents');
});

test('create rejects a professional_id/service_id from another organization, and a duplicate capability', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const other = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceId = await createService(organizationId);
  const otherProfessionalId = await createProfessional(supabaseAdmin, other.organizationId);

  const crossTenantProfessional = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: otherProfessionalId, service_id: serviceId, duration_override_minutes: 30 });
  assert.equal(crossTenantProfessional.status, 400);
  assert.equal(crossTenantProfessional.body.code, 'invalid_professional_id');

  const first = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, duration_override_minutes: 30 });
  assert.equal(first.status, 201);

  const duplicate = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, duration_override_minutes: 50 });
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.body.code, 'already_exists');
});

test('read is open to any active member, write requires owner/admin/manager, delete requires owner/admin', async () => {
  const reception = await setUpOrgWithRole('reception');
  const professionalIdForReception = await createProfessional(supabaseAdmin, reception.organizationId);
  const serviceIdForReception = await createService(reception.organizationId);

  const readAsReception = await request(app)
    .get('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 200, 'read is open to any active member, unlike financial data');

  const writeAsReception = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({
      professional_id: professionalIdForReception,
      service_id: serviceIdForReception,
      duration_override_minutes: 40,
    });
  assert.equal(writeAsReception.status, 403);
  assert.equal(writeAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const professionalIdForManager = await createProfessional(supabaseAdmin, manager.organizationId);
  const serviceIdForManager = await createService(manager.organizationId);
  const createdByManager = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({
      professional_id: professionalIdForManager,
      service_id: serviceIdForManager,
      duration_override_minutes: 40,
    });
  assert.equal(createdByManager.status, 201);

  const deleteAsManager = await request(app)
    .delete(`/api/v1/professional-service-capabilities/${createdByManager.body.professional_service_capability.id}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsManager.status, 403);

  const deleteAsOwner = await request(app)
    .delete(`/api/v1/professional-service-capabilities/${createdByManager.body.professional_service_capability.id}`)
    .set('Authorization', `Bearer ${manager.ownerAccessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsOwner.status, 204);
});

test('a professional service capability from another organization is invisible (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, orgA.organizationId);
  const serviceId = await createService(orgA.organizationId);

  const created = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, duration_override_minutes: 30 });
  const id = created.body.professional_service_capability.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/professional-service-capabilities/${id}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);
});

test('update rejects an unknown field and an empty payload', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceId = await createService(organizationId);

  const created = await request(app)
    .post('/api/v1/professional-service-capabilities')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, duration_override_minutes: 30 });
  const id = created.body.professional_service_capability.id;

  const unknownField = await request(app)
    .patch(`/api/v1/professional-service-capabilities/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ service_id: serviceId });
  assert.equal(unknownField.status, 400);
  assert.equal(unknownField.body.code, 'unknown_fields');

  const emptyPayload = await request(app)
    .patch(`/api/v1/professional-service-capabilities/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({});
  assert.equal(emptyPayload.status, 400);
  assert.equal(emptyPayload.body.code, 'empty_payload');
});
