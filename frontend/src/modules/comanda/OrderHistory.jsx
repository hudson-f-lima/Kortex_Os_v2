import { useCallback, useEffect, useState } from 'react';
import { formatCents } from '../../shared/money.js';
import { messageForError, OFFLINE_FALLBACK } from '../../shared/apiErrorMessage.js';
import { RefundModal } from './RefundModal.jsx';
import { RecloseModal } from './RecloseModal.jsx';
import { ReopenModal } from './ReopenModal.jsx';
import { DiscardReopenModal } from './DiscardReopenModal.jsx';
import { Button } from '../../ui/primitives/Button.jsx';

const STATUS_LABELS = { closed: 'Fechada', reopened: 'Reaberta', refunded: 'Estornada', draft: 'Rascunho', cancelled: 'Cancelada' };

// GET /orders (docs/PWA_PLANEJAMENTO.md §5.2 nunca teve uma UI própria até a
// Fase 9 — a Comanda só escrevia via checkout_close). Lista comandas já
// fechadas para permitir o estorno com motivo obrigatório (ADR 0006).
export function OrderHistory({ apiClient, canRefund, canReclose }) {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [refundingOrder, setRefundingOrder] = useState(null);
  const [reclosingOrder, setReclosingOrder] = useState(null);
  const [reopeningOrder, setReopeningOrder] = useState(null);
  const [discardingOrder, setDiscardingOrder] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { orders: data } = await apiClient.get('/orders');
      setOrders(data);
    } catch (err) {
      setError(messageForError(err, { fallback: OFFLINE_FALLBACK }));
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
        <Button onClick={load}>Tentar novamente</Button>
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
              <Button variant="link" onClick={() => setRefundingOrder(order)}>
                Estornar
              </Button>
            )}
            {canReclose && order.status === 'closed' && (
              <Button variant="link" onClick={() => setReopeningOrder(order)}>
                Reabrir
              </Button>
            )}
            {canReclose && order.status === 'reopened' && (
              <Button variant="link" onClick={() => setReclosingOrder(order)}>
                Refinalizar
              </Button>
            )}
            {canReclose && order.status === 'reopened' && (
              <Button variant="link" onClick={() => setDiscardingOrder(order)}>
                Descartar reabertura
              </Button>
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
      {reclosingOrder && (
        <RecloseModal
          order={reclosingOrder}
          apiClient={apiClient}
          onClose={() => setReclosingOrder(null)}
          onReclosed={() => {
            setReclosingOrder(null);
            load();
          }}
        />
      )}
      {reopeningOrder && (
        <ReopenModal order={reopeningOrder} apiClient={apiClient} onClose={() => setReopeningOrder(null)} onReopened={() => { setReopeningOrder(null); load(); }} />
      )}
      {discardingOrder && (
        <DiscardReopenModal order={discardingOrder} apiClient={apiClient} onClose={() => setDiscardingOrder(null)} onDiscarded={() => { setDiscardingOrder(null); load(); }} />
      )}
    </div>
  );
}
