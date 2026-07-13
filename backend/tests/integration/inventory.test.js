import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

async function seedProduct(organizationId, { stock = 5 } = {}) {
  const { data: product, error } = await supabaseAdmin
    .from('products')
    .insert({ organization_id: organizationId, sku: `SKU-${randomUUID()}`, name: 'Produto', price_cents: 1000, stock_on_hand: stock })
    .select('id')
    .single();
  assert.equal(error, null, error?.message);
  return product.id;
}

test('owner can adjust inventory and see the movement in the list', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const productId = await seedProduct(organizationId, { stock: 5 });

  const adjust = await request(app)
    .post('/api/v1/inventory/adjustments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ia-${randomUUID()}`)
    .send({ product_id: productId, quantity_delta: 20, reason: 'purchase' });
  assert.equal(adjust.status, 201);
  assert.equal(adjust.body.stock_on_hand, 25);

  const movements = await request(app)
    .get('/api/v1/inventory/movements')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(movements.status, 200);
  assert.equal(movements.body.movements.length, 1);
  assert.equal(movements.body.movements[0].reason, 'purchase');
  assert.equal(movements.body.movements[0].quantity_delta, 20);
  assert.equal(movements.body.movements[0].balance_after, 25);

  const filtered = await request(app)
    .get(`/api/v1/inventory/movements?product_id=${productId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(filtered.body.movements.length, 1);
});

test('manager can adjust inventory, reception cannot', async () => {
  const manager = await setUpOrgWithRole('manager');
  const productId = await seedProduct(manager.organizationId);

  const asManager = await request(app)
    .post('/api/v1/inventory/adjustments')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .set('Idempotency-Key', `ia-${randomUUID()}`)
    .send({ product_id: productId, quantity_delta: 5, reason: 'adjustment' });
  assert.equal(asManager.status, 201);

  const reception = await setUpOrgWithRole('reception');
  const receptionProductId = await seedProduct(reception.organizationId);
  const asReception = await request(app)
    .post('/api/v1/inventory/adjustments')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .set('Idempotency-Key', `ia-${randomUUID()}`)
    .send({ product_id: receptionProductId, quantity_delta: 5, reason: 'adjustment' });
  assert.equal(asReception.status, 403);
  assert.equal(asReception.body.code, 'insufficient_role');
});

test('inventory adjustment requires an Idempotency-Key header', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const productId = await seedProduct(organizationId);

  const res = await request(app)
    .post('/api/v1/inventory/adjustments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ product_id: productId, quantity_delta: 5, reason: 'purchase' });
  assert.equal(res.status, 400);
  assert.equal(res.body.code, 'missing_idempotency_key');
});

test('an adjustment that would drive stock below zero is rejected with 409', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const productId = await seedProduct(organizationId, { stock: 2 });

  const res = await request(app)
    .post('/api/v1/inventory/adjustments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ia-${randomUUID()}`)
    .send({ product_id: productId, quantity_delta: -10, reason: 'adjustment' });
  assert.equal(res.status, 409);
  assert.equal(res.body.code, 'operation_rejected');
});

test('a purchase/return reason with a negative delta is rejected as invalid_payload', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const productId = await seedProduct(organizationId);

  const res = await request(app)
    .post('/api/v1/inventory/adjustments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ia-${randomUUID()}`)
    .send({ product_id: productId, quantity_delta: -3, reason: 'purchase' });
  assert.equal(res.status, 400);
  assert.equal(res.body.code, 'invalid_payload');
});
