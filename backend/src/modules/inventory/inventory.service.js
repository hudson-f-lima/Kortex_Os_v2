import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const MOVEMENT_COLUMNS = 'id, product_id, order_id, reason, quantity_delta, balance_after, created_at';

export function createInventoryService(supabaseAdmin) {
  return {
    async adjust({ organizationId, actorUserId, idempotencyKey, payload }) {
      const { data, error } = await supabaseAdmin.rpc('inventory_adjust', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_product_id: payload.product_id,
        p_quantity_delta: payload.quantity_delta,
        p_reason: payload.reason,
      });
      if (error) throw mapRpcError(error);
      return data;
    },

    async listMovements({ organizationId, productId }) {
      let query = supabaseAdmin
        .from('inventory_movements')
        .select(MOVEMENT_COLUMNS)
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: false });
      if (productId !== undefined) {
        query = query.eq('product_id', productId);
      }
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },
  };
}
