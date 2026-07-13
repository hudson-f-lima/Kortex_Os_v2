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

async function createService(organizationId, accessToken, overrides = {}) {
  const serviceGroupId = overrides.service_group_id ?? (await createServiceGroup(supabaseAdmin, organizationId));
  const created = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({
      name: overrides.name ?? 'Corte',
      price_cents: overrides.price_cents ?? 5000,
      duration_minutes: overrides.duration_minutes ?? 30,
      service_group_id: serviceGroupId,
    });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  return created.body.service.id;
}

test('owner can create, list, get, update and delete a package', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const corteId = await createService(organizationId, accessToken, { name: 'Corte', price_cents: 8000 });
  const escovaId = await createService(organizationId, accessToken, { name: 'Escova', price_cents: 6000 });

  const created = await request(app)
    .post('/api/v1/packages')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({
      name: 'Dia da Noiva',
      price_cents: 12000,
      items: [
        { service_id: corteId, quantity: 1 },
        { service_id: escovaId, quantity: 1 },
      ],
    });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  assert.equal(created.body.package.name, 'Dia da Noiva');
  assert.equal(created.body.package.price_cents, 12000);
  assert.equal(created.body.package.items.length, 2);
  const packageId = created.body.package.id;

  const listed = await request(app)
    .get('/api/v1/packages')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.packages.length, 1);

  const fetched = await request(app)
    .get(`/api/v1/packages/${packageId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(fetched.status, 200);
  assert.equal(fetched.body.package.items.length, 2);

  const renamed = await request(app)
    .patch(`/api/v1/packages/${packageId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Dia da Noiva Premium' });
  assert.equal(renamed.status, 200);
  assert.equal(renamed.body.package.name, 'Dia da Noiva Premium');
  assert.equal(renamed.body.package.items.length, 2, 'renaming does not touch the composition');

  const replacedItems = await request(app)
    .patch(`/api/v1/packages/${packageId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ items: [{ service_id: corteId, quantity: 1 }] });
  assert.equal(replacedItems.status, 200);
  assert.equal(replacedItems.body.package.items.length, 1, 'items replace the full composition');

  const deleted = await request(app)
    .delete(`/api/v1/packages/${packageId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/packages/${packageId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'package_not_found');
});

test('create_package rejects a duplicate service_id and an inactive service, mapped to safe HTTP errors', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const corteId = await createService(organizationId, accessToken);

  const duplicate = await request(app)
    .post('/api/v1/packages')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({
      name: 'Pacote Duplicado',
      price_cents: 1000,
      items: [
        { service_id: corteId, quantity: 1 },
        { service_id: corteId, quantity: 1 },
      ],
    });
  assert.equal(duplicate.status, 400);
  assert.equal(duplicate.body.code, 'invalid_payload');

  const inactiveId = await createService(organizationId, accessToken, { name: 'Descontinuado' });
  await request(app)
    .patch(`/api/v1/services/${inactiveId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ active: false });

  const withInactive = await request(app)
    .post('/api/v1/packages')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Pacote Inativo', price_cents: 1000, items: [{ service_id: inactiveId, quantity: 1 }] });
  assert.equal(withInactive.status, 400);
  assert.equal(withInactive.body.code, 'reference_not_found');
});

test('any member can read packages, write requires owner/admin/manager, delete requires owner/admin', async () => {
  const reception = await setUpOrgWithRole('reception');
  const corteId = await createService(reception.organizationId, reception.ownerAccessToken);

  const readAsReception = await request(app)
    .get('/api/v1/packages')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 200);

  const writeAsReception = await request(app)
    .post('/api/v1/packages')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({ name: 'Should Not Be Created', price_cents: 1000, items: [{ service_id: corteId, quantity: 1 }] });
  assert.equal(writeAsReception.status, 403);
  assert.equal(writeAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const managerServiceId = await createService(manager.organizationId, manager.ownerAccessToken);
  const createdByManager = await request(app)
    .post('/api/v1/packages')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ name: 'Created By Manager', price_cents: 1000, items: [{ service_id: managerServiceId, quantity: 1 }] });
  assert.equal(createdByManager.status, 201);

  const deleteAsManager = await request(app)
    .delete(`/api/v1/packages/${createdByManager.body.package.id}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsManager.status, 403);

  const deleteAsOwner = await request(app)
    .delete(`/api/v1/packages/${createdByManager.body.package.id}`)
    .set('Authorization', `Bearer ${manager.ownerAccessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsOwner.status, 204);
});

test('a package from another organization is invisible and cannot be mutated (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const serviceId = await createService(orgA.organizationId, orgA.accessToken);

  const created = await request(app)
    .post('/api/v1/packages')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ name: 'Package Org A', price_cents: 1000, items: [{ service_id: serviceId, quantity: 1 }] });
  const packageId = created.body.package.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/packages/${packageId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);

  const updateFromOrgB = await request(app)
    .patch(`/api/v1/packages/${packageId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId)
    .send({ name: 'Hijacked' });
  assert.equal(updateFromOrgB.status, 400);
  assert.equal(updateFromOrgB.body.code, 'reference_not_found');
});
