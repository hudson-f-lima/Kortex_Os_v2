import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { createSupabaseAdmin } from '../../src/shared/supabaseAdmin.js';
import { localTestEnv, setUpOrgWithRole } from '../helpers/localSupabase.js';

const env = localTestEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

async function reopenedOrder(owner) {
  const { data: product, error: productError } = await supabaseAdmin
    .from('products')
    .insert({ organization_id: owner.organizationId, sku: `reclose-${randomUUID()}`, name: 'Produto Reclose', price_cents: 1000, cost_cents: 100, stock_on_hand: 8 })
    .select('id')
    .single();
  assert.equal(productError, null, productError?.message);
  const { error: flagError } = await supabaseAdmin
    .from('organizations')
    .update({ settings: { checkout_reopen_enabled: true } })
    .eq('id', owner.organizationId);
  assert.equal(flagError, null, flagError?.message);
  const { data: closed, error: closeError } = await supabaseAdmin.rpc('checkout_close', {
    p_organization_id: owner.organizationId,
    p_actor_user_id: owner.userId,
    p_idempotency_key: `reclose-close-${randomUUID()}`,
    p_payload: { items: [{ kind: 'product', id: product.id, quantity: 1 }], payments: [{ method: 'cash', amount_cents: 1000 }] },
  });
  assert.equal(closeError, null, closeError?.message);
  const { data: requested, error: requestError } = await supabaseAdmin.rpc('order_reopen_request', {
    p_organization_id: owner.organizationId,
    p_actor_user_id: owner.userId,
    p_idempotency_key: `reclose-request-${randomUUID()}`,
    p_order_id: closed.order_id,
    p_reason_code: 'item_correction',
    p_reason_detail: 'adicionar uma unidade',
  });
  assert.equal(requestError, null, requestError?.message);
  const { error: openError } = await supabaseAdmin.rpc('order_reopen', {
    p_organization_id: owner.organizationId,
    p_actor_user_id: owner.userId,
    p_idempotency_key: `reclose-open-${randomUUID()}`,
    p_order_id: closed.order_id,
    p_reopen_attempt_id: requested.reopen_attempt_id,
  });
  assert.equal(openError, null, openError?.message);
  return { orderId: closed.order_id, reopenAttemptId: requested.reopen_attempt_id, productId: product.id };
}

test('owner re-closes a reopened order only through the dark-launched server command', async () => {
  const owner = await setUpOrgWithRole(supabaseAdmin, 'owner');
  const { orderId, reopenAttemptId, productId } = await reopenedOrder(owner);

  const response = await request(app)
    .post(`/api/v1/orders/${orderId}/reclose`)
    .set('Authorization', `Bearer ${owner.accessToken}`)
    .set('X-Organization-Id', owner.organizationId)
    .set('Idempotency-Key', `reclose-http-${randomUUID()}`)
    .send({
      items: [{ kind: 'product', id: productId, quantity: 2 }],
      payments: [{ method: 'cash', amount_cents: 2000 }],
      discount_cents: 0,
      tip_cents: 0,
      reopen_attempt_id: reopenAttemptId,
    });

  assert.equal(response.status, 200, JSON.stringify(response.body));
  assert.equal(response.body.status, 'closed');
  assert.equal(response.body.revision_number, 2);
  assert.equal(response.body.cash_delta_cents, 1000);
});

test('keeps the reclose command unavailable while checkout_reopen_enabled is false', async () => {
  const owner = await setUpOrgWithRole(supabaseAdmin, 'owner');

  const response = await request(app)
    .post(`/api/v1/orders/${randomUUID()}/reclose`)
    .set('Authorization', `Bearer ${owner.accessToken}`)
    .set('X-Organization-Id', owner.organizationId)
    .set('Idempotency-Key', `reclose-disabled-${randomUUID()}`)
    .send({});

  assert.equal(response.status, 403, JSON.stringify(response.body));
  assert.equal(response.body.code, 'feature_disabled');
});
