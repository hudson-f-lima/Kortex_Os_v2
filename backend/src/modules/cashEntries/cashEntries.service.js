import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, order_id, kind, amount_cents, description, created_at';

// Read-only: cash_entries rows are only ever created by the checkout_close
// RPC (kind = 'sale'). There is no RPC yet for manual income/expense/refund
// entries, so the API does not expose writes here.
export function createCashEntriesService(supabaseAdmin) {
  return {
    async list({ organizationId, kind }) {
      let query = supabaseAdmin
        .from('cash_entries')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: false });
      if (kind !== undefined) {
        query = query.eq('kind', kind);
      }
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },
  };
}
