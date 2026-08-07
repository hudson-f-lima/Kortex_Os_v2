import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createServiceGroup, localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);
const idemKey = (prefix) => `${prefix}-${randomUUID()}`;

async function seedFixtures(organizationId, ownerUserId, serviceOverrides = {}) {
  const { data: client, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({ organization_id: organizationId, name: 'Cliente Teste', created_by: ownerUserId })
    .select('id')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const { data: professional, error: professionalError } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: organizationId, name: 'Prof Teste' })
    .select('id')
    .single();
  assert.equal(professionalError, null, professionalError?.message);

  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name: 'Corte',
      price_cents: 20000,
      duration_minutes: 30,
      service_group_id: serviceGroupId,
      ...serviceOverrides,
    })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);

  return { clientId: client.id, professionalId: professional.id, serviceId: service.id };
}

test('marking an appointment with an active deposit hold as no_show generates a full, visible synthetic order', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedFixtures(organizationId, ownerUserId, {
    deposit_mechanic: 'hold',
    deposit_type: 'fixed',
    deposit_value: 5000,
    no_show_commission_type: 'percentage',
    no_show_commission_value: 3000,
  });

  const appt = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('appt'))
    .send({ client_id: clientId, professional_id: professionalId, service_id: serviceId, starts_at: '2026-08-25T10:00:00Z' });
  assert.equal(appt.status, 201);
  assert.notEqual(appt.body.deposit_hold, null);
  const appointmentId = appt.body.appointment.id;

  const marked = await request(app)
    .patch(`/api/v1/appointments/${appointmentId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('upd'))
    .send({ status: 'no_show', version: appt.body.appointment.version });
  assert.equal(marked.status, 200);
  assert.equal(marked.body.appointment.status, 'no_show');
  assert.notEqual(marked.body.no_show_settlement, null, 'a settlement is returned alongside the appointment');
  assert.equal(marked.body.no_show_settlement.amount_cents, 5000);
  assert.equal(marked.body.no_show_settlement.commission_cents, 1500);

  const { data: order, error: orderError } = await supabaseAdmin
    .from('orders')
    .select('status, total_cents')
    .eq('id', marked.body.no_show_settlement.order_id)
    .single();
  assert.equal(orderError, null, orderError?.message);
  assert.equal(order.status, 'closed');
  assert.equal(order.total_cents, 5000);

  const { data: items, error: itemsError } = await supabaseAdmin
    .from('order_items')
    .select('commission_cents, professional_id')
    .eq('order_id', marked.body.no_show_settlement.order_id);
  assert.equal(itemsError, null, itemsError?.message);
  assert.equal(items.length, 1);
  assert.equal(items[0].professional_id, professionalId);
  assert.equal(items[0].commission_cents, 1500, 'visible via the same order_items.commission_cents column');
});

test('marking an appointment with no deposit policy as no_show does not create a settlement', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedFixtures(organizationId, ownerUserId);

  const appt = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('appt'))
    .send({ client_id: clientId, professional_id: professionalId, service_id: serviceId, starts_at: '2026-08-25T11:00:00Z' });
  assert.equal(appt.status, 201);
  assert.equal(appt.body.deposit_hold, null);

  const marked = await request(app)
    .patch(`/api/v1/appointments/${appt.body.appointment.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('upd'))
    .send({ status: 'no_show', version: appt.body.appointment.version });
  assert.equal(marked.status, 200);
  assert.equal(marked.body.no_show_settlement, null);
});
