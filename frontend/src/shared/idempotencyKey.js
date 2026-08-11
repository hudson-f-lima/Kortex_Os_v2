// Chave usada no header Idempotency-Key de POST/PATCH mutáveis (ADR 0012).
// Compartilhado entre o formulário do AppointmentModal e o
// drag-to-reschedule da grade (AgendaPage) — os dois disparam o mesmo
// PATCH /appointments/:id e não podem duplicar essa geração.
export function newIdempotencyKey(prefix = 'appt') {
  return `${prefix}-${crypto.randomUUID()}`;
}
