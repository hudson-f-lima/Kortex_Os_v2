import { HttpError } from '../../shared/httpError.js';
import { assertKnownFields, validateBoolean, validateMoneyCents, validateUuidField } from '../../shared/validation.js';

const CREATE_FIELDS = new Set([
  'professional_id',
  'service_id',
  'duration_override_minutes',
  'buffer_before_min',
  'buffer_after_min',
  'price_override_cents',
  'active',
]);
const UPDATE_FIELDS = new Set([
  'duration_override_minutes',
  'buffer_before_min',
  'buffer_after_min',
  'price_override_cents',
  'active',
]);

// Mirrors services.duration_minutes check (5-1440) — an override cannot
// escape the bounds the base service itself is held to.
function validateOptionalDurationMinutes(value, fieldName) {
  if (value === undefined || value === null) return null;
  if (!Number.isInteger(value) || value < 5 || value > 1440) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be an integer between 5 and 1440`);
  }
  return value;
}

// Buffers cap at 480 (8h) — mirrors the migration's CHECK constraint.
function validateBufferMinutes(value, fieldName) {
  if (value === undefined) return undefined;
  if (!Number.isInteger(value) || value < 0 || value > 480) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be an integer between 0 and 480`);
  }
  return value;
}

function validateOptionalPriceCents(value, fieldName) {
  if (value === undefined || value === null) return null;
  return validateMoneyCents(value, fieldName);
}

export function validateCapabilityId(id) {
  return validateUuidField(id, 'id');
}

export function validateCreateCapabilityPayload(body) {
  assertKnownFields(body, CREATE_FIELDS);
  const professional_id = validateUuidField(body.professional_id, 'professional_id');
  const service_id = validateUuidField(body.service_id, 'service_id');
  const duration_override_minutes = validateOptionalDurationMinutes(
    body.duration_override_minutes,
    'duration_override_minutes',
  );
  const buffer_before_min = validateBufferMinutes(body.buffer_before_min ?? 0, 'buffer_before_min');
  const buffer_after_min = validateBufferMinutes(body.buffer_after_min ?? 0, 'buffer_after_min');
  const price_override_cents = validateOptionalPriceCents(body.price_override_cents, 'price_override_cents');
  const active = body.active === undefined ? true : validateBoolean(body.active, 'active');
  return {
    professional_id,
    service_id,
    duration_override_minutes,
    buffer_before_min,
    buffer_after_min,
    price_override_cents,
    active,
  };
}

export function validateUpdateCapabilityPayload(body) {
  assertKnownFields(body, UPDATE_FIELDS);
  if (Object.keys(body).length === 0) {
    throw HttpError.badRequest('empty_payload', 'at least one field must be provided');
  }
  const patch = {};
  if ('duration_override_minutes' in body) {
    patch.duration_override_minutes = validateOptionalDurationMinutes(
      body.duration_override_minutes,
      'duration_override_minutes',
    );
  }
  if (body.buffer_before_min !== undefined) {
    patch.buffer_before_min = validateBufferMinutes(body.buffer_before_min, 'buffer_before_min');
  }
  if (body.buffer_after_min !== undefined) {
    patch.buffer_after_min = validateBufferMinutes(body.buffer_after_min, 'buffer_after_min');
  }
  if ('price_override_cents' in body) {
    patch.price_override_cents = validateOptionalPriceCents(body.price_override_cents, 'price_override_cents');
  }
  if (body.active !== undefined) {
    patch.active = validateBoolean(body.active, 'active');
  }
  return patch;
}
