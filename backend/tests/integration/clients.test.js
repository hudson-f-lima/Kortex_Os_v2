import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { createServiceGroup, localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

async function seedProfessionalAppointment({ organizationId, userId, ownerUserId, client }) {
  const { data: unit, error: unitError } = await supabaseAdmin
    .from('units')
    .select('id')
    .eq('organization_id', organizationId)
    .eq('is_default', true)
    .eq('active', true)
    .single();
  assert.equal(unitError, null, unitError?.message);

  const { data: professional, error: professionalError } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: organizationId, user_id: userId, name: 'Profissional autenticado' })
    .select('id')
    .single();
  assert.equal(professionalError, null, professionalError?.message);

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

  const { data: createdClient, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({
      organization_id: organizationId,
      created_by: ownerUserId,
      name: client.name,
      phone: client.phone,
      email: client.email,
    })
    .select('id, name')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const { error: appointmentError } = await supabaseAdmin.from('appointments').insert({
    organization_id: organizationId,
    unit_id: unit.id,
    client_id: createdClient.id,
    professional_id: professional.id,
    service_id: service.id,
    starts_at: '2026-09-01T10:00:00Z',
    ends_at: '2026-09-01T10:30:00Z',
    created_by: ownerUserId,
  });
  assert.equal(appointmentError, null, appointmentError?.message);

  return { client: createdClient, professionalId: professional.id, serviceId: service.id, unitId: unit.id };
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

test('professional sees only id and name for a client associated with an own appointment, and still cannot write', async () => {
  const { organizationId, accessToken, userId, ownerUserId } = await setUpOrgWithRole('professional');
  const { client } = await seedProfessionalAppointment({
    organizationId,
    userId,
    ownerUserId,
    client: {
      name: 'Cliente da agenda',
      phone: '11999999999',
      email: 'pii@example.com',
    },
  });

  const list = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(list.status, 200);
  assert.deepEqual(list.body.clients, [{ id: client.id, name: client.name }]);

  const detail = await request(app)
    .get(`/api/v1/clients/${client.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(detail.status, 200);
  assert.deepEqual(detail.body.client, { id: client.id, name: client.name });

  const create = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Should Not Exist' });
  assert.equal(create.status, 403);

  const update = await request(app)
    .patch(`/api/v1/clients/${client.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ phone: '11900000000' });
  assert.equal(update.status, 403);

  const remove = await request(app)
    .delete(`/api/v1/clients/${client.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(remove.status, 403);
});

test('professional minimal projection excludes clients from another unit and another professional', async () => {
  const { organizationId, accessToken, userId, ownerUserId } = await setUpOrgWithRole('professional');
  const own = await seedProfessionalAppointment({
    organizationId,
    userId,
    ownerUserId,
    client: {
      name: 'Cliente permitido',
      phone: '11911111111',
      email: 'permitido@example.com',
    },
  });

  const { data: otherUnit, error: unitError } = await supabaseAdmin
    .from('units')
    .insert({
      organization_id: organizationId,
      name: `Unidade ${Math.random()}`,
      timezone: 'America/Sao_Paulo',
      active: true,
      is_default: false,
    })
    .select('id')
    .single();
  assert.equal(unitError, null, unitError?.message);
  const { error: linkError } = await supabaseAdmin.from('professional_units').insert({
    organization_id: organizationId,
    professional_id: own.professionalId,
    unit_id: otherUnit.id,
    active: true,
  });
  assert.equal(linkError, null, linkError?.message);

  const { data: crossUnitClient, error: crossUnitClientError } = await supabaseAdmin
    .from('clients')
    .insert({
      organization_id: organizationId,
      created_by: ownerUserId,
      name: 'Cliente de outra unidade',
      phone: '11922222222',
      email: 'outra-unidade@example.com',
    })
    .select('id')
    .single();
  assert.equal(crossUnitClientError, null, crossUnitClientError?.message);
  const { error: crossUnitAppointmentError } = await supabaseAdmin.from('appointments').insert({
    organization_id: organizationId,
    unit_id: otherUnit.id,
    client_id: crossUnitClient.id,
    professional_id: own.professionalId,
    service_id: own.serviceId,
    starts_at: '2026-09-02T10:00:00Z',
    ends_at: '2026-09-02T10:30:00Z',
    created_by: ownerUserId,
  });
  assert.equal(crossUnitAppointmentError, null, crossUnitAppointmentError?.message);

  const { data: unrelatedClient, error: unrelatedClientError } = await supabaseAdmin
    .from('clients')
    .insert({
      organization_id: organizationId,
      created_by: ownerUserId,
      name: 'Cliente de outro profissional',
      phone: '11933333333',
      email: 'outro-profissional@example.com',
    })
    .select('id')
    .single();
  assert.equal(unrelatedClientError, null, unrelatedClientError?.message);
  const { data: otherProfessional, error: otherProfessionalError } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: organizationId, name: 'Outro profissional' })
    .select('id')
    .single();
  assert.equal(otherProfessionalError, null, otherProfessionalError?.message);
  const { error: otherProfessionalAppointmentError } = await supabaseAdmin.from('appointments').insert({
    organization_id: organizationId,
    unit_id: own.unitId,
    client_id: unrelatedClient.id,
    professional_id: otherProfessional.id,
    service_id: own.serviceId,
    starts_at: '2026-09-03T10:00:00Z',
    ends_at: '2026-09-03T10:30:00Z',
    created_by: ownerUserId,
  });
  assert.equal(otherProfessionalAppointmentError, null, otherProfessionalAppointmentError?.message);

  const list = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(list.status, 200);
  assert.deepEqual(list.body.clients, [{ id: own.client.id, name: own.client.name }]);

  for (const invisibleClientId of [crossUnitClient.id, unrelatedClient.id]) {
    const detail = await request(app)
      .get(`/api/v1/clients/${invisibleClientId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Organization-Id', organizationId);
    assert.equal(detail.status, 404);
    assert.equal(detail.body.code, 'client_not_found');
  }
});

test('clients:view_all is re-evaluated per request and exposes the full org-wide DTO only while active', async () => {
  const { organizationId, accessToken, userId, ownerUserId } = await setUpOrgWithRole('professional');
  const own = await seedProfessionalAppointment({
    organizationId,
    userId,
    ownerUserId,
    client: {
      name: 'Cliente próprio',
      phone: '11944444444',
      email: 'proprio@example.com',
    },
  });
  const { data: orgWideClient, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({
      organization_id: organizationId,
      created_by: ownerUserId,
      name: 'Cliente sem agendamento próprio',
      phone: '11955555555',
      email: 'org-wide@example.com',
    })
    .select('id')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const beforeGrant = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(beforeGrant.status, 200);
  assert.deepEqual(beforeGrant.body.clients, [{ id: own.client.id, name: own.client.name }]);

  const { data: permission, error: permissionError } = await supabaseAdmin
    .from('membership_permissions')
    .insert({
      organization_id: organizationId,
      user_id: userId,
      permission_code: 'clients:view_all',
      granted_by: ownerUserId,
    })
    .select('id')
    .single();
  assert.equal(permissionError, null, permissionError?.message);

  const afterGrant = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterGrant.status, 200);
  assert.equal(afterGrant.body.clients.length, 2);
  const fullDto = afterGrant.body.clients.find((client) => client.id === orgWideClient.id);
  assert.equal(fullDto.phone, '11955555555');
  assert.equal(fullDto.email, 'org-wide@example.com');
  assert.equal(fullDto.organization_id, organizationId);

  const fullDetail = await request(app)
    .get(`/api/v1/clients/${orgWideClient.id}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(fullDetail.status, 200);
  assert.equal(fullDetail.body.client.phone, '11955555555');
  assert.equal(fullDetail.body.client.email, 'org-wide@example.com');

  const { error: revokeError } = await supabaseAdmin
    .from('membership_permissions')
    .update({
      revoked_by: ownerUserId,
      revoked_at: new Date().toISOString(),
    })
    .eq('id', permission.id);
  assert.equal(revokeError, null, revokeError?.message);

  const afterRevoke = await request(app)
    .get('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  assert.equal(afterRevoke.status, 200);
  assert.deepEqual(afterRevoke.body.clients, [{ id: own.client.id, name: own.client.name }]);
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
