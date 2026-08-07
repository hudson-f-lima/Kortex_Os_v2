import { test } from 'node:test';
import assert from 'node:assert/strict';
import { requireFeatureFlag } from '../../src/middleware/requireFeatureFlag.js';

// Mocks supabaseAdmin.from('organizations').select('settings').eq('id', ...).single()
// — the real shape requireFeatureFlag queries, matching how organizationContext
// resolves req.auth.organizationId elsewhere in the middleware chain.
function mockSupabaseAdmin(settings) {
  return {
    from(table) {
      assert.equal(table, 'organizations');
      return {
        select() {
          return {
            eq() {
              return {
                async single() {
                  return { data: { settings }, error: null };
                },
              };
            },
          };
        },
      };
    },
  };
}

test('requireFeatureFlag allows request when feature flag is true in organization settings', async () => {
  const supabaseAdmin = mockSupabaseAdmin({ enable_sale_commission: true });
  const middleware = requireFeatureFlag(supabaseAdmin, 'enable_sale_commission');
  const req = { auth: { organizationId: 'org-1' } };
  let calledNext = false;
  let errorPassed = 'not-called';

  await middleware(req, {}, (err) => {
    calledNext = true;
    errorPassed = err;
  });

  assert.equal(calledNext, true);
  assert.equal(errorPassed, undefined);
});

test('requireFeatureFlag blocks request with 403 when feature flag is false', async () => {
  const supabaseAdmin = mockSupabaseAdmin({ enable_sale_commission: false });
  const middleware = requireFeatureFlag(supabaseAdmin, 'enable_sale_commission');
  const req = { auth: { organizationId: 'org-1' } };
  let errorPassed = null;

  await middleware(req, {}, (err) => {
    errorPassed = err;
  });

  assert.notEqual(errorPassed, null);
  assert.equal(errorPassed.status, 403);
  assert.equal(errorPassed.code, 'feature_disabled');
});

test('requireFeatureFlag blocks request with 403 when the flag key is absent from settings', async () => {
  const supabaseAdmin = mockSupabaseAdmin({});
  const middleware = requireFeatureFlag(supabaseAdmin, 'enable_sale_commission');
  const req = { auth: { organizationId: 'org-1' } };
  let errorPassed = null;

  await middleware(req, {}, (err) => {
    errorPassed = err;
  });

  assert.equal(errorPassed?.status, 403);
});
