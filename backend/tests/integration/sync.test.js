import { test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import http from 'node:http';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

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
  const updateEventId = afterUpdate.body.events[0].id;

  // 7. Verify professional role can also sync (read-only allowed for projection)
  const profOrg = await setUpOrgWithRole('professional');
  const profSync = await request(app)
    .get('/api/v1/sync?since=0')
    .set('Authorization', `Bearer ${profOrg.accessToken}`)
    .set('X-Organization-Id', profOrg.organizationId);
  
  assert.equal(profSync.status, 200);
  assert.ok(Array.isArray(profSync.body.events));
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
