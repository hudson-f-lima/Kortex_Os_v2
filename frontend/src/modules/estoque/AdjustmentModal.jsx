import { useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';

const REASONS = [
  { value: 'purchase', label: 'Compra/reposição' },
  { value: 'adjustment', label: 'Ajuste (contagem, perda, quebra)' },
  { value: 'return', label: 'Devolução' },
];

function messageForError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    return err.message;
  }
  return 'Erro inesperado. Tente novamente.';
}

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
      setError(messageForError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
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
      </div>
    </div>
  );
}
