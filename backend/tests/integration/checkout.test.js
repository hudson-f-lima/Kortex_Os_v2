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

async function seedProductAndService(organizationId, { stock = 10 } = {}) {
  const { data: product, error: productError } = await supabaseAdmin
    .from('products')
    .insert({ organization_id: organizationId, sku: `SKU-${randomUUID()}`, name: 'Shampoo', price_cents: 2500, stock_on_hand: stock })
    .select('id')
    .single();
  assert.equal(productError, null, productError?.message);

  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({ organization_id: organizationId, name: 'Corte', price_cents: 5000, duration_minutes: 30 })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);

  return { productId: product.id, serviceId: service.id };
}

test('owner can close a checkout with a product and a service; stock and cash entries update', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const { productId, serviceId } = await seedProductAndService(organizationId);

  const checkout = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({
      items: [
        { kind: 'product', id: productId, quantity: 2 },
        { kind: 'service', id: serviceId, quantity: 1 },
      ],
      payments: [{ method: 'cash', amount_cents: 10000 }],
    });
  assert.equal(checkout.status, 201);
  assert.equal(checkout.body.status, 'closed');
  assert.equal(checkout.body.total_cents, 10000);
  const orderId = checkout.body.order_id;

  const orders = await request(app)
    .get('/api/v1/orders')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(orders.status, 200);
  assert.equal(orders.body.orders.length, 1);
  assert.equal(orders.body.orders[0].id, orderId);

  const order = await request(app)
    .get(`/api/v1/orders/${orderId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(order.status, 200);
  assert.equal(order.body.order.items.length, 2);
  assert.equal(order.body.order.payments.length, 1);

  const product = await request(app)
    .get(`/api/v1/products/${productId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(product.body.product.stock_on_hand, 8, 'stock decremented by the purchased quantity');

  const cashEntries = await request(app)
    .get('/api/v1/cash-entries')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(cashEntries.status, 200);
  assert.equal(cashEntries.body.cash_entries.length, 1);
  assert.equal(cashEntries.body.cash_entries[0].kind, 'sale');
  assert.equal(cashEntries.body.cash_entries[0].amount_cents, 10000);
});

test('checkout requires an Idempotency-Key header', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const { serviceId } = await seedProductAndService(organizationId);

  const res = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ items: [{ kind: 'service', id: serviceId, quantity: 1 }], payments: [{ method: 'cash', amount_cents: 5000 }] });
  assert.equal(res.status, 400);
  assert.equal(res.body.code, 'missing_idempotency_key');
});

test('reception can checkout, professional role cannot', async () => {
  const reception = await setUpOrgWithRole('reception');
  const { serviceId } = await seedProductAndService(reception.organizationId);

  const asReception = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({ items: [{ kind: 'service', id: serviceId, quantity: 1 }], payments: [{ method: 'cash', amount_cents: 5000 }] });
  assert.equal(asReception.status, 201);

  const professional = await setUpOrgWithRole('professional');
  const seed = await seedProductAndService(professional.organizationId);
  const asProfessional = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${professional.accessToken}`)
    .set('X-Organization-Id', professional.organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({ items: [{ kind: 'service', id: seed.serviceId, quantity: 1 }], payments: [{ method: 'cash', amount_cents: 5000 }] });
  assert.equal(asProfessional.status, 403);
  assert.equal(asProfessional.body.code, 'insufficient_role');
});

test('insufficient stock is rejected with 409, leaving stock untouched', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const { productId } = await seedProductAndService(organizationId, { stock: 1 });

  const res = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({ items: [{ kind: 'product', id: productId, quantity: 5 }], payments: [{ method: 'cash', amount_cents: 12500 }] });
  assert.equal(res.status, 409);
  assert.equal(res.body.code, 'operation_rejected');

  const product = await request(app)
    .get(`/api/v1/products/${productId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(product.body.product.stock_on_hand, 1);
});

test('replaying the same idempotency key returns the cached response without duplicating the order', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const { serviceId } = await seedProductAndService(organizationId);
  const key = `ck-${randomUUID()}`;
  const body = { items: [{ kind: 'service', id: serviceId, quantity: 1 }], payments: [{ method: 'cash', amount_cents: 5000 }] };

  const first = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', key)
    .send(body);
  assert.equal(first.status, 201);

  const replay = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', key)
    .send(body);
  assert.equal(replay.status, 201);
  assert.equal(replay.body.order_id, first.body.order_id);

  const orders = await request(app)
    .get('/api/v1/orders')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(orders.body.orders.length, 1);

  const differentPayload = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', key)
    .send({ items: [{ kind: 'service', id: serviceId, quantity: 2 }], payments: [{ method: 'cash', amount_cents: 10000 }] });
  assert.equal(differentPayload.status, 400);
  assert.equal(differentPayload.body.code, 'invalid_payload');
});

test('a product id from another organization is rejected as a reference not found', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const seedB = await seedProductAndService(orgB.organizationId);

  const res = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({ items: [{ kind: 'product', id: seedB.productId, quantity: 1 }], payments: [{ method: 'cash', amount_cents: 2500 }] });
  assert.equal(res.status, 400);
  assert.equal(res.body.code, 'reference_not_found');
});
