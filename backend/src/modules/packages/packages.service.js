import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { mapRpcError } from '../../shared/rpcError.js';

const PACKAGE_COLUMNS = 'id, name, price_cents, active, created_at, updated_at';
const ITEM_COLUMNS = 'id, service_id, quantity';

export function createPackagesService(supabaseAdmin) {
  const service = {
    async list({ organizationId, active }) {
      let query = supabaseAdmin
        .from('packages')
        .select(PACKAGE_COLUMNS)
        .eq('organization_id', organizationId)
        .order('name', { ascending: true });
      if (active !== undefined) {
        query = query.eq('active', active);
      }
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, packageId }) {
      const { data: pkg, error } = await supabaseAdmin
        .from('packages')
        .select(PACKAGE_COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', packageId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!pkg) throw HttpError.notFound('package_not_found', 'package not found');

      const { data: items, error: itemsError } = await supabaseAdmin
        .from('package_items')
        .select(ITEM_COLUMNS)
        .eq('organization_id', organizationId)
        .eq('package_id', packageId);
      if (itemsError) throw mapPostgresError(itemsError);

      return { ...pkg, items };
    },

    async create({ organizationId, actorUserId, payload }) {
      const { data, error } = await supabaseAdmin.rpc('create_package', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_payload: payload,
      });
      if (error) throw mapRpcError(error);
      return service.get({ organizationId, packageId: data.id });
    },

    async update({ organizationId, actorUserId, packageId, patch }) {
      const { error } = await supabaseAdmin.rpc('update_package', {
        p_organization_id: organizationId,
        p_actor_user_id: actorUserId,
        p_package_id: packageId,
        p_payload: patch,
      });
      if (error) throw mapRpcError(error);
      return service.get({ organizationId, packageId });
    },

    async remove({ organizationId, packageId }) {
      const { data, error } = await supabaseAdmin
        .from('packages')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', packageId)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('package_not_found', 'package not found');
    },
  };
  return service;
}
