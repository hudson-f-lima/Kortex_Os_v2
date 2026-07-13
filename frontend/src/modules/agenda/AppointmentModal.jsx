import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ApiError } from '../../shared/apiClient.js';
import { ClientPicker } from '../../shared/ClientPicker.jsx';
import { ACTIVE_STATUSES, statusLabel } from './appointmentStatus.js';
import { addMinutes, fromDateTimeLocalValue, toDateTimeLocalValue } from './dateUtils.js';

const ERROR_MESSAGES = {
  professional_double_booked: 'Este profissional já tem um agendamento nesse horário.',
  invalid_client_id: 'Cliente inválido para esta organização.',
  invalid_professional_id: 'Profissional inválido para esta organização.',
  invalid_service_id: 'Serviço inválido para esta organização.',
  invalid_time_range: 'O horário de término deve ser depois do início.',
};

function messageForError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    return ERROR_MESSAGES[err.code] ?? err.message;
  }
  return 'Erro inesperado. Tente novamente.';
}

// Cria e edita agendamentos (docs/PWA_PLANEJAMENTO.md §5.1/§5.3): cliente
// buscável ou criado inline, serviço define o término automaticamente
// (duration_minutes), profissional pré-preenchido quando aberto a partir de
// um slot da grade. Reaproveitado tanto para "novo" quanto para "mover"
// (reagendar = editar horário/profissional de um existente).
export function AppointmentModal({
  mode,
  initialValues,
  professionals,
  services,
  clients,
  canWrite,
  apiClient,
  onClose,
  onSaved,
  onClientCreated,
}) {
  const navigate = useNavigate();
  const [clientId, setClientId] = useState(initialValues.client_id ?? '');
  const [professionalId, setProfessionalId] = useState(initialValues.professional_id ?? '');
  const [serviceId, setServiceId] = useState(initialValues.service_id ?? '');
  const [startValue, setStartValue] = useState(
    initialValues.starts_at ? toDateTimeLocalValue(initialValues.starts_at) : '',
  );
  const [status, setStatus] = useState(initialValues.status ?? 'scheduled');
  const [confirmingCancel, setConfirmingCancel] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const selectedService = services.find((service) => service.id === serviceId);

  const computedEnd = useMemo(() => {
    const start = fromDateTimeLocalValue(startValue);
    if (!start || !selectedService) return null;
    return addMinutes(start, selectedService.duration_minutes);
  }, [startValue, selectedService]);

  async function handleSubmit(event) {
    event.preventDefault();
    const start = fromDateTimeLocalValue(startValue);
    if (!clientId || !professionalId || !serviceId || !start || !computedEnd) {
      setError('Preencha cliente, profissional, serviço e horário.');
      return;
    }

    setSubmitting(true);
    setError(null);
    try {
      const payload = {
        client_id: clientId,
        professional_id: professionalId,
        service_id: serviceId,
        starts_at: start.toISOString(),
        ends_at: computedEnd.toISOString(),
      };
      const appointment =
        mode === 'edit'
          ? (await apiClient.patch(`/appointments/${initialValues.id}`, { ...payload, status })).appointment
          : (await apiClient.post('/appointments', payload)).appointment;
      onSaved(appointment);
    } catch (err) {
      setError(messageForError(err));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleCancelAppointment() {
    setSubmitting(true);
    setError(null);
    try {
      const { appointment } = await apiClient.patch(`/appointments/${initialValues.id}`, { status: 'cancelled' });
      onSaved(appointment);
    } catch (err) {
      setError(messageForError(err));
      setSubmitting(false);
    }
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h2>{mode === 'edit' ? 'Editar agendamento' : 'Novo agendamento'}</h2>

        <form className="auth-form" onSubmit={handleSubmit}>
          <ClientPicker
            clients={clients}
            value={clientId}
            onChange={setClientId}
            apiClient={apiClient}
            onClientCreated={onClientCreated}
            disabled={!canWrite}
          />

          <label>
            Profissional
            <select
              aria-label="Selecionar profissional"
              value={professionalId}
              onChange={(event) => setProfessionalId(event.target.value)}
              disabled={!canWrite}
              required
            >
              <option value="">Selecione um profissional</option>
              {professionals.map((professional) => (
                <option key={professional.id} value={professional.id}>
                  {professional.name}
                </option>
              ))}
            </select>
          </label>

          <label>
            Serviço
            <select
              aria-label="Selecionar serviço"
              value={serviceId}
              onChange={(event) => setServiceId(event.target.value)}
              disabled={!canWrite}
              required
            >
              <option value="">Selecione um serviço</option>
              {services.map((service) => (
                <option key={service.id} value={service.id}>
                  {service.name} ({service.duration_minutes} min)
                </option>
              ))}
            </select>
          </label>

          <label>
            Início
            <input
              type="datetime-local"
              value={startValue}
              onChange={(event) => setStartValue(event.target.value)}
              disabled={!canWrite}
              required
            />
          </label>

          <p className="agenda-computed-end">
            Término: {computedEnd ? computedEnd.toLocaleString('pt-BR') : '—'} (calculado pela duração do serviço)
          </p>

          {mode === 'edit' && (
            <label>
              Status
              <select value={status} onChange={(event) => setStatus(event.target.value)} disabled={!canWrite}>
                {ACTIVE_STATUSES.map((value) => (
                  <option key={value} value={value}>
                    {statusLabel(value)}
                  </option>
                ))}
              </select>
            </label>
          )}

          {error && <p className="form-error">{error}</p>}

          <div className="modal-actions">
            <button type="button" className="link-button" onClick={onClose}>
              Fechar
            </button>
            {canWrite && (
              <button type="submit" disabled={submitting}>
                {mode === 'edit' ? 'Salvar alterações' : 'Criar agendamento'}
              </button>
            )}
          </div>

          {canWrite && mode === 'edit' && status !== 'cancelled' && (
            <div className="modal-actions">
              <button type="button" onClick={() => navigate(`/comanda?appointment_id=${initialValues.id}`)}>
                Abrir comanda
              </button>
              {!confirmingCancel ? (
                <button type="button" className="danger-button" onClick={() => setConfirmingCancel(true)}>
                  Cancelar agendamento
                </button>
              ) : (
                <>
                  <span>Confirma o cancelamento?</span>
                  <button type="button" className="danger-button" disabled={submitting} onClick={handleCancelAppointment}>
                    Confirmar
                  </button>
                  <button type="button" className="link-button" onClick={() => setConfirmingCancel(false)}>
                    Voltar
                  </button>
                </>
              )}
            </div>
          )}
        </form>
      </div>
    </div>
  );
}
