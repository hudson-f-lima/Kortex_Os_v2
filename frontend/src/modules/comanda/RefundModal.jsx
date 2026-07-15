import { useState } from 'react';
import { formatCents } from '../../shared/money.js';
import { messageForRefundError } from './comandaErrors.js';

// Taxonomia mínima do ADR 0006 — motivo obrigatório, nunca um valor
// default: correção operacional (erro de digitação da recepção) é um void
// que não usa esta RPC (depende de cash_sessions, fora de escopo da Fase 9).
const REASONS = [
  { value: 'customer_cancellation', label: 'Desistência do cliente' },
  { value: 'customer_default', label: 'Inadimplência do cliente' },
];

// Idempotency-Key gerada uma vez por tentativa (mesmo padrão de
// AdjustmentModal.jsx/ManualEntryModal.jsx) — reabrir o modal gera uma nova.
export function RefundModal({ order, apiClient, onClose, onRefunded }) {
  const [reason, setReason] = useState('');
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    if (!reason) {
      setError('Selecione o motivo do estorno.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await apiClient.post(
        `/orders/${order.id}/refund`,
        { reason },
        { headers: { 'Idempotency-Key': idempotencyKey } },
      );
      onRefunded();
    } catch (err) {
      setError(messageForRefundError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h2>Estornar comanda</h2>
        <p className="section-hint">
          Pedido #{order.id.slice(0, 8)} · {formatCents(order.total_cents)}
        </p>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Motivo do estorno
            <select value={reason} onChange={(event) => setReason(event.target.value)} required>
              <option value="" disabled>
                Selecione um motivo
              </option>
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
            <button type="submit" disabled={submitting || !reason}>
              {submitting ? 'Estornando…' : 'Confirmar estorno'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
