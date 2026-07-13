import { HttpError } from '../../shared/httpError.js';
import {
  assertKnownFields,
  assertNonEmptyPatch,
  validateBoolean,
  validateId,
  validateMoneyCents,
  validateRequiredString,
} from '../../shared/validation.js';

const ALLOWED_FIELDS = new Set(['name', 'price_cents', 'duration_minutes', 'active']);

export const validateServiceId = validateId;

export function validateServicePayload(body, { requireAll = true } = {}) {
  assertKnownFields(body, ALLOWED_FIELDS);
  const patch = {};

  if (requireAll || body.name !== undefined) {
    patch.name = validateRequiredString(body.name, 'name', { min: 1, max: 160 });
  }

  if (requireAll || body.price_cents !== undefined) {
    patch.price_cents = validateMoneyCents(body.price_cents, 'price_cents');
  }

  if (requireAll || body.duration_minutes !== undefined) {
    const value = body.duration_minutes;
    if (!Number.isInteger(value) || value < 5 || value > 1440) {
      throw HttpError.badRequest(
        'invalid_duration_minutes',
        'duration_minutes must be an integer between 5 and 1440',
      );
    }
    patch.duration_minutes = value;
  }

  if (body.active !== undefined) {
    patch.active = validateBoolean(body.active, 'active');
  }

  if (!requireAll) {
    assertNonEmptyPatch(patch);
  }

  return patch;
}
