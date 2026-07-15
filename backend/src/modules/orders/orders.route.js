import { Router } from 'express';
import { requireRole } from '../../middleware/requireRole.js';
import { validateId, validateIdempotencyKey } from '../../shared/validation.js';
import { HttpError } from '../../shared/httpError.js';
import { createOrdersService } from './orders.service.js';

// Mirrors orders_select / order_items_select / payments_select (read-only).
const READ_ROLES = ['owner', 'admin', 'manager', 'reception'];
// Mirrors order_refund's internal actor_has_role check.
const REFUND_ROLES = ['owner', 'admin', 'manager'];
// Mirrors order_refund's reason check (ADR 0006) — correção operacional
// (void) nunca usa esta rota, só desistência/inadimplência real do cliente.
const REFUND_REASONS = ['customer_cancellation', 'customer_default'];

function validateRefundPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const allowed = new Set(['reason']);
  const unknown = Object.keys(body).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  if (typeof body.reason !== 'string' || !REFUND_REASONS.includes(body.reason)) {
    throw HttpError.badRequest('invalid_reason', `reason must be one of: ${REFUND_REASONS.join(', ')}`);
  }

  return { reason: body.reason };
}

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

  router.post('/orders/:id/refund', requireRole(...REFUND_ROLES), async (req, res, next) => {
    try {
      const orderId = validateId(req.params.id);
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const { reason } = validateRefundPayload(req.body);
      const result = await service.refund({
        organizationId: req.auth.organizationId,
        actorUserId: req.auth.userId,
        orderId,
        idempotencyKey,
        reason,
      });
      res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
