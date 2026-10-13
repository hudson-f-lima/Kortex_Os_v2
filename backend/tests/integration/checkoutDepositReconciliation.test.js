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

test('checkout of an appointment with an active deposit closes with the correct amount, capturing the hold', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedFixtures(organizationId, ownerUserId, {
    deposit_mechanic: 'hold',
    deposit_type: 'fixed',
    deposit_value: 5000,
  });

  const appt = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('appt'))
    .send({ client_id: clientId, professional_id: professionalId, service_id: serviceId, starts_at: '2026-08-20T10:00:00Z' });
  assert.equal(appt.status, 201);
  assert.notEqual(appt.body.deposit_hold, null);
  const appointmentId = appt.body.appointment.id;
  const { error: firstStatusError } = await supabaseAdmin
    .from('appointments')
    .update({ status: 'in_service' })
    .eq('organization_id', organizationId)
    .eq('id', appointmentId);
  assert.equal(firstStatusError, null, firstStatusError?.message);

  const checkout = await request(app)
    .post(`/api/v1/appointments/${appointmentId}/checkout`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('ck'))
    .send({
      items: [{ kind: 'service', id: serviceId, quantity: 1, professional_id: professionalId }],
      payments: [{ method: 'cash', amount_cents: 15000 }],
    });
  assert.equal(checkout.status, 201);
  assert.equal(checkout.body.total_cents, 20000, 'full service price, unaffected by the deposit reconciliation');
  assert.equal(checkout.body.deposit_applied_cents, 5000);

  const { data: hold, error } = await supabaseAdmin
    .from('deposit_holds')
    .select('status')
    .eq('appointment_id', appointmentId)
    .single();
  assert.equal(error, null, error?.message);
  assert.equal(hold.status, 'captured_checkout');

  const { data: payments } = await supabaseAdmin
    .from('payments')
    .select('method, amount_cents')
    .eq('order_id', checkout.body.order_id);
  assert.equal(payments.length, 2, 'a deposit payment plus the client cash payment');
  const total = payments.reduce((sum, p) => sum + p.amount_cents, 0);
  assert.equal(total, 20000);
});

test('appointment checkout rejects a client claim instead of borrowing another appointment\'s deposit', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId: clientA, professionalId, serviceId: serviceA } = await seedFixtures(organizationId, ownerUserId, {
    deposit_mechanic: 'hold',
    deposit_type: 'fixed',
    deposit_value: 5000,
  });
  const { data: clientB, error: clientBError } = await supabaseAdmin
    .from('clients')
    .insert({ organization_id: organizationId, name: 'Cliente B', created_by: ownerUserId })
    .select('id')
    .single();
  assert.equal(clientBError, null, clientBError?.message);
  const serviceGroupB = await createServiceGroup(supabaseAdmin, organizationId);
  const { data: serviceB, error: serviceBError } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name: 'Manicure',
      price_cents: 3000,
      duration_minutes: 20,
      service_group_id: serviceGroupB,
    })
    .select('id')
    .single();
  assert.equal(serviceBError, null, serviceBError?.message);

  const appt = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('appt'))
    .send({ client_id: clientA, professional_id: professionalId, service_id: serviceA, starts_at: '2026-08-21T10:00:00Z' });
  assert.equal(appt.status, 201);
  assert.notEqual(appt.body.deposit_hold, null);
  const appointmentId = appt.body.appointment.id;
  const { error: secondStatusError } = await supabaseAdmin
    .from('appointments')
    .update({ status: 'in_service' })
    .eq('organization_id', organizationId)
    .eq('id', appointmentId);
  assert.equal(secondStatusError, null, secondStatusError?.message);

  const exploit = await request(app)
    .post(`/api/v1/appointments/${appointmentId}/checkout`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('ck-exploit'))
    .send({
      client_id: clientB.id,
      items: [{ kind: 'service', id: serviceB.id, quantity: 1, professional_id: professionalId }],
      payments: [],
    });
  assert.equal(exploit.status, 400, 'the client claim is rejected before the financial RPC');
  assert.equal(exploit.body.code, 'unknown_fields');

  const { data: hold, error } = await supabaseAdmin
    .from('deposit_holds')
    .select('status')
    .eq('appointment_id', appointmentId)
    .single();
  assert.equal(error, null, error?.message);
  assert.equal(hold.status, 'active', 'the unrelated appointment\'s hold is untouched');
});

test('checkout without appointment_id (or without an active deposit) behaves exactly as before', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { serviceId, professionalId } = await seedFixtures(organizationId, ownerUserId);

  const checkout = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey('ck'))
    .send({
      items: [{ kind: 'service', id: serviceId, quantity: 1, professional_id: professionalId }],
      payments: [{ method: 'cash', amount_cents: 20000 }],
    });
  assert.equal(checkout.status, 201);
  assert.equal(checkout.body.total_cents, 20000);
  assert.equal(checkout.body.deposit_applied_cents, 0);
});
