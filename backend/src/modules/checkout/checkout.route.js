import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { validateIdempotencyKey } from '../../shared/validation.js';
import { createCheckoutService } from './checkout.service.js';
import { validateCheckoutPayload } from './checkout.validation.js';

// Mirrors checkout_close's internal actor_has_role check.
const CHECKOUT_ROLES = ['owner', 'admin', 'manager', 'reception'];

export function checkoutRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createCheckoutService(supabaseAdmin);

  router.use(organizationContext);

  router.post('/checkout', requireRole(...CHECKOUT_ROLES), async (req, res, next) => {
    try {
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const payload = validateCheckoutPayload(req.body);
      const result = await service.close({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        idempotencyKey,
        payload,
      });
      res.status(201).json(result);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
