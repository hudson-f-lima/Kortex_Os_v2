import { mapPostgresError } from '../../shared/postgresError.js';

// Read-only aggregation over services + products, tagged with the same
// `kind` discriminator ('service' | 'product') that checkout_close uses for
// order_items. There is no catalog_items table: this mirrors the existing
// polymorphism at the checkout boundary without introducing a new schema.
export function createCatalogService(supabaseAdmin) {
  return {
    async list({ organizationId, active }) {
      let servicesQuery = supabaseAdmin
        .from('services')
        .select('id, name, price_cents, duration_minutes, active')
        .eq('organization_id', organizationId);
      let productsQuery = supabaseAdmin
        .from('products')
        .select('id, sku, name, price_cents, cost_cents, stock_on_hand, active')
        .eq('organization_id', organizationId);

      if (active !== undefined) {
        servicesQuery = servicesQuery.eq('active', active);
        productsQuery = productsQuery.eq('active', active);
      }

      const [servicesResult, productsResult] = await Promise.all([servicesQuery, productsQuery]);
      if (servicesResult.error) throw mapPostgresError(servicesResult.error);
      if (productsResult.error) throw mapPostgresError(productsResult.error);

      const items = [
        ...servicesResult.data.map((service) => ({ kind: 'service', ...service })),
        ...productsResult.data.map((product) => ({ kind: 'product', ...product })),
      ];
      items.sort((a, b) => a.name.localeCompare(b.name));
      return items;
    },
  };
}
