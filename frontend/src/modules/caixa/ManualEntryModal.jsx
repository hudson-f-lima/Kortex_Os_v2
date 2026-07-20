import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { reaisToCents } from '../../shared/money.js';
import { messageForCashEntryError } from './cashEntryErrors.js';
import { Button } from '../../ui/primitives/Button.jsx';
import { Input } from '../../ui/primitives/Input.jsx';
import { Select } from '../../ui/primitives/Select.jsx';

const KINDS = [
  { value: 'income', label: 'Entrada' },
  { value: 'expense', label: 'Saída' },
];

// Idempotency-Key gerada uma vez por tentativa e reaproveitada só em
// reenvios da mesma tentativa (mesmo padrão de AdjustmentModal.jsx) —
// reabrir o modal (nova tentativa do usuário) gera uma chave nova.
export function ManualEntryModal({ apiClient, onClose, onCreated }) {
  const [kind, setKind] = useState('income');
  const [amountReais, setAmountReais] = useState('');
  const [description, setDescription] = useState('');
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    const amountCents = reaisToCents(amountReais);
    if (!Number.isInteger(amountCents) || amountCents <= 0) {
      setError('Informe um valor maior que zero.');
      return;
    }
    if (description.trim().length === 0) {
      setError('Informe uma descrição para o lançamento.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await apiClient.post(
        '/cash-entries/manual',
        { kind, amount_cents: amountCents, description: description.trim() },
        { headers: { 'Idempotency-Key': idempotencyKey } },
      );
      onCreated();
    } catch (err) {
      setError(messageForCashEntryError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal onClose={submitting ? () => {} : onClose}>
      <h2>Novo lançamento</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <Select label="Tipo" value={kind} onChange={(event) => setKind(event.target.value)}>
            {KINDS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </Select>
          <Input
            label="Valor (R$)"
            type="text"
            inputMode="decimal"
            value={amountReais}
            placeholder="0,00"
            onChange={(event) => setAmountReais(event.target.value)}
            required
          />
          <Input label="Descrição" type="text" value={description} onChange={(event) => setDescription(event.target.value)} required />

          {error && <p className="form-error" role="alert">{error}</p>}

          <div className="modal-actions">
            <Button variant="secondary" onClick={onClose} disabled={submitting}>
              Fechar
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Lançando…' : 'Confirmar lançamento'}
            </Button>
          </div>
        </form>
    </Modal>
  );
}
