import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpError } from '../../src/shared/httpError.js';

test('HttpError.unauthorized builds a 401 with the given code and message', () => {
  const err = HttpError.unauthorized('missing_bearer_token', 'Authorization required');
  assert.equal(err.status, 401);
  assert.equal(err.code, 'missing_bearer_token');
  assert.equal(err.message, 'Authorization required');
});

test('HttpError.forbidden builds a 403', () => {
  const err = HttpError.forbidden('not_a_member', 'no membership');
  assert.equal(err.status, 403);
});

test('HttpError carries optional details without leaking by default', () => {
  const withDetails = HttpError.badRequest('invalid_payload', 'bad payload', { field: 'quantity' });
  assert.deepEqual(withDetails.details, { field: 'quantity' });

  const withoutDetails = HttpError.badRequest('invalid_payload', 'bad payload');
  assert.equal(withoutDetails.details, undefined);
});
