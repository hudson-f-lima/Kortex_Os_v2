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

async function setUpOrgWithRole(role) {
  const email = `clients-test-${randomUUID()}@test.local`;
  const owner = await signUpTestUser(email, 'S3nhaForte!123');
  const { data: org, error } = await supabaseAdmin.rpc('create_organization', {
    p_actor_user_id: owner.userId,
    p_name: 'Clients Test Org',
    p_slug: `clients-test-org-${randomUUID()}`,
  });
  assert.equal(error, null, `create_organization failed: ${error?.message}`);

  if (role === 'owner') {
    return { organizationId: org.id, accessToken: owner.accessToken, userId: owner.userId };
  }

  const memberEmail = `clients-test-member-${randomUUID()}@test.local`;
  const member = await signUpTestUser(memberEmail, 'S3nhaForte!123');
  const { error: memberError } = await supabaseAdmin.rpc('membership_set', {
    p_organization_id: org.id,
    p_actor_user_id: owner.userId,
    p_target_user_id: member.userId,
    p_role: role,
  });
  assert.equal(memberError, null, `membership_set failed: ${memberError?.message}`);
  return { organizationId: org.id, accessToken: member.accessToken, userId: member.userId };
}

test('owner can create, list, update and delete a client', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: '  Maria Silva  ', email: 'maria@example.com' });
  assert.equal(created.status, 201);
  assert.equal(created.body.client.name, 'Maria Silva');
  assert.equal(created.body.client.active, true);
  const clientId = created.body.client.id;

  const listed = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.clients.length, 1);
  assert.equal(listed.body.clients[0].id, clientId);

  const updated = await request(app)
    .patch(`/api/v1/clients/${clientId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ phone: '11988887777' });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.client.phone, '11988887777');
  assert.equal(updated.body.client.name, 'Maria Silva', 'unrelated fields are preserved');

  const deleted = await request(app)
    .delete(`/api/v1/clients/${clientId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/clients/${clientId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'client_not_found');
});

test('professional role can neither read nor write clients', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('professional');

  const list = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(list.status, 403);
  assert.equal(list.body.code, 'insufficient_role');

  const create = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Should Not Exist' });
  assert.equal(create.status, 403);
});

test('reception can create/update clients but cannot delete', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('reception');

  const created = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Cliente Recepcao' });
  assert.equal(created.status, 201);

  const del = await request(app)
    .delete(`/api/v1/clients/${created.body.client.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(del.status, 403);
  assert.equal(del.body.code, 'insufficient_role');
});

test('validation errors return a 400 with the stable error contract', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const missingName = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({});
  assert.equal(missingName.status, 400);
  assert.equal(missingName.body.code, 'invalid_name');

  const unknownField = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Valid Name', organization_id: 'hijack' });
  assert.equal(unknownField.status, 400);
  assert.equal(unknownField.body.code, 'unknown_fields');
  assert.deepEqual(unknownField.body.details.fields, ['organization_id']);
});

test('a client from another organization is invisible and cannot be mutated (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ name: 'Cliente Org A' });
  assert.equal(created.status, 201);
  const clientId = created.body.client.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/clients/${clientId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404, 'org B must not see org A client, even by direct id');

  const deleteFromOrgB = await request(app)
    .delete(`/api/v1/clients/${clientId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(deleteFromOrgB.status, 404);

  const stillThere = await request(app)
    .get(`/api/v1/clients/${clientId}`)
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId);
  assert.equal(stillThere.status, 200, 'org A client survives the cross-tenant delete attempt');
});

test('deleting a client referenced by an appointment returns 409 instead of a raw DB error', async () => {
  const { organizationId, accessToken, userId } = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Cliente Com Agendamento' });
  const clientId = created.body.client.id;

  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({ organization_id: organizationId, name: 'Corte', price_cents: 5000, duration_minutes: 30 })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);

  const { data: professional, error: professionalError } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: organizationId, name: 'Prof Teste' })
    .select('id')
    .single();
  assert.equal(professionalError, null, professionalError?.message);

  const { error: appointmentError } = await supabaseAdmin.from('appointments').insert({
    organization_id: organizationId,
    client_id: clientId,
    professional_id: professional.id,
    service_id: service.id,
    starts_at: '2026-09-01T10:00:00Z',
    ends_at: '2026-09-01T10:30:00Z',
    created_by: userId,
  });
  assert.equal(appointmentError, null, appointmentError?.message);

  const del = await request(app)
    .delete(`/api/v1/clients/${clientId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(del.status, 409);
  assert.equal(del.body.code, 'referenced_by_other_records');
});
