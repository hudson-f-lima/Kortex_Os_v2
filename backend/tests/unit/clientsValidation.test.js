import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateClientId, validateClientPayload } from '../../src/modules/clients/clients.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validateClientId accepts a well-formed uuid', () => {
  assert.equal(validateClientId('11111111-1111-1111-1111-111111111111'), '11111111-1111-1111-1111-111111111111');
});

test('validateClientId rejects a non-uuid string', () => {
  throwsCode(() => validateClientId('not-a-uuid'), 'invalid_id');
});

test('validateClientPayload requires name on create', () => {
  throwsCode(() => validateClientPayload({}, { requireName: true }), 'invalid_name');
});

test('validateClientPayload trims and accepts a valid name', () => {
  const patch = validateClientPayload({ name: '  Maria  ' }, { requireName: true });
  assert.equal(patch.name, 'Maria');
});

test('validateClientPayload rejects an empty name', () => {
  throwsCode(() => validateClientPayload({ name: '   ' }, { requireName: true }), 'invalid_name');
});

test('validateClientPayload rejects a name over 160 chars', () => {
  const longName = 'a'.repeat(161);
  throwsCode(() => validateClientPayload({ name: longName }, { requireName: true }), 'invalid_name');
});

test('validateClientPayload rejects unknown fields', () => {
  throwsCode(
    () => validateClientPayload({ name: 'Maria', organization_id: 'x' }, { requireName: true }),
    'unknown_fields',
  );
});

test('validateClientPayload rejects an invalid email', () => {
  throwsCode(() => validateClientPayload({ name: 'Maria', email: 'not-an-email' }), 'invalid_email');
});

test('validateClientPayload accepts a null email to clear it', () => {
  const patch = validateClientPayload({ email: null }, { requireName: false });
  assert.equal(patch.email, null);
});

test('validateClientPayload rejects a non-boolean active', () => {
  throwsCode(() => validateClientPayload({ active: 'yes' }, { requireName: false }), 'invalid_active');
});

test('validateClientPayload on update does not require name', () => {
  const patch = validateClientPayload({ phone: '11999999999' }, { requireName: false });
  assert.deepEqual(patch, { phone: '11999999999' });
});

test('validateClientPayload rejects an empty patch on update', () => {
  throwsCode(() => validateClientPayload({}, { requireName: false }), 'empty_payload');
});

test('validateClientPayload rejects a non-object payload', () => {
  throwsCode(() => validateClientPayload(null, { requireName: false }), 'invalid_payload');
  throwsCode(() => validateClientPayload([], { requireName: false }), 'invalid_payload');
});
