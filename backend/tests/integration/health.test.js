import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { localTestEnv } from '../helpers/localSupabase.js';

test('GET /health returns 200 with no auth required', async () => {
  const env = localTestEnv();
  const app = createApp(env, {});
  const res = await request(app).get('/health');
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { status: 'ok' });
});
