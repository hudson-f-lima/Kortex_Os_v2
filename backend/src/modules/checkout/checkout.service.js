import { mapRpcError } from '../../shared/rpcError.js';

export function createCheckoutService(supabaseAdmin) {
  return {
    async close({ organizationId, actorUserId, idempotencyKey, payload }) {
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
