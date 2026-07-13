import { HttpError } from '../../shared/httpError.js';
import { assertKnownFields, assertNonEmptyPatch, validateId, validateUuidField } from '../../shared/validation.js';

const ALLOWED_FIELDS = new Set(['client_id', 'professional_id', 'service_id', 'starts_at', 'ends_at', 'status']);

export const APPOINTMENT_STATUSES = ['scheduled', 'confirmed', 'in_service', 'completed', 'cancelled', 'no_show'];

export const validateAppointmentId = validateId;

export function validateDateTime(value, fieldName) {
  if (typeof value !== 'string') {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be an ISO 8601 datetime string`);
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be a valid ISO 8601 datetime string`);
  }
  return date.toISOString();
}

export function validateStatus(value) {
  if (typeof value !== 'string' || !APPOINTMENT_STATUSES.includes(value)) {
    throw HttpError.badRequest('invalid_status', `status must be one of: ${APPOINTMENT_STATUSES.join(', ')}`);
  }
  return value;
}

export function validateAppointmentPayload(body, { requireAll = true } = {}) {
  assertKnownFields(body, ALLOWED_FIELDS);
  const patch = {};

  if (requireAll || body.client_id !== undefined) {
    patch.client_id = validateUuidField(body.client_id, 'client_id');
  }
  if (requireAll || body.professional_id !== undefined) {
    patch.professional_id = validateUuidField(body.professional_id, 'professional_id');
  }
  if (requireAll || body.service_id !== undefined) {
    patch.service_id = validateUuidField(body.service_id, 'service_id');
  }
  if (requireAll || body.starts_at !== undefined) {
    patch.starts_at = validateDateTime(body.starts_at, 'starts_at');
  }
  if (requireAll || body.ends_at !== undefined) {
    patch.ends_at = validateDateTime(body.ends_at, 'ends_at');
  }
  if (body.status !== undefined) {
    patch.status = validateStatus(body.status);
  }

  if (
    patch.starts_at !== undefined &&
    patch.ends_at !== undefined &&
    new Date(patch.ends_at) <= new Date(patch.starts_at)
  ) {
    throw HttpError.badRequest('invalid_time_range', 'ends_at must be after starts_at');
  }

  if (!requireAll) {
    assertNonEmptyPatch(patch);
  }

  return patch;
}
