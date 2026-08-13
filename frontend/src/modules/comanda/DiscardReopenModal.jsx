import { useEffect, useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { messageForCheckoutError } from './comandaErrors.js';
import { Button } from '../../ui/primitives/Button.jsx';

export function DiscardReopenModal({ order, apiClient, onClose, onDiscarded }) {
  const [attemptId, setAttemptId] = useState(null);
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    let active = true;
    apiClient.get(`/orders/${order.id}`)
      .then(({ order: loaded }) => { if (active) setAttemptId(loaded.reopen_attempt_id); })
      .catch((err) => { if (active) setError(messageForCheckoutError(err)); });
    return () => { active = false; };
  }, [apiClient, order.id]);

  async function handleDiscard() {
    if (!attemptId) return;
    setSubmitting(true);
    setError(null);
    try {
      await apiClient.post(`/orders/${order.id}/reopen-discard`, { reopen_attempt_id: attemptId }, { headers: { 'Idempotency-Key': crypto.randomUUID() } });
      onDiscarded();
    } catch (err) {
      setError(messageForCheckoutError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal size="sm" title="Descartar reabertura" onClose={submitting ? () => {} : onClose}>
      <p className="section-hint">Isso restaura a versão anterior sem criar nova venda ou estorno.</p>
      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="modal-actions">
        <Button variant="secondary" onClick={onClose} disabled={submitting}>Cancelar</Button>
        <Button variant="danger" onClick={handleDiscard} disabled={!attemptId || submitting} isLoading={submitting}>Descartar reabertura</Button>
      </div>
    </Modal>
  );
}
