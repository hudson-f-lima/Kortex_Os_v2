import { mapPostgresError } from '../../shared/postgresError.js';

// Read-only aggregation over services + products + packages, tagged with a
// `kind` discriminator ('service' | 'product' | 'package'). checkout_close
// still only understands 'service'/'product' (package checkout is Fase 5.1
// of docs/PLANEJAMENTO_COMISSOES.md) — this is a browse-only view so the
// catalog is navigable in one place even before packages are sellable.
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
      let packagesQuery = supabaseAdmin
        .from('packages')
        .select('id, name, price_cents, active')
        .eq('organization_id', organizationId);

      if (active !== undefined) {
        servicesQuery = servicesQuery.eq('active', active);
        productsQuery = productsQuery.eq('active', active);
        packagesQuery = packagesQuery.eq('active', active);
      }

      const [servicesResult, productsResult, packagesResult] = await Promise.all([
        servicesQuery,
        productsQuery,
        packagesQuery,
      ]);
      if (servicesResult.error) throw mapPostgresError(servicesResult.error);
      if (productsResult.error) throw mapPostgresError(productsResult.error);
      if (packagesResult.error) throw mapPostgresError(packagesResult.error);

      const items = [
        ...servicesResult.data.map((service) => ({ kind: 'service', ...service })),
        ...productsResult.data.map((product) => ({ kind: 'product', ...product })),
        ...packagesResult.data.map((pkg) => ({ kind: 'package', ...pkg })),
      ];
      items.sort((a, b) => a.name.localeCompare(b.name));
      return items;
    },
  };
}
