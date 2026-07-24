import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const COLUMNS = 'user_id, role, unit_id, active, created_at';
const UNIT_SCOPED_ROLES = new Set(['reception', 'professional']);

export function createMembershipsService(supabaseAdmin) {
  async function resolveUnitId(organizationId, role) {
    if (!UNIT_SCOPED_ROLES.has(role)) return null;
    const { data, error } = await supabaseAdmin
      .from('units')
      .select('id')
      .eq('organization_id', organizationId)
      .eq('is_default', true)
      .eq('active', true)
      .single();
    if (error) throw mapPostgresError(error);
    return data.id;
  }

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
      const unitId = await resolveUnitId(organizationId, role);
      const { data, error } = await supabaseAdmin.rpc('membership_scope_set', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_target_user_id: targetUserId,
        p_role: role,
        p_unit_id: unitId,
        p_active: active,
      });
      if (error) throw mapRpcError(error);
      return data;
    },
  };
}
