import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateMembershipPayload } from '../../src/modules/memberships/memberships.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validateMembershipPayload requires a valid role', () => {
  throwsCode(() => validateMembershipPayload({}), 'invalid_role');
  throwsCode(() => validateMembershipPayload({ role: 'ceo' }), 'invalid_role');
});

test('validateMembershipPayload defaults active to true', () => {
  const patch = validateMembershipPayload({ role: 'manager' });
  assert.deepEqual(patch, { role: 'manager', active: true });
});

test('validateMembershipPayload accepts an explicit active value', () => {
  const patch = validateMembershipPayload({ role: 'reception', active: false });
  assert.deepEqual(patch, { role: 'reception', active: false });
});

test('validateMembershipPayload rejects a non-boolean active', () => {
  throwsCode(() => validateMembershipPayload({ role: 'manager', active: 'yes' }), 'invalid_active');
});

test('validateMembershipPayload rejects unknown fields', () => {
  throwsCode(() => validateMembershipPayload({ role: 'manager', user_id: 'x' }), 'unknown_fields');
});
