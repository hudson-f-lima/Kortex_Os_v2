import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const COLUMNS =
  'id, organization_id, client_id, professional_id, service_id, starts_at, ends_at, status, version, resolved_duration_minutes, resolved_eligibility_source, resolved_at, created_at, updated_at';

export function createAppointmentsService(supabaseAdmin) {
  return {
    async list({ organizationId, professionalId, clientId, status, from, to }) {
      let query = supabaseAdmin
        .from('appointments')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .order('starts_at', { ascending: true });
      if (professionalId !== undefined) query = query.eq('professional_id', professionalId);
      if (clientId !== undefined) query = query.eq('client_id', clientId);
      if (status !== undefined) query = query.eq('status', status);
      if (from !== undefined) query = query.gte('starts_at', from);
      if (to !== undefined) query = query.lt('starts_at', to);
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, appointmentId }) {
      const { data, error } = await supabaseAdmin
        .from('appointments')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', appointmentId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('appointment_not_found', 'appointment not found');
      return data;
    },

    // Rota B (ADR 0012): absorve elegibilidade (ADR 0010), snapshot (ADR 0011)
    // e idempotência atômica dentro de create_appointment — mesma arquitetura
    // de checkout_close, não mais um insert direto do Express.
    async create({ organizationId, actorUserId, idempotencyKey, patch }) {
      const { data, error } = await supabaseAdmin.rpc('create_appointment', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_payload: patch,
      });
      if (error) throw mapRpcError(error);
      return data.appointment;
    },

    // update_appointment pode responder com status='confirmation_required'
    // (ADR 0013 change plan) em vez de aplicar — nesse caso não houve
    // mutação nenhuma, e o 409 carrega o diff para o cliente decidir.
    async update({ organizationId, actorUserId, appointmentId, idempotencyKey, patch }) {
      const { data, error } = await supabaseAdmin.rpc('update_appointment', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_appointment_id: appointmentId,
        p_payload: patch,
      });
      if (error) throw mapRpcError(error);
      if (data.status === 'confirmation_required') {
        throw HttpError.conflict(
          'confirmation_required',
          'changing professional_id/service_id needs confirmation — review diff and retry with confirm=true',
          data.diff,
        );
      }
      return data.appointment;
    },

    async remove({ organizationId, appointmentId }) {
      const { data, error } = await supabaseAdmin
        .from('appointments')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', appointmentId)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('appointment_not_found', 'appointment not found');
    },
  };
}
