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

test('owner can create, list, get, update and delete a group eligibility row', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);

  const created = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_group_id: serviceGroupId, eligibility: 'DISABLED' });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  assert.equal(created.body.professional_service_group_eligibility.professional_id, professionalId);
  assert.equal(created.body.professional_service_group_eligibility.service_group_id, serviceGroupId);
  assert.equal(created.body.professional_service_group_eligibility.eligibility, 'DISABLED');
  const id = created.body.professional_service_group_eligibility.id;

  const listed = await request(app)
    .get('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.professional_service_group_eligibility.length, 1);

  const fetched = await request(app)
    .get(`/api/v1/professional-service-group-eligibility/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(fetched.status, 200);
  assert.equal(fetched.body.professional_service_group_eligibility.id, id);

  const updated = await request(app)
    .patch(`/api/v1/professional-service-group-eligibility/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ eligibility: 'ENABLED' });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.professional_service_group_eligibility.eligibility, 'ENABLED');
  assert.equal(updated.body.professional_service_group_eligibility.professional_id, professionalId, 'identity fields are preserved');

  const deleted = await request(app)
    .delete(`/api/v1/professional-service-group-eligibility/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/professional-service-group-eligibility/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'group_eligibility_not_found');
});

test('create defaults eligibility to ENABLED and validates the tri-state enum', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);

  const defaulted = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_group_id: serviceGroupId });
  assert.equal(defaulted.status, 201);
  assert.equal(defaulted.body.professional_service_group_eligibility.eligibility, 'ENABLED');

  const otherGroup = await createServiceGroup(supabaseAdmin, organizationId);
  const invalid = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_group_id: otherGroup, eligibility: 'nope' });
  assert.equal(invalid.status, 400);
  assert.equal(invalid.body.code, 'invalid_eligibility');
});

test('create rejects a professional_id/service_group_id from another organization, and a duplicate row', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const other = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const otherProfessionalId = await createProfessional(supabaseAdmin, other.organizationId);

  const crossTenant = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: otherProfessionalId, service_group_id: serviceGroupId, eligibility: 'ENABLED' });
  assert.equal(crossTenant.status, 400);
  assert.equal(crossTenant.body.code, 'invalid_professional_id');

  const first = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_group_id: serviceGroupId, eligibility: 'ENABLED' });
  assert.equal(first.status, 201);

  const duplicate = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_group_id: serviceGroupId, eligibility: 'DISABLED' });
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.body.code, 'already_exists');
});

test('read is open to any active member, write requires owner/admin/manager, delete requires owner/admin', async () => {
  const reception = await setUpOrgWithRole('reception');
  const professionalIdForReception = await createProfessional(supabaseAdmin, reception.organizationId);
  const groupIdForReception = await createServiceGroup(supabaseAdmin, reception.organizationId);

  const readAsReception = await request(app)
    .get('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 200, 'read is open to any active member');

  const writeAsReception = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({ professional_id: professionalIdForReception, service_group_id: groupIdForReception, eligibility: 'DISABLED' });
  assert.equal(writeAsReception.status, 403);
  assert.equal(writeAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const professionalIdForManager = await createProfessional(supabaseAdmin, manager.organizationId);
  const groupIdForManager = await createServiceGroup(supabaseAdmin, manager.organizationId);
  const createdByManager = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ professional_id: professionalIdForManager, service_group_id: groupIdForManager, eligibility: 'DISABLED' });
  assert.equal(createdByManager.status, 201);

  const deleteAsManager = await request(app)
    .delete(`/api/v1/professional-service-group-eligibility/${createdByManager.body.professional_service_group_eligibility.id}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsManager.status, 403);

  const deleteAsOwner = await request(app)
    .delete(`/api/v1/professional-service-group-eligibility/${createdByManager.body.professional_service_group_eligibility.id}`)
    .set('Authorization', `Bearer ${manager.ownerAccessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsOwner.status, 204);
});

test('a group eligibility row from another organization is invisible (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, orgA.organizationId);
  const serviceGroupId = await createServiceGroup(supabaseAdmin, orgA.organizationId);

  const created = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ professional_id: professionalId, service_group_id: serviceGroupId, eligibility: 'ENABLED' });
  const id = created.body.professional_service_group_eligibility.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/professional-service-group-eligibility/${id}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);
});

test('update rejects an unknown field and an empty payload', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);

  const created = await request(app)
    .post('/api/v1/professional-service-group-eligibility')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ professional_id: professionalId, service_group_id: serviceGroupId, eligibility: 'ENABLED' });
  const id = created.body.professional_service_group_eligibility.id;

  const unknownField = await request(app)
    .patch(`/api/v1/professional-service-group-eligibility/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ service_group_id: serviceGroupId });
  assert.equal(unknownField.status, 400);
  assert.equal(unknownField.body.code, 'unknown_fields');

  const emptyPayload = await request(app)
    .patch(`/api/v1/professional-service-group-eligibility/${id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({});
  assert.equal(emptyPayload.status, 400);
  assert.equal(emptyPayload.body.code, 'empty_payload');
});
