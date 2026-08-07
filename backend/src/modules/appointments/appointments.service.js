import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const COLUMNS =
  'id, organization_id, unit_id, client_id, professional_id, service_id, starts_at, ends_at, status, version, resolved_duration_minutes, resolved_eligibility_source, resolved_at, created_at, updated_at';

async function resolveAppointmentWriteUnit(supabaseAdmin, organizationId, membershipUnitId) {
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
  if (membershipUnitId !== undefined && membershipUnitId !== defaultUnit.id) {
    throw HttpError.conflict(
      'unit_write_not_supported',
      'this command cannot target a non-default unit until its server-side unit contract is promoted',
    );
  }
  return defaultUnit.id;
}

async function assertProfessionalAvailableInUnit(supabaseAdmin, organizationId, unitId, professionalId) {
  const { data, error } = await supabaseAdmin
    .from('professional_units')
    .select('professional_id')
    .eq('organization_id', organizationId)
    .eq('unit_id', unitId)
    .eq('professional_id', professionalId)
    .eq('active', true)
    .maybeSingle();
  if (error) throw mapPostgresError(error);
  if (!data) {
    const { data: professional, error: professionalError } = await supabaseAdmin
      .from('professionals')
      .select('id')
      .eq('organization_id', organizationId)
      .eq('id', professionalId)
      .maybeSingle();
    if (professionalError) throw mapPostgresError(professionalError);
    if (!professional) {
      throw HttpError.badRequest(
        'reference_not_found',
        'one or more referenced records do not exist in this organization',
      );
    }
    throw HttpError.badRequest(
      'professional_not_available_in_unit',
      'professional must have an active link to the appointment unit',
    );
  }
}

