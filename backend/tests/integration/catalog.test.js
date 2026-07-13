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

test('catalog combines services and products with a polymorphic kind, readable by any member', async () => {
  const owner = await setUpOrgWithRole('owner');

  await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${owner.accessToken}`)
    .set('X-Organization-Id', owner.organizationId)
    .send({ name: 'Corte', price_cents: 5000, duration_minutes: 30 });
  await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${owner.accessToken}`)
    .set('X-Organization-Id', owner.organizationId)
    .send({ sku: 'SKU-1', name: 'Shampoo', price_cents: 2500 });

  const reception = await setUpOrgWithRole('reception');
  await supabaseAdmin.rpc('membership_set', {
    p_organization_id: owner.organizationId,
    p_actor_user_id: owner.ownerUserId,
    p_target_user_id: reception.userId,
    p_role: 'reception',
  });

  const listed = await request(app)
    .get('/api/v1/catalog')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', owner.organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.items.length, 2);

  const service = listed.body.items.find((item) => item.kind === 'service');
  const product = listed.body.items.find((item) => item.kind === 'product');
  assert.ok(service, 'service item present');
  assert.ok(product, 'product item present');
  assert.equal(service.name, 'Corte');
  assert.equal(service.duration_minutes, 30);
  assert.equal(product.name, 'Shampoo');
  assert.equal(product.sku, 'SKU-1');
  assert.equal(product.stock_on_hand, 0);
});

test('catalog active filter excludes inactive items', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Inactive Service', price_cents: 1000, duration_minutes: 10 });
  await request(app)
    .patch(`/api/v1/services/${created.body.service.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ active: false });

  const activeOnly = await request(app)
    .get('/api/v1/catalog?active=true')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(activeOnly.status, 200);
  assert.equal(activeOnly.body.items.length, 0);

  const all = await request(app)
    .get('/api/v1/catalog')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(all.body.items.length, 1);
});

test('catalog is tenant-scoped', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');

  await request(app)
    .post('/api/v1/services')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ name: 'Org A Service', price_cents: 1000, duration_minutes: 10 });

  const listedFromOrgB = await request(app)
    .get('/api/v1/catalog')
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(listedFromOrgB.status, 200);
  assert.equal(listedFromOrgB.body.items.length, 0);
});
