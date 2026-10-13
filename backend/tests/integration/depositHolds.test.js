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
const idemKey = () => `appt-${randomUUID()}`;

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

test('booking a service with a deposit policy creates a deposit_hold with the snapshotted values', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedFixtures(organizationId, ownerUserId, {
    deposit_mechanic: 'hold',
    deposit_type: 'percentage',
    deposit_value: 2000,
    no_show_commission_type: 'fixed',
    no_show_commission_value: 1500,
  });

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-10T10:00:00Z',
    });
  assert.equal(created.status, 201);
  assert.notEqual(created.body.deposit_hold, null, 'a deposit_hold is returned alongside the appointment');
  assert.equal(created.body.deposit_hold.mechanic, 'hold');
  assert.equal(created.body.deposit_hold.amount_cents, 4000, '20000 * 2000bp / 10000 = 4000 cents');
  assert.equal(created.body.deposit_hold.status, 'active');
  assert.notEqual(created.body.deposit_hold.expires_at, null);

  const { data: holds, error } = await supabaseAdmin
    .from('deposit_holds')
    .select('appointment_id, payment_intent_id, status')
    .eq('appointment_id', created.body.appointment.id);
  assert.equal(error, null, error?.message);
  assert.equal(holds.length, 1, 'exactly one deposit_hold row exists for this appointment');
});

test('booking a service without a deposit policy creates no deposit_hold', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');
  const { clientId, professionalId, serviceId } = await seedFixtures(organizationId, ownerUserId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .set('Idempotency-Key', idemKey())
    .send({
      client_id: clientId,
      professional_id: professionalId,
      service_id: serviceId,
      starts_at: '2026-08-10T11:00:00Z',
    });
  assert.equal(created.status, 201);
  assert.equal(created.body.deposit_hold, null, 'no deposit_hold is returned for a service without a deposit policy');

  const { data: holds, error } = await supabaseAdmin
    .from('deposit_holds')
    .select('id')
    .eq('appointment_id', created.body.appointment.id);
  assert.equal(error, null, error?.message);
  assert.equal(holds.length, 0, 'no deposit_hold row is created');
});
