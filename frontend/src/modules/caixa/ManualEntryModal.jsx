import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { reaisToCents, formatCents } from '../../shared/money.js';
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
  // Erros por campo (amount/description) ficam junto do input que falhou;
  // `form` é reservado para falhas que não pertencem a um campo específico
  // (idempotency key expirada, papel sem permissão, rede fora do ar).
  const [fieldErrors, setFieldErrors] = useState({ amount: null, description: null, form: null });

  // reaisToCents faz manipulação de string (não `* 100`) e trunca qualquer
  // dígito decimal além do segundo em vez de rejeitar (ex.: "10,999" vira
  // R$ 10,99 silenciosamente) — mostrar o valor já interpretado antes do
  // envio dá ao usuário a chance de perceber que não é o que ele quis dizer.
  const parsedAmountCents = reaisToCents(amountReais);
  const amountPreview =
    amountReais.trim() !== '' && Number.isInteger(parsedAmountCents) && parsedAmountCents > 0
      ? `Confirma ${formatCents(parsedAmountCents)}`
      : undefined;

  function validate() {
    const amountCents = reaisToCents(amountReais);
    const errors = {
      amount: !Number.isInteger(amountCents) || amountCents <= 0 ? 'Informe um valor maior que zero.' : null,
      description: description.trim().length === 0 ? 'Informe uma descrição para o lançamento.' : null,
      form: null,
    };
    return { amountCents, errors };
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const { amountCents, errors } = validate();
    if (errors.amount || errors.description) {
      setFieldErrors(errors);
      return;
    }
    setSubmitting(true);
    setFieldErrors({ amount: null, description: null, form: null });
    try {
      await apiClient.post(
        '/cash-entries/manual',
        { kind, amount_cents: amountCents, description: description.trim() },
        { headers: { 'Idempotency-Key': idempotencyKey } },
      );
      onCreated();
    } catch (err) {
      setFieldErrors({ amount: null, description: null, form: messageForCashEntryError(err) });
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal title="Novo lançamento" onClose={submitting ? () => {} : onClose}>
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
          error={fieldErrors.amount}
          helperText={amountPreview}
          required
        />
        <Input
          label="Descrição"
          type="text"
          value={description}
          onChange={(event) => setDescription(event.target.value)}
          error={fieldErrors.description}
          required
        />

        {fieldErrors.form && <p className="form-error" role="alert">{fieldErrors.form}</p>}

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
