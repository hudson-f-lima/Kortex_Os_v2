import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateCheckoutPayload } from '../../src/modules/checkout/checkout.validation.js';
import { validateIdempotencyKey } from '../../src/shared/validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

const UUID = '11111111-1111-1111-1111-111111111111';
const VALID = {
  items: [{ kind: 'product', id: UUID, quantity: 2 }],
  payments: [{ method: 'cash', amount_cents: 1000 }],
};

test('validateIdempotencyKey rejects a missing or too-short header', () => {
  throwsCode(() => validateIdempotencyKey(undefined), 'missing_idempotency_key');
  throwsCode(() => validateIdempotencyKey('short'), 'missing_idempotency_key');
});

test('validateIdempotencyKey accepts an 8-200 char header', () => {
  assert.equal(validateIdempotencyKey('ck-0001-abc'), 'ck-0001-abc');
});

test('validateCheckoutPayload requires a non-empty items array', () => {
  throwsCode(() => validateCheckoutPayload({ payments: VALID.payments }), 'invalid_items');
  throwsCode(() => validateCheckoutPayload({ items: [], payments: VALID.payments }), 'invalid_items');
});

test('validateCheckoutPayload requires a non-empty payments array', () => {
  throwsCode(() => validateCheckoutPayload({ items: VALID.items }), 'invalid_payments');
  throwsCode(() => validateCheckoutPayload({ items: VALID.items, payments: [] }), 'invalid_payments');
});

test('validateCheckoutPayload accepts a well-formed payload and defaults client_id to null', () => {
  const result = validateCheckoutPayload(VALID);
  assert.equal(result.client_id, null);
  assert.deepEqual(result.items, VALID.items);
  assert.deepEqual(result.payments, VALID.payments);
});

test('validateCheckoutPayload rejects an item with an invalid kind', () => {
  throwsCode(
    () => validateCheckoutPayload({ items: [{ kind: 'bogus', id: UUID, quantity: 1 }], payments: VALID.payments }),
    'invalid_items',
  );
});

test('validateCheckoutPayload rejects a non-positive quantity', () => {
  throwsCode(
    () =>
      validateCheckoutPayload({
        items: [{ kind: 'product', id: UUID, quantity: 0 }],
        payments: VALID.payments,
      }),
    'invalid_items',
  );
});

test('validateCheckoutPayload rejects a payment with an invalid method', () => {
  throwsCode(
    () => validateCheckoutPayload({ items: VALID.items, payments: [{ method: 'bogus', amount_cents: 100 }] }),
    'invalid_payments',
  );
});

test('validateCheckoutPayload rejects a non-positive payment amount', () => {
  throwsCode(
    () => validateCheckoutPayload({ items: VALID.items, payments: [{ method: 'cash', amount_cents: 0 }] }),
    'invalid_payments',
  );
});

test('validateCheckoutPayload rejects an invalid client_id', () => {
  throwsCode(() => validateCheckoutPayload({ ...VALID, client_id: 'not-a-uuid' }), 'invalid_client_id');
});

test('validateCheckoutPayload accepts a null client_id', () => {
  const result = validateCheckoutPayload({ ...VALID, client_id: null });
  assert.equal(result.client_id, null);
});

test('validateCheckoutPayload rejects unknown top-level fields', () => {
  throwsCode(() => validateCheckoutPayload({ ...VALID, total_cents: 1000 }), 'unknown_fields');
});
