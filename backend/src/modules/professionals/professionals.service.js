import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, name, user_id, active, created_at, updated_at';

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
    async list({ organizationId, active }) {
      let query = supabaseAdmin
        .from('professionals')
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

    async get({ organizationId, professionalId }) {
      const { data, error } = await supabaseAdmin
        .from('professionals')
        .select(COLUMNS)
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

    async update({ organizationId, professionalId, patch }) {
      await assertUserIdIsMember(organizationId, patch.user_id);
      const { data, error } = await supabaseAdmin
        .from('professionals')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', professionalId)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('professional_not_found', 'professional not found');
      return data;
    },

    async remove({ organizationId, professionalId }) {
      const { data, error } = await supabaseAdmin
        .from('professionals')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', professionalId)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('professional_not_found', 'professional not found');
    },
  };
}
