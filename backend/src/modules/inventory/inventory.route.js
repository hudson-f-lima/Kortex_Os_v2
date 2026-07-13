import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { HttpError } from '../../shared/httpError.js';
import { UUID_RE, validateIdempotencyKey } from '../../shared/validation.js';
import { createInventoryService } from './inventory.service.js';
import { validateInventoryAdjustmentPayload } from './inventory.validation.js';

// Mirrors inventory_adjust's internal actor_has_role check (no reception)
// and inventory_movements_select (owner/admin/manager).
const ADJUST_ROLES = ['owner', 'admin', 'manager'];
const READ_ROLES = ['owner', 'admin', 'manager'];

function parseOptionalUuidQuery(value, fieldName) {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || !UUID_RE.test(value)) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} query param must be a uuid`);
  }
  return value;
}

export function inventoryRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createInventoryService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/inventory/movements', requireRole(...READ_ROLES), async (req, res, next) => {
    try {
      const movements = await service.listMovements({
        organizationId: req.auth.organizationId,
        productId: parseOptionalUuidQuery(req.query.product_id, 'product_id'),
      });
      res.status(200).json({ movements });
    } catch (err) {
      next(err);
    }
  });

  router.post('/inventory/adjustments', requireRole(...ADJUST_ROLES), async (req, res, next) => {
    try {
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const payload = validateInventoryAdjustmentPayload(req.body);
      const result = await service.adjust({
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
