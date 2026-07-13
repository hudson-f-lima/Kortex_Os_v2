import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateInventoryAdjustmentPayload } from '../../src/modules/inventory/inventory.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

const UUID = '11111111-1111-1111-1111-111111111111';

test('validateInventoryAdjustmentPayload requires product_id, quantity_delta and reason', () => {
  throwsCode(() => validateInventoryAdjustmentPayload({}), 'invalid_product_id');
  throwsCode(() => validateInventoryAdjustmentPayload({ product_id: UUID }), 'invalid_quantity_delta');
  throwsCode(
    () => validateInventoryAdjustmentPayload({ product_id: UUID, quantity_delta: 5 }),
    'invalid_reason',
  );
});

test('validateInventoryAdjustmentPayload accepts a valid purchase payload', () => {
  const patch = validateInventoryAdjustmentPayload({ product_id: UUID, quantity_delta: 10, reason: 'purchase' });
  assert.deepEqual(patch, { product_id: UUID, quantity_delta: 10, reason: 'purchase' });
});

test('validateInventoryAdjustmentPayload accepts a negative delta for adjustment', () => {
  const patch = validateInventoryAdjustmentPayload({ product_id: UUID, quantity_delta: -3, reason: 'adjustment' });
  assert.equal(patch.quantity_delta, -3);
});

test('validateInventoryAdjustmentPayload rejects a zero delta', () => {
  throwsCode(
    () => validateInventoryAdjustmentPayload({ product_id: UUID, quantity_delta: 0, reason: 'adjustment' }),
    'invalid_quantity_delta',
  );
});

test('validateInventoryAdjustmentPayload rejects a non-integer delta', () => {
  throwsCode(
    () => validateInventoryAdjustmentPayload({ product_id: UUID, quantity_delta: 1.5, reason: 'purchase' }),
    'invalid_quantity_delta',
  );
});

test('validateInventoryAdjustmentPayload rejects an invalid reason', () => {
  throwsCode(
    () => validateInventoryAdjustmentPayload({ product_id: UUID, quantity_delta: 5, reason: 'bogus' }),
    'invalid_reason',
  );
});

test('validateInventoryAdjustmentPayload rejects unknown fields', () => {
  throwsCode(
    () =>
      validateInventoryAdjustmentPayload({
        product_id: UUID,
        quantity_delta: 5,
        reason: 'purchase',
        note: 'x',
      }),
    'unknown_fields',
  );
});
