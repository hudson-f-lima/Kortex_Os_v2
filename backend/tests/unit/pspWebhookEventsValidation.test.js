import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validatePspWebhookPayload } from '../../src/modules/pspWebhookEvents/pspWebhookEvents.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

const VALID = {
  provider: 'stub_psp',
  provider_event_id: 'evt_001',
  event_type: 'payment_intent.captured',
  provider_reference: 'pi_ext_001',
  status: 'captured',
};

test('validatePspWebhookPayload accepts a well-formed synthetic event', () => {
  const result = validatePspWebhookPayload(VALID);
  assert.deepEqual(result, {
    provider: 'stub_psp',
    providerEventId: 'evt_001',
    eventType: 'payment_intent.captured',
    providerReference: 'pi_ext_001',
    status: 'captured',
  });
});

test('validatePspWebhookPayload rejects a missing provider', () => {
  const { provider, ...rest } = VALID;
  throwsCode(() => validatePspWebhookPayload(rest), 'invalid_provider');
});

test('validatePspWebhookPayload rejects a missing provider_event_id', () => {
  const { provider_event_id, ...rest } = VALID;
  throwsCode(() => validatePspWebhookPayload(rest), 'invalid_provider_event_id');
});

test('validatePspWebhookPayload rejects a missing event_type', () => {
  const { event_type, ...rest } = VALID;
  throwsCode(() => validatePspWebhookPayload(rest), 'invalid_event_type');
});

test('validatePspWebhookPayload rejects a missing provider_reference', () => {
  const { provider_reference, ...rest } = VALID;
  throwsCode(() => validatePspWebhookPayload(rest), 'invalid_provider_reference');
});

test('validatePspWebhookPayload rejects an invalid status', () => {
  throwsCode(() => validatePspWebhookPayload({ ...VALID, status: 'paid' }), 'invalid_status');
});

test('validatePspWebhookPayload ignores unknown fields (raw PSP envelopes carry extra data)', () => {
  const result = validatePspWebhookPayload({ ...VALID, card_brand: 'visa', signature: 'abc123' });
  assert.deepEqual(result, {
    provider: 'stub_psp',
    providerEventId: 'evt_001',
    eventType: 'payment_intent.captured',
    providerReference: 'pi_ext_001',
    status: 'captured',
  });
});
