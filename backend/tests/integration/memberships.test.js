import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, setUpOrgWithRole as setUpOrg, signUpTestUser } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

test('owner can list memberships and upsert a role for another user', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const initialList = await request(app)
    .get('/api/v1/memberships')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(initialList.status, 200);
  assert.equal(initialList.body.memberships.length, 1);
  assert.equal(initialList.body.memberships[0].role, 'owner');

  const newMember = await signUpTestUser(`membership-test-${randomUUID()}@test.local`, 'S3nhaForte!123');
  const set = await request(app)
    .put(`/api/v1/memberships/${newMember.userId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ role: 'reception' });
  assert.equal(set.status, 200);
  assert.equal(set.body.membership.role, 'reception');
  assert.equal(set.body.membership.active, true);

  const listAfter = await request(app)
    .get('/api/v1/memberships')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listAfter.body.memberships.length, 2);

  const upsertRole = await request(app)
    .put(`/api/v1/memberships/${newMember.userId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ role: 'manager' });
  assert.equal(upsertRole.status, 200);
  assert.equal(upsertRole.body.membership.role, 'manager');

  const listAfterUpsert = await request(app)
    .get('/api/v1/memberships')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listAfterUpsert.body.memberships.length, 2, 'upsert updates in place, no duplicate row');
});

test('any active member can list memberships, but only owner can upsert', async () => {
  const reception = await setUpOrgWithRole('reception');

  const listAsReception = await request(app)
    .get('/api/v1/memberships')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(listAsReception.status, 200);
  assert.equal(listAsReception.body.memberships.length, 2, 'owner + reception member');

  const target = await signUpTestUser(`membership-test-${randomUUID()}@test.local`, 'S3nhaForte!123');
  const setAsReception = await request(app)
    .put(`/api/v1/memberships/${target.userId}`)
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({ role: 'manager' });
  assert.equal(setAsReception.status, 403);
  assert.equal(setAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const setAsManager = await request(app)
    .put(`/api/v1/memberships/${target.userId}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ role: 'manager' });
  assert.equal(setAsManager.status, 403, 'membership_set requires owner, not just manager');
});

test('validation and RPC errors surface with the stable contract', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const invalidRole = await request(app)
    .put(`/api/v1/memberships/${randomUUID()}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ role: 'ceo' });
  assert.equal(invalidRole.status, 400);
  assert.equal(invalidRole.body.code, 'invalid_role');

  const nonexistentUser = await request(app)
    .put(`/api/v1/memberships/${randomUUID()}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ role: 'reception' });
  assert.equal(nonexistentUser.status, 400);
  assert.equal(nonexistentUser.body.code, 'reference_not_found');
});

test('an owner of one organization cannot manage memberships of another (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');

  const res = await request(app)
    .put(`/api/v1/memberships/${orgB.ownerUserId}`)
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId)
    .send({ role: 'admin' });
  assert.equal(res.status, 403);
  assert.equal(res.body.code, 'not_a_member', 'orgA owner has no membership in orgB at all');
});
