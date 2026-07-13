import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createProfessional, createServiceGroup, localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

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

  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name: 'Corte',
      price_cents: 5000,
      duration_minutes: 30,
      service_group_id: serviceGroupId,
    })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);
  const professionalId = await createProfessional(supabaseAdmin, organizationId);

  return { productId: product.id, serviceId: service.id, professionalId };
}

async function createServiceForPackage(organizationId, { name, priceCents }) {
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data: service, error } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name,
      price_cents: priceCents,
      duration_minutes: 30,
      service_group_id: serviceGroupId,
    })
    .select('id')
    .single();
  assert.equal(error, null, error?.message);
  return service.id;
}

async function createPackageWithTwoServices(organizationId) {
  const corteId = await createServiceForPackage(organizationId, { name: 'Corte', priceCents: 8000 });
  const escovaId = await createServiceForPackage(organizationId, { name: 'Escova', priceCents: 6000 });
  const { data: pkg, error } = await supabaseAdmin
    .from('packages')
    .insert({ organization_id: organizationId, name: 'Dia da Noiva', price_cents: 12600 })
    .select('id')
    .single();
  assert.equal(error, null, error?.message);
  const { error: itemsError } = await supabaseAdmin
    .from('package_items')
    .insert([
      { organization_id: organizationId, package_id: pkg.id, service_id: corteId, quantity: 1 },
      { organization_id: organizationId, package_id: pkg.id, service_id: escovaId, quantity: 1 },
    ]);
  assert.equal(itemsError, null, itemsError?.message);
  return { packageId: pkg.id, corteId, escovaId };
}

test('owner can close a checkout with a product and a service; stock and cash entries update', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const { productId, serviceId, professionalId } = await seedProductAndService(organizationId);

  const checkout = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({
      items: [
        { kind: 'product', id: productId, quantity: 2 },
        { kind: 'service', id: serviceId, quantity: 1, professional_id: professionalId },
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
  const serviceItem = order.body.order.items.find((item) => item.kind === 'service');
  assert.equal(serviceItem.professional_id, professionalId);
  assert.equal(serviceItem.commission_type, 'percentage');
  assert.equal(serviceItem.commission_cents, 2000, '40% (createServiceGroup default) of the 5000 cents service price');
  const productItem = order.body.order.items.find((item) => item.kind === 'product');
  assert.equal(productItem.professional_id, null);
  assert.equal(productItem.commission_cents, 0);

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
  const { serviceId, professionalId } = await seedProductAndService(organizationId);

  const res = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({
      items: [{ kind: 'service', id: serviceId, quantity: 1, professional_id: professionalId }],
      payments: [{ method: 'cash', amount_cents: 5000 }],
    });
  assert.equal(res.status, 400);
  assert.equal(res.body.code, 'missing_idempotency_key');
});

test('a service item without professional_id is rejected', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const { serviceId } = await seedProductAndService(organizationId);

  const res = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({ items: [{ kind: 'service', id: serviceId, quantity: 1 }], payments: [{ method: 'cash', amount_cents: 5000 }] });
  assert.equal(res.status, 400);
  assert.equal(res.body.code, 'invalid_items');
});

test('reception can checkout, professional role cannot', async () => {
  const reception = await setUpOrgWithRole('reception');
  const { serviceId, professionalId } = await seedProductAndService(reception.organizationId);

  const asReception = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({
      items: [{ kind: 'service', id: serviceId, quantity: 1, professional_id: professionalId }],
      payments: [{ method: 'cash', amount_cents: 5000 }],
    });
  assert.equal(asReception.status, 201);

  const professional = await setUpOrgWithRole('professional');
  const seed = await seedProductAndService(professional.organizationId);
  const asProfessional = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${professional.accessToken}`)
    .set('X-Organization-Id', professional.organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({
      items: [{ kind: 'service', id: seed.serviceId, quantity: 1, professional_id: seed.professionalId }],
      payments: [{ method: 'cash', amount_cents: 5000 }],
    });
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
  const { serviceId, professionalId } = await seedProductAndService(organizationId);
  const key = `ck-${randomUUID()}`;
  const body = {
    items: [{ kind: 'service', id: serviceId, quantity: 1, professional_id: professionalId }],
    payments: [{ method: 'cash', amount_cents: 5000 }],
  };

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
    .send({
      items: [{ kind: 'service', id: serviceId, quantity: 2, professional_id: professionalId }],
      payments: [{ method: 'cash', amount_cents: 10000 }],
    });
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

test('a professional_id from another organization is rejected as a reference not found', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const { serviceId } = await seedProductAndService(orgA.organizationId);
  const seedB = await seedProductAndService(orgB.organizationId);

  const res = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({
      items: [{ kind: 'service', id: serviceId, quantity: 1, professional_id: seedB.professionalId }],
      payments: [{ method: 'cash', amount_cents: 5000 }],
    });
  assert.equal(res.status, 400);
  assert.equal(res.body.code, 'reference_not_found');
});

test('owner can checkout a package; it expands into one order_item per component with the assigned professionals', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const { packageId, corteId, escovaId } = await createPackageWithTwoServices(organizationId);
  const anaId = await createProfessional(supabaseAdmin, organizationId, { name: 'Ana' });
  const beatrizId = await createProfessional(supabaseAdmin, organizationId, { name: 'Beatriz' });

  const checkout = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({
      items: [
        {
          kind: 'package',
          id: packageId,
          quantity: 1,
          professionals: { [corteId]: anaId, [escovaId]: beatrizId },
        },
      ],
      payments: [{ method: 'cash', amount_cents: 12600 }],
    });
  assert.equal(checkout.status, 201, JSON.stringify(checkout.body));
  assert.equal(checkout.body.total_cents, 12600);

  const order = await request(app)
    .get(`/api/v1/orders/${checkout.body.order_id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(order.body.order.items.length, 2, 'the package expands into one order_item per component');
  assert.equal(
    order.body.order.items.reduce((sum, item) => sum + item.total_cents, 0),
    12600,
    'allocated component values sum exactly to the package price',
  );
  const corteItem = order.body.order.items.find((item) => item.service_id === corteId);
  const escovaItem = order.body.order.items.find((item) => item.service_id === escovaId);
  assert.equal(corteItem.professional_id, anaId);
  assert.equal(corteItem.total_cents, 7200, '8000/14000 share of the 12600 package price');
  assert.equal(escovaItem.professional_id, beatrizId);
  assert.equal(escovaItem.total_cents, 5400, '6000/14000 share of the 12600 package price');
});

test('a package item with quantity other than 1, or a professionals map that does not match the components, is rejected', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const { packageId, corteId, escovaId } = await createPackageWithTwoServices(organizationId);
  const anaId = await createProfessional(supabaseAdmin, organizationId, { name: 'Ana' });

  const wrongQuantity = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({
      items: [{ kind: 'package', id: packageId, quantity: 2, professionals: { [corteId]: anaId, [escovaId]: anaId } }],
      payments: [{ method: 'cash', amount_cents: 25200 }],
    });
  assert.equal(wrongQuantity.status, 400);
  assert.equal(wrongQuantity.body.code, 'invalid_items');

  const incompleteMap = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `ck-${randomUUID()}`)
    .send({
      items: [{ kind: 'package', id: packageId, quantity: 1, professionals: { [corteId]: anaId } }],
      payments: [{ method: 'cash', amount_cents: 12600 }],
    });
  assert.equal(incompleteMap.status, 400);
  assert.equal(incompleteMap.body.code, 'invalid_payload');
});
