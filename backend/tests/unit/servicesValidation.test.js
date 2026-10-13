import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateServiceId, validateServicePayload } from '../../src/modules/services/services.validation.js';

const GROUP_ID = '22222222-2222-2222-2222-222222222222';

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

test('validateServicePayload requires name, price_cents, duration_minutes and service_group_id on create', () => {
  throwsCode(() => validateServicePayload({}, { requireAll: true }), 'invalid_name');
  throwsCode(() => validateServicePayload({ name: 'Corte' }, { requireAll: true }), 'invalid_price_cents');
  throwsCode(
    () => validateServicePayload({ name: 'Corte', price_cents: 5000 }, { requireAll: true }),
    'invalid_duration_minutes',
  );
  throwsCode(
    () => validateServicePayload({ name: 'Corte', price_cents: 5000, duration_minutes: 30 }, { requireAll: true }),
    'invalid_service_group_id',
  );
});

test('validateServicePayload accepts a valid create payload', () => {
  const patch = validateServicePayload(
    { name: '  Corte  ', price_cents: 5000, duration_minutes: 30, service_group_id: GROUP_ID },
    { requireAll: true },
  );
  assert.deepEqual(patch, { name: 'Corte', price_cents: 5000, duration_minutes: 30, service_group_id: GROUP_ID });
});

test('validateServicePayload rejects a negative price_cents', () => {
  throwsCode(
    () =>
      validateServicePayload(
        { name: 'Corte', price_cents: -1, duration_minutes: 30, service_group_id: GROUP_ID },
        { requireAll: true },
      ),
    'invalid_price_cents',
  );
});

test('validateServicePayload rejects a non-integer price_cents', () => {
  throwsCode(
    () =>
      validateServicePayload(
        { name: 'Corte', price_cents: 12.5, duration_minutes: 30, service_group_id: GROUP_ID },
        { requireAll: true },
      ),
    'invalid_price_cents',
  );
});

test('validateServicePayload rejects duration_minutes out of range', () => {
  throwsCode(
    () =>
      validateServicePayload(
        { name: 'Corte', price_cents: 5000, duration_minutes: 1, service_group_id: GROUP_ID },
        { requireAll: true },
      ),
    'invalid_duration_minutes',
  );
  throwsCode(
    () =>
      validateServicePayload(
        { name: 'Corte', price_cents: 5000, duration_minutes: 1441, service_group_id: GROUP_ID },
        { requireAll: true },
      ),
    'invalid_duration_minutes',
  );
});

test('validateServicePayload rejects a malformed service_group_id', () => {
  throwsCode(
    () =>
      validateServicePayload(
        { name: 'Corte', price_cents: 5000, duration_minutes: 30, service_group_id: 'nope' },
        { requireAll: true },
      ),
    'invalid_service_group_id',
  );
});

