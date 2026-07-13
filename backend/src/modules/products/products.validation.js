import {
  assertKnownFields,
  assertNonEmptyPatch,
  validateBoolean,
  validateId,
  validateMoneyCents,
  validateRequiredString,
} from '../../shared/validation.js';

// stock_on_hand is intentionally not writable here: only the inventory_adjust
// and checkout_close RPCs may change it, so every movement is recorded.
const ALLOWED_FIELDS = new Set(['sku', 'name', 'price_cents', 'cost_cents', 'active']);

export const validateProductId = validateId;

export function validateProductPayload(body, { requireAll = true } = {}) {
  assertKnownFields(body, ALLOWED_FIELDS);
  const patch = {};

  if (requireAll || body.sku !== undefined) {
    patch.sku = validateRequiredString(body.sku, 'sku', { min: 1, max: 64 });
  }

  if (requireAll || body.name !== undefined) {
    patch.name = validateRequiredString(body.name, 'name', { min: 1, max: 160 });
  }

  if (requireAll || body.price_cents !== undefined) {
    patch.price_cents = validateMoneyCents(body.price_cents, 'price_cents');
  }

  if (body.cost_cents !== undefined) {
    patch.cost_cents = validateMoneyCents(body.cost_cents, 'cost_cents');
  }

  if (body.active !== undefined) {
    patch.active = validateBoolean(body.active, 'active');
  }

  if (!requireAll) {
    assertNonEmptyPatch(patch);
  }

  return patch;
}
