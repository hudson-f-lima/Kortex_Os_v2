import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requireFeatureFlag } from '../../src/middleware/requireFeatureFlag.js';

test('requireFeatureFlag allows request when feature flag is true in organization settings', () => {
  const middleware = requireFeatureFlag('enable_sale_commission');
  const req = {
    organizationContext: {
      organization: {
        settings: { enable_sale_commission: true },
      },
    },
  };
  let calledNext = false;
  let errorPassed = null;

  middleware(req, {}, (err) => {
    calledNext = true;
    errorPassed = err;
  });

  assert.equal(calledNext, true);
  assert.equal(errorPassed, undefined);
});

test('requireFeatureFlag blocks request with 403 when feature flag is false or missing', () => {
  const middleware = requireFeatureFlag('enable_sale_commission');
  const req = {
    organizationContext: {
      organization: {
        settings: { enable_sale_commission: false },
      },
    },
  };
  let errorPassed = null;

  middleware(req, {}, (err) => {
    errorPassed = err;
  });

  assert.notEqual(errorPassed, null);
  assert.equal(errorPassed.status, 403);
  assert.equal(errorPassed.code, 'feature_disabled');
});
