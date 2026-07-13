import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateProductId, validateProductPayload } from '../../src/modules/products/products.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validateProductId accepts a well-formed uuid', () => {
  const id = '11111111-1111-1111-1111-111111111111';
  assert.equal(validateProductId(id), id);
});

test('validateProductId rejects a non-uuid string', () => {
  throwsCode(() => validateProductId('nope'), 'invalid_id');
});

test('validateProductPayload requires sku, name and price_cents on create', () => {
  throwsCode(() => validateProductPayload({}, { requireAll: true }), 'invalid_sku');
  throwsCode(() => validateProductPayload({ sku: 'SKU-1' }, { requireAll: true }), 'invalid_name');
  throwsCode(
    () => validateProductPayload({ sku: 'SKU-1', name: 'Shampoo' }, { requireAll: true }),
    'invalid_price_cents',
  );
});

test('validateProductPayload accepts a valid create payload with default cost_cents omitted', () => {
  const patch = validateProductPayload(
    { sku: '  SKU-1  ', name: '  Shampoo  ', price_cents: 2500 },
    { requireAll: true },
  );
  assert.deepEqual(patch, { sku: 'SKU-1', name: 'Shampoo', price_cents: 2500 });
});

test('validateProductPayload accepts an explicit cost_cents', () => {
  const patch = validateProductPayload(
    { sku: 'SKU-1', name: 'Shampoo', price_cents: 2500, cost_cents: 1200 },
    { requireAll: true },
  );
  assert.equal(patch.cost_cents, 1200);
});

test('validateProductPayload rejects stock_on_hand as an unknown field', () => {
  throwsCode(
    () =>
      validateProductPayload(
        { sku: 'SKU-1', name: 'Shampoo', price_cents: 2500, stock_on_hand: 999 },
        { requireAll: true },
      ),
    'unknown_fields',
  );
});

test('validateProductPayload rejects a negative cost_cents', () => {
  throwsCode(
    () =>
      validateProductPayload(
        { sku: 'SKU-1', name: 'Shampoo', price_cents: 2500, cost_cents: -1 },
        { requireAll: true },
      ),
    'invalid_cost_cents',
  );
});

test('validateProductPayload on update allows a partial patch', () => {
  const patch = validateProductPayload({ price_cents: 3000 }, { requireAll: false });
  assert.deepEqual(patch, { price_cents: 3000 });
});

test('validateProductPayload rejects an empty patch on update', () => {
  throwsCode(() => validateProductPayload({}, { requireAll: false }), 'empty_payload');
});
