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
  const { organizationId, accessToken, userId } = await setUpOrgWithRole('owner');

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
  const { data: unitLinksBeforeDelete, error: unitLinksBeforeDeleteError } = await supabaseAdmin
    .from('professional_units')
    .select('professional_id')
    .eq('organization_id', organizationId)
    .eq('professional_id', professionalId);
  assert.equal(unitLinksBeforeDeleteError, null, unitLinksBeforeDeleteError?.message);
  assert.equal(unitLinksBeforeDelete.length, 1, 'new professionals are linked to the default unit');

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
  const { data: unitLinksAfterDelete, error: unitLinksAfterDeleteError } = await supabaseAdmin
    .from('professional_units')
    .select('professional_id')
    .eq('organization_id', organizationId)
    .eq('professional_id', professionalId);
  assert.equal(unitLinksAfterDeleteError, null, unitLinksAfterDeleteError?.message);
  assert.equal(unitLinksAfterDelete.length, 0, 'owned unit links are removed with the professional');
  const { data: deleteAudit, error: deleteAuditError } = await supabaseAdmin
    .from('unit_access_audit_events')
    .select('actor_kind, actor_user_id')
    .eq('organization_id', organizationId)
    .eq('professional_id', professionalId)
    .eq('event_type', 'professional_unit_changed')
    .eq('after_state->>action', 'deleted')
    .single();
  assert.equal(deleteAuditError, null, deleteAuditError?.message);
  assert.equal(deleteAudit.actor_kind, 'user');
  assert.equal(deleteAudit.actor_user_id, userId, 'cascade audit preserves the human owner');

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

test('professional list and GET expose only the linked self profile with a minimal DTO', async () => {
  const actor = await setUpOrgWithRole('professional');
  const selfCreated = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${actor.ownerAccessToken}`)
    .set('X-Organization-Id', actor.organizationId)
    .send({ name: 'Perfil Próprio', user_id: actor.userId });
  assert.equal(selfCreated.status, 201);
  const selfId = selfCreated.body.professional.id;

  const colleagueCreated = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${actor.ownerAccessToken}`)
    .set('X-Organization-Id', actor.organizationId)
    .send({ name: 'Perfil Colega' });
  assert.equal(colleagueCreated.status, 201);

  const listed = await request(app)
    .get('/api/v1/professionals')
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(listed.status, 200);
  assert.equal(listed.body.professionals.length, 1);
  assert.deepEqual(listed.body.professionals[0], {
    id: selfId,
    name: 'Perfil Próprio',
    active: true,
  });

  const fetched = await request(app)
    .get(`/api/v1/professionals/${selfId}`)
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(fetched.status, 200);
  assert.deepEqual(fetched.body.professional, {
    id: selfId,
    name: 'Perfil Próprio',
    active: true,
  });
});

test('professional GET returns 404 for another profile in the same organization', async () => {
  const actor = await setUpOrgWithRole('professional');
  const selfCreated = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${actor.ownerAccessToken}`)
    .set('X-Organization-Id', actor.organizationId)
    .send({ name: 'Perfil Próprio', user_id: actor.userId });
  assert.equal(selfCreated.status, 201);

  const colleagueCreated = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${actor.ownerAccessToken}`)
    .set('X-Organization-Id', actor.organizationId)
    .send({ name: 'Perfil Colega' });
  assert.equal(colleagueCreated.status, 201);

  const response = await request(app)
    .get(`/api/v1/professionals/${colleagueCreated.body.professional.id}`)
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(response.status, 404);
  assert.equal(response.body.code, 'professional_not_found');
});

