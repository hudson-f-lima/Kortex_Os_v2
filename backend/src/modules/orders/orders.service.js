import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const ORDER_COLUMNS =
  'id, unit_id, client_id, status, current_revision, subtotal_cents, discount_cents, tip_cents, total_cents, refund_reason, created_at, closed_at';
const ITEM_COLUMNS =
  'id, unit_id, kind, service_id, product_id, description, quantity, unit_price_cents, total_cents, ' +
  'professional_id, commission_type, commission_value, commission_cents';
const PAYMENT_COLUMNS = 'id, unit_id, revision_number, method, amount_cents, created_at';

export function createOrdersService(supabaseAdmin) {
  return {
    async list({ organizationId, unitId }) {
      let query = supabaseAdmin
        .from('orders')
        .select(ORDER_COLUMNS)
        .eq('organization_id', organizationId);
      if (unitId !== undefined) query = query.eq('unit_id', unitId);
      const { data, error } = await query.order('created_at', { ascending: false });
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, unitId, orderId }) {
      let orderQuery = supabaseAdmin
        .from('orders')
        .select(ORDER_COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', orderId);
      if (unitId !== undefined) orderQuery = orderQuery.eq('unit_id', unitId);
      const { data: order, error } = await orderQuery.maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!order) throw HttpError.notFound('order_not_found', 'order not found');

      let itemsQuery = supabaseAdmin
          .from('order_items')
          .select(ITEM_COLUMNS)
          .eq('organization_id', organizationId)
          .eq('order_id', orderId);
      let paymentsQuery = supabaseAdmin
          .from('payments')
          .select(PAYMENT_COLUMNS)
          .eq('organization_id', organizationId)
          .eq('order_id', orderId);
      if (unitId !== undefined) {
        itemsQuery = itemsQuery.eq('unit_id', unitId);
        paymentsQuery = paymentsQuery.eq('unit_id', unitId);
      }
      paymentsQuery = paymentsQuery.eq('revision_number', order.current_revision);
      const [itemsResult, paymentsResult] = await Promise.all([itemsQuery, paymentsQuery]);
      if (itemsResult.error) throw mapPostgresError(itemsResult.error);
      if (paymentsResult.error) throw mapPostgresError(paymentsResult.error);

      let reopenAttemptId = null;
      if (order.status === 'reopened') {
        let attemptQuery = supabaseAdmin
          .from('order_reopen_attempts')
          .select('id')
          .eq('organization_id', organizationId)
          .eq('order_id', orderId)
          .eq('status', 'opened');
        if (unitId !== undefined) attemptQuery = attemptQuery.eq('unit_id', unitId);
        const { data: attempt, error: attemptError } = await attemptQuery.maybeSingle();
        if (attemptError) throw mapPostgresError(attemptError);
        reopenAttemptId = attempt?.id ?? null;
      }

      return { ...order, items: itemsResult.data, payments: paymentsResult.data, reopen_attempt_id: reopenAttemptId };
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

    async reclose({ organizationId, unitId, actorUserId, orderId, reopenAttemptId, idempotencyKey, payload }) {
      let scopeQuery = supabaseAdmin
        .from('orders')
        .select('id, unit_id')
        .eq('organization_id', organizationId)
        .eq('id', orderId);
      if (unitId !== undefined) scopeQuery = scopeQuery.eq('unit_id', unitId);
      const { data: order, error: scopeError } = await scopeQuery.maybeSingle();
      if (scopeError) throw mapPostgresError(scopeError);
      if (!order) throw HttpError.notFound('order_not_found', 'order not found');

      const { data, error } = await supabaseAdmin.rpc('order_reclose', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_order_id: orderId,
        p_reopen_attempt_id: reopenAttemptId,
        p_payload: payload,
      });
      if (error) throw mapRpcError(error);
      return data;
    },
  };
}
