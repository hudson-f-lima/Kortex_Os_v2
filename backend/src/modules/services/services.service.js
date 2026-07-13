import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, name, price_cents, duration_minutes, active, created_at, updated_at';

export function createServicesService(supabaseAdmin) {
  return {
    async list({ organizationId, active }) {
      let query = supabaseAdmin
        .from('services')
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

    async get({ organizationId, serviceId }) {
      const { data, error } = await supabaseAdmin
        .from('services')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', serviceId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('service_not_found', 'service not found');
      return data;
    },

    async create({ organizationId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('services')
        .insert({ organization_id: organizationId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, serviceId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('services')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', serviceId)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('service_not_found', 'service not found');
      return data;
    },

    async remove({ organizationId, serviceId }) {
      const { data, error } = await supabaseAdmin
        .from('services')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', serviceId)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('service_not_found', 'service not found');
    },
  };
}
