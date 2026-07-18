import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { reaisToCents } from '../../shared/money.js';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';
import { basisPointsToPercentString, percentStringToBasisPoints } from './commission.js';

// Todo serviço pertence a um grupo (cascata de comissão profissional>serviço>
// grupo só termina se houver um padrão de grupo) — este é o fundamento da
// cascata, criado antes de qualquer serviço poder existir.
export function ServiceGroupModal({ mode, group, apiClient, onClose, onSaved }) {
  const [name, setName] = useState(group?.name ?? '');
  const [commissionType, setCommissionType] = useState(group?.default_commission_type ?? 'percentage');
  const [commissionValue, setCommissionValue] = useState(
    group
      ? group.default_commission_type === 'percentage'
        ? basisPointsToPercentString(group.default_commission_value)
        : (group.default_commission_value / 100).toFixed(2)
      : '',
  );
  const [active, setActive] = useState(group?.active ?? true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    const value = commissionType === 'percentage' ? percentStringToBasisPoints(commissionValue) : reaisToCents(commissionValue);
    if (!name.trim() || value === null) {
      setError('Preencha nome e comissão padrão válidos.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const payload = {
        name: name.trim(),
        default_commission_type: commissionType,
        default_commission_value: value,
        ...(mode === 'edit' ? { active } : {}),
      };
      const { service_group: saved } =
        mode === 'edit'
          ? await apiClient.patch(`/service-groups/${group.id}`, payload)
          : await apiClient.post('/service-groups', payload);
      onSaved(saved);
    } catch (err) {
      setError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE } }));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal onClose={onClose}>
      <h2>{mode === 'edit' ? 'Editar grupo de serviço' : 'Novo grupo de serviço'}</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Nome
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label>
            Tipo de comissão padrão
            <select value={commissionType} onChange={(event) => setCommissionType(event.target.value)}>
              <option value="percentage">Percentual</option>
              <option value="fixed">Valor fixo</option>
            </select>
          </label>
          <label>
            {commissionType === 'percentage' ? 'Comissão padrão (%)' : 'Comissão padrão (R$)'}
            <input
              inputMode="decimal"
              value={commissionValue}
              onChange={(event) => setCommissionValue(event.target.value)}
              required
            />
          </label>

          {mode === 'edit' && (
            <label className="inline-checkbox">
              <input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />
              Ativo
            </label>
          )}

          {error && <p className="form-error">{error}</p>}

          <div className="modal-actions">
            <button type="button" className="link-button" onClick={onClose}>
              Fechar
            </button>
            <button type="submit" disabled={submitting}>
              {mode === 'edit' ? 'Salvar' : 'Criar grupo'}
            </button>
          </div>
        </form>
    </Modal>
  );
}
