import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, organization_id, name, phone, email, active, created_at, updated_at';

export function createClientsService(supabaseAdmin) {
  return {
    async list({ organizationId, active }) {
      let query = supabaseAdmin
        .from('clients')
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

    async get({ organizationId, clientId }) {
      const { data, error } = await supabaseAdmin
        .from('clients')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', clientId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('client_not_found', 'client not found');
      return data;
    },

    async create({ organizationId, actorUserId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('clients')
        .insert({ organization_id: organizationId, created_by: actorUserId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, clientId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('clients')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', clientId)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('client_not_found', 'client not found');
      return data;
    },

    async remove({ organizationId, clientId }) {
      const { data, error } = await supabaseAdmin
        .from('clients')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', clientId)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('client_not_found', 'client not found');
    },
  };
}
