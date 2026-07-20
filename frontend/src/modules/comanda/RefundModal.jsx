import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { formatCents } from '../../shared/money.js';
import { messageForRefundError } from './comandaErrors.js';
import { Button } from '../../ui/primitives/Button.jsx';
import { Select } from '../../ui/primitives/Select.jsx';

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
    <Modal onClose={submitting ? () => {} : onClose}>
      <h2>Estornar comanda</h2>
        <p className="section-hint">
          Pedido #{order.id.slice(0, 8)} · {formatCents(order.total_cents)}
        </p>
        <form className="auth-form" onSubmit={handleSubmit}>
          <Select 
            label="Motivo do estorno" 
            value={reason} 
            onChange={(event) => setReason(event.target.value)} 
            required
          >
            <option value="" disabled>Selecione um motivo</option>
            {REASONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </Select>

          {error && <p className="form-error" role="alert">{error}</p>}

          <div className="modal-actions">
            <Button variant="secondary" onClick={onClose} disabled={submitting}>
              Fechar
            </Button>
            <Button type="submit" disabled={submitting || !reason}>
              {submitting ? 'Estornando…' : 'Confirmar estorno'}
            </Button>
          </div>
        </form>
    </Modal>
  );
}
