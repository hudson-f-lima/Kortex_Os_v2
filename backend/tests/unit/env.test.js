import { test } from 'node:test';
import assert from 'node:assert/strict';
import { loadEnv } from '../../src/config/env.js';

const BASE = {
  SUPABASE_URL: 'http://127.0.0.1:54321',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
  SUPABASE_JWKS_URL: 'http://127.0.0.1:54321/auth/v1/.well-known/jwks.json',
  CORS_ORIGINS: 'http://localhost:5173,https://hudson-f-lima.github.io',
  PORT: '3000',
};

test('loadEnv returns parsed config when all required vars are present', () => {
  const env = loadEnv(BASE);
  assert.equal(env.port, 3000);
  assert.deepEqual(env.corsOrigins, ['http://localhost:5173', 'https://hudson-f-lima.github.io']);
});

test('loadEnv fails closed when a required var is missing', () => {
  const { SUPABASE_JWKS_URL, ...withoutJwks } = BASE;
  assert.throws(() => loadEnv(withoutJwks), /SUPABASE_JWKS_URL/);
});

test('loadEnv fails closed on a non-numeric PORT', () => {
  assert.throws(() => loadEnv({ ...BASE, PORT: 'not-a-number' }), /PORT/);
});

test('loadEnv fails closed on empty CORS_ORIGINS', () => {
  assert.throws(() => loadEnv({ ...BASE, CORS_ORIGINS: '' }), /CORS_ORIGINS/);
});
