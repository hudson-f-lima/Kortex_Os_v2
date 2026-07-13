import { HttpError } from '../../shared/httpError.js';
import {
  assertKnownFields,
  assertNonEmptyPatch,
  validateBoolean,
  validateCommissionType,
  validateCommissionValue,
  validateId,
  validateRequiredString,
} from '../../shared/validation.js';

const ALLOWED_FIELDS = new Set(['name', 'default_commission_type', 'default_commission_value', 'active']);

export const validateServiceGroupId = validateId;

export function validateServiceGroupPayload(body, { requireAll = true } = {}) {
  assertKnownFields(body, ALLOWED_FIELDS);
  const patch = {};

  if (requireAll || body.name !== undefined) {
    patch.name = validateRequiredString(body.name, 'name', { min: 1, max: 160 });
  }

  const patchingType = body.default_commission_type !== undefined;
  const patchingValue = body.default_commission_value !== undefined;
  if (requireAll || patchingType || patchingValue) {
    if (!requireAll && patchingType !== patchingValue) {
      throw HttpError.badRequest(
        'invalid_default_commission',
        'default_commission_type and default_commission_value must be provided together',
      );
    }
    patch.default_commission_type = validateCommissionType(body.default_commission_type, 'default_commission_type');
    patch.default_commission_value = validateCommissionValue(
      body.default_commission_value,
      patch.default_commission_type,
      'default_commission_value',
    );
  }

  if (body.active !== undefined) {
    patch.active = validateBoolean(body.active, 'active');
  }

  if (!requireAll) {
    assertNonEmptyPatch(patch);
  }

  return patch;
}
