import { statusLabel } from '../../modules/agenda/appointmentStatus.js';
import './AppointmentCard.css';

export function AppointmentCard({ appointment, clientName, serviceName, onAppointmentClick, top, height }) {
  // O height e top vem em porcentagem ou pixels baseados na timeline
  
  // Status classes: confirmed, pending, in-progress, completed, canceled, no-show
  const statusClass = `k-appt-card--${appointment.status}`;
  
  // Se for < 45 min, o card fica mais compacto, podemos esconder alguns dados
  const isCompact = height && parseInt(height, 10) < 60; // dependendo de como calcular height

  return (
    <button
      type="button"
      className={`k-appt-card ${statusClass} ${isCompact ? 'k-appt-card--compact' : ''}`}
      style={{ top, height }}
      onClick={(e) => onAppointmentClick(e)}
    >
      <div className="k-appt-card__status-bar" />
      <div className="k-appt-card__content">
        <div className="k-appt-card__header">
          <span className="k-appt-card__time">
            {new Date(appointment.starts_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
          </span>
          <span className="k-appt-card__status-text">{statusLabel(appointment.status)}</span>
        </div>
        <div className="k-appt-card__client">{clientName}</div>
        {!isCompact && <div className="k-appt-card__service text-supporting">{serviceName}</div>}
      </div>
    </button>
  );
}
