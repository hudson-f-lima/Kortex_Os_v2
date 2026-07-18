import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const PROFESSIONAL_COLUMNS = 'id, name, user_id, active, created_at, updated_at';

// Mapeia erros da Admin API do GoTrue (auth.admin.inviteUserByEmail), que tem
// um shape diferente de erro do PostgREST/RPC (AuthError: { message, status,
// code }, sem sqlstate) — não passa por mapPostgresError/mapRpcError.
function mapInviteAuthError(error) {
  if (error.status === 422 || error.code === 'email_exists') {
    return HttpError.conflict('email_already_invited', 'this email is already registered');
  }
  return HttpError.badRequest('invite_failed', error.message ?? 'failed to send invite');
}

export function createConvitesService(supabaseAdmin, env) {
  async function assertProfessionalIsUnclaimed(organizationId, professionalId) {
    const { data, error } = await supabaseAdmin
      .from('professionals')
      .select('id, user_id')
      .eq('organization_id', organizationId)
      .eq('id', professionalId)
      .maybeSingle();
    if (error) throw mapPostgresError(error);
    if (!data) {
      throw HttpError.badRequest('professional_not_found', 'professionalId must reference an existing professional in this organization');
    }
    if (data.user_id) {
      throw HttpError.conflict('professional_already_linked', 'this professional is already linked to a user');
    }
  }

  return {
    async invite({ organizationId, actorUserId, email, role, professionalId, professionalName }) {
      if (professionalId) {
        await assertProfessionalIsUnclaimed(organizationId, professionalId);
      }

      const { data: inviteData, error: inviteError } = await supabaseAdmin.auth.admin.inviteUserByEmail(email, {
        redirectTo: env.siteUrl,
      });
      if (inviteError) throw mapInviteAuthError(inviteError);
      const newUserId = inviteData.user.id;

      const { error: membershipError } = await supabaseAdmin.rpc('membership_set', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_target_user_id: newUserId,
        p_role: role,
        p_active: true,
      });
      if (membershipError) throw mapRpcError(membershipError);

      let professional = null;
      if (role === 'professional' && professionalId) {
        const { data, error } = await supabaseAdmin
          .from('professionals')
          .update({ user_id: newUserId })
          .eq('organization_id', organizationId)
          .eq('id', professionalId)
          .is('user_id', null)
          .select(PROFESSIONAL_COLUMNS)
          .maybeSingle();
        if (error) throw mapPostgresError(error);
        if (!data) {
          throw HttpError.conflict('professional_already_linked', 'this professional was linked to another user concurrently');
        }
        professional = data;
      } else if (role === 'professional' && professionalName) {
        const { data, error } = await supabaseAdmin
          .from('professionals')
          .insert({ organization_id: organizationId, user_id: newUserId, name: professionalName })
          .select(PROFESSIONAL_COLUMNS)
          .single();
        if (error) throw mapPostgresError(error);
        professional = data;
      }

      return { userId: newUserId, email, role, professional };
    },
  };
}