test('professional without a linked profile receives an empty list and 404 by id', async () => {
  const actor = await setUpOrgWithRole('professional');
  const unlinkedCreated = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${actor.ownerAccessToken}`)
    .set('X-Organization-Id', actor.organizationId)
    .send({ name: 'Perfil Não Vinculado' });
  assert.equal(unlinkedCreated.status, 201);

  const listed = await request(app)
    .get('/api/v1/professionals')
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(listed.status, 200);
  assert.deepEqual(listed.body.professionals, []);

  const fetched = await request(app)
    .get(`/api/v1/professionals/${unlinkedCreated.body.professional.id}`)
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(fetched.status, 404);
  assert.equal(fetched.body.code, 'professional_not_found');
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

test('deleting a linked professional invalidates membership and permissions before the next request', async () => {
  const actor = await setUpOrgWithRole('professional');
  const { data: professional, error: professionalError } = await supabaseAdmin
    .from('professionals')
    .insert({
      organization_id: actor.organizationId,
      user_id: actor.userId,
      name: 'Lifecycle Professional',
    })
    .select('id')
    .single();
  assert.equal(professionalError, null, professionalError?.message);

  for (const permissionCode of ['schedule:view_all', 'clients:view_all']) {
    const { error } = await supabaseAdmin.rpc('membership_permission_grant', {
      p_organization_id: actor.organizationId,
      p_actor_user_id: actor.ownerUserId,
      p_target_user_id: actor.userId,
      p_permission_code: permissionCode,
    });
    assert.equal(error, null, error?.message);
  }

  const { error: clientError } = await supabaseAdmin.from('clients').insert({
    organization_id: actor.organizationId,
    name: 'Cliente Lifecycle',
    phone: '11999999999',
    created_by: actor.ownerUserId,
  });
  assert.equal(clientError, null, clientError?.message);

  const beforeDelete = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(beforeDelete.status, 200);
  assert.equal(beforeDelete.body.clients[0].phone, '11999999999');

  const { error: unlinkUnitError } = await supabaseAdmin
    .from('professional_units')
    .update({ active: false })
    .eq('organization_id', actor.organizationId)
    .eq('professional_id', professional.id);
  assert.equal(unlinkUnitError, null, unlinkUnitError?.message);
  const withoutUnitLink = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(withoutUnitLink.status, 200);
  assert.deepEqual(withoutUnitLink.body.clients, [], 'orphan permissions are ignored without an active unit link');
  const { error: restoreUnitError } = await supabaseAdmin
    .from('professional_units')
    .update({ active: true })
    .eq('organization_id', actor.organizationId)
    .eq('professional_id', professional.id);
  assert.equal(restoreUnitError, null, restoreUnitError?.message);

  const deleted = await request(app)
    .delete(`/api/v1/professionals/${professional.id}`)
    .set('Authorization', `Bearer ${actor.ownerAccessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(deleted.status, 204);

  for (const path of ['/api/v1/clients', '/api/v1/appointments', '/api/v1/sync']) {
    const denied = await request(app)
      .get(path)
      .set('Authorization', `Bearer ${actor.accessToken}`)
      .set('X-Organization-Id', actor.organizationId);
    assert.equal(denied.status, 403, `${path} must fail after professional deletion`);
    assert.equal(denied.body.code, 'not_a_member');
  }

  const { data: membership } = await supabaseAdmin
    .from('memberships')
    .select('active')
    .eq('organization_id', actor.organizationId)
    .eq('user_id', actor.userId)
    .single();
  assert.equal(membership.active, false);

  const { data: activePermissions } = await supabaseAdmin
    .from('membership_permissions')
    .select('id')
    .eq('organization_id', actor.organizationId)
    .eq('user_id', actor.userId)
    .is('revoked_at', null);
  assert.deepEqual(activePermissions, []);
});

test('deactivating a linked professional audits the human actor and invalidates access', async () => {
  const actor = await setUpOrgWithRole('professional');
  const created = await request(app)
    .post('/api/v1/professionals')
    .set('Authorization', `Bearer ${actor.ownerAccessToken}`)
    .set('X-Organization-Id', actor.organizationId)
    .send({ name: 'Lifecycle Patch Professional', user_id: actor.userId });
  assert.equal(created.status, 201);

  const { error: grantError } = await supabaseAdmin.rpc('membership_permission_grant', {
    p_organization_id: actor.organizationId,
    p_actor_user_id: actor.ownerUserId,
    p_target_user_id: actor.userId,
    p_permission_code: 'clients:view_all',
  });
  assert.equal(grantError, null, grantError?.message);

  const updated = await request(app)
    .patch(`/api/v1/professionals/${created.body.professional.id}`)
    .set('Authorization', `Bearer ${actor.ownerAccessToken}`)
    .set('X-Organization-Id', actor.organizationId)
    .send({ active: false });
  assert.equal(updated.status, 200);
  assert.equal(updated.body.professional.active, false);

  const { data: membership, error: membershipError } = await supabaseAdmin
    .from('memberships')
    .select('active')
    .eq('organization_id', actor.organizationId)
    .eq('user_id', actor.userId)
    .single();
  assert.equal(membershipError, null, membershipError?.message);
  assert.equal(membership.active, false);

  const { data: activePermissions, error: permissionsError } = await supabaseAdmin
    .from('membership_permissions')
    .select('id')
    .eq('organization_id', actor.organizationId)
    .eq('user_id', actor.userId)
    .is('revoked_at', null);
  assert.equal(permissionsError, null, permissionsError?.message);
  assert.deepEqual(activePermissions, []);

  const { data: lifecycleAudit, error: lifecycleAuditError } = await supabaseAdmin
    .from('unit_access_audit_events')
    .select('actor_kind, actor_user_id, after_state')
    .eq('organization_id', actor.organizationId)
    .eq('target_user_id', actor.userId)
    .eq('event_type', 'membership_scope_changed')
    .eq('after_state->>source', 'professional_lifecycle')
    .single();
  assert.equal(lifecycleAuditError, null, lifecycleAuditError?.message);
  assert.equal(lifecycleAudit.actor_kind, 'user');
  assert.equal(lifecycleAudit.actor_user_id, actor.ownerUserId);
  assert.equal(lifecycleAudit.after_state.active, false);

  const denied = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(denied.status, 403);
  assert.equal(denied.body.code, 'not_a_member');
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
