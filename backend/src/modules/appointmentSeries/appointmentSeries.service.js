import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

export function createAppointmentSeriesService(supabaseAdmin) {
  async function invoke({ rpc, organizationId, actorUserId, idempotencyKey, payload }) {
    const { data, error } = await supabaseAdmin.rpc(rpc, {
      p_organization_id: organizationId,
      p_actor_user_id: actorUserId,
      p_idempotency_key: idempotencyKey,
      p_payload: payload,
    });
    if (error) throw mapRpcError(error);
    return data;
  }

  return {
    async getSeriesUnit({ organizationId, seriesId }) {
      const { data, error } = await supabaseAdmin
        .from('appointment_series')
        .select('unit_id')
        .eq('organization_id', organizationId)
        .eq('id', seriesId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('appointment_series_not_found', 'appointment series not found');
      return data.unit_id;
    },
    create(input) {
      return invoke({ ...input, rpc: 'appointment_series_create' });
    },
    extend(input) {
      return invoke({ ...input, rpc: 'appointment_series_extend_window' });
    },
    update(input) {
      return invoke({ ...input, rpc: 'appointment_series_update' });
    },
    cancel(input) {
      return invoke({ ...input, rpc: 'appointment_series_cancel' });
    },
    retryConflict(input) {
      return invoke({ ...input, rpc: 'appointment_series_conflict_retry' });
    },
  };
}
