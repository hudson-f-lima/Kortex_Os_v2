import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { setTimeout as nodeSetTimeout, clearTimeout as nodeClearTimeout } from 'node:timers';
import request from 'supertest';
import http from 'node:http';
import express from 'express';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { syncRouter } from '../../src/modules/sync/sync.route.js';
import { localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

async function seedAppointmentsInTwoUnits(actor) {
  const { data: defaultUnit, error: defaultUnitError } = await supabaseAdmin
    .from('units')
    .select('id')
    .eq('organization_id', actor.organizationId)
    .eq('is_default', true)
    .single();
  assert.equal(defaultUnitError, null, defaultUnitError?.message);

  const { data: otherUnit, error: otherUnitError } = await supabaseAdmin
    .from('units')
    .insert({
      organization_id: actor.organizationId,
      name: `Outra Unidade ${randomUUID().slice(0, 8)}`,
      timezone: 'America/Sao_Paulo',
      active: true,
      is_default: false,
      created_by: actor.ownerUserId,
    })
    .select('id')
    .single();
  assert.equal(otherUnitError, null, otherUnitError?.message);

  const { data: client, error: clientError } = await supabaseAdmin
    .from('clients')
    .insert({
      organization_id: actor.organizationId,
      name: 'Cliente Sync Unit',
      email: 'private-sync@example.com',
      created_by: actor.ownerUserId,
    })
    .select('id')
    .single();
  assert.equal(clientError, null, clientError?.message);

  const { data: professional, error: professionalError } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: actor.organizationId, name: 'Prof Sync Unit' })
    .select('id')
    .single();
  assert.equal(professionalError, null, professionalError?.message);

  const { error: otherUnitLinkError } = await supabaseAdmin.from('professional_units').insert({
    organization_id: actor.organizationId,
    professional_id: professional.id,
    unit_id: otherUnit.id,
    active: true,
    created_by: actor.ownerUserId,
  });
  assert.equal(otherUnitLinkError, null, otherUnitLinkError?.message);

  const { data: group, error: groupError } = await supabaseAdmin
    .from('service_groups')
    .insert({
      organization_id: actor.organizationId,
      name: `Grupo Sync ${randomUUID().slice(0, 8)}`,
      default_commission_type: 'percentage',
      default_commission_value: 4000,
    })
    .select('id')
    .single();
  assert.equal(groupError, null, groupError?.message);

  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({
      organization_id: actor.organizationId,
      service_group_id: group.id,
      name: 'Servico Sync Unit',
      price_cents: 5000,
      duration_minutes: 30,
    })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);

  const common = {
    organization_id: actor.organizationId,
    client_id: client.id,
    professional_id: professional.id,
    service_id: service.id,
    created_by: actor.ownerUserId,
  };
  const { data: appointments, error: appointmentsError } = await supabaseAdmin
    .from('appointments')
    .insert([
      {
        ...common,
        unit_id: defaultUnit.id,
        starts_at: '2026-10-01T10:00:00Z',
        ends_at: '2026-10-01T10:30:00Z',
      },
      {
        ...common,
        unit_id: otherUnit.id,
        starts_at: '2026-10-01T11:00:00Z',
        ends_at: '2026-10-01T11:30:00Z',
      },
    ])
    .select('id, unit_id');
  assert.equal(appointmentsError, null, appointmentsError?.message);

  return {
    clientId: client.id,
    professionalId: professional.id,
    serviceId: service.id,
    defaultUnitId: defaultUnit.id,
    otherUnitId: otherUnit.id,
    ownAppointmentId: appointments.find((item) => item.unit_id === defaultUnit.id).id,
    otherAppointmentId: appointments.find((item) => item.unit_id === otherUnit.id).id,
  };
}

