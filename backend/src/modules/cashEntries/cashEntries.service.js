import { mapRpcError } from '../../shared/rpcError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, order_id, kind, amount_cents, description, created_at';

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

    async createManualEntry({ organizationId, actorUserId, idempotencyKey, kind, amountCents, description }) {
      const { data, error } = await supabaseAdmin.rpc('cash_entry_manual', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_idempotency_key: idempotencyKey,
        p_kind: kind,
        p_amount_cents: amountCents,
        p_description: description,
      });
      if (error) throw mapRpcError(error);
      return data;
    },
  };
}
