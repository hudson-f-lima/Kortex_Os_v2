import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, setUpOrgWithRole as setUpOrg } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

const setUpOrgWithRole = (role) => setUpOrg(supabaseAdmin, role);

async function closeACheckout(organizationId, actorUserId) {
  const { data: service, error: serviceError } = await supabaseAdmin
    .from('services')
    .insert({ organization_id: organizationId, name: 'Corte', price_cents: 4000, duration_minutes: 30 })
    .select('id')
    .single();
  assert.equal(serviceError, null, serviceError?.message);

  const { error } = await supabaseAdmin.rpc('checkout_close', {
    p_organization_id: organizationId,
    p_actor_user_id: actorUserId,
    p_idempotency_key: `seed-${randomUUID()}`,
    p_payload: {
      items: [{ kind: 'service', id: service.id, quantity: 1 }],
      payments: [{ method: 'cash', amount_cents: 4000 }],
    },
  });
  assert.equal(error, null, error?.message);
}

test('owner/manager can read cash entries, reception cannot', async () => {
  const manager = await setUpOrgWithRole('manager');
  await closeACheckout(manager.organizationId, manager.ownerUserId);

  const listedAsManager = await request(app)
    .get('/api/v1/cash-entries')
    .set('Authorization', `Bearer ${manager.accessToken}`)
    .set('X-Organization-Id', manager.organizationId);
  assert.equal(listedAsManager.status, 200);
  assert.equal(listedAsManager.body.cash_entries.length, 1);
  assert.equal(listedAsManager.body.cash_entries[0].kind, 'sale');
  assert.equal(listedAsManager.body.cash_entries[0].amount_cents, 4000);

  const reception = await setUpOrgWithRole('reception');
  const listedAsReception = await request(app)
    .get('/api/v1/cash-entries')
    .set('Authorization', `Bearer ${reception.accessToken}`)
    .set('X-Organization-Id', reception.organizationId);
  assert.equal(listedAsReception.status, 403, 'cash_entries_select does not include reception');
  assert.equal(listedAsReception.body.code, 'insufficient_role');
});

test('cash entries support filtering by kind and are tenant-scoped', async () => {
  const orgA = await setUpOrgWithRole('owner');
  const orgB = await setUpOrgWithRole('owner');
  await closeACheckout(orgA.organizationId, orgA.ownerUserId);

  const wrongKind = await request(app)
    .get('/api/v1/cash-entries?kind=expense')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId);
  assert.equal(wrongKind.body.cash_entries.length, 0);

  const rightKind = await request(app)
    .get('/api/v1/cash-entries?kind=sale')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId);
  assert.equal(rightKind.body.cash_entries.length, 1);

  const fromOrgB = await request(app)
    .get('/api/v1/cash-entries')
    .set('Authorization', `Bearer ${orgB.accessToken}`)
    .set('X-Organization-Id', orgB.organizationId);
  assert.equal(fromOrgB.body.cash_entries.length, 0);

  const invalidKind = await request(app)
    .get('/api/v1/cash-entries?kind=bogus')
    .set('Authorization', `Bearer ${orgA.accessToken}`)
    .set('X-Organization-Id', orgA.organizationId);
  assert.equal(invalidKind.status, 400);
  assert.equal(invalidKind.body.code, 'invalid_kind');
});
