import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

async function assertCheckoutWriteUnit(supabaseAdmin, organizationId, membershipUnitId) {
  if (membershipUnitId === undefined) return;

  const { data: defaultUnit, error } = await supabaseAdmin
    .from('units')
    .select('id')
    .eq('organization_id', organizationId)
    .eq('is_default', true)
    .eq('active', true)
    .maybeSingle();
  if (error) throw mapPostgresError(error);
  if (!defaultUnit) {
    throw HttpError.conflict('active_default_unit_required', 'organization has no active default unit');
  }
  if (membershipUnitId !== defaultUnit.id) {
    throw HttpError.conflict(
      'unit_write_not_supported',
      'checkout cannot target a non-default unit until checkout_close accepts an explicit server-owned unit',
    );
  }
}

async function getScopedAppointment(supabaseAdmin, organizationId, membershipUnitId, appointmentId) {
  let query = supabaseAdmin
    .from('appointments')
    .select('id, unit_id')
    .eq('organization_id', organizationId)
    .eq('id', appointmentId);
  if (membershipUnitId !== undefined) query = query.eq('unit_id', membershipUnitId);
  const { data, error } = await query.maybeSingle();
  if (error) throw mapPostgresError(error);
  if (!data) throw HttpError.notFound('appointment_not_found', 'appointment not found');
  return data;
}

export function createCheckoutService(supabaseAdmin) {
  return {
    async close({ organizationId, unitId, actorUserId, idempotencyKey, payload }) {
      await assertCheckoutWriteUnit(supabaseAdmin, organizationId, unitId);
      const { data, error } = await supabaseAdmin.rpc('checkout_close', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_payload: payload,
      });
      if (error) throw mapRpcError(error);
      return data;
    },

    async closeAppointment({ organizationId, unitId, actorUserId, idempotencyKey, appointmentId, payload }) {
      // Scope before the privileged RPC: a unit-scoped membership must not be
      // able to discover or act on an occurrence from another unit.
      await getScopedAppointment(supabaseAdmin, organizationId, unitId, appointmentId);
      const { data, error } = await supabaseAdmin.rpc('checkout_close_appointment', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_appointment_id: appointmentId,
        p_payload: payload,
      });
      if (error) throw mapRpcError(error);
      // An expired hold is intentionally persisted by the RPC before it
      // returns this terminal result; returning HTTP 201 would falsely imply
      // that an order was created.
      if (data?.status === 'deposit_expired') {
        throw HttpError.conflict('deposit_hold_expired', 'deposit hold has expired');
      }
      return data;
    },
  };
}
