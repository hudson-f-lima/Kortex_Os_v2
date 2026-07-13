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

test('owner can create, list, get, update and delete a professional service commission override', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceId = await createService(organizationId);

  const created = await request(app)
    .post('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, commission_type: 'percentage', commission_value: 6000 });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  assert.equal(created.body.professional_service_commission.professional_id, professionalId);
  assert.equal(created.body.professional_service_commission.service_id, serviceId);
  assert.equal(created.body.professional_service_commission.commission_type, 'percentage');
  assert.equal(created.body.professional_service_commission.commission_value, 6000);
  const id = created.body.professional_service_commission.id;

  const listed = await request(app)
    .get('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.professional_service_commissions.length, 1);

  const fetched = await request(app)
    .get(`/api/v1/professional-service-commissions/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(fetched.status, 200);
  assert.equal(fetched.body.professional_service_commission.id, id);

  const updated = await request(app)
    .patch(`/api/v1/professional-service-commissions/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ commission_type: 'fixed', commission_value: 1500 });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.professional_service_commission.commission_type, 'fixed');
  assert.equal(updated.body.professional_service_commission.commission_value, 1500);
  assert.equal(updated.body.professional_service_commission.professional_id, professionalId, 'identity fields are preserved');

  const deleted = await request(app)
    .delete(`/api/v1/professional-service-commissions/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/professional-service-commissions/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'professional_service_commission_not_found');
});

test('create rejects a professional_id/service_id from another organization, and a duplicate override', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const other = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceId = await createService(organizationId);
  const otherProfessionalId = await createProfessional(supabaseAdmin, other.organizationId);

  const crossTenantProfessional = await request(app)
    .post('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: otherProfessionalId, service_id: serviceId, commission_type: 'percentage', commission_value: 3000 });
  assert.equal(crossTenantProfessional.status, 400);
  assert.equal(crossTenantProfessional.body.code, 'invalid_professional_id');

  const first = await request(app)
    .post('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, commission_type: 'percentage', commission_value: 3000 });
  assert.equal(first.status, 201);

  const duplicate = await request(app)
    .post('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, commission_type: 'fixed', commission_value: 1000 });
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.body.code, 'already_exists');
});

test('read and write require owner/admin/manager (no reception), delete requires owner/admin', async () => {
  const reception = await setUpOrgWithRole('reception');
  const professionalIdForReception = await createProfessional(supabaseAdmin, reception.organizationId);
  const serviceIdForReception = await createService(reception.organizationId);

  const readAsReception = await request(app)
    .get('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 403);
  assert.equal(readAsReception.body.code, 'insufficient_role');

  const writeAsReception = await request(app)
    .post('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({
      professional_id: professionalIdForReception,
      service_id: serviceIdForReception,
      commission_type: 'percentage',
      commission_value: 1000,
    });
  assert.equal(writeAsReception.status, 403);
  assert.equal(writeAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const professionalIdForManager = await createProfessional(supabaseAdmin, manager.organizationId);
  const serviceIdForManager = await createService(manager.organizationId);
  const createdByManager = await request(app)
    .post('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({
      professional_id: professionalIdForManager,
      service_id: serviceIdForManager,
      commission_type: 'percentage',
      commission_value: 1000,
    });
  assert.equal(createdByManager.status, 201);

  const deleteAsManager = await request(app)
    .delete(`/api/v1/professional-service-commissions/${createdByManager.body.professional_service_commission.id}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsManager.status, 403);

  const deleteAsOwner = await request(app)
    .delete(`/api/v1/professional-service-commissions/${createdByManager.body.professional_service_commission.id}`)
    .set('Authorization', `Bearer ${manager.ownerAccessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsOwner.status, 204);
});

test('a professional service commission from another organization is invisible (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, orgA.organizationId);
  const serviceId = await createService(orgA.organizationId);

  const created = await request(app)
    .post('/api/v1/professional-service-commissions')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ professional_id: professionalId, service_id: serviceId, commission_type: 'percentage', commission_value: 3000 });
  const id = created.body.professional_service_commission.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/professional-service-commissions/${id}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);
});
