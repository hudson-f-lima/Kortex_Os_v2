import { HttpError } from '../../shared/httpError.js';
import { assertKnownFields, validateBoolean, validateId, validateUuidField } from '../../shared/validation.js';

// ends_at is intentionally absent: it is always computed server-side from the
// resolved service/capability duration (Fase 10 hardening, extended by the
// ADR 0011 snapshot). A client that still sends it gets a loud 400
// (unknown_fields) rather than having the value silently discarded — see
// docs/PLANEJAMENTO_AGENDA_TRANSACIONAL.md §15.
const CREATE_FIELDS = new Set(['client_id', 'professional_id', 'service_id', 'starts_at', 'status']);
// version and confirm only make sense when editing an existing appointment
// (ADR 0012 optimistic concurrency, ADR 0013 change-plan confirmation).
const UPDATE_FIELDS = new Set([
  'client_id',
  'professional_id',
  'service_id',
  'starts_at',
  'status',
  'version',
  'confirm',
]);

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

// Mirrors appointments.version (bigint, starts at 1) — ADR 0012 optimistic
// concurrency requires the client to echo back the version it last read.
export function validateVersion(value) {
  if (!Number.isInteger(value) || value < 1) {
    throw HttpError.badRequest('invalid_version', 'version must be a positive integer');
  }
  return value;
}

export function validateAppointmentPayload(body, { requireAll = true } = {}) {
  assertKnownFields(body, requireAll ? CREATE_FIELDS : UPDATE_FIELDS);
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
  if (body.status !== undefined) {
    patch.status = validateStatus(body.status);
  }

  if (!requireAll) {
    if (body.version === undefined) {
      throw HttpError.badRequest('missing_version', 'version is required');
    }
    patch.version = validateVersion(body.version);
    if (body.confirm !== undefined) {
      patch.confirm = validateBoolean(body.confirm, 'confirm');
    }
  }

  return patch;
}
