import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const COLUMNS = 'user_id, role, active, created_at';

export function createMembershipsService(supabaseAdmin) {
  return {
    async list({ organizationId }) {
      const { data, error } = await supabaseAdmin
        .from('memberships')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .order('created_at', { ascending: true });
      if (error) throw mapPostgresError(error);
      return data;
    },

    async set({ organizationId, actorUserId, targetUserId, role, active }) {
      const { data, error } = await supabaseAdmin.rpc('membership_set', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_target_user_id: targetUserId,
        p_role: role,
        p_active: active,
      });
      if (error) throw mapRpcError(error);
      return data;
    },
  };
}
