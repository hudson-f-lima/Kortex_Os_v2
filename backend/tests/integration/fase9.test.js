import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpError } from '../../src/shared/httpError.js';
import { validateCheckoutPayload } from '../../src/modules/checkout/checkout.validation.js';

test('checkout validation — discount_cents and tip_cents', async () => {
  // T1: Basic validation passes
  const validPayload = {
    client_id: '550e8400-e29b-41d4-a716-446655440000',
    items: [{ kind: 'product', id: '550e8400-e29b-41d4-a716-446655440001', quantity: 1 }],
    payments: [{ method: 'cash', amount_cents: 1000 }],
    discount_cents: 100,
    tip_cents: 50,
  };
  const result = validateCheckoutPayload(validPayload);
  assert.deepEqual(result.discount_cents, 100);
  assert.deepEqual(result.tip_cents, 50);
});

test('checkout validation — defaults discount/tip to 0', async () => {
  const payload = {
    items: [{ kind: 'product', id: '550e8400-e29b-41d4-a716-446655440001', quantity: 1 }],
    payments: [{ method: 'cash', amount_cents: 1000 }],
  };
  const result = validateCheckoutPayload(payload);
  assert.deepEqual(result.discount_cents, 0);
  assert.deepEqual(result.tip_cents, 0);
});

test('checkout validation — discount must be non-negative', async () => {
  const payload = {
    items: [{ kind: 'product', id: '550e8400-e29b-41d4-a716-446655440001', quantity: 1 }],
    payments: [{ method: 'cash', amount_cents: 1000 }],
    discount_cents: -100,
  };
  assert.throws(() => validateCheckoutPayload(payload), (err) => {
    return err.code === 'invalid_discount_cents';
  });
});

test('checkout validation — tip must be non-negative', async () => {
  const payload = {
    items: [{ kind: 'product', id: '550e8400-e29b-41d4-a716-446655440001', quantity: 1 }],
    payments: [{ method: 'cash', amount_cents: 1000 }],
    tip_cents: -50,
  };
  assert.throws(() => validateCheckoutPayload(payload), (err) => {
    return err.code === 'invalid_tip_cents';
  });
});

test('checkout validation — discount must be integer', async () => {
  const payload = {
    items: [{ kind: 'product', id: '550e8400-e29b-41d4-a716-446655440001', quantity: 1 }],
    payments: [{ method: 'cash', amount_cents: 1000 }],
    discount_cents: 10.5,
  };
  assert.throws(() => validateCheckoutPayload(payload), (err) => {
    return err.code === 'invalid_discount_cents';
  });
});

test('checkout validation — unknown fields rejected', async () => {
  const payload = {
    items: [{ kind: 'product', id: '550e8400-e29b-41d4-a716-446655440001', quantity: 1 }],
    payments: [{ method: 'cash', amount_cents: 1000 }],
    discount_cents: 100,
    unknown_field: 'should_fail',
  };
  assert.throws(() => validateCheckoutPayload(payload), (err) => {
    return err.code === 'unknown_fields';
  });
});

test('checkout validation — allowed fields: client_id, items, payments, discount_cents, tip_cents', async () => {
  const payload = {
    client_id: null,
    items: [{ kind: 'product', id: '550e8400-e29b-41d4-a716-446655440001', quantity: 1 }],
    payments: [{ method: 'cash', amount_cents: 1000 }],
    discount_cents: 100,
    tip_cents: 50,
  };
  const result = validateCheckoutPayload(payload);
  assert.ok(result);
  assert.deepEqual(Object.keys(result).sort(), ['client_id', 'discount_cents', 'items', 'payments', 'tip_cents']);
});
