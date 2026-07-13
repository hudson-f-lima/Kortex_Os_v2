import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateProfessionalId,
  validateProfessionalPayload,
} from '../../src/modules/professionals/professionals.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validateProfessionalId accepts a well-formed uuid', () => {
  const id = '11111111-1111-1111-1111-111111111111';
  assert.equal(validateProfessionalId(id), id);
});

test('validateProfessionalId rejects a non-uuid string', () => {
  throwsCode(() => validateProfessionalId('nope'), 'invalid_id');
});

test('validateProfessionalPayload requires name on create', () => {
  throwsCode(() => validateProfessionalPayload({}, { requireName: true }), 'invalid_name');
});

test('validateProfessionalPayload trims a valid name', () => {
  const patch = validateProfessionalPayload({ name: '  Joana  ' }, { requireName: true });
  assert.equal(patch.name, 'Joana');
});

test('validateProfessionalPayload rejects unknown fields', () => {
  throwsCode(
    () => validateProfessionalPayload({ name: 'Joana', organization_id: 'x' }, { requireName: true }),
    'unknown_fields',
  );
});

test('validateProfessionalPayload accepts a valid user_id uuid', () => {
  const patch = validateProfessionalPayload(
    { name: 'Joana', user_id: '11111111-1111-1111-1111-111111111111' },
    { requireName: true },
  );
  assert.equal(patch.user_id, '11111111-1111-1111-1111-111111111111');
});

test('validateProfessionalPayload accepts a null user_id to unlink', () => {
  const patch = validateProfessionalPayload({ user_id: null }, { requireName: false });
  assert.equal(patch.user_id, null);
});

test('validateProfessionalPayload rejects a malformed user_id', () => {
  throwsCode(() => validateProfessionalPayload({ user_id: 'not-a-uuid' }, { requireName: false }), 'invalid_user_id');
});

test('validateProfessionalPayload rejects a non-boolean active', () => {
  throwsCode(() => validateProfessionalPayload({ active: 1 }, { requireName: false }), 'invalid_active');
});

test('validateProfessionalPayload rejects an empty patch on update', () => {
  throwsCode(() => validateProfessionalPayload({}, { requireName: false }), 'empty_payload');
});
