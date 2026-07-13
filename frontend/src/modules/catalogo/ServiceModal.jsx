import { useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { reaisToCents } from '../../shared/money.js';
import { basisPointsToPercentString, percentStringToBasisPoints } from './commission.js';

function messageForError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    return err.message;
  }
  return 'Erro inesperado. Tente novamente.';
}

// commission_type/commission_value são um par opcional que sobrepõe o
// padrão do grupo só para este serviço (nível 2 da cascata) — ambos ou
// nenhum, nunca um sem o outro (services.validation.js).
export function ServiceModal({ mode, service, groups, apiClient, onClose, onSaved }) {
  const [name, setName] = useState(service?.name ?? '');
  const [priceReais, setPriceReais] = useState(service ? (service.price_cents / 100).toFixed(2) : '');
  const [durationMinutes, setDurationMinutes] = useState(service?.duration_minutes ?? 30);
  const [groupId, setGroupId] = useState(service?.service_group_id ?? '');
  const [overrideCommission, setOverrideCommission] = useState(Boolean(service?.commission_type));
  const [commissionType, setCommissionType] = useState(service?.commission_type ?? 'percentage');
  const [commissionValue, setCommissionValue] = useState(
    service?.commission_type === 'percentage'
      ? basisPointsToPercentString(service.commission_value)
      : service?.commission_type === 'fixed'
        ? (service.commission_value / 100).toFixed(2)
        : '',
  );
  const [active, setActive] = useState(service?.active ?? true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    const priceCents = reaisToCents(priceReais);
    if (!name.trim() || priceCents === null || !groupId) {
      setError('Preencha nome, preço e grupo de serviço.');
      return;
    }

    let commissionPatch = {};
    if (overrideCommission) {
      const value = commissionType === 'percentage' ? percentStringToBasisPoints(commissionValue) : reaisToCents(commissionValue);
      if (value === null) {
        setError('Informe um valor de comissão válido.');
        return;
      }
      commissionPatch = { commission_type: commissionType, commission_value: value };
    }

    setSubmitting(true);
    setError(null);
    try {
      const payload = {
        name: name.trim(),
        price_cents: priceCents,
        duration_minutes: Number(durationMinutes),
        service_group_id: groupId,
        ...commissionPatch,
        ...(mode === 'edit' ? { active } : {}),
      };
      const { service: saved } =
        mode === 'edit' ? await apiClient.patch(`/services/${service.id}`, payload) : await apiClient.post('/services', payload);
      onSaved(saved);
    } catch (err) {
      setError(messageForError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h2>{mode === 'edit' ? 'Editar serviço' : 'Novo serviço'}</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Nome
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label>
            Preço (R$)
            <input inputMode="decimal" value={priceReais} onChange={(event) => setPriceReais(event.target.value)} required />
          </label>
          <label>
            Duração (minutos)
            <input
              type="number"
              min="5"
              max="1440"
              value={durationMinutes}
              onChange={(event) => setDurationMinutes(event.target.value)}
              required
            />
          </label>
          <label>
            Grupo de serviço
            <select
              aria-label="Selecionar grupo de serviço"
              value={groupId}
              onChange={(event) => setGroupId(event.target.value)}
              required
            >
              <option value="">Selecione um grupo</option>
              {groups.map((group) => (
                <option key={group.id} value={group.id}>
                  {group.name}
                </option>
              ))}
            </select>
          </label>

          <label className="inline-checkbox">
            <input
              type="checkbox"
              checked={overrideCommission}
              onChange={(event) => setOverrideCommission(event.target.checked)}
            />
            Sobrepor comissão do grupo para este serviço
          </label>

          {overrideCommission && (
            <>
              <label>
                Tipo de comissão
                <select value={commissionType} onChange={(event) => setCommissionType(event.target.value)}>
                  <option value="percentage">Percentual</option>
                  <option value="fixed">Valor fixo</option>
                </select>
              </label>
              <label>
                {commissionType === 'percentage' ? 'Comissão (%)' : 'Comissão (R$)'}
                <input
                  inputMode="decimal"
                  value={commissionValue}
                  onChange={(event) => setCommissionValue(event.target.value)}
                />
              </label>
            </>
          )}

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
              {mode === 'edit' ? 'Salvar' : 'Criar serviço'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
