import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const ORDER_COLUMNS =
  'id, client_id, status, subtotal_cents, discount_cents, tip_cents, total_cents, refund_reason, created_at, closed_at';
const ITEM_COLUMNS =
  'id, kind, service_id, product_id, description, quantity, unit_price_cents, total_cents, ' +
  'professional_id, commission_type, commission_value, commission_cents';
const PAYMENT_COLUMNS = 'id, method, amount_cents, created_at';

export function createOrdersService(supabaseAdmin) {
  return {
    async list({ organizationId }) {
      const { data, error } = await supabaseAdmin
        .from('orders')
        .select(ORDER_COLUMNS)
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: false });
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, orderId }) {
      const { data: order, error } = await supabaseAdmin
        .from('orders')
        .select(ORDER_COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', orderId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!order) throw HttpError.notFound('order_not_found', 'order not found');

      const [itemsResult, paymentsResult] = await Promise.all([
        supabaseAdmin
          .from('order_items')
          .select(ITEM_COLUMNS)
          .eq('organization_id', organizationId)
          .eq('order_id', orderId),
        supabaseAdmin
          .from('payments')
          .select(PAYMENT_COLUMNS)
          .eq('organization_id', organizationId)
          .eq('order_id', orderId),
      ]);
      if (itemsResult.error) throw mapPostgresError(itemsResult.error);
      if (paymentsResult.error) throw mapPostgresError(paymentsResult.error);

      return { ...order, items: itemsResult.data, payments: paymentsResult.data };
    },

    async refund({ organizationId, actorUserId, orderId, idempotencyKey, reason }) {
      const { data, error } = await supabaseAdmin.rpc('order_refund', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_order_id: orderId,
        p_reason: reason,
      });
      if (error) throw mapRpcError(error);
      return data;
    },
  };
}
