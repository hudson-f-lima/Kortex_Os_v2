import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { createProductsService } from './products.service.js';
import { validateProductId, validateProductPayload } from './products.validation.js';

// Mirrors RLS on public.products (defense in depth): products_select allows
// any active member; insert/update require owner/admin/manager; delete
// requires owner/admin. stock_on_hand is read-only here by design.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

export function productsRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createProductsService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/products', async (req, res, next) => {
    try {
      const { active } = req.query;
      const products = await service.list({
        organizationId: req.auth.organizationId,
        active: active === undefined ? undefined : active === 'true',
      });
      res.status(200).json({ products });
    } catch (err) {
      next(err);
    }
  });

  router.get('/products/:id', async (req, res, next) => {
    try {
      const productId = validateProductId(req.params.id);
      const result = await service.get({ organizationId: req.auth.organizationId, productId });
      res.status(200).json({ product: result });
    } catch (err) {
      next(err);
    }
  });

  router.post('/products', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const patch = validateProductPayload(req.body, { requireAll: true });
      const result = await service.create({ organizationId: req.auth.organizationId, patch });
      res.status(201).json({ product: result });
    } catch (err) {
      next(err);
    }
  });

  router.patch('/products/:id', requireRole(...WRITE_ROLES), async (req, res, next) => {
    try {
      const productId = validateProductId(req.params.id);
      const patch = validateProductPayload(req.body, { requireAll: false });
      const result = await service.update({ organizationId: req.auth.organizationId, productId, patch });
      res.status(200).json({ product: result });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/products/:id', requireRole(...DELETE_ROLES), async (req, res, next) => {
    try {
      const productId = validateProductId(req.params.id);
      await service.remove({ organizationId: req.auth.organizationId, productId });
      res.status(204).send();
    } catch (err) {
      next(err);
    }
  });

  return router;
}
