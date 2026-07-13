import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, name, default_commission_type, default_commission_value, active, created_at, updated_at';

export function createServiceGroupsService(supabaseAdmin) {
  return {
    async list({ organizationId, active }) {
      let query = supabaseAdmin
        .from('service_groups')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .order('name', { ascending: true });
      if (active !== undefined) {
        query = query.eq('active', active);
      }
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, serviceGroupId }) {
      const { data, error } = await supabaseAdmin
        .from('service_groups')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', serviceGroupId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('service_group_not_found', 'service group not found');
      return data;
    },

    async create({ organizationId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('service_groups')
        .insert({ organization_id: organizationId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, serviceGroupId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('service_groups')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', serviceGroupId)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('service_group_not_found', 'service group not found');
      return data;
    },

    async remove({ organizationId, serviceGroupId }) {
      const { data, error } = await supabaseAdmin
        .from('service_groups')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', serviceGroupId)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('service_group_not_found', 'service group not found');
    },
  };
}
