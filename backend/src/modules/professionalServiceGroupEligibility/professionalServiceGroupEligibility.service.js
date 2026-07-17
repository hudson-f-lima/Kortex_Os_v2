import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, organization_id, professional_id, service_group_id, eligibility, created_at, updated_at';

const REFERENCE_FIELDS = [
  { patchKey: 'professional_id', table: 'professionals', label: 'professional' },
  { patchKey: 'service_group_id', table: 'service_groups', label: 'service group' },
];

export function createProfessionalServiceGroupEligibilityService(supabaseAdmin) {
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
    async list({ organizationId, professionalId, serviceGroupId }) {
      let query = supabaseAdmin
        .from('professional_service_group_eligibility')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: false });
      if (professionalId !== undefined) query = query.eq('professional_id', professionalId);
      if (serviceGroupId !== undefined) query = query.eq('service_group_id', serviceGroupId);
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, id }) {
      const { data, error } = await supabaseAdmin
        .from('professional_service_group_eligibility')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', id)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) {
        throw HttpError.notFound('group_eligibility_not_found', 'professional service group eligibility not found');
      }
      return data;
    },

    async create({ organizationId, patch }) {
      await assertReferencesBelongToOrg(organizationId, patch);
      const { data, error } = await supabaseAdmin
        .from('professional_service_group_eligibility')
        .insert({ organization_id: organizationId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, id, patch }) {
      const { data, error } = await supabaseAdmin
        .from('professional_service_group_eligibility')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', id)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) {
        throw HttpError.notFound('group_eligibility_not_found', 'professional service group eligibility not found');
      }
      return data;
    },

    async remove({ organizationId, id }) {
      const { data, error } = await supabaseAdmin
        .from('professional_service_group_eligibility')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', id)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) {
        throw HttpError.notFound('group_eligibility_not_found', 'professional service group eligibility not found');
      }
    },
  };
}
