import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { messageForInventoryError } from './inventoryErrors.js';

const REASONS = [
  { value: 'purchase', label: 'Compra/reposição' },
  { value: 'adjustment', label: 'Ajuste (contagem, perda, quebra)' },
  { value: 'return', label: 'Devolução' },
];

// Espelha o invariante do RPC (migration: "p_reason in ('purchase','return')
// and p_quantity_delta < 0" é rejeitado) — só 'adjustment' aceita saída
// negativa (perda/quebra); compra/devolução sempre entram estoque.
const REASONS_REQUIRING_POSITIVE_DELTA = new Set(['purchase', 'return']);

// Idempotency-Key gerada uma vez por tentativa de ajuste e reaproveitada só
// em reenvios da mesma tentativa (docs/PWA_PLANEJAMENTO.md §4.3) — reabrir o
// modal (nova tentativa do usuário) gera uma chave nova.
export function AdjustmentModal({ product, apiClient, onClose, onAdjusted }) {
  const [quantityDelta, setQuantityDelta] = useState('');
  const [reason, setReason] = useState('purchase');
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    const delta = Number(quantityDelta);
    if (!Number.isInteger(delta) || delta === 0) {
      setError('Informe uma quantidade inteira diferente de zero (negativa para saída).');
      return;
    }
    if (REASONS_REQUIRING_POSITIVE_DELTA.has(reason) && delta < 0) {
      setError('Compra e devolução só aceitam entrada de estoque (quantidade positiva). Use "Ajuste" para saída.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await apiClient.post(
        '/inventory/adjustments',
        { product_id: product.id, quantity_delta: delta, reason },
        { headers: { 'Idempotency-Key': idempotencyKey } },
      );
      onAdjusted();
    } catch (err) {
      setError(messageForInventoryError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal onClose={submitting ? () => {} : onClose}>
      <h2>Ajustar estoque — {product.name}</h2>
        <p className="section-hint">Estoque atual: {product.stock_on_hand}</p>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Quantidade (negativa para saída)
            <input
              type="number"
              value={quantityDelta}
              onChange={(event) => setQuantityDelta(event.target.value)}
              required
            />
          </label>
          <label>
            Motivo
            <select value={reason} onChange={(event) => setReason(event.target.value)}>
              {REASONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>

          {error && <p className="form-error">{error}</p>}

          <div className="modal-actions">
            <button type="button" className="link-button" onClick={onClose} disabled={submitting}>
              Fechar
            </button>
            <button type="submit" disabled={submitting}>
              {submitting ? 'Ajustando…' : 'Confirmar ajuste'}
            </button>
          </div>
        </form>
    </Modal>
  );
}
