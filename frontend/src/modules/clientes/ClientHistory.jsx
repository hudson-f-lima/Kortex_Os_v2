import { useEffect, useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { statusLabel } from '../agenda/appointmentStatus.js';

function messageForError(err) {
  if (err instanceof ApiError) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

// Perfil do cliente como registro vivo (docs/PWA_PLANEJAMENTO.md §2.3): dado
// operacional (histórico de agendamentos via GET /appointments?client_id=)
// junto do cadastro, num só lugar. O backend não expõe gasto agregado nem
// preferências/observações — não inventadas aqui.
export function ClientHistory({ client, apiClient, onClose }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [appointments, setAppointments] = useState([]);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    apiClient
      .get(`/appointments?client_id=${client.id}`)
      .then(({ appointments: data }) => {
        if (cancelled) return;
        setAppointments([...data].sort((a, b) => new Date(b.starts_at) - new Date(a.starts_at)));
      })
      .catch((err) => {
        if (cancelled) return;
        setError(messageForError(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [apiClient, client.id]);

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h2>{client.name}</h2>
        <p className="client-history-contact">
          {client.phone || '—'}
          {client.email ? ` · ${client.email}` : ''}
        </p>

        <h3>Histórico de agendamentos</h3>
        {loading && <p>Carregando histórico…</p>}
        {!loading && error && <p className="form-error">{error}</p>}
        {!loading && !error && appointments.length === 0 && <p className="list-empty">Nenhum agendamento ainda.</p>}
        {!loading && !error && appointments.length > 0 && (
          <ul className="record-list">
            {appointments.map((appointment) => (
              <li key={appointment.id} className="record-list-item">
                <span className="record-list-main">
                  {new Date(appointment.starts_at).toLocaleString('pt-BR')} · {statusLabel(appointment.status)}
                </span>
              </li>
            ))}
          </ul>
        )}

        <div className="modal-actions">
          <button type="button" className="link-button" onClick={onClose}>
            Fechar
          </button>
        </div>
      </div>
    </div>
  );
}
