import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { messageForCheckoutError } from './comandaErrors.js';
import { Button } from '../../ui/primitives/Button.jsx';
import { Input } from '../../ui/primitives/Input.jsx';
import { Select } from '../../ui/primitives/Select.jsx';

const REASONS = [
  ['item_correction', 'Correção de item'],
  ['pricing_error', 'Erro de preço'],
  ['professional_correction', 'Correção de profissional'],
  ['payment_correction', 'Correção de pagamento'],
  ['inventory_correction', 'Correção de estoque'],
  ['other', 'Outro'],
];

export function ReopenModal({ order, apiClient, onClose, onReopened }) {
  const [reasonCode, setReasonCode] = useState('item_correction');
  const [reasonDetail, setReasonDetail] = useState('');
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event) {
    event.preventDefault();
    if (!reasonDetail.trim()) {
      setError('Descreva o motivo da reabertura.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const request = await apiClient.post(
        `/orders/${order.id}/reopen-request`,
        { reason_code: reasonCode, reason_detail: reasonDetail.trim() },
        { headers: { 'Idempotency-Key': crypto.randomUUID() } },
      );
      await apiClient.post(
        `/orders/${order.id}/reopen`,
        { reopen_attempt_id: request.reopen_attempt_id },
        { headers: { 'Idempotency-Key': crypto.randomUUID() } },
      );
      onReopened();
    } catch (err) {
      setError(messageForCheckoutError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal size="md" title="Reabrir comanda" onClose={submitting ? () => {} : onClose}>
      <form className="auth-form" onSubmit={handleSubmit}>
        <p className="section-hint">A reabertura reverte a versão atual de forma auditável. Nenhum valor é calculado no navegador.</p>
        <Select label="Motivo" value={reasonCode} onChange={(event) => setReasonCode(event.target.value)}>
          {REASONS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </Select>
        <Input label="Descrição" value={reasonDetail} onChange={(event) => setReasonDetail(event.target.value)} />
        {error && <p className="form-error" role="alert">{error}</p>}
        <div className="modal-actions">
          <Button variant="secondary" onClick={onClose} disabled={submitting}>Cancelar</Button>
          <Button type="submit" disabled={submitting} isLoading={submitting}>Confirmar reabertura</Button>
        </div>
      </form>
    </Modal>
  );
}
