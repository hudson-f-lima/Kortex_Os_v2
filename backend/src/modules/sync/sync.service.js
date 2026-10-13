import { mapPostgresError } from '../../shared/postgresError.js';

const ORG_WIDE_ROLES = new Set(['owner', 'admin', 'manager']);
const TRANSACTIONAL_TABLES = new Set([
  'appointments',
  'orders',
  'order_items',
  'payments',
  'inventory_movements',
  'cash_entries',
]);

export function canAccessSyncEvent(event, auth) {
  if (ORG_WIDE_ROLES.has(auth.role)) return true;
  if (auth.role === 'reception') {
    return !TRANSACTIONAL_TABLES.has(event.table_name) || event.payload?.unit_id === auth.unitId;
  }
  if (auth.role === 'professional') {
    if (event.table_name === 'clients') return false;
    if (event.table_name === 'professionals') {
      return auth.professionalId !== undefined && event.payload?.id === auth.professionalId;
    }
    if (
      event.table_name === 'professional_service_capabilities' ||
      event.table_name === 'professional_service_commissions'
    ) {
      return (
        auth.professionalId !== undefined &&
        event.payload?.professional_id === auth.professionalId
      );
    }
    if (!TRANSACTIONAL_TABLES.has(event.table_name)) return true;
    if (event.table_name !== 'appointments' || event.payload?.unit_id !== auth.unitId) return false;
    return (
      auth.permissions.includes('schedule:view_all') ||
      (auth.professionalId !== undefined && event.payload?.professional_id === auth.professionalId)
    );
  }
  return false;
}

export function createSyncService(supabaseAdmin) {
  return {
    async listEvents({ organizationId, sinceId, auth }) {
      const { data, error } = await supabaseAdmin
        .from('sync_events')
        .select('id, table_name, record_id, action, payload, created_at')
        .eq('organization_id', organizationId)
        .gt('id', sinceId)
        .order('id', { ascending: true });

      if (error) throw mapPostgresError(error);
      return data.filter((event) => canAccessSyncEvent(event, auth));
    }
  };
}
