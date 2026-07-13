import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateServiceId, validateServicePayload } from '../../src/modules/services/services.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validateServiceId accepts a well-formed uuid', () => {
  const id = '11111111-1111-1111-1111-111111111111';
  assert.equal(validateServiceId(id), id);
});

test('validateServiceId rejects a non-uuid string', () => {
  throwsCode(() => validateServiceId('nope'), 'invalid_id');
});

test('validateServicePayload requires name, price_cents and duration_minutes on create', () => {
  throwsCode(() => validateServicePayload({}, { requireAll: true }), 'invalid_name');
  throwsCode(() => validateServicePayload({ name: 'Corte' }, { requireAll: true }), 'invalid_price_cents');
  throwsCode(
    () => validateServicePayload({ name: 'Corte', price_cents: 5000 }, { requireAll: true }),
    'invalid_duration_minutes',
  );
});

test('validateServicePayload accepts a valid create payload', () => {
  const patch = validateServicePayload(
    { name: '  Corte  ', price_cents: 5000, duration_minutes: 30 },
    { requireAll: true },
  );
  assert.deepEqual(patch, { name: 'Corte', price_cents: 5000, duration_minutes: 30 });
});

test('validateServicePayload rejects a negative price_cents', () => {
  throwsCode(
    () => validateServicePayload({ name: 'Corte', price_cents: -1, duration_minutes: 30 }, { requireAll: true }),
    'invalid_price_cents',
  );
});

test('validateServicePayload rejects a non-integer price_cents', () => {
  throwsCode(
    () => validateServicePayload({ name: 'Corte', price_cents: 12.5, duration_minutes: 30 }, { requireAll: true }),
    'invalid_price_cents',
  );
});

test('validateServicePayload rejects duration_minutes out of range', () => {
  throwsCode(
    () => validateServicePayload({ name: 'Corte', price_cents: 5000, duration_minutes: 1 }, { requireAll: true }),
    'invalid_duration_minutes',
  );
  throwsCode(
    () => validateServicePayload({ name: 'Corte', price_cents: 5000, duration_minutes: 1441 }, { requireAll: true }),
    'invalid_duration_minutes',
  );
});

test('validateServicePayload rejects unknown fields', () => {
  throwsCode(
    () =>
      validateServicePayload(
        { name: 'Corte', price_cents: 5000, duration_minutes: 30, stock_on_hand: 10 },
        { requireAll: true },
      ),
    'unknown_fields',
  );
});

test('validateServicePayload on update allows a partial patch', () => {
  const patch = validateServicePayload({ price_cents: 6000 }, { requireAll: false });
  assert.deepEqual(patch, { price_cents: 6000 });
});

test('validateServicePayload rejects an empty patch on update', () => {
  throwsCode(() => validateServicePayload({}, { requireAll: false }), 'empty_payload');
});
