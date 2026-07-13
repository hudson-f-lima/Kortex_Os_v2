import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateCreatePackagePayload,
  validatePackageId,
  validateUpdatePackagePayload,
} from '../../src/modules/packages/packages.validation.js';

const SERVICE_ID = '11111111-1111-1111-1111-111111111111';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validatePackageId accepts a well-formed uuid', () => {
  const id = '22222222-2222-2222-2222-222222222222';
  assert.equal(validatePackageId(id), id);
});

test('validatePackageId rejects a non-uuid string', () => {
  throwsCode(() => validatePackageId('nope'), 'invalid_id');
});

test('validateCreatePackagePayload requires name, price_cents and a non-empty items array', () => {
  throwsCode(() => validateCreatePackagePayload({}), 'invalid_name');
  throwsCode(() => validateCreatePackagePayload({ name: 'Dia da Noiva' }), 'invalid_price_cents');
  throwsCode(
    () => validateCreatePackagePayload({ name: 'Dia da Noiva', price_cents: 12000 }),
    'invalid_items',
  );
  throwsCode(
    () => validateCreatePackagePayload({ name: 'Dia da Noiva', price_cents: 12000, items: [] }),
    'invalid_items',
  );
});

test('validateCreatePackagePayload accepts a valid payload and defaults quantity to 1', () => {
  const payload = validateCreatePackagePayload({
    name: 'Dia da Noiva',
    price_cents: 12000,
    items: [{ service_id: SERVICE_ID }],
  });
  assert.deepEqual(payload, {
    name: 'Dia da Noiva',
    price_cents: 12000,
    items: [{ service_id: SERVICE_ID, quantity: 1 }],
  });
});

test('validateCreatePackagePayload rejects an item with a malformed service_id', () => {
  throwsCode(
    () =>
      validateCreatePackagePayload({
        name: 'Dia da Noiva',
        price_cents: 12000,
        items: [{ service_id: 'nope' }],
      }),
    'invalid_items',
  );
});

test('validateCreatePackagePayload rejects a non-positive item quantity', () => {
  throwsCode(
    () =>
      validateCreatePackagePayload({
        name: 'Dia da Noiva',
        price_cents: 12000,
        items: [{ service_id: SERVICE_ID, quantity: 0 }],
      }),
    'invalid_items',
  );
});

test('validateCreatePackagePayload rejects unknown fields', () => {
  throwsCode(
    () =>
      validateCreatePackagePayload({
        name: 'Dia da Noiva',
        price_cents: 12000,
        items: [{ service_id: SERVICE_ID }],
        active: true,
      }),
    'unknown_fields',
  );
});

test('validateUpdatePackagePayload allows a partial patch', () => {
  const patch = validateUpdatePackagePayload({ name: 'Novo Nome' });
  assert.deepEqual(patch, { name: 'Novo Nome' });
});

test('validateUpdatePackagePayload rejects an empty patch', () => {
  throwsCode(() => validateUpdatePackagePayload({}), 'empty_payload');
});

test('validateUpdatePackagePayload validates items when present', () => {
  throwsCode(() => validateUpdatePackagePayload({ items: [] }), 'invalid_items');
  const patch = validateUpdatePackagePayload({ items: [{ service_id: SERVICE_ID, quantity: 2 }] });
  assert.deepEqual(patch, { items: [{ service_id: SERVICE_ID, quantity: 2 }] });
});
