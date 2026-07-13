import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createServiceGroup, localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

test('owner can create, list, update and delete a professional', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: '  Joana Souza  ' });
  assert.equal(created.status, 201);
  assert.equal(created.body.professional.name, 'Joana Souza');
  assert.equal(created.body.professional.active, true);
  assert.equal(created.body.professional.user_id, null);
  const professionalId = created.body.professional.id;

  const listed = await request(app)
    .get('/api/v1/professionals')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.professionals.length, 1);

  const updated = await request(app)
    .patch(`/api/v1/professionals/${professionalId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ active: false });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.professional.active, false);
  assert.equal(updated.body.professional.name, 'Joana Souza', 'unrelated fields are preserved');

  const deleted = await request(app)
    .delete(`/api/v1/professionals/${professionalId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(deleted.status, 204);

  const afterDelete = await request(app)
    .get(`/api/v1/professionals/${professionalId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterDelete.status, 404);
  assert.equal(afterDelete.body.code, 'professional_not_found');
});

test('any member can read professionals, but only owner/admin/manager can write and only owner/admin can delete', async () => {
  const reception = await setUpOrgWithRole('reception');

  const readAsReception = await request(app)
    .get('/api/v1/professionals')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(readAsReception.status, 200, 'professionals_select allows any active member, not just certain roles');

  const writeAsReception = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId)
    .send({ name: 'Should Not Be Created' });
  assert.equal(writeAsReception.status, 403);
  assert.equal(writeAsReception.body.code, 'insufficient_role');

  const manager = await setUpOrgWithRole('manager');
  const createdByManager = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId)
    .send({ name: 'Created By Manager' });
  assert.equal(createdByManager.status, 201, 'manager is allowed to create professionals');

  const deleteAsManager = await request(app)
    .delete(`/api/v1/professionals/${createdByManager.body.professional.id}`)
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsManager.status, 403, 'manager cannot delete, only owner/admin can');

  const deleteAsOwner = await request(app)
    .delete(`/api/v1/professionals/${createdByManager.body.professional.id}`)
    .set('Authorization', `Bearer ${manager.ownerAccessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(deleteAsOwner.status, 204);
});

test('user_id must reference an existing membership and stays unique per professional', async () => {
  const professionalMember = await setUpOrgWithRole('professional');

  const linked = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${professionalMember.ownerAccessToken}`)
    .set('X-Organization-Id', professionalMember.organizationId)
    .send({ name: 'Linked Professional', user_id: professionalMember.userId });
  assert.equal(linked.status, 201);
  assert.equal(linked.body.professional.user_id, professionalMember.userId);

  const invalidUserId = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${professionalMember.ownerAccessToken}`)
    .set('X-Organization-Id', professionalMember.organizationId)
    .send({ name: 'Ghost Professional', user_id: randomUUID() });
  assert.equal(invalidUserId.status, 400);
  assert.equal(invalidUserId.body.code, 'invalid_user_id');

  const duplicateLink = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${professionalMember.ownerAccessToken}`)
    .set('X-Organization-Id', professionalMember.organizationId)
    .send({ name: 'Duplicate Link', user_id: professionalMember.userId });
  assert.equal(duplicateLink.status, 409);
  assert.equal(duplicateLink.body.code, 'already_exists');
});

test('a professional from another organization is invisible and cannot be mutated (cross-tenant)', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');

  const created = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId)
    .send({ name: 'Professional Org A' });
  const professionalId = created.body.professional.id;

  const getFromOrgB = await request(app)
    .get(`/api/v1/professionals/${professionalId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(getFromOrgB.status, 404);

  const deleteFromOrgB = await request(app)
    .delete(`/api/v1/professionals/${professionalId}`)
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(deleteFromOrgB.status, 404);

  const stillThere = await request(app)
    .get(`/api/v1/professionals/${professionalId}`)
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId);
  assert.equal(stillThere.status, 200);
});

test('deleting a professional referenced by an appointment returns 409 instead of a raw DB error', async () => {
  const { organizationId, accessToken, ownerUserId } = await setUpOrgWithRole('owner');

  const createdProfessional = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Professional Com Agendamento' });
  const professionalId = createdProfessional.body.professional.id;

  const { data: client, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({ organization_id: organizationId, name: 'Cliente Teste', created_by: ownerUserId })
    .select('id')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const serviceGroupId = await createServiceGroup(supabaseAdmin, organizationId);
  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: organizationId,
      name: 'Corte',
      price_cents: 5000,
      duration_minutes: 30,
      service_group_id: serviceGroupId,
    })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);

  const { error: appointmentError } = await supabaseAdmin.from('appointments').insert({
    organization_id: organizationId,
    client_id: client.id,
    professional_id: professionalId,
    service_id: service.id,
    starts_at: '2026-09-02T10:00:00Z',
    ends_at: '2026-09-02T10:30:00Z',
    created_by: ownerUserId,
  });
  assert.equal(appointmentError, null, appointmentError?.message);

  const del = await request(app)
    .delete(`/api/v1/professionals/${professionalId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(del.status, 409);
  assert.equal(del.body.code, 'referenced_by_other_records');
});
