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

async function closeACheckout(organizationId, actorUserId) {
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId, {
    defaultCommissionType: 'percentage',
    defaultCommissionValue: 4000,
  });
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

  const { data, error } = await supabaseAdmin.rpc('checkout_close', {
    p_organization_id: organizationId,
    p_actor_user_id: actorUserId,
    p_idempotency_key: `seed-${randomUUID()}`,
    p_payload: {
      items: [{ kind: 'service', id: service.id, quantity: 1, professional_id: professionalId }],
      payments: [{ method: 'cash', amount_cents: 5000 }],
    },
  });
  assert.equal(error, null, error?.message);
  return { orderId: data.order_id, professionalId };
}

test('reception can list and read orders, professional role cannot', async () => {
  const reception = await setUpOrgWithRole('reception');
  const { orderId, professionalId } = await closeACheckout(reception.organizationId, reception.ownerUserId);

  const listedAsReception = await request(app)
    .get('/api/v1/orders')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(listedAsReception.status, 200);
  assert.equal(listedAsReception.body.orders.length, 1);

  const getAsReception = await request(app)
    .get(`/api/v1/orders/${orderId}`)
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(getAsReception.status, 200);
  const [serviceItem] = getAsReception.body.order.items;
  assert.equal(serviceItem.professional_id, professionalId, 'commission is frozen with the professional who performed it');
  assert.equal(serviceItem.commission_type, 'percentage');
  assert.equal(serviceItem.commission_value, 4000);
  assert.equal(serviceItem.commission_cents, 2000, '40% of the 5000 cents service price');

  const professional = await setUpOrgWithRole('professional');
  const listedAsProfessional = await request(app)
    .get('/api/v1/orders')
    .set('Authorization', `Bearer ${professional.accessToken}`)
    .set('X-Organization-Id', professional.organizationId);
  assert.equal(listedAsProfessional.status, 403);
  assert.equal(listedAsProfessional.body.code, 'insufficient_role');
});

test('an order from another organization is invisible (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  const { orderId } = await closeACheckout(orgA.organizationId, orgA.ownerUserId);

  const getFromOrgB = await request(app)
    .get(`/api/v1/orders/${orderId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);
  assert.equal(getFromOrgB.body.code, 'order_not_found');

  const listedFromOrgB = await request(app)
    .get('/api/v1/orders')
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(listedFromOrgB.body.orders.length, 0);
});

test('owner can refund a closed order with a valid reason (ADR 0006)', async () => {
  const owner = await setUpOrgWithRole('owner');
  const { orderId } = await closeACheckout(owner.organizationId, owner.ownerUserId);

  const refunded = await request(app)
    .post(`/api/v1/orders/${orderId}/refund`)
    .set('Authorization', `Bearer ${owner.accessToken}`)
    .set('X-Organization-Id', owner.organizationId)
    .set('Idempotency-Key', `refund-${randomUUID()}`)
    .send({ reason: 'customer_cancellation' });
  assert.equal(refunded.status, 200, JSON.stringify(refunded.body));
  assert.equal(refunded.body.status, 'refunded');

  const getAfterRefund = await request(app)
    .get(`/api/v1/orders/${orderId}`)
    .set('Authorization', `Bearer ${owner.accessToken}`)
    .set('X-Organization-Id', owner.organizationId);
  assert.equal(getAfterRefund.body.order.status, 'refunded');
  assert.equal(getAfterRefund.body.order.refund_reason, 'customer_cancellation');

  const cashEntries = await request(app)
    .get('/api/v1/cash-entries?kind=refund')
    .set('Authorization', `Bearer ${owner.accessToken}`)
    .set('X-Organization-Id', owner.organizationId);
  assert.equal(cashEntries.body.cash_entries.length, 1);
  assert.equal(cashEntries.body.cash_entries[0].amount_cents, 5000);
});

test('refund rejects reception, missing/invalid reason, and a second refund on the same order', async () => {
  const reception = await setUpOrgWithRole('reception');
  const { orderId: orderForReception } = await closeACheckout(reception.organizationId, reception.ownerUserId);
  const forbidden = await request(app)
    .post(`/api/v1/orders/${orderForReception}/refund`)
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .set('Idempotency-Key', `refund-${randomUUID()}`)
    .send({ reason: 'customer_cancellation' });
  assert.equal(forbidden.status, 403);
  assert.equal(forbidden.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const { orderId } = await closeACheckout(manager.organizationId, manager.ownerUserId);

  const missingReason = await request(app)
    .post(`/api/v1/orders/${orderId}/refund`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .set('Idempotency-Key', `refund-${randomUUID()}`)
    .send({});
  assert.equal(missingReason.status, 400);
  assert.equal(missingReason.body.code, 'invalid_reason');

  const invalidReason = await request(app)
    .post(`/api/v1/orders/${orderId}/refund`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .set('Idempotency-Key', `refund-${randomUUID()}`)
    .send({ reason: 'operator_typo' });
  assert.equal(invalidReason.status, 400);
  assert.equal(invalidReason.body.code, 'invalid_reason');

  const firstRefund = await request(app)
    .post(`/api/v1/orders/${orderId}/refund`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .set('Idempotency-Key', `refund-${randomUUID()}`)
    .send({ reason: 'customer_default' });
  assert.equal(firstRefund.status, 200);

  const secondRefund = await request(app)
    .post(`/api/v1/orders/${orderId}/refund`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .set('Idempotency-Key', `refund-${randomUUID()}`)
    .send({ reason: 'customer_default' });
  assert.equal(secondRefund.status, 409, JSON.stringify(secondRefund.body));
  assert.equal(secondRefund.body.code, 'operation_rejected');
});