test('validateServicePayload rejects unknown fields', () => {
  throwsCode(
    () =>
      validateServicePayload(
        { name: 'Corte', price_cents: 5000, duration_minutes: 30, service_group_id: GROUP_ID, stock_on_hand: 10 },
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

test('validateServicePayload requires commission_type and commission_value together', () => {
  throwsCode(
    () => validateServicePayload({ commission_type: 'percentage' }, { requireAll: false }),
    'invalid_commission',
  );
  throwsCode(
    () => validateServicePayload({ commission_value: 1000 }, { requireAll: false }),
    'invalid_commission',
  );
});

test('validateServicePayload rejects a percentage commission above 10000 basis points', () => {
  throwsCode(
    () => validateServicePayload({ commission_type: 'percentage', commission_value: 10001 }, { requireAll: false }),
    'invalid_commission_value',
  );
});

test('validateServicePayload accepts an unbounded fixed commission override', () => {
  const patch = validateServicePayload(
    { commission_type: 'fixed', commission_value: 999999 },
    { requireAll: false },
  );
  assert.deepEqual(patch, { commission_type: 'fixed', commission_value: 999999 });
});

test('validateServicePayload accepts a valid deposit_mechanic on its own', () => {
  const patch = validateServicePayload({ deposit_mechanic: 'hold' }, { requireAll: false });
  assert.deepEqual(patch, { deposit_mechanic: 'hold' });
});

test('validateServicePayload rejects an invalid deposit_mechanic', () => {
  throwsCode(
    () => validateServicePayload({ deposit_mechanic: 'card' }, { requireAll: false }),
    'invalid_deposit_mechanic',
  );
});

test('validateServicePayload requires deposit_type and deposit_value together', () => {
  throwsCode(
    () => validateServicePayload({ deposit_type: 'percentage' }, { requireAll: false }),
    'invalid_deposit',
  );
  throwsCode(
    () => validateServicePayload({ deposit_value: 1000 }, { requireAll: false }),
    'invalid_deposit',
  );
});

test('validateServicePayload accepts a valid deposit_type/deposit_value pair', () => {
  const patch = validateServicePayload(
    { deposit_type: 'percentage', deposit_value: 5000 },
    { requireAll: false },
  );
  assert.deepEqual(patch, { deposit_type: 'percentage', deposit_value: 5000 });
});

test('validateServicePayload rejects a percentage deposit_value above 10000 basis points', () => {
  throwsCode(
    () => validateServicePayload({ deposit_type: 'percentage', deposit_value: 10001 }, { requireAll: false }),
    'invalid_deposit_value',
  );
});

test('validateServicePayload accepts an unbounded fixed deposit_value', () => {
  const patch = validateServicePayload(
    { deposit_type: 'fixed', deposit_value: 999999 },
    { requireAll: false },
  );
  assert.deepEqual(patch, { deposit_type: 'fixed', deposit_value: 999999 });
});

test('validateServicePayload rejects a negative deposit_value', () => {
  throwsCode(
    () => validateServicePayload({ deposit_type: 'fixed', deposit_value: -1 }, { requireAll: false }),
    'invalid_deposit_value',
  );
});

test('validateServicePayload requires no_show_commission_type and no_show_commission_value together', () => {
  throwsCode(
    () => validateServicePayload({ no_show_commission_type: 'percentage' }, { requireAll: false }),
    'invalid_no_show_commission',
  );
  throwsCode(
    () => validateServicePayload({ no_show_commission_value: 1000 }, { requireAll: false }),
    'invalid_no_show_commission',
  );
});

test('validateServicePayload accepts a valid no_show_commission pair independent of commission_type', () => {
  const patch = validateServicePayload(
    {
      commission_type: 'percentage',
      commission_value: 3000,
      no_show_commission_type: 'fixed',
      no_show_commission_value: 800,
    },
    { requireAll: false },
  );
  assert.deepEqual(patch, {
    commission_type: 'percentage',
    commission_value: 3000,
    no_show_commission_type: 'fixed',
    no_show_commission_value: 800,
  });
});

test('validateServicePayload rejects a percentage no_show_commission_value above 10000 basis points', () => {
  throwsCode(
    () =>
      validateServicePayload(
        { no_show_commission_type: 'percentage', no_show_commission_value: 10001 },
        { requireAll: false },
      ),
    'invalid_no_show_commission_value',
  );
});

test('validateServicePayload accepts explicit null to clear deposit_mechanic', () => {
  const patch = validateServicePayload({ deposit_mechanic: null }, { requireAll: false });
  assert.deepEqual(patch, { deposit_mechanic: null });
});

test('validateServicePayload accepts explicit null on both deposit_type and deposit_value to clear the pair', () => {
  const patch = validateServicePayload({ deposit_type: null, deposit_value: null }, { requireAll: false });
  assert.deepEqual(patch, { deposit_type: null, deposit_value: null });
});

test('validateServicePayload rejects a mismatched null when clearing deposit_type/deposit_value', () => {
  throwsCode(
    () => validateServicePayload({ deposit_type: null, deposit_value: 500 }, { requireAll: false }),
    'invalid_deposit',
  );
});

test('validateServicePayload accepts explicit null on both no_show_commission fields to clear the pair', () => {
  const patch = validateServicePayload(
    { no_show_commission_type: null, no_show_commission_value: null },
    { requireAll: false },
  );
  assert.deepEqual(patch, { no_show_commission_type: null, no_show_commission_value: null });
});
