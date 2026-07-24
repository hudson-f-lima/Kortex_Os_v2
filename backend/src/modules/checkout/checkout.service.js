import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

async function assertCheckoutWriteUnit(supabaseAdmin, organizationId, membershipUnitId) {
  if (membershipUnitId === undefined) return;

  const { data: defaultUnit, error } = await supabaseAdmin
    .from('units')
    .select('id')
    .eq('organization_id', organizationId)
    .eq('is_default', true)
    .eq('active', true)
    .maybeSingle();
  if (error) throw mapPostgresError(error);
  if (!defaultUnit) {
    throw HttpError.conflict('active_default_unit_required', 'organization has no active default unit');
  }
  if (membershipUnitId !== defaultUnit.id) {
    throw HttpError.conflict(
      'unit_write_not_supported',
      'checkout cannot target a non-default unit until checkout_close accepts an explicit server-owned unit',
    );
  }
}

export function createCheckoutService(supabaseAdmin) {
  return {
    async close({ organizationId, unitId, actorUserId, idempotencyKey, payload }) {
      await assertCheckoutWriteUnit(supabaseAdmin, organizationId, unitId);
      const { data, error } = await supabaseAdmin.rpc('checkout_close', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_payload: payload,
      });
      if (error) throw mapRpcError(error);
      return data;
    },
  };
}
