import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const ORDER_COLUMNS = 'id, client_id, status, subtotal_cents, discount_cents, total_cents, created_at, closed_at';
const ITEM_COLUMNS = 'id, kind, service_id, product_id, description, quantity, unit_price_cents, total_cents';
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
  };
}
