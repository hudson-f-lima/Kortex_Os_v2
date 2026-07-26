import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createProfessional, createServiceGroup, localTestEnv, setUpOrgWithRole } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

async function createHeldAppointment() {
  const organization = await setUpOrgWithRole(supabaseAdmin, 'owner');
  const { data: client, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({
      organization_id: organization.organizationId,
      name: 'Cliente para replanejamento',
      created_by: organization.ownerUserId,
    })
    .select('id')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const serviceGroupId = await createServiceGroup(supabaseAdmin, organization.organizationId);
  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organization.organizationId,
      name: 'Servico com sinal',
      price_cents: 5000,
      duration_minutes: 30,
      service_group_id: serviceGroupId,
      deposit_mechanic: 'hold',
      deposit_type: 'fixed',
      deposit_value: 1500,
    })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);
  const professionalId = await createProfessional(supabaseAdmin, organization.organizationId);

  const created = await request(app)
    .post('/api/v1/appointments')
    .set('Authorization', `Bearer ${organization.accessToken}`)
    .set('X-Organization-Id', organization.organizationId)
    .set('Idempotency-Key', `appointment-${randomUUID()}`)
    .send({
      client_id: client.id,
      professional_id: professionalId,
      service_id: service.id,
      starts_at: '2026-09-05T10:00:00Z',
    });
  assert.equal(created.status, 201, JSON.stringify(created.body));
  assert.notEqual(created.body.deposit_hold, null, 'the fixture requires an active authorization hold');

  return { organization, appointment: created.body.appointment };
}

test('owner replans a held appointment through the explicit, idempotent command', async () => {
  const { organization, appointment } = await createHeldAppointment();
  const key = `replan-${randomUUID()}`;
  const payload = {
    starts_at: '2026-09-05T11:00:00Z',
    version: appointment.version,
  };

  const response = await request(app)
    .post(`/api/v1/appointments/${appointment.id}/replan`)
    .set('Authorization', `Bearer ${organization.accessToken}`)
    .set('X-Organization-Id', organization.organizationId)
    .set('Idempotency-Key', key)
    .send(payload);

  assert.equal(response.status, 200, JSON.stringify(response.body));
  assert.equal(response.body.appointment.starts_at, '2026-09-05T11:00:00+00:00');
  assert.notEqual(response.body.released_hold_id, null);
  assert.notEqual(response.body.deposit_hold, null);

  const replay = await request(app)
    .post(`/api/v1/appointments/${appointment.id}/replan`)
    .set('Authorization', `Bearer ${organization.accessToken}`)
    .set('X-Organization-Id', organization.organizationId)
    .set('Idempotency-Key', key)
    .send(payload);
  assert.equal(replay.status, 200, JSON.stringify(replay.body));
  assert.equal(replay.body.deposit_hold.id, response.body.deposit_hold.id, 'replay returns the original command result');
});
