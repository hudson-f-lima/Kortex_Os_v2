import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { localTestEnv } from '../helpers/localSupabase.js';

test('unknown routes return the stable error contract with no stack/SQL/secret leakage', async () => {
  const env = localTestEnv();
  const app = createApp(env, {});
  const res = await request(app).get('/this-route-does-not-exist');

  assert.equal(res.status, 404);
  assert.deepEqual(Object.keys(res.body).sort(), ['code', 'message', 'request_id']);
  assert.equal(res.body.code, 'not_found');
  assert.doesNotMatch(JSON.stringify(res.body), /at \S+:\d+:\d+/, 'no stack trace frames leaked');
});
