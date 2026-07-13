import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateOrganizationPayload } from '../../src/modules/organizations/organizations.validation.js';

function throwsCode(fn, code) {
  assert.throws(fn, (err) => err.code === code);
}

test('validateOrganizationPayload requires name and slug', () => {
  throwsCode(() => validateOrganizationPayload({}), 'invalid_name');
  throwsCode(() => validateOrganizationPayload({ name: 'Studio Bela' }), 'invalid_slug');
});

test('validateOrganizationPayload accepts a valid payload and normalizes slug case', () => {
  const patch = validateOrganizationPayload({ name: '  Studio Bela  ', slug: 'Studio-Bela' });
  assert.equal(patch.name, 'Studio Bela');
  assert.equal(patch.slug, 'studio-bela');
});

test('validateOrganizationPayload rejects a name shorter than 2 chars', () => {
  throwsCode(() => validateOrganizationPayload({ name: 'A', slug: 'a-org' }), 'invalid_name');
});

test('validateOrganizationPayload rejects a slug with invalid characters', () => {
  throwsCode(() => validateOrganizationPayload({ name: 'Studio Bela', slug: 'studio_bela!' }), 'invalid_slug');
  throwsCode(() => validateOrganizationPayload({ name: 'Studio Bela', slug: '-studio-bela' }), 'invalid_slug');
  throwsCode(() => validateOrganizationPayload({ name: 'Studio Bela', slug: 'studio--bela' }), 'invalid_slug');
});

test('validateOrganizationPayload rejects unknown fields', () => {
  throwsCode(
    () => validateOrganizationPayload({ name: 'Studio Bela', slug: 'studio-bela', owner_id: 'x' }),
    'unknown_fields',
  );
});
