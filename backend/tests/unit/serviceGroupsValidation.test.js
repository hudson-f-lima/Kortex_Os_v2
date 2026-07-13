import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateServiceGroupId,
  validateServiceGroupPayload,
} from '../../src/modules/serviceGroups/serviceGroups.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validateServiceGroupId accepts a well-formed uuid', () => {
  const id = '11111111-1111-1111-1111-111111111111';
  assert.equal(validateServiceGroupId(id), id);
});

test('validateServiceGroupId rejects a non-uuid string', () => {
  throwsCode(() => validateServiceGroupId('nope'), 'invalid_id');
});

test('validateServiceGroupPayload requires name, default_commission_type and default_commission_value on create', () => {
  throwsCode(() => validateServiceGroupPayload({}, { requireAll: true }), 'invalid_name');
  throwsCode(
    () => validateServiceGroupPayload({ name: 'Cabelo' }, { requireAll: true }),
    'invalid_default_commission_type',
  );
});

test('validateServiceGroupPayload accepts a valid percentage create payload', () => {
  const patch = validateServiceGroupPayload(
    { name: '  Cabelo  ', default_commission_type: 'percentage', default_commission_value: 4500 },
    { requireAll: true },
  );
  assert.deepEqual(patch, { name: 'Cabelo', default_commission_type: 'percentage', default_commission_value: 4500 });
});

test('validateServiceGroupPayload rejects a percentage default above 10000 basis points', () => {
  throwsCode(
    () =>
      validateServiceGroupPayload(
        { name: 'Cabelo', default_commission_type: 'percentage', default_commission_value: 10001 },
        { requireAll: true },
      ),
    'invalid_default_commission_value',
  );
});

test('validateServiceGroupPayload accepts an unbounded fixed default', () => {
  const patch = validateServiceGroupPayload(
    { name: 'Produtos', default_commission_type: 'fixed', default_commission_value: 999999 },
    { requireAll: true },
  );
  assert.deepEqual(patch, { name: 'Produtos', default_commission_type: 'fixed', default_commission_value: 999999 });
});

test('validateServiceGroupPayload rejects an unknown commission type', () => {
  throwsCode(
    () =>
      validateServiceGroupPayload(
        { name: 'Cabelo', default_commission_type: 'flat_rate', default_commission_value: 100 },
        { requireAll: true },
      ),
    'invalid_default_commission_type',
  );
});

test('validateServiceGroupPayload on update requires type and value together', () => {
  throwsCode(
    () => validateServiceGroupPayload({ default_commission_type: 'percentage' }, { requireAll: false }),
    'invalid_default_commission',
  );
});

test('validateServiceGroupPayload on update allows a partial patch', () => {
  const patch = validateServiceGroupPayload({ active: false }, { requireAll: false });
  assert.deepEqual(patch, { active: false });
});

test('validateServiceGroupPayload rejects an empty patch on update', () => {
  throwsCode(() => validateServiceGroupPayload({}, { requireAll: false }), 'empty_payload');
});

test('validateServiceGroupPayload rejects unknown fields', () => {
  throwsCode(
    () =>
      validateServiceGroupPayload(
        { name: 'Cabelo', default_commission_type: 'percentage', default_commission_value: 100, extra: 1 },
        { requireAll: true },
      ),
    'unknown_fields',
  );
});