test('sync endpoint returns changes incrementally and supports all roles', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  // 1. Initial sync when there are no events
  const initial = await request(app)
    .get('/api/v1/sync?since=0')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  
  assert.equal(initial.status, 200);
  assert.ok(Array.isArray(initial.body.events));
  const baselineCount = initial.body.events.length;

  // 2. Create a client to trigger a sync event
  const clientRes = await request(app)
    .post('/api/v1/clients')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ name: 'Sync Client 1', email: 'sync1@example.com' });
  assert.equal(clientRes.status, 201);
  const clientId = clientRes.body.client.id;

  // 3. Verify sync detects the new client insertion
  const afterInsert = await request(app)
    .get('/api/v1/sync?since=0')
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  
  assert.equal(afterInsert.status, 200);
  // Should have at least the new event
  assert.ok(afterInsert.body.events.length > baselineCount);
  
  const insertEvent = afterInsert.body.events.find(
    e => e.table_name === 'clients' && e.record_id === clientId && e.action === 'INSERT'
  );
  assert.ok(insertEvent);
  assert.equal(insertEvent.payload.name, 'Sync Client 1');
  const insertEventId = insertEvent.id;

  // 4. Query since the insert event ID - should be empty (no changes since)
  const querySince = await request(app)
    .get(`/api/v1/sync?since=${insertEventId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  
  assert.equal(querySince.status, 200);
  assert.equal(querySince.body.events.length, 0);

  // 5. Update the client
  const updateRes = await request(app)
    .patch(`/api/v1/clients/${clientId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId)
    .send({ phone: '555-5555' });
  assert.equal(updateRes.status, 200);

  // 6. Verify sync returns the update event when querying since insertEventId
  const afterUpdate = await request(app)
    .get(`/api/v1/sync?since=${insertEventId}`)
    .set('Authorization', `Bearer ${accessToken}`)
    .set('X-Organization-Id', organizationId);
  
  assert.equal(afterUpdate.status, 200);
  assert.equal(afterUpdate.body.events.length, 1);
  assert.equal(afterUpdate.body.events[0].action, 'UPDATE');
  assert.equal(afterUpdate.body.events[0].record_id, clientId);
  assert.equal(afterUpdate.body.events[0].payload.phone, '555-5555');
  // 7. Verify professional role can also sync (read-only allowed for projection)
  const profOrg = await setUpOrgWithRole('professional');
  const profSync = await request(app)
    .get('/api/v1/sync?since=0')
    .set('Authorization', `Bearer ${profOrg.accessToken}`)
    .set('X-Organization-Id', profOrg.organizationId);
  
  assert.equal(profSync.status, 200);
  assert.ok(Array.isArray(profSync.body.events));
});

test('reception sync only returns transactional events from its membership unit', async () => {
  const reception = await setUpOrgWithRole('reception');
  const seeded = await seedAppointmentsInTwoUnits(reception);

  const response = await request(app)
    .get('/api/v1/sync?since=0')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);

  assert.equal(response.status, 200);
  const appointmentEvents = response.body.events.filter((event) => event.table_name === 'appointments');
  assert.ok(appointmentEvents.some((event) => event.record_id === seeded.ownAppointmentId));
  assert.ok(!appointmentEvents.some((event) => event.record_id === seeded.otherAppointmentId));
  assert.ok(
    response.body.events.some((event) => event.table_name === 'services'),
    'organization-wide catalog events remain visible',
  );
});

test('professional sync excludes client payloads and scopes appointments unless schedule:view_all is granted', async () => {
  const professionalActor = await setUpOrgWithRole('professional');
  const seeded = await seedAppointmentsInTwoUnits(professionalActor);

  const { error: actorLinkError } = await supabaseAdmin
    .from('professionals')
    .update({ user_id: professionalActor.userId })
    .eq('organization_id', professionalActor.organizationId)
    .eq('id', seeded.professionalId);
  assert.equal(actorLinkError, null, actorLinkError?.message);

  const { data: colleague, error: colleagueError } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: professionalActor.organizationId, name: 'Colega Sync' })
    .select('id')
    .single();
  assert.equal(colleagueError, null, colleagueError?.message);

  const { data: colleagueAppointment, error: colleagueAppointmentError } = await supabaseAdmin
    .from('appointments')
    .insert({
      organization_id: professionalActor.organizationId,
      unit_id: seeded.defaultUnitId,
      client_id: seeded.clientId,
      professional_id: colleague.id,
      service_id: seeded.serviceId,
      starts_at: '2026-10-01T12:00:00Z',
      ends_at: '2026-10-01T12:30:00Z',
      created_by: professionalActor.ownerUserId,
    })
    .select('id')
    .single();
  assert.equal(colleagueAppointmentError, null, colleagueAppointmentError?.message);

  const ownOnly = await request(app)
    .get('/api/v1/sync?since=0')
    .set('Authorization', `Bearer ${professionalActor.accessToken}`)
    .set('X-Organization-Id', professionalActor.organizationId);
  assert.equal(ownOnly.status, 200);
  assert.ok(!ownOnly.body.events.some((event) => event.table_name === 'clients'));
  const ownOnlyAppointmentIds = ownOnly.body.events
    .filter((event) => event.table_name === 'appointments')
    .map((event) => event.record_id);
  assert.deepEqual(ownOnlyAppointmentIds, [seeded.ownAppointmentId]);

  const { error: permissionError } = await supabaseAdmin.from('membership_permissions').insert({
    organization_id: professionalActor.organizationId,
    user_id: professionalActor.userId,
    permission_code: 'schedule:view_all',
    granted_by: professionalActor.ownerUserId,
  });
  assert.equal(permissionError, null, permissionError?.message);

  const viewAllInUnit = await request(app)
    .get('/api/v1/sync?since=0')
    .set('Authorization', `Bearer ${professionalActor.accessToken}`)
    .set('X-Organization-Id', professionalActor.organizationId);
  assert.equal(viewAllInUnit.status, 200);
  assert.ok(!viewAllInUnit.body.events.some((event) => event.table_name === 'clients'));
  const viewAllAppointmentIds = viewAllInUnit.body.events
    .filter((event) => event.table_name === 'appointments')
    .map((event) => event.record_id)
    .sort();
  assert.deepEqual(viewAllAppointmentIds, [seeded.ownAppointmentId, colleagueAppointment.id].sort());
});

