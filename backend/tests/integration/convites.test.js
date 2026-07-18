import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, setUpOrgWithRole as setUpOrg, createProfessional } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

test('owner can invite a new team member and it lands as an active membership', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const email = `invite-${randomUUID()}@test.local`;

  const res = await request(app)
    .post('/api/v1/convites')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ email, role: 'reception' });

  assert.equal(res.status, 201);
  assert.equal(res.body.invite.email, email);
  assert.equal(res.body.invite.role, 'reception');
  assert.ok(res.body.invite.userId);
  assert.equal(res.body.invite.professional, null);

  const memberships = await request(app)
    .get('/api/v1/memberships')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  const invited = memberships.body.memberships.find((m) => m.user_id === res.body.invite.userId);
  assert.ok(invited, 'invited user has an active membership');
  assert.equal(invited.role, 'reception');
  assert.equal(invited.active, true);
});

test('inviting with role professional and a professionalName creates and links a new professional row', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const email = `invite-pro-${randomUUID()}@test.local`;

  const res = await request(app)
    .post('/api/v1/convites')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ email, role: 'professional', professionalName: 'Ana Convidada' });

  assert.equal(res.status, 201);
  assert.equal(res.body.invite.professional.name, 'Ana Convidada');
  assert.equal(res.body.invite.professional.user_id, res.body.invite.userId);
});

test('inviting with role professional and an existing unclaimed professionalId links it', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const professionalId = await createProfessional(supabaseAdmin, organizationId, { name: 'Pré-cadastrada' });
  const email = `invite-link-${randomUUID()}@test.local`;

  const res = await request(app)
    .post('/api/v1/convites')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ email, role: 'professional', professionalId });

  assert.equal(res.status, 201);
  assert.equal(res.body.invite.professional.id, professionalId);
  assert.equal(res.body.invite.professional.user_id, res.body.invite.userId);
});

test('inviting to link an already-claimed professional is rejected', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');
  const firstEmail = `invite-claim1-${randomUUID()}@test.local`;
  const professionalId = await createProfessional(supabaseAdmin, organizationId, { name: 'Já vinculada' });

  const first = await request(app)
    .post('/api/v1/convites')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ email: firstEmail, role: 'professional', professionalId });
  assert.equal(first.status, 201);

  const second = await request(app)
    .post('/api/v1/convites')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ email: `invite-claim2-${randomUUID()}@test.local`, role: 'professional', professionalId });
  assert.equal(second.status, 409);
  assert.equal(second.body.code, 'professional_already_linked');
});

test('only owner can send invites', async () => {
  const manager = await setUpOrgWithRole('manager');

  const res = await request(app)
    .post('/api/v1/convites')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ email: `invite-${randomUUID()}@test.local`, role: 'reception' });
  assert.equal(res.status, 403);
  assert.equal(res.body.code, 'insufficient_role');
});

test('validation rejects inviting an owner role and mismatched professional fields', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const ownerInvite = await request(app)
    .post('/api/v1/convites')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ email: `invite-${randomUUID()}@test.local`, role: 'owner' });
  assert.equal(ownerInvite.status, 400);
  assert.equal(ownerInvite.body.code, 'invalid_role');

  const nameOnNonProfessional = await request(app)
    .post('/api/v1/convites')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ email: `invite-${randomUUID()}@test.local`, role: 'reception', professionalName: 'X' });
  assert.equal(nameOnNonProfessional.status, 400);
  assert.equal(nameOnNonProfessional.body.code, 'professional_fields_require_role');
});
