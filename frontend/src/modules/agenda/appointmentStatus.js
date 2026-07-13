// Espelha appointments.validation.js (APPOINTMENT_STATUSES) do backend.
export const STATUS_LABELS = {
  scheduled: 'Agendado',
  confirmed: 'Confirmado',
  in_service: 'Em atendimento',
  completed: 'Concluído',
  cancelled: 'Cancelado',
  no_show: 'Não compareceu',
};

// Só estes bloqueiam o slot na exclusion constraint do banco
// (appointments: `where (status in ('scheduled','confirmed','in_service'))`).
export const BLOCKING_STATUSES = ['scheduled', 'confirmed', 'in_service'];

export const ACTIVE_STATUSES = Object.keys(STATUS_LABELS);

export function statusLabel(status) {
  return STATUS_LABELS[status] ?? status;
}
