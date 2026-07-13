import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

test('owner can create, list, update and delete a service', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: '  Corte  ', price_cents: 5000, duration_minutes: 30 });
  assert.equal(created.status, 201);
  assert.equal(created.body.service.name, 'Corte');
  assert.equal(created.body.service.active, true);
  const serviceId = created.body.service.id;

  const listed = await request(app)
    .get('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.services.length, 1);

  const updated = await request(app)
    .patch(`/api/v1/services/${serviceId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ price_cents: 6000 });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.service.price_cents, 6000);
  assert.equal(updated.body.service.duration_minutes, 30, 'unrelated fields are preserved');

  const deleted = await request(app)
    .delete(`/api/v1/services/${serviceId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/services/${serviceId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'service_not_found');
});

test('any member can read services, write requires owner/admin/manager, delete requires owner/admin', async () => {
  const reception = await setUpOrgWithRole('reception');

  const readAsReception = await request(app)
    .get('/api/v1/services')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 200);

  const writeAsReception = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({ name: 'Should Not Be Created', price_cents: 1000, duration_minutes: 10 });
  assert.equal(writeAsReception.status, 403);
  assert.equal(writeAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const createdByManager = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ name: 'Created By Manager', price_cents: 4000, duration_minutes: 20 });
  assert.equal(createdByManager.status, 201);

  const deleteAsManager = await request(app)
    .delete(`/api/v1/services/${createdByManager.body.service.id}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsManager.status, 403);

  const deleteAsOwner = await request(app)
    .delete(`/api/v1/services/${createdByManager.body.service.id}`)
    .set('Authorization', `Bearer ${manager.ownerAccessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsOwner.status, 204);
});

test('a service from another organization is invisible and cannot be mutated (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ name: 'Service Org A', price_cents: 1000, duration_minutes: 15 });
  const serviceId = created.body.service.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/services/${serviceId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);
});

test('deleting a service referenced by an appointment returns 409 instead of a raw DB error', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');

  const createdService = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Service Com Agendamento', price_cents: 5000, duration_minutes: 30 });
  const serviceId = createdService.body.service.id;

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

  const { error: appointmentError } = await supabaseAdmin.from('appointments').insert({
    organization_id: organizationId,
    client_id: client.id,
    professional_id: professional.id,
    service_id: serviceId,
    starts_at: '2026-09-03T10:00:00Z',
    ends_at: '2026-09-03T10:30:00Z',
    created_by: ownerUserId,
  });
  assert.equal(appointmentError, null, appointmentError?.message);

  const del = await request(app)
    .delete(`/api/v1/services/${serviceId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(del.status, 409);
  assert.equal(del.body.code, 'referenced_by_other_records');
});
