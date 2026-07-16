import { useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';

function messageForError(err) {
  if (err instanceof ApiError) {
    if (err.code === 'already_exists') return 'Este profissional já tem uma capacidade cadastrada para este serviço.';
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    return err.message;
  }
  return 'Erro inesperado. Tente novamente.';
}

function toIntOrNull(value) {
  if (value === '' || value === null || value === undefined) return null;
  return Number(value);
}

// Cria/edita uma capacidade profissional×serviço (Fase 10). professional_id/
// service_id são a identidade da capacidade — o backend só os aceita no
// create; o PATCH rejeita esses campos (mesma regra de professional_service_commissions:
// mudar a identidade é apagar uma capacidade e criar outra, não um patch).
export function CapabilityModal({ capability, professionals, services, apiClient, onClose, onSaved }) {
  const [professionalId, setProfessionalId] = useState(capability?.professional_id ?? '');
  const [serviceId, setServiceId] = useState(capability?.service_id ?? '');
  const [durationOverride, setDurationOverride] = useState(capability?.duration_override_minutes ?? '');
  const [bufferBefore, setBufferBefore] = useState(capability?.buffer_before_min ?? 0);
  const [bufferAfter, setBufferAfter] = useState(capability?.buffer_after_min ?? 0);
  const [priceOverride, setPriceOverride] = useState(capability?.price_override_cents ?? '');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  function validate() {
    if (!capability && !professionalId) return 'Selecione um profissional.';
    if (!capability && !serviceId) return 'Selecione um serviço.';
    if (durationOverride !== '') {
      const dur = Number(durationOverride);
      if (!Number.isInteger(dur) || dur < 5 || dur > 1440) return 'Duração deve ser um número inteiro entre 5 e 1440 minutos.';
    }
    for (const [label, value] of [
      ['Buffer antes', bufferBefore],
      ['Buffer depois', bufferAfter],
    ]) {
      const num = Number(value);
      if (!Number.isInteger(num) || num < 0 || num > 480) return `${label} deve ser um número inteiro entre 0 e 480 minutos.`;
    }
    if (priceOverride !== '') {
      const price = Number(priceOverride);
      if (!Number.isInteger(price) || price < 0) return 'Preço deve ser um número inteiro não negativo, em centavos.';
    }
    return null;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }

    setSubmitting(true);
    setError(null);
    try {
      const patch = {
        duration_override_minutes: toIntOrNull(durationOverride),
        buffer_before_min: Number(bufferBefore),
        buffer_after_min: Number(bufferAfter),
        price_override_cents: toIntOrNull(priceOverride),
      };
      const { professional_service_capability: saved } = capability
        ? await apiClient.patch(`/professional-service-capabilities/${capability.id}`, patch)
        : await apiClient.post('/professional-service-capabilities', { professional_id: professionalId, service_id: serviceId, ...patch });
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
        <h2>{capability ? 'Editar capacidade' : 'Nova capacidade'}</h2>
        <form className="auth-form" onSubmit={handleSubmit} noValidate>
          <label>
            Profissional
            <select
              value={professionalId}
              onChange={(event) => setProfessionalId(event.target.value)}
              disabled={!!capability}
              required
            >
              <option value="">Selecione um profissional</option>
              {professionals?.map((professional) => (
                <option key={professional.id} value={professional.id}>
                  {professional.name}
                </option>
              ))}
            </select>
          </label>

          <label>
            Serviço
            <select value={serviceId} onChange={(event) => setServiceId(event.target.value)} disabled={!!capability} required>
              <option value="">Selecione um serviço</option>
              {services?.map((service) => (
                <option key={service.id} value={service.id}>
                  {service.name}
                </option>
              ))}
            </select>
          </label>

          <label>
            Duração customizada (minutos)
            <input
              type="number"
              min="5"
              max="1440"
              value={durationOverride}
              onChange={(event) => setDurationOverride(event.target.value)}
              placeholder="Padrão do serviço"
            />
          </label>

          <label>
            Preço customizado (centavos)
            <input
              type="number"
              min="0"
              value={priceOverride}
              onChange={(event) => setPriceOverride(event.target.value)}
              placeholder="Padrão do serviço"
            />
          </label>

          <label>
            Buffer antes (minutos)
            <input type="number" min="0" max="480" value={bufferBefore} onChange={(event) => setBufferBefore(event.target.value)} />
          </label>

          <label>
            Buffer depois (minutos)
            <input type="number" min="0" max="480" value={bufferAfter} onChange={(event) => setBufferAfter(event.target.value)} />
          </label>

          {error && <p className="form-error">{error}</p>}

          <div className="modal-actions">
            <button type="button" className="link-button" onClick={onClose}>
              Fechar
            </button>
            <button type="submit" disabled={submitting}>
              {submitting ? 'Salvando…' : 'Salvar'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
