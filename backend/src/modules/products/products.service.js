import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, sku, name, price_cents, cost_cents, stock_on_hand, active, created_at, updated_at';

export function createProductsService(supabaseAdmin) {
  return {
    async list({ organizationId, active }) {
      let query = supabaseAdmin
        .from('products')
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

    async get({ organizationId, productId }) {
      const { data, error } = await supabaseAdmin
        .from('products')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', productId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('product_not_found', 'product not found');
      return data;
    },

    async create({ organizationId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('products')
        .insert({ organization_id: organizationId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, productId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('products')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', productId)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('product_not_found', 'product not found');
      return data;
    },

    async remove({ organizationId, productId }) {
      const { data, error } = await supabaseAdmin
        .from('products')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', productId)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('product_not_found', 'product not found');
    },
  };
}
