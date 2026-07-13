import { HttpError } from './httpError.js';

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validateId(id) {
  if (typeof id !== 'string' || !UUID_RE.test(id)) {
    throw HttpError.badRequest('invalid_id', 'id must be a uuid');
  }
  return id;
}

export function validateUuidField(value, fieldName) {
  if (typeof value !== 'string' || !UUID_RE.test(value)) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be a uuid`);
  }
  return value;
}

export function validateRequiredString(value, fieldName, { min = 1, max = 160 } = {}) {
  const str = typeof value === 'string' ? value.trim() : '';
  if (str.length < min || str.length > max) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be between ${min} and ${max} characters`);
  }
  return str;
}

export function validateMoneyCents(value, fieldName) {
  if (!Number.isInteger(value) || value < 0) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be a non-negative integer (cents)`);
  }
  return value;
}

export function validateBoolean(value, fieldName) {
  if (typeof value !== 'boolean') {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be a boolean`);
  }
  return value;
}

const COMMISSION_TYPES = ['percentage', 'fixed'];
// Basis points: 10000 = 100.00%. Mirrors money-in-cents discipline — never
// a float for anything that turns into a payout (docs/PLANEJAMENTO_COMISSOES.md §4.2).
const MAX_COMMISSION_PERCENTAGE_BASIS_POINTS = 10000;

export function validateCommissionType(value, fieldName = 'commission_type') {
  if (!COMMISSION_TYPES.includes(value)) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be one of: ${COMMISSION_TYPES.join(', ')}`);
  }
  return value;
}

export function validateCommissionValue(value, type, fieldName = 'commission_value') {
  if (!Number.isInteger(value) || value < 0) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be a non-negative integer`);
  }
  if (type === 'percentage' && value > MAX_COMMISSION_PERCENTAGE_BASIS_POINTS) {
    throw HttpError.badRequest(
      `invalid_${fieldName}`,
      `${fieldName} must be at most ${MAX_COMMISSION_PERCENTAGE_BASIS_POINTS} basis points (100%) when commission_type is percentage`,
    );
  }
  return value;
}

export function assertKnownFields(body, allowedFields) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }
  const unknown = Object.keys(body).filter((key) => !allowedFields.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }
}

export function assertNonEmptyPatch(patch) {
  if (Object.keys(patch).length === 0) {
    throw HttpError.badRequest('empty_payload', 'at least one field must be provided');
  }
}

// Mirrors the idempotency_keys.key check constraint (length between 8 and 200)
// shared by checkout_close and inventory_adjust.
export function validateIdempotencyKey(headerValue) {
  if (typeof headerValue !== 'string' || headerValue.length < 8 || headerValue.length > 200) {
    throw HttpError.badRequest(
      'missing_idempotency_key',
      'Idempotency-Key header is required and must be 8-200 characters',
    );
  }
  return headerValue;
}
