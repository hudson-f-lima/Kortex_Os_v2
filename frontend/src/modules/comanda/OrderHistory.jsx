import { useCallback, useEffect, useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { formatCents } from '../../shared/money.js';
import { RefundModal } from './RefundModal.jsx';

const STATUS_LABELS = { closed: 'Fechada', refunded: 'Estornada', draft: 'Rascunho', cancelled: 'Cancelada' };

function messageForListError(err) {
  if (err instanceof ApiError) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

// GET /orders (docs/PWA_PLANEJAMENTO.md §5.2 nunca teve uma UI própria até a
// Fase 9 — a Comanda só escrevia via checkout_close). Lista comandas já
// fechadas para permitir o estorno com motivo obrigatório (ADR 0006).
export function OrderHistory({ apiClient, canRefund }) {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [refundingOrder, setRefundingOrder] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { orders: data } = await apiClient.get('/orders');
      setOrders(data);
    } catch (err) {
      setError(messageForListError(err));
    } finally {
      setLoading(false);
    }
  }, [apiClient]);

  useEffect(() => {
    load();
  }, [load]);

  if (loading) return <p>Carregando comandas…</p>;

  if (error) {
    return (
      <div className="full-page-error">
        <p>{error}</p>
        <button type="button" onClick={load}>
          Tentar novamente
        </button>
      </div>
    );
  }

  if (orders.length === 0) {
    return <p className="list-empty">Nenhuma comanda fechada ainda.</p>;
  }

  return (
    <div className="comanda-history">
      <ul className="record-list">
        {orders.map((order) => (
          <li key={order.id} className="record-list-item">
            <span className="record-list-main">
              <strong>{formatCents(order.total_cents)}</strong>
              <span>
                Pedido #{order.id.slice(0, 8)} · {STATUS_LABELS[order.status] ?? order.status} ·{' '}
                {new Date(order.created_at).toLocaleString('pt-BR')}
                {order.status === 'refunded' && order.refund_reason && (
                  <> · motivo: {order.refund_reason === 'customer_cancellation' ? 'desistência' : 'inadimplência'}</>
                )}
              </span>
            </span>
            {canRefund && order.status === 'closed' && (
              <button type="button" className="link-button" onClick={() => setRefundingOrder(order)}>
                Estornar
              </button>
            )}
          </li>
        ))}
      </ul>

      {refundingOrder && (
        <RefundModal
          order={refundingOrder}
          apiClient={apiClient}
          onClose={() => setRefundingOrder(null)}
          onRefunded={() => {
            setRefundingOrder(null);
            load();
          }}
        />
      )}
    </div>
  );
}
