// Compara current (snapshot de antes do PATCH) com proposed (o que a RPC
// resolveria se confirmado) — ADR 0013 change plan. Extraído do
// AppointmentModal para ser reaproveitado pela confirmação de
// drag-to-reschedule da grade (AgendaPage/TimelineView): os dois batem no
// mesmo PATCH /appointments/:id e podem receber o mesmo 409
// confirmation_required.
export function ChangeDiff({ diff, professionals, services, onConfirm, onCancel, submitting }) {
  const nameFor = (list, id) => list.find((item) => item.id === id)?.name ?? '—';

  function formatDateTime(value) {
    if (!value) return '—';
    return new Date(value).toLocaleString('pt-BR');
  }

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
