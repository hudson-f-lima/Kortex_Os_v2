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

test('owner can create, list, update and delete a product; stock_on_hand starts at zero and is read-only', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ sku: '  SKU-1  ', name: '  Shampoo  ', price_cents: 2500 });
  assert.equal(created.status, 201);
  assert.equal(created.body.product.sku, 'SKU-1');
  assert.equal(created.body.product.name, 'Shampoo');
  assert.equal(created.body.product.stock_on_hand, 0);
  assert.equal(created.body.product.cost_cents, 0);
  const productId = created.body.product.id;

  const rejectedStockWrite = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ sku: 'SKU-2', name: 'Condicionador', price_cents: 2500, stock_on_hand: 999 });
  assert.equal(rejectedStockWrite.status, 400);
  assert.equal(rejectedStockWrite.body.code, 'unknown_fields');
  assert.deepEqual(rejectedStockWrite.body.details.fields, ['stock_on_hand']);

  const listed = await request(app)
    .get('/api/v1/products')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.products.length, 1);

  const updated = await request(app)
    .patch(`/api/v1/products/${productId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ price_cents: 3000, cost_cents: 1000 });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.product.price_cents, 3000);
  assert.equal(updated.body.product.cost_cents, 1000);

  const deleted = await request(app)
    .delete(`/api/v1/products/${productId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/products/${productId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'product_not_found');
});

test('any member can read products, write requires owner/admin/manager, delete requires owner/admin', async () => {
  const reception = await setUpOrgWithRole('reception');

  const readAsReception = await request(app)
    .get('/api/v1/products')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 200);

  const writeAsReception = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({ sku: 'SKU-X', name: 'Should Not Be Created', price_cents: 1000 });
  assert.equal(writeAsReception.status, 403);

  const manager = await setUpOrgWithRole('manager');
  const createdByManager = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ sku: 'SKU-M', name: 'Created By Manager', price_cents: 4000 });
  assert.equal(createdByManager.status, 201);

  const deleteAsManager = await request(app)
    .delete(`/api/v1/products/${createdByManager.body.product.id}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsManager.status, 403);

  const deleteAsOwner = await request(app)
    .delete(`/api/v1/products/${createdByManager.body.product.id}`)
    .set('Authorization', `Bearer ${manager.ownerAccessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsOwner.status, 204);
});

test('sku is unique per organization', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const first = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ sku: 'DUP-1', name: 'Produto A', price_cents: 1000 });
  assert.equal(first.status, 201);

  const duplicate = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ sku: 'DUP-1', name: 'Produto B', price_cents: 2000 });
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.body.code, 'already_exists');
});

test('a product from another organization is invisible and cannot be mutated (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ sku: 'ORG-A-1', name: 'Produto Org A', price_cents: 1000 });
  const productId = created.body.product.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/products/${productId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);

  const sameSkuInOrgB = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId)
    .send({ sku: 'ORG-A-1', name: 'Produto Org B', price_cents: 1500 });
  assert.equal(sameSkuInOrgB.status, 201, 'sku uniqueness is per organization, not global');
});

test('deleting a product referenced by an inventory movement returns 409 instead of a raw DB error', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');

  const createdProduct = await request(app)
    .post('/api/v1/products')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ sku: 'SKU-MOV', name: 'Produto Com Movimento', price_cents: 1000 });
  const productId = createdProduct.body.product.id;

  const { error: adjustError } = await supabaseAdmin.rpc('inventory_adjust', {
    p_organization_id: organizationId,
    p_actor_user_id: ownerUserId,
    p_idempotency_key: 'products-test-adjust-0001',
    p_product_id: productId,
    p_quantity_delta: 10,
    p_reason: 'purchase',
  });
  assert.equal(adjustError, null, adjustError?.message);

  const del = await request(app)
    .delete(`/api/v1/products/${productId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(del.status, 409);
  assert.equal(del.body.code, 'referenced_by_other_records');
});
