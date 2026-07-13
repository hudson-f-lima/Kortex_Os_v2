import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { validateId } from '../../shared/validation.js';
import { createOrdersService } from './orders.service.js';

// Mirrors orders_select / order_items_select / payments_select. Read-only:
// orders are only ever created by the checkout_close RPC.
const READ_ROLES = ['owner', 'admin', 'manager', 'reception'];

export function ordersRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createOrdersService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/orders', requireRole(...READ_ROLES), async (req, res, next) => {
    try {
      const orders = await service.list({ organizationId: req.auth.organizationId });
      res.status(200).json({ orders });
    } catch (err) {
      next(err);
    }
  });

  router.get('/orders/:id', requireRole(...READ_ROLES), async (req, res, next) => {
    try {
      const orderId = validateId(req.params.id);
      const order = await service.get({ organizationId: req.auth.organizationId, orderId });
      res.status(200).json({ order });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
