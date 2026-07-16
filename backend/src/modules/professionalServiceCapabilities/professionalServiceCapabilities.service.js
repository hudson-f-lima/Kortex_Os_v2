import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS =
  'id, organization_id, professional_id, service_id, duration_override_minutes, buffer_before_min, buffer_after_min, price_override_cents, active, created_at, updated_at';

const REFERENCE_FIELDS = [
  { patchKey: 'professional_id', table: 'professionals', label: 'professional' },
  { patchKey: 'service_id', table: 'services', label: 'service' },
];

export function createProfessionalServiceCapabilitiesService(supabaseAdmin) {
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
    async list({ organizationId, professionalId, serviceId }) {
      let query = supabaseAdmin
        .from('professional_service_capabilities')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: false });
      if (professionalId !== undefined) query = query.eq('professional_id', professionalId);
      if (serviceId !== undefined) query = query.eq('service_id', serviceId);
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, id }) {
      const { data, error } = await supabaseAdmin
        .from('professional_service_capabilities')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', id)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) {
        throw HttpError.notFound('capability_not_found', 'professional service capability not found');
      }
      return data;
    },

    async create({ organizationId, patch }) {
      await assertReferencesBelongToOrg(organizationId, patch);
      const { data, error } = await supabaseAdmin
        .from('professional_service_capabilities')
        .insert({ organization_id: organizationId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, id, patch }) {
      const { data, error } = await supabaseAdmin
        .from('professional_service_capabilities')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', id)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) {
        throw HttpError.notFound('capability_not_found', 'professional service capability not found');
      }
      return data;
    },

    async remove({ organizationId, id }) {
      const { data, error } = await supabaseAdmin
        .from('professional_service_capabilities')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', id)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) {
        throw HttpError.notFound('capability_not_found', 'professional service capability not found');
      }
    },
  };
}
