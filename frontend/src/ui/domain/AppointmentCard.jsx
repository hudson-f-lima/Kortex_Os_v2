import { statusLabel } from '../../modules/agenda/appointmentStatus.js';
import './AppointmentCard.css';

// draggable/dragging/saving/onDragPointerDown existem pro drag-to-reschedule
// da TimelineView (AgendaPage.jsx) — copiado do comportamento grátis do
// plugin `interaction` do FullCalendar (eventDrop), via Pointer Events em vez
// de HTML5 drag-and-drop nativo (que não funciona bem em touch/mobile).
export function AppointmentCard({
  appointment,
  clientName,
  serviceName,
  onAppointmentClick,
  top,
  height,
  draggable = false,
  dragging = false,
  saving = false,
  onDragPointerDown,
}) {
  // O height e top vem em porcentagem ou pixels baseados na timeline

  // Status classes: confirmed, pending, in-progress, completed, canceled, no-show
  const statusClass = `k-appt-card--${appointment.status}`;

  // Se for < 45 min, o card fica mais compacto, podemos esconder alguns dados
  const isCompact = height && parseInt(height, 10) < 60; // dependendo de como calcular height

  const classNames = [
    'k-appt-card',
    statusClass,
    isCompact ? 'k-appt-card--compact' : '',
    draggable ? 'k-appt-card--draggable' : '',
    dragging ? 'k-appt-card--dragging' : '',
    saving ? 'k-appt-card--saving' : '',
  ].filter(Boolean).join(' ');

  function handlePointerDown(event) {
    if (!draggable) return;
    try {
      event.currentTarget.setPointerCapture(event.pointerId);
    } catch {
      // setPointerCapture pode não existir (jsdom/navegadores antigos) — a
      // captura só evita perder eventos em movimentos rápidos, não é
      // essencial pro drag funcionar.
    }
    onDragPointerDown?.(event);
  }

  return (
    <button
      type="button"
      className={classNames}
      style={{ top, height }}
      onClick={(e) => onAppointmentClick(e)}
      onPointerDown={draggable ? handlePointerDown : undefined}
      aria-busy={saving}
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
