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
