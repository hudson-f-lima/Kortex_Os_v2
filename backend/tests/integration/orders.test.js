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
