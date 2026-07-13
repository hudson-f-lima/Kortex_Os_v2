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
      const { data, error } = await supabaseAdmin
        .from('appointments')
        .insert({ organization_id: organizationId, created_by: actorUserId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, appointmentId, patch }) {
      await assertReferencesBelongToOrg(organizationId, patch);
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
