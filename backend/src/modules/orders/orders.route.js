import { Router } from 'express';
import { requireFeatureFlag } from '../../middleware/requireFeatureFlag.js';
import { requireRole } from '../../middleware/requireRole.js';
import { UUID_RE, validateId, validateIdempotencyKey } from '../../shared/validation.js';
import { HttpError } from '../../shared/httpError.js';
import { createOrdersService } from './orders.service.js';
import { validateCheckoutPayload } from '../checkout/checkout.validation.js';

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

function validateReclosePayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }
  if (typeof body.reopen_attempt_id !== 'string' || !UUID_RE.test(body.reopen_attempt_id)) {
    throw HttpError.badRequest('invalid_reopen_attempt_id', 'reopen_attempt_id must be a uuid');
  }
  const { reopen_attempt_id: reopenAttemptId, ...checkoutPayload } = body;
  return { reopenAttemptId, payload: validateCheckoutPayload(checkoutPayload, { allowAppointmentId: false }) };
}

const REOPEN_REASON_CODES = new Set([
  'pricing_error',
  'item_correction',
  'professional_correction',
  'payment_correction',
  'inventory_correction',
  'other',
]);

function validateReopenRequestPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }
  const unknown = Object.keys(body).filter((key) => !['reason_code', 'reason_detail'].includes(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }
  if (typeof body.reason_code !== 'string' || !REOPEN_REASON_CODES.has(body.reason_code)) {
    throw HttpError.badRequest('invalid_reason_code', 'reason_code is invalid');
  }
  if (typeof body.reason_detail !== 'string' || body.reason_detail.trim().length === 0) {
    throw HttpError.badRequest('invalid_reason_detail', 'reason_detail is required');
  }
  return { reasonCode: body.reason_code, reasonDetail: body.reason_detail.trim() };
}

function validateReopenAttemptPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }
  const unknown = Object.keys(body).filter((key) => key !== 'reopen_attempt_id');
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }
  if (typeof body.reopen_attempt_id !== 'string' || !UUID_RE.test(body.reopen_attempt_id)) {
    throw HttpError.badRequest('invalid_reopen_attempt_id', 'reopen_attempt_id must be a uuid');
  }
  return body.reopen_attempt_id;
}

export function ordersRouter({ supabaseAdmin, organizationContext }) {
  const router = Router();
  const service = createOrdersService(supabaseAdmin);

  router.use(organizationContext);

  router.get('/orders', requireRole(...READ_ROLES), async (req, res, next) => {
    try {
      const orders = await service.list({
        organizationId: req.auth.organizationId,
        unitId: req.auth.unitId,
      });
      res.status(200).json({ orders });
    } catch (err) {
      next(err);
    }
  });

  router.get('/orders/:id', requireRole(...READ_ROLES), async (req, res, next) => {
    try {
      const orderId = validateId(req.params.id);
      const order = await service.get({
        organizationId: req.auth.organizationId,
        unitId: req.auth.unitId,
        orderId,
      });
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

  router.post('/orders/:id/reopen-request', requireRole(...REFUND_ROLES), requireFeatureFlag(supabaseAdmin, 'checkout_reopen_enabled'), async (req, res, next) => {
    try {
      const orderId = validateId(req.params.id);
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const { reasonCode, reasonDetail } = validateReopenRequestPayload(req.body);
      const result = await service.reopenRequest({
        organizationId: req.auth.organizationId, actorUserId: req.auth.userId, orderId, idempotencyKey, reasonCode, reasonDetail,
      });
      res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  });

  router.post('/orders/:id/reopen', requireRole(...REFUND_ROLES), requireFeatureFlag(supabaseAdmin, 'checkout_reopen_enabled'), async (req, res, next) => {
    try {
      const orderId = validateId(req.params.id);
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const reopenAttemptId = validateReopenAttemptPayload(req.body);
      const result = await service.reopen({
        organizationId: req.auth.organizationId, actorUserId: req.auth.userId, orderId, idempotencyKey, reopenAttemptId,
      });
      res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  });

  router.post('/orders/:id/reopen-approve', requireRole('owner'), requireFeatureFlag(supabaseAdmin, 'checkout_reopen_enabled'), async (req, res, next) => {
    try {
      const orderId = validateId(req.params.id);
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const reopenAttemptId = validateReopenAttemptPayload(req.body);
      const result = await service.reopenApprove({
        organizationId: req.auth.organizationId, actorUserId: req.auth.userId, orderId, idempotencyKey, reopenAttemptId,
      });
      res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  });

  router.post('/orders/:id/reopen-discard', requireRole(...REFUND_ROLES), requireFeatureFlag(supabaseAdmin, 'checkout_reopen_enabled'), async (req, res, next) => {
    try {
      const orderId = validateId(req.params.id);
      const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
      const reopenAttemptId = validateReopenAttemptPayload(req.body);
      const result = await service.reopenDiscard({
        organizationId: req.auth.organizationId, actorUserId: req.auth.userId, orderId, idempotencyKey, reopenAttemptId,
      });
      res.status(200).json(result);
    } catch (err) {
      next(err);
    }
  });

  router.post(
    '/orders/:id/reclose',
    requireRole(...REFUND_ROLES),
    requireFeatureFlag(supabaseAdmin, 'checkout_reopen_enabled'),
    async (req, res, next) => {
      try {
        const orderId = validateId(req.params.id);
        const idempotencyKey = validateIdempotencyKey(req.headers['idempotency-key']);
        const { reopenAttemptId, payload } = validateReclosePayload(req.body);
        const result = await service.reclose({
          organizationId: req.auth.organizationId,
          unitId: req.auth.unitId,
          actorUserId: req.auth.userId,
          orderId,
          reopenAttemptId,
          idempotencyKey,
          payload,
        });
        res.status(200).json(result);
      } catch (err) {
        next(err);
      }
    },
  );

  return router;
}
