import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, client_id, professional_id, service_id, starts_at, ends_at, status, created_at, updated_at';

const REFERENCE_FIELDS = [
  { patchKey: 'client_id', table: 'clients', label: 'client' },
  { patchKey: 'professional_id', table: 'professionals', label: 'professional' },
  { patchKey: 'service_id', table: 'services', label: 'service' },
];

export function createAppointmentsService(supabaseAdmin) {
  async function assertReferencesBelongToOrg(organizationId, patch) {
    await Promise.all(
      REFERENCE_FIELDS.map(async ({ patchKey, table, label }) => {
        const id = patch[patchKey];
        if (id === undefined) return;
        const { data, error } = await supabaseAdmin
          .from(table)
          .select('id')
          .eq('organization_id', organizationId)
          .eq('id', id)
          .maybeSingle();
        if (error) throw mapPostgresError(error);
        if (!data) {
          throw HttpError.badRequest(
            `invalid_${patchKey}`,
            `${patchKey} must reference an existing ${label} in this organization`,
          );
        }
      }),
    );
  }

  // Resolves the duration that governs an appointment's ends_at: a
  // professional×service capability override (Fase 10) wins over the
  // service's own default, mirroring private.resolve_commission's
  // "more specific wins" cascade already used by checkout_close.
  async function resolveDurationMinutes(organizationId, professionalId, serviceId) {
    const { data: capability, error: capabilityError } = await supabaseAdmin
      .from('professional_service_capabilities')
      .select('duration_override_minutes')
      .eq('organization_id', organizationId)
      .eq('professional_id', professionalId)
      .eq('service_id', serviceId)
      .eq('active', true)
      .maybeSingle();
    if (capabilityError) throw mapPostgresError(capabilityError);
    if (capability?.duration_override_minutes) return capability.duration_override_minutes;

    const { data: service, error: serviceError } = await supabaseAdmin
      .from('services')
      .select('duration_minutes')
      .eq('organization_id', organizationId)
      .eq('id', serviceId)
      .maybeSingle();
    if (serviceError) throw mapPostgresError(serviceError);
    if (!service) {
      throw HttpError.badRequest('invalid_service_id', 'service_id must reference an existing service in this organization');
    }
    return service.duration_minutes;
  }

  async function computeEndsAt(organizationId, professionalId, serviceId, startsAt) {
    const durationMinutes = await resolveDurationMinutes(organizationId, professionalId, serviceId);
    return new Date(new Date(startsAt).getTime() + durationMinutes * 60000).toISOString();
  }

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

    async create({ organizationId, actorUserId, patch }) {
      await assertReferencesBelongToOrg(organizationId, patch);
      const endsAt = await computeEndsAt(organizationId, patch.professional_id, patch.service_id, patch.starts_at);
      const { data, error } = await supabaseAdmin
        .from('appointments')
        .insert({ organization_id: organizationId, created_by: actorUserId, ...patch, ends_at: endsAt })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, appointmentId, patch }) {
      await assertReferencesBelongToOrg(organizationId, patch);

      // ends_at only depends on professional_id/service_id/starts_at — recompute
      // it whenever any of those three change, falling back to the row's
      // current values for whichever ones the patch left untouched.
      const touchesDuration =
        patch.professional_id !== undefined || patch.service_id !== undefined || patch.starts_at !== undefined;
      if (touchesDuration) {
        const { data: existing, error: fetchError } = await supabaseAdmin
          .from('appointments')
          .select('professional_id, service_id, starts_at')
          .eq('organization_id', organizationId)
          .eq('id', appointmentId)
          .maybeSingle();
        if (fetchError) throw mapPostgresError(fetchError);
        if (!existing) throw HttpError.notFound('appointment_not_found', 'appointment not found');

        patch.ends_at = await computeEndsAt(
          organizationId,
          patch.professional_id ?? existing.professional_id,
          patch.service_id ?? existing.service_id,
          patch.starts_at ?? existing.starts_at,
        );
      }

      const { data, error } = await supabaseAdmin
        .from('appointments')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', appointmentId)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('appointment_not_found', 'appointment not found');
      return data;
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
