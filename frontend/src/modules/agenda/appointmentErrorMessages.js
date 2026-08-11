// Mapeia códigos de erro de negócio do PATCH /appointments/:id (ver
// backend/src/modules/appointments/appointments.service.js e a RPC
// update_appointment) para mensagens em pt-BR. Compartilhado entre o
// AppointmentModal (edição via formulário) e o drag-to-reschedule da grade
// (AgendaPage/TimelineView) — os dois batem no mesmo endpoint e podem
// receber os mesmos códigos.
export const APPOINTMENT_ERROR_MESSAGES = {
  professional_double_booked: 'Este profissional já tem um agendamento nesse horário.',
  reference_not_found: 'Um dos itens selecionados não foi encontrado para esta organização.',
  professional_not_eligible_for_service: 'Este profissional não está habilitado para este serviço.',
  version_conflict: 'Este agendamento foi alterado por outro usuário. Feche e abra de novo para ver a versão mais recente.',
  invalid_time_range: 'O horário de término deve ser depois do início.',
};
