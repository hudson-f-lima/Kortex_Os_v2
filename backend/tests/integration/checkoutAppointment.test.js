import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import {
  createProfessional,
  createServiceGroup,
  localTestEnv,
  setUpOrgWithRole as setUpOrg,
} from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

async function seedService(organizationId) {
  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data: service, error } = await supabaseAdmin
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
  assert.equal(error, null, error?.message);
  const professionalId = await createProfessional(supabaseAdmin, organizationId);
  return { serviceId: service.id, professionalId };
}

async function seedAppointment(organizationId, ownerUserId, accessToken, { status = 'in_service' } = {}) {
  const { data: client, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({ organization_id: organizationId, name: 'Cliente de agendamento', created_by: ownerUserId })
    .select('id')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name: 'Corte com sinal',
      price_cents: 5000,
      duration_minutes: 30,
      service_group_id: serviceGroupId,
      deposit_mechanic: 'hold',
      deposit_type: 'fixed',
      deposit_value: 2000,
    })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);
  const professionalId = await createProfessional(supabaseAdmin, organizationId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `appointment-${randomUUID()}`)
    .send({
      client_id: client.id,
      professional_id: professionalId,
      service_id: service.id,
      starts_at: '2026-08-31T10:00:00.000Z',
    });
  assert.equal(created.status, 201, JSON.stringify(created.body));

  if (status !== 'scheduled') {
    const { error: statusError } = await supabaseAdmin
      .from('appointments')
      .update({ status })
      .eq('organization_id', organizationId)
      .eq('id', created.body.appointment.id);
    assert.equal(statusError, null, statusError?.message);
  }

  return { appointmentId: created.body.appointment.id, clientId: client.id, serviceId: service.id, professionalId };
}

test('walk-in checkout rejects an appointment_id claim', async () => {
  const { organizationId, accessToken } = await setUpOrg(supabaseAdmin, 'owner');
  const { serviceId, professionalId } = await seedService(organizationId);

  const response = await request(app)
    .post('/api/v1/checkout')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `checkout-walk-in-${randomUUID()}`)
    .send({
      appointment_id: randomUUID(),
      items: [{ kind: 'service', id: serviceId, quantity: 1, professional_id: professionalId }],
      payments: [{ method: 'cash', amount_cents: 5000 }],
    });

  assert.equal(response.status, 400);
  assert.equal(response.body.code, 'unknown_fields');
});

test('appointment checkout derives the appointment and client from its scoped path occurrence', async () => {
  const { organizationId, ownerUserId, accessToken } = await setUpOrg(supabaseAdmin, 'owner');
  const appointment = await seedAppointment(organizationId, ownerUserId, accessToken);

  const response = await request(app)
    .post(`/api/v1/appointments/${appointment.appointmentId}/checkout`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `checkout-appointment-${randomUUID()}`)
    .send({
      items: [{ kind: 'service', id: appointment.serviceId, quantity: 1, professional_id: appointment.professionalId }],
      payments: [{ method: 'cash', amount_cents: 3000 }],
    });

  assert.equal(response.status, 201, JSON.stringify(response.body));
  const { data: order, error: orderError } = await supabaseAdmin
    .from('orders')
    .select('appointment_id, client_id, deposit_hold_id')
    .eq('organization_id', organizationId)
    .eq('id', response.body.order_id)
    .single();
  assert.equal(orderError, null, orderError?.message);
  assert.equal(order.appointment_id, appointment.appointmentId);
  assert.equal(order.client_id, appointment.clientId);
  assert.notEqual(order.deposit_hold_id, null);
});

test('appointment checkout maps an ineligible occurrence state to a stable conflict', async () => {
  const { organizationId, ownerUserId, accessToken } = await setUpOrg(supabaseAdmin, 'owner');
  const appointment = await seedAppointment(organizationId, ownerUserId, accessToken, { status: 'scheduled' });

  const response = await request(app)
    .post(`/api/v1/appointments/${appointment.appointmentId}/checkout`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', `checkout-scheduled-${randomUUID()}`)
    .send({
      items: [{ kind: 'service', id: appointment.serviceId, quantity: 1, professional_id: appointment.professionalId }],
      payments: [{ method: 'cash', amount_cents: 3000 }],
    });

  assert.equal(response.status, 409);
  assert.equal(response.body.code, 'appointment_checkout_mismatch');
});
