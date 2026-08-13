import { useEffect, useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { formatCents } from '../../shared/money.js';
import { messageForCheckoutError } from './comandaErrors.js';
import { Button } from '../../ui/primitives/Button.jsx';

function asRecloseItem(item) {
  if (item.product_id) {
    return { kind: 'product', id: item.product_id, quantity: item.quantity };
  }
  return {
    kind: 'service',
    id: item.service_id,
    quantity: item.quantity,
    professional_id: item.professional_id,
  };
}

// A refinalização nunca calcula preço, estoque ou delta financeiro no cliente.
// A PWA só reconstrói um payload explícito a partir do pedido ainda reaberto e
// delega toda validação/contabilização ao único comando HTTP do backend.
export function RecloseModal({ order, apiClient, onClose, onReclosed }) {
  const [fullOrder, setFullOrder] = useState(null);
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [idempotencyKey] = useState(() => crypto.randomUUID());

  useEffect(() => {
    let active = true;
    apiClient
      .get(`/orders/${order.id}`)
      .then(({ order: loaded }) => {
        if (active) setFullOrder(loaded);
      })
      .catch((err) => {
        if (active) setError(messageForCheckoutError(err));
      });
    return () => {
      active = false;
    };
  }, [apiClient, order.id]);

  async function handleSubmit(event) {
    event.preventDefault();
    if (!fullOrder?.reopen_attempt_id) {
      setError('Esta tentativa de reabertura não está mais disponível. Atualize a lista de comandas.');
      return;
    }

    setSubmitting(true);
    setError(null);
    try {
      await apiClient.post(
        `/orders/${order.id}/reclose`,
        {
          reopen_attempt_id: fullOrder.reopen_attempt_id,
          client_id: fullOrder.client_id,
          items: fullOrder.items.map(asRecloseItem),
          payments: fullOrder.payments.map(({ method, amount_cents }) => ({ method, amount_cents })),
          discount_cents: fullOrder.discount_cents,
          tip_cents: fullOrder.tip_cents,
        },
        { headers: { 'Idempotency-Key': idempotencyKey } },
      );
      onReclosed();
    } catch (err) {
      setError(messageForCheckoutError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal size="md" title="Refinalizar comanda" onClose={submitting ? () => {} : onClose}>
      {!fullOrder && !error && <p>Carregando a revisão reaberta…</p>}
      {fullOrder && (
        <form className="auth-form" onSubmit={handleSubmit}>
          <p className="section-hint">
            A revisão atual será validada novamente no servidor. Estoque, preço, comissão, livro razão e a diferença de caixa
            são recalculados de forma atômica.
          </p>
          <ul className="record-list" aria-label="Itens da revisão reaberta">
            {fullOrder.items.map((item) => (
              <li key={item.id} className="record-list-item">
                <span>{item.description} × {item.quantity}</span>
                <strong>{formatCents(item.total_cents)}</strong>
              </li>
            ))}
          </ul>
          <p className="comanda-total">Total revisado: {formatCents(fullOrder.total_cents)}</p>

          {error && <p className="form-error" role="alert">{error}</p>}

          <div className="modal-actions">
            <Button variant="secondary" onClick={onClose} disabled={submitting}>Cancelar</Button>
            <Button type="submit" disabled={submitting} isLoading={submitting}>Confirmar refinalização</Button>
          </div>
        </form>
      )}
      {!fullOrder && error && (
        <div className="modal-actions">
          <Button variant="secondary" onClick={onClose}>Fechar</Button>
        </div>
      )}
    </Modal>
  );
}
