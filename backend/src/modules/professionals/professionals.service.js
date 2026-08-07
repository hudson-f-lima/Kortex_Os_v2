import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const COLUMNS = 'id, name, user_id, active, created_at, updated_at';
const PROFESSIONAL_SELF_COLUMNS = 'id, name, active';

export function createProfessionalsService(supabaseAdmin) {
  async function assertUserIdIsMember(organizationId, userId) {
    if (userId === undefined || userId === null) return;
    const { data, error } = await supabaseAdmin
      .from('memberships')
      .select('user_id')
      .eq('organization_id', organizationId)
      .eq('user_id', userId)
      .maybeSingle();
    if (error) throw mapPostgresError(error);
    if (!data) {
      throw HttpError.badRequest(
        'invalid_user_id',
        'user_id must reference an existing membership in this organization',
      );
    }
  }

  return {
    async list({ organizationId, scopeProfessionalId, active }) {
      if (scopeProfessionalId === null) return [];
      let query = supabaseAdmin
        .from('professionals')
        .select(scopeProfessionalId === undefined ? COLUMNS : PROFESSIONAL_SELF_COLUMNS)
        .eq('organization_id', organizationId)
        .order('name', { ascending: true });
      if (scopeProfessionalId !== undefined) {
        query = query.eq('id', scopeProfessionalId);
      }
      if (active !== undefined) {
        query = query.eq('active', active);
      }
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, scopeProfessionalId, professionalId }) {
      if (scopeProfessionalId === null || (
        scopeProfessionalId !== undefined &&
        scopeProfessionalId !== professionalId
      )) {
        throw HttpError.notFound('professional_not_found', 'professional not found');
      }
      const { data, error } = await supabaseAdmin
        .from('professionals')
        .select(scopeProfessionalId === undefined ? COLUMNS : PROFESSIONAL_SELF_COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', professionalId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('professional_not_found', 'professional not found');
      return data;
    },

    async create({ organizationId, patch }) {
      await assertUserIdIsMember(organizationId, patch.user_id);
      const { data, error } = await supabaseAdmin
        .from('professionals')
        .insert({ organization_id: organizationId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, actorUserId, professionalId, patch }) {
      await assertUserIdIsMember(organizationId, patch.user_id);
      const { data, error } = await supabaseAdmin.rpc('professional_update', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_professional_id: professionalId,
        p_patch: patch,
      });
      if (error?.code === 'P0002' && error.message === 'professional not found in organization') {
        throw HttpError.notFound('professional_not_found', 'professional not found');
      }
      if (error) throw mapRpcError(error);
      return data;
    },

    async remove({ organizationId, actorUserId, professionalId }) {
      const { error } = await supabaseAdmin.rpc('professional_delete', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_professional_id: professionalId,
      });
      if (error?.code === 'P0002') {
        throw HttpError.notFound('professional_not_found', 'professional not found');
      }
      if (error) throw mapRpcError(error);
    },
  };
}
