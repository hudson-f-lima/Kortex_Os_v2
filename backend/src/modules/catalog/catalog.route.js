import { Router } from 'express';
import { createCatalogService } from './catalog.service.js';

// Read-only; open to any active member, matching services_select/products_select.
export function catalogRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const catalog = createCatalogService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/catalog', async (req, res, next) => {
    try {
      const { active } = req.query;
      const items = await catalog.list({
        organizationId: req.auth.organizationId,
        active: active === undefined ? undefined : active === 'true',
      });
      res.status(200).json({ items });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
