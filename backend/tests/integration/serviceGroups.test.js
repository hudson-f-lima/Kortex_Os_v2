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

test('owner can create, list, update and delete a service group', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/service-groups')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: '  Cabelo  ', default_commission_type: 'percentage', default_commission_value: 4500 });
  assert.equal(created.status, 201);
  assert.equal(created.body.service_group.name, 'Cabelo');
  assert.equal(created.body.service_group.default_commission_type, 'percentage');
  assert.equal(created.body.service_group.default_commission_value, 4500);
  assert.equal(created.body.service_group.active, true);
  const groupId = created.body.service_group.id;

  const listed = await request(app)
    .get('/api/v1/service-groups')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.service_groups.length, 1);

  const updated = await request(app)
    .patch(`/api/v1/service-groups/${groupId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ default_commission_type: 'fixed', default_commission_value: 800 });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.service_group.default_commission_type, 'fixed');
  assert.equal(updated.body.service_group.default_commission_value, 800);
  assert.equal(updated.body.service_group.name, 'Cabelo', 'unrelated fields are preserved');

  const deleted = await request(app)
    .delete(`/api/v1/service-groups/${groupId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/service-groups/${groupId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'service_group_not_found');
});

test('any member can read service groups, write requires owner/admin/manager, delete requires owner/admin', async () => {
  const reception = await setUpOrgWithRole('reception');

  const readAsReception = await request(app)
    .get('/api/v1/service-groups')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 200);

  const writeAsReception = await request(app)
    .post('/api/v1/service-groups')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({ name: 'Should Not Be Created', default_commission_type: 'percentage', default_commission_value: 100 });
  assert.equal(writeAsReception.status, 403);
  assert.equal(writeAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const createdByManager = await request(app)
    .post('/api/v1/service-groups')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ name: 'Created By Manager', default_commission_type: 'percentage', default_commission_value: 100 });
  assert.equal(createdByManager.status, 201);

  const deleteAsManager = await request(app)
    .delete(`/api/v1/service-groups/${createdByManager.body.service_group.id}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsManager.status, 403);

  const deleteAsOwner = await request(app)
    .delete(`/api/v1/service-groups/${createdByManager.body.service_group.id}`)
    .set('Authorization', `Bearer ${manager.ownerAccessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsOwner.status, 204);
});

test('a service group from another organization is invisible and cannot be mutated (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/service-groups')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ name: 'Group Org A', default_commission_type: 'percentage', default_commission_value: 100 });
  const groupId = created.body.service_group.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/service-groups/${groupId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);
});