test('professional sync only exposes its own profile, capabilities and commissions', async () => {
  const actor = await setUpOrgWithRole('professional');
  const { data: actorProfessional, error: actorProfessionalError } = await supabaseAdmin
    .from('professionals')
    .insert({
      organization_id: actor.organizationId,
      user_id: actor.userId,
      name: 'Profissional Ator Sync',
    })
    .select('id')
    .single();
  assert.equal(actorProfessionalError, null, actorProfessionalError?.message);

  const { data: colleague, error: colleagueError } = await supabaseAdmin
    .from('professionals')
    .insert({ organization_id: actor.organizationId, name: 'Profissional Colega Sync' })
    .select('id')
    .single();
  assert.equal(colleagueError, null, colleagueError?.message);

  const syntheticEvents = [
    {
      table_name: 'professional_service_capabilities',
      record_id: randomUUID(),
      payload: { id: randomUUID(), professional_id: actorProfessional.id },
    },
    {
      table_name: 'professional_service_capabilities',
      record_id: randomUUID(),
      payload: { id: randomUUID(), professional_id: colleague.id },
    },
    {
      table_name: 'professional_service_commissions',
      record_id: randomUUID(),
      payload: { id: randomUUID(), professional_id: actorProfessional.id, commission_value: 4000 },
    },
    {
      table_name: 'professional_service_commissions',
      record_id: randomUUID(),
      payload: { id: randomUUID(), professional_id: colleague.id, commission_value: 9000 },
    },
  ].map((event) => ({
    organization_id: actor.organizationId,
    action: 'INSERT',
    ...event,
  }));
  const { error: syncEventError } = await supabaseAdmin.from('sync_events').insert(syntheticEvents);
  assert.equal(syncEventError, null, syncEventError?.message);

  const response = await request(app)
    .get('/api/v1/sync?since=0')
    .set('Authorization', `Bearer ${actor.accessToken}`)
    .set('X-Organization-Id', actor.organizationId);
  assert.equal(response.status, 200);

  const sensitiveEvents = response.body.events.filter((event) =>
    ['professionals', 'professional_service_capabilities', 'professional_service_commissions'].includes(
      event.table_name,
    ),
  );
  assert.ok(sensitiveEvents.some((event) => event.table_name === 'professionals'));
  assert.ok(sensitiveEvents.some((event) => event.table_name === 'professional_service_capabilities'));
  assert.ok(sensitiveEvents.some((event) => event.table_name === 'professional_service_commissions'));
  assert.ok(
    sensitiveEvents.every((event) => {
      if (event.table_name === 'professionals') return event.payload.id === actorProfessional.id;
      return event.payload.professional_id === actorProfessional.id;
    }),
  );
});

test('sync stream (SSE) establishes connection and sends correct headers', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const server = app.listen(0);
  const { port } = server.address();

  await new Promise((resolve, reject) => {
    const req = http.get(
      `http://127.0.0.1:${port}/api/v1/sync/stream`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'X-Organization-Id': organizationId,
        },
      },
      (res) => {
        assert.equal(res.statusCode, 200);
        assert.equal(res.headers['content-type'], 'text/event-stream');
        assert.equal(res.headers['connection'], 'keep-alive');

        let data = '';
        res.on('data', (chunk) => {
          data += chunk.toString();
          if (data.includes('event: connected')) {
            req.destroy();
            server.close();
            resolve();
          }
        });
      }
    );
    req.on('error', (err) => {
      server.close();
      reject(err);
    });
  });
});

test('sync stream handles concurrent connections for the same organization without crashing', async () => {
  const { organizationId, accessToken } = await setUpOrgWithRole('owner');

  const server = app.listen(0);
  const { port } = server.address();

  function connect() {
    return new Promise((resolve, reject) => {
      const req = http.get(
        `http://127.0.0.1:${port}/api/v1/sync/stream`,
        {
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'X-Organization-Id': organizationId,
          },
        },
        (res) => {
          let data = '';
          res.on('data', (chunk) => {
            data += chunk.toString();
            if (data.includes('event: connected')) {
              resolve({ req, res });
            }
          });
        }
      );
      req.on('error', reject);
    });
  }

  try {
    // Fire two concurrent SSE requests for the same organization to trigger
    // the race where supabaseAdmin.channel() reuses an already-subscribed
    // RealtimeChannel instance across the two requests.
    const [first, second] = await Promise.all([connect(), connect()]);

    // Both connections should be alive and the server process must not have crashed.
    assert.equal(first.res.statusCode, 200);
    assert.equal(second.res.statusCode, 200);

    first.req.destroy();
    second.req.destroy();

    // A follow-up request for the same organization must still succeed,
    // proving the server survived the concurrent subscribe attempt.
    const third = await connect();
    assert.equal(third.res.statusCode, 200);
    third.req.destroy();
  } finally {
    server.close();
  }
});

