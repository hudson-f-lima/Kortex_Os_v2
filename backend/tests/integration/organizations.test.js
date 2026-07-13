import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, signUpTestUser } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

test('GET /api/v1/organizations without Authorization is rejected', async () => {
  const res = await request(app).get('/api/v1/organizations');
  assert.equal(res.status, 401);
  assert.equal(res.body.code, 'missing_bearer_token');
  assert.ok(res.body.request_id, 'error contract includes request_id');
});

test('GET /api/v1/organizations with a malformed token is rejected', async () => {
  const res = await request(app).get('/api/v1/organizations').set('Authorization', 'Bearer not-a-real-jwt');
  assert.equal(res.status, 401);
  assert.equal(res.body.code, 'invalid_token');
});

test('a valid Supabase session lists only the caller organizations, and X-Organization-Id alone grants nothing', async () => {
  const email = `backend-test-${randomUUID()}@test.local`;
  const { accessToken, userId } = await signUpTestUser(email, 'S3nhaForte!123');

  const emptyList = await request(app).get('/api/v1/organizations').set('Authorization', `Bearer ${accessToken}`);
  assert.equal(emptyList.status, 200);
  assert.deepEqual(emptyList.body.organizations, []);

  const { data: org, error } = await supabaseAdmin.rpc('create_organization', {
    p_actor_user_id: userId,
    p_name: 'Backend Test Org',
    p_slug: `backend-test-org-${randomUUID()}`,
  });
  assert.equal(error, null, `create_organization RPC failed: ${error?.message}`);

  const listWithOrg = await request(app).get('/api/v1/organizations').set('Authorization', `Bearer ${accessToken}`);
  assert.equal(listWithOrg.status, 200);
  assert.equal(listWithOrg.body.organizations.length, 1);
  assert.equal(listWithOrg.body.organizations[0].id, org.id);
  assert.equal(listWithOrg.body.organizations[0].role, 'owner');

  const missingHeader = await request(app)
    .get('/api/v1/organizations/current')
    .set('Authorization', `Bearer ${accessToken}`);
  assert.equal(missingHeader.status, 400);
  assert.equal(missingHeader.body.code, 'missing_organization_id');

  const wrongOrg = await request(app)
    .get('/api/v1/organizations/current')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', randomUUID());
  assert.equal(wrongOrg.status, 403, 'a random organization id in the header must not grant access');
  assert.equal(wrongOrg.body.code, 'not_a_member');

  const correctOrg = await request(app)
    .get('/api/v1/organizations/current')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', org.id);
  assert.equal(correctOrg.status, 200);
  assert.equal(correctOrg.body.organization_id, org.id);
  assert.equal(correctOrg.body.role, 'owner');
});
