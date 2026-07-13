import { HttpError } from '../../shared/httpError.js';
import {
  assertKnownFields,
  assertNonEmptyPatch,
  validateBoolean,
  validateCommissionType,
  validateCommissionValue,
  validateId,
  validateMoneyCents,
  validateRequiredString,
  validateUuidField,
} from '../../shared/validation.js';

const ALLOWED_FIELDS = new Set([
  'name',
  'price_cents',
  'duration_minutes',
  'service_group_id',
  'commission_type',
  'commission_value',
  'active',
]);

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

  // Every service belongs to a group (commission cascade fallback,
  // docs/PLANEJAMENTO_COMISSOES.md §4.1) — required on create, optional on patch.
  if (requireAll || body.service_group_id !== undefined) {
    patch.service_group_id = validateUuidField(body.service_group_id, 'service_group_id');
  }

  // commission_type/commission_value are an optional pair that overrides the
  // group default for this one service; both or neither.
  const patchingType = body.commission_type !== undefined;
  const patchingValue = body.commission_value !== undefined;
  if (patchingType || patchingValue) {
    if (patchingType !== patchingValue) {
      throw HttpError.badRequest(
        'invalid_commission',
        'commission_type and commission_value must be provided together',
      );
    }
    patch.commission_type = validateCommissionType(body.commission_type);
    patch.commission_value = validateCommissionValue(body.commission_value, patch.commission_type);
  }

  if (body.active !== undefined) {
    patch.active = validateBoolean(body.active, 'active');
  }

  if (!requireAll) {
    assertNonEmptyPatch(patch);
  }

  return patch;
}
