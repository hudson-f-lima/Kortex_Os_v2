import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRateLimiter } from '../../src/middleware/rateLimiter.js';

test('createRateLimiter allows requests up to maxRequests limit', () => {
  const limiter = createRateLimiter({ maxRequests: 2, windowMs: 60000 });
  const req = { auth: { userId: 'user-1' }, ip: '127.0.0.1' };
  let errorPassed = null;

  limiter(req, {}, (err) => { errorPassed = err; });
  assert.equal(errorPassed, undefined);

  limiter(req, {}, (err) => { errorPassed = err; });
  assert.equal(errorPassed, undefined);
});

test('createRateLimiter rejects requests exceeding maxRequests limit with 429', () => {
  const limiter = createRateLimiter({ maxRequests: 1, windowMs: 60000 });
  const req = { auth: { userId: 'user-rate-test' }, ip: '127.0.0.1' };

  limiter(req, {}, () => {});
  let errorPassed = null;
  limiter(req, {}, (err) => { errorPassed = err; });

  assert.notEqual(errorPassed, null);
  assert.equal(errorPassed.status, 429);
  assert.equal(errorPassed.code, 'rate_limit_exceeded');
});
