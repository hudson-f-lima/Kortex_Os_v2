import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ApiError } from '../../shared/apiClient.js';
import { ClientPicker } from '../../shared/ClientPicker.jsx';
import { Modal } from '../../shared/Modal.jsx';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';
import { ACTIVE_STATUSES, statusLabel } from './appointmentStatus.js';
import { addMinutes, fromDateTimeLocalValue, toDateTimeLocalValue } from './dateUtils.js';

const ERROR_MESSAGES = {
  professional_double_booked: 'Este profissional já tem um agendamento nesse horário.',
  reference_not_found: 'Um dos itens selecionados não foi encontrado para esta organização.',
  professional_not_eligible_for_service: 'Este profissional não está habilitado para este serviço.',
  version_conflict: 'Este agendamento foi alterado por outro usuário. Feche e abra de novo para ver a versão mais recente.',
  invalid_time_range: 'O horário de término deve ser depois do início.',
};

function newIdempotencyKey() {
  return `appt-${crypto.randomUUID()}`;
}

function formatDateTime(value) {
  if (!value) return '—';
  return new Date(value).toLocaleString('pt-BR');
}

// Compara current (snapshot do PATCH pouco antes de reconfigurar) com
// proposed (o que a RPC resolveria se confirmado) — ADR 0013 change plan.
function ChangeDiff({ diff, professionals, services, onConfirm, onCancel, submitting }) {
  const nameFor = (list, id) => list.find((item) => item.id === id)?.name ?? '—';

  const rows = [
    {
      label: 'Profissional',
      current: nameFor(professionals, diff.current.professional_id),
      proposed: nameFor(professionals, diff.proposed.professional_id),
    },
    {
      label: 'Serviço',
      current: nameFor(services, diff.current.service_id),
      proposed: nameFor(services, diff.proposed.service_id),
    },
    {
      label: 'Duração',
      current: `${diff.current.resolved_duration_minutes} min`,
      proposed: `${diff.proposed.resolved_duration_minutes} min`,
    },
    {
      label: 'Término',
      current: formatDateTime(diff.current.ends_at),
      proposed: formatDateTime(diff.proposed.ends_at),
    },
  ];

  return (
    <div className="appointment-diff">
      <p>Essa mudança recalcula a duração do agendamento. Confirme antes de aplicar:</p>
      <table className="data-table">
        <thead>
          <tr>
            <th />
            <th>Atual</th>
            <th>Novo</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.label}>
              <td>{row.label}</td>
              <td>{row.current}</td>
              <td>{row.proposed}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="modal-actions">
        <button type="button" className="link-button" onClick={onCancel} disabled={submitting}>
          Voltar
        </button>
        <button type="button" onClick={onConfirm} disabled={submitting}>
          {submitting ? 'Aplicando…' : 'Confirmar mudança'}
        </button>
      </div>
    </div>
  );
}

// Cria e edita agendamentos (docs/PWA_PLANEJAMENTO.md §5.1/§5.3): cliente
// buscável ou criado inline, serviço define o término automaticamente
// (duration_minutes), profissional pré-preenchido quando aberto a partir de
// um slot da grade. Reaproveitado tanto para "novo" quanto para "mover"
// (reagendar = editar horário/profissional de um existente).
//
// PATCH exige Idempotency-Key + version (ADR 0012) e, ao reconfigurar
// professional_id/service_id, pode responder 409 confirmation_required com
// um diff (ADR 0013) — ver ChangeDiff acima.
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
  // { patch, diff } enquanto aguarda confirmação explícita de reconfiguração
  const [pendingChange, setPendingChange] = useState(null);

  const selectedService = services.find((service) => service.id === serviceId);

  const computedEnd = useMemo(() => {
    const start = fromDateTimeLocalValue(startValue);
    if (!start || !selectedService) return null;
    return addMinutes(start, selectedService.duration_minutes);
  }, [startValue, selectedService]);

  function buildEditPatch(start) {
    // Só inclui campos que de fato mudaram — reenviar professional_id/
    // service_id iguais ao valor atual dispararia confirmation_required à
    // toa (ADR 0013 só se aplica a uma reconfiguração real).
    const patch = { version: initialValues.version };
    if (clientId !== initialValues.client_id) patch.client_id = clientId;
    if (professionalId !== initialValues.professional_id) patch.professional_id = professionalId;
    if (serviceId !== initialValues.service_id) patch.service_id = serviceId;
    if (start.toISOString() !== new Date(initialValues.starts_at).toISOString()) patch.starts_at = start.toISOString();
    if (status !== initialValues.status) patch.status = status;
    return patch;
  }

  async function submitPatch(patch) {
    const result = await apiClient.patch(`/appointments/${initialValues.id}`, patch, {
      headers: { 'Idempotency-Key': newIdempotencyKey() },
    });
    return result.appointment;
  }

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
      if (mode === 'edit') {
        const patch = buildEditPatch(start);
        try {
          const appointment = await submitPatch(patch);
          onSaved(appointment);
        } catch (err) {
          if (err instanceof ApiError && err.code === 'confirmation_required') {
            setPendingChange({ patch, diff: err.details });
            return;
          }
          throw err;
        }
      } else {
        const payload = {
          client_id: clientId,
          professional_id: professionalId,
          service_id: serviceId,
          starts_at: start.toISOString(),
        };
        const { appointment } = await apiClient.post('/appointments', payload, {
          headers: { 'Idempotency-Key': newIdempotencyKey() },
        });
        onSaved(appointment);
      }
    } catch (err) {
      setError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE }, codes: ERROR_MESSAGES }));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleConfirmChange() {
    setSubmitting(true);
    setError(null);
    try {
      const appointment = await submitPatch({ ...pendingChange.patch, confirm: true });
      onSaved(appointment);
    } catch (err) {
      setPendingChange(null);
      setError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE }, codes: ERROR_MESSAGES }));
    } finally {
      setSubmitting(false);
    }
  }

  async function handleCancelAppointment() {
    setSubmitting(true);
    setError(null);
    try {
      const appointment = await submitPatch({ status: 'cancelled', version: initialValues.version });
      onSaved(appointment);
    } catch (err) {
      setError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE }, codes: ERROR_MESSAGES }));
      setSubmitting(false);
    }
  }

  if (pendingChange) {
    return (
      <Modal onClose={submitting ? () => {} : () => setPendingChange(null)}>
        <h2>Confirmar alteração</h2>
        {error && <p className="form-error">{error}</p>}
        <ChangeDiff
          diff={pendingChange.diff}
          professionals={professionals}
          services={services}
          submitting={submitting}
          onConfirm={handleConfirmChange}
          onCancel={() => setPendingChange(null)}
        />
      </Modal>
    );
  }

  return (
    <Modal onClose={onClose}>
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
    </Modal>
  );
}
