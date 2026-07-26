import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, setUpOrgWithRole } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

async function getDefaultUnitId(organizationId) {
  const { data, error } = await supabaseAdmin
    .from('units')
    .select('id')
    .eq('organization_id', organizationId)
    .eq('is_default', true)
    .single();
  assert.equal(error, null, error?.message);
  return data.id;
}

async function createPaymentIntent(organizationId, unitId, overrides = {}) {
  const { data, error } = await supabaseAdmin
    .from('payment_intents')
    .insert({
      organization_id: organizationId,
      unit_id: unitId,
      purpose: overrides.purpose ?? 'deposit',
      provider: overrides.provider ?? 'stub_psp',
      provider_reference: overrides.providerReference ?? `pi_ext_${randomUUID()}`,
      amount_cents: overrides.amountCents ?? 2000,
    })
    .select('id, status, provider, provider_reference')
    .single();
  assert.equal(error, null, error?.message);
  return data;
}

test('a webhook event matching a known payment_intent updates its status', async () => {
  const { organizationId } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  const unitId = await getDefaultUnitId(organizationId);
  const intent = await createPaymentIntent(organizationId, unitId);

  const response = await request(app).post('/api/v1/webhooks/psp').send({
    provider: intent.provider,
    provider_event_id: `evt_${randomUUID()}`,
    event_type: 'payment_intent.captured',
    provider_reference: intent.provider_reference,
    status: 'captured',
  });
  assert.equal(response.status, 200);
  assert.equal(response.body.matched, true);
  assert.equal(response.body.duplicate, false);

  const { data: updated } = await supabaseAdmin
    .from('payment_intents')
    .select('status')
    .eq('id', intent.id)
    .single();
  assert.equal(updated.status, 'captured');
});

test('a webhook event with no matching payment_intent is stored as a dead-letter, never discarded', async () => {
  const eventId = `evt_${randomUUID()}`;
  const response = await request(app).post('/api/v1/webhooks/psp').send({
    provider: 'stub_psp',
    provider_event_id: eventId,
    event_type: 'payment_intent.captured',
    provider_reference: `pi_ext_unmatched_${randomUUID()}`,
    status: 'captured',
  });
  assert.equal(response.status, 200);
  assert.equal(response.body.matched, false);
  assert.equal(response.body.duplicate, false);

  const { data: stored, error } = await supabaseAdmin
    .from('psp_webhook_events')
    .select('organization_id, unit_id, payment_intent_id, processed_at')
    .eq('provider', 'stub_psp')
    .eq('provider_event_id', eventId)
    .single();
  assert.equal(error, null, error?.message);
  assert.equal(stored.organization_id, null);
  assert.equal(stored.unit_id, null);
  assert.equal(stored.payment_intent_id, null);
  assert.equal(stored.processed_at, null);
});

test('redelivering the same provider_event_id is idempotent end-to-end (at-least-once replay)', async () => {
  const { organizationId } = await setUpOrgWithRole(supabaseAdmin, 'owner');
  const unitId = await getDefaultUnitId(organizationId);
  const intent = await createPaymentIntent(organizationId, unitId);
  const eventId = `evt_${randomUUID()}`;
  const body = {
    provider: intent.provider,
    provider_event_id: eventId,
    event_type: 'payment_intent.captured',
    provider_reference: intent.provider_reference,
    status: 'captured',
  };

  const first = await request(app).post('/api/v1/webhooks/psp').send(body);
  assert.equal(first.status, 200);
  assert.equal(first.body.duplicate, false);
  assert.equal(first.body.matched, true);

  const second = await request(app).post('/api/v1/webhooks/psp').send(body);
  assert.equal(second.status, 200, 'redelivery is a 200, never an error');
  assert.equal(second.body.duplicate, true, 'the outbox recognizes the replay as a duplicate, not a new event');

  const { data: events, error: eventsError } = await supabaseAdmin
    .from('psp_webhook_events')
    .select('id')
    .eq('provider', intent.provider)
    .eq('provider_event_id', eventId);
  assert.equal(eventsError, null, eventsError?.message);
  assert.equal(events.length, 1, 'the unique constraint means only one outbox row exists, not two');

  const { data: finalIntent } = await supabaseAdmin
    .from('payment_intents')
    .select('status')
    .eq('id', intent.id)
    .single();
  assert.equal(finalIntent.status, 'captured', 'same final state after the replay as after the first delivery');
});
