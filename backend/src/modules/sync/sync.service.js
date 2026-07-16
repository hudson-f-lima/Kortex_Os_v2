import { mapPostgresError } from '../../shared/postgresError.js';

export function createSyncService(supabaseAdmin) {
  return {
    async listEvents({ organizationId, sinceId }) {
      const { data, error } = await supabaseAdmin
        .from('sync_events')
        .select('id, table_name, record_id, action, payload, created_at')
        .eq('organization_id', organizationId)
        .gt('id', sinceId)
        .order('id', { ascending: true });

      if (error) throw mapPostgresError(error);
      return data;
    }
  };
}