test('shared SSE channel applies unit authorization independently for each listener', async () => {
  const organizationId = randomUUID();
  const receptionUnitId = randomUUID();
  let emitRealtimeEvent;
  let markSubscribed;

  const realtimeChannel = {
    on(_event, _filter, callback) {
      emitRealtimeEvent = callback;
      return this;
    },
    subscribe(callback) {
      markSubscribed = callback;
      process.nextTick(() => callback('SUBSCRIBED'));
      return this;
    },
  };
  const fakeSupabase = {
    channel() {
      return realtimeChannel;
    },
    removeChannel() {},
  };
  const organizationContext = (req, _res, next) => {
    const role = req.headers['x-test-role'];
    req.auth = {
      userId: randomUUID(),
      organizationId,
      role,
      unitId: role === 'reception' ? receptionUnitId : undefined,
      permissions: [],
    };
    next();
  };
  const scopedApp = express();
  scopedApp.use('/api/v1', syncRouter({ supabaseAdmin: fakeSupabase, organizationContext }));
  const server = scopedApp.listen(0);
  const { port } = server.address();

  function connect(role) {
    return new Promise((resolve, reject) => {
      const events = [];
      const waiters = new Map();
      const req = http.get(
        `http://127.0.0.1:${port}/api/v1/sync/stream`,
        { headers: { 'X-Test-Role': role } },
        (res) => {
          let buffer = '';
          res.on('data', (chunk) => {
            buffer += chunk.toString();
            const frames = buffer.split('\n\n');
            buffer = frames.pop();
            for (const frame of frames) {
              const dataLine = frame
                .split('\n')
                .find((line) => line.startsWith('data: '));
              if (dataLine) {
                const event = JSON.parse(dataLine.slice('data: '.length));
                if (event.record_id) {
                  events.push(event);
                  waiters.get(event.record_id)?.(event);
                }
              }
              if (frame.includes('event: subscribed')) {
                resolve({
                  req,
                  events,
                  waitForRecord(recordId) {
                    const existing = events.find((event) => event.record_id === recordId);
                    if (existing) return Promise.resolve(existing);
                    return new Promise((recordResolve) => waiters.set(recordId, recordResolve));
                  },
                });
              }
            }
          });
        },
      );
      req.on('error', reject);
    });
  }

  function withTimeout(promise) {
    return new Promise((resolve, reject) => {
      const timeout = nodeSetTimeout(() => reject(new Error('timed out waiting for SSE event')), 3000);
      promise.then(
        (value) => {
          nodeClearTimeout(timeout);
          resolve(value);
        },
        (error) => {
          nodeClearTimeout(timeout);
          reject(error);
        },
      );
    });
  }

  try {
    const [owner, reception] = await Promise.all([connect('owner'), connect('reception')]);
    assert.equal(typeof emitRealtimeEvent, 'function');
    assert.equal(typeof markSubscribed, 'function');

    const otherUnitRecordId = randomUUID();
    emitRealtimeEvent({
      new: {
        id: 1,
        organization_id: organizationId,
        table_name: 'appointments',
        record_id: otherUnitRecordId,
        action: 'INSERT',
        payload: { id: otherUnitRecordId, unit_id: randomUUID() },
        created_at: new Date().toISOString(),
      },
    });
    await withTimeout(owner.waitForRecord(otherUnitRecordId));

    const ownUnitRecordId = randomUUID();
    emitRealtimeEvent({
      new: {
        id: 2,
        organization_id: organizationId,
        table_name: 'appointments',
        record_id: ownUnitRecordId,
        action: 'INSERT',
        payload: { id: ownUnitRecordId, unit_id: receptionUnitId },
        created_at: new Date().toISOString(),
      },
    });
    await Promise.all([
      withTimeout(owner.waitForRecord(ownUnitRecordId)),
      withTimeout(reception.waitForRecord(ownUnitRecordId)),
    ]);

    assert.ok(!reception.events.some((event) => event.record_id === otherUnitRecordId));
    owner.req.destroy();
    reception.req.destroy();
  } finally {
    server.closeAllConnections();
    server.close();
  }
});
