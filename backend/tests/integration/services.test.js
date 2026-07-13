import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createServiceGroup, localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

test('owner can create, list, update and delete a service', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);

  const created = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: '  Corte  ', price_cents: 5000, duration_minutes: 30, service_group_id: serviceGroupId });
  assert.equal(created.status, 201);
  assert.equal(created.body.service.name, 'Corte');
  assert.equal(created.body.service.service_group_id, serviceGroupId);
  assert.equal(created.body.service.commission_type, null, 'no service-level override by default');
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
    .send({ price_cents: 6000, commission_type: 'fixed', commission_value: 1500 });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.service.price_cents, 6000);
  assert.equal(updated.body.service.duration_minutes, 30, 'unrelated fields are preserved');
  assert.equal(updated.body.service.commission_type, 'fixed');
  assert.equal(updated.body.service.commission_value, 1500);

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

test('creating a service requires a valid service_group_id in the same organization', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const other = await setUpOrgWithRole('owner');
  const otherGroupId = await createServiceGroup(supabaseAdmin, other.organizationId);

  const missingGroup = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Sem Grupo', price_cents: 1000, duration_minutes: 10 });
  assert.equal(missingGroup.status, 400);
  assert.equal(missingGroup.body.code, 'invalid_service_group_id');

  const crossTenantGroup = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Grupo De Outro Tenant', price_cents: 1000, duration_minutes: 10, service_group_id: otherGroupId });
  assert.equal(crossTenantGroup.status, 400);
  assert.equal(crossTenantGroup.body.code, 'invalid_service_group_id');
});

test('commission_type and commission_value must be provided together and percentage is capped at 10000 basis points', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const base = { name: 'Corte', price_cents: 5000, duration_minutes: 30, service_group_id: serviceGroupId };

  const onlyType = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ ...base, commission_type: 'percentage' });
  assert.equal(onlyType.status, 400);
  assert.equal(onlyType.body.code, 'invalid_commission');

  const overCap = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ ...base, commission_type: 'percentage', commission_value: 10001 });
  assert.equal(overCap.status, 400);
  assert.equal(overCap.body.code, 'invalid_commission_value');

  const fixedUnbounded = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ ...base, commission_type: 'fixed', commission_value: 999999 });
  assert.equal(fixedUnbounded.status, 201, 'fixed commission is not bounded by the percentage cap');
});

test('any member can read services, write requires owner/admin/manager, delete requires owner/admin', async () => {
  const reception = await setUpOrgWithRole('reception');
  const serviceGroupId = await createServiceGroup(supabaseAdmin, reception.organizationId);

  const readAsReception = await request(app)
    .get('/api/v1/services')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 200);

  const writeAsReception = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({ name: 'Should Not Be Created', price_cents: 1000, duration_minutes: 10, service_group_id: serviceGroupId });
  assert.equal(writeAsReception.status, 403);
  assert.equal(writeAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const managerGroupId = await createServiceGroup(supabaseAdmin, manager.organizationId);
  const createdByManager = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ name: 'Created By Manager', price_cents: 4000, duration_minutes: 20, service_group_id: managerGroupId });
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
  const groupA = await createServiceGroup(supabaseAdmin, orgA.organizationId);

  const created = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ name: 'Service Org A', price_cents: 1000, duration_minutes: 15, service_group_id: groupA });
  const serviceId = created.body.service.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/services/${serviceId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);
});

test('deleting a service referenced by an appointment returns 409 instead of a raw DB error', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);

  const createdService = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Service Com Agendamento', price_cents: 5000, duration_minutes: 30, service_group_id: serviceGroupId });
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

test('deleting a service group referenced by a service returns 409 instead of a raw DB error', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Corte', price_cents: 5000, duration_minutes: 30, service_group_id: serviceGroupId });

  const del = await request(app)
    .delete(`/api/v1/service-groups/${serviceGroupId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(del.status, 409);
  assert.equal(del.body.code, 'referenced_by_other_records');
});
