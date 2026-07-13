import { HttpError } from '../../shared/httpError.js';
import { validateUuidField } from '../../shared/validation.js';

const REASONS = ['purchase', 'adjustment', 'return'];

export function validateInventoryAdjustmentPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const allowed = new Set(['product_id', 'quantity_delta', 'reason']);
  const unknown = Object.keys(body).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  const productId = validateUuidField(body.product_id, 'product_id');

  if (!Number.isInteger(body.quantity_delta) || body.quantity_delta === 0) {
    throw HttpError.badRequest('invalid_quantity_delta', 'quantity_delta must be a non-zero integer');
  }

  if (typeof body.reason !== 'string' || !REASONS.includes(body.reason)) {
    throw HttpError.badRequest('invalid_reason', `reason must be one of: ${REASONS.join(', ')}`);
  }

  return { product_id: productId, quantity_delta: body.quantity_delta, reason: body.reason };
}