export function createAppointmentsService(supabaseAdmin) {
  return {
    async list({ organizationId, unitId, professionalId, clientId, status, from, to }) {
      if (professionalId === null) return [];
      let query = supabaseAdmin
        .from('appointments')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .order('starts_at', { ascending: true });
      if (unitId !== undefined) query = query.eq('unit_id', unitId);
      if (professionalId !== undefined) query = query.eq('professional_id', professionalId);
      if (clientId !== undefined) query = query.eq('client_id', clientId);
      if (status !== undefined) query = query.eq('status', status);
      if (from !== undefined) query = query.gte('starts_at', from);
      if (to !== undefined) query = query.lt('starts_at', to);
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, unitId, professionalId, appointmentId }) {
      if (professionalId === null) {
        throw HttpError.notFound('appointment_not_found', 'appointment not found');
      }
      let query = supabaseAdmin
        .from('appointments')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', appointmentId);
      if (unitId !== undefined) query = query.eq('unit_id', unitId);
      if (professionalId !== undefined) query = query.eq('professional_id', professionalId);
      const { data, error } = await query.maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('appointment_not_found', 'appointment not found');
      return data;
    },

    // Rota B (ADR 0012): absorve elegibilidade (ADR 0010), snapshot (ADR 0011)
    // e idempotência atômica dentro de create_appointment — mesma arquitetura
    // de checkout_close, não mais um insert direto do Express.
    async create({ organizationId, unitId, actorUserId, idempotencyKey, patch }) {
      const writeUnitId = await resolveAppointmentWriteUnit(supabaseAdmin, organizationId, unitId);
      await assertProfessionalAvailableInUnit(
        supabaseAdmin,
        organizationId,
        writeUnitId,
        patch.professional_id,
      );
      const { data, error } = await supabaseAdmin.rpc('create_appointment', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_payload: patch,
      });
      if (error) throw mapRpcError(error);

      // deposit_hold_create (issues/003-deposit-holds-creation.md) is a
      // separate, additive RPC — create_appointment itself is untouched. It
      // no-ops (status: 'skipped') when the service has no deposit policy.
      const { data: holdResult, error: holdError } = await supabaseAdmin.rpc('deposit_hold_create', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_appointment_id: data.appointment.id,
      });
      if (holdError) throw mapRpcError(holdError);

      return {
        appointment: data.appointment,
        depositHold: holdResult.status === 'created' ? holdResult.deposit_hold : null,
      };
    },

    // update_appointment pode responder com status='confirmation_required'
    // (ADR 0013 change plan) em vez de aplicar — nesse caso não houve
    // mutação nenhuma, e o 409 carrega o diff para o cliente decidir.
    async update({ organizationId, unitId, actorUserId, appointmentId, idempotencyKey, patch }) {
      let scopeQuery = supabaseAdmin
        .from('appointments')
        .select('id, unit_id')
        .eq('organization_id', organizationId)
        .eq('id', appointmentId);
      if (unitId !== undefined) scopeQuery = scopeQuery.eq('unit_id', unitId);
      const { data: scopedAppointment, error: scopeError } = await scopeQuery.maybeSingle();
      if (scopeError) throw mapPostgresError(scopeError);
      if (!scopedAppointment) throw HttpError.notFound('appointment_not_found', 'appointment not found');
      if (patch.professional_id !== undefined) {
        await assertProfessionalAvailableInUnit(
          supabaseAdmin,
          organizationId,
          scopedAppointment.unit_id,
          patch.professional_id,
        );
      }

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

      // The lifecycle trigger settles an active hold in the *same* transaction
      // as the status transition. Read its durable order back for the existing
      // HTTP contract; never call the former second-step settlement RPC here.
      let noShowSettlement = null;
      if (patch.status === 'no_show') {
        const { data: order, error: orderError } = await supabaseAdmin
          .from('orders')
          .select('id, total_cents')
          .eq('organization_id', organizationId)
          .eq('appointment_id', appointmentId)
          .eq('status', 'closed')
          .maybeSingle();
        if (orderError) throw mapPostgresError(orderError);
        if (order) {
          const { data: item, error: itemError } = await supabaseAdmin
            .from('order_items')
            .select('commission_cents')
            .eq('organization_id', organizationId)
            .eq('order_id', order.id)
            .maybeSingle();
          if (itemError) throw mapPostgresError(itemError);
          noShowSettlement = {
            status: 'settled',
            order_id: order.id,
            amount_cents: order.total_cents,
            commission_cents: item?.commission_cents ?? 0,
          };
        }
      }

      return { appointment: data.appointment, noShowSettlement };
    },

    async replan({ organizationId, unitId, actorUserId, appointmentId, idempotencyKey, patch }) {
      let scopeQuery = supabaseAdmin
        .from('appointments')
        .select('id, unit_id')
        .eq('organization_id', organizationId)
        .eq('id', appointmentId);
      if (unitId !== undefined) scopeQuery = scopeQuery.eq('unit_id', unitId);
      const { data: scopedAppointment, error: scopeError } = await scopeQuery.maybeSingle();
      if (scopeError) throw mapPostgresError(scopeError);
      if (!scopedAppointment) throw HttpError.notFound('appointment_not_found', 'appointment not found');

      if (patch.professional_id !== undefined) {
        await assertProfessionalAvailableInUnit(
          supabaseAdmin,
          organizationId,
          scopedAppointment.unit_id,
          patch.professional_id,
        );
      }

      const { data, error } = await supabaseAdmin.rpc('appointment_replan_with_hold', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_appointment_id: appointmentId,
        p_payload: patch,
      });
      if (error) throw mapRpcError(error);
      return {
        appointment: data.appointment,
        releasedHoldId: data.released_hold_id,
        depositHold: data.deposit_hold,
      };
    },

    async remove({ organizationId, unitId, appointmentId }) {
      let query = supabaseAdmin
        .from('appointments')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', appointmentId);
      if (unitId !== undefined) query = query.eq('unit_id', unitId);
      const { data, error } = await query.select('id').maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('appointment_not_found', 'appointment not found');
    },
  };
}
