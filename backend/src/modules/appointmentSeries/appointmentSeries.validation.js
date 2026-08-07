import { HttpError } from '../../shared/httpError.js';
import { assertKnownFields, validateId, validateUuidField } from '../../shared/validation.js';

const CREATE_FIELDS = new Set([
  'client_id', 'professional_id', 'service_id', 'unit_id', 'anchor_date', 'local_start_time',
  'recurrence_days', 'recurrence_interval_weeks', 'duration_minutes', 'valid_from', 'valid_until',
]);
const EXTEND_FIELDS = new Set(['as_of_date']);
const UPDATE_FIELDS = new Set([
  'scope', 'occurrence_date', 'local_start_time', 'recurrence_days', 'recurrence_interval_weeks',
  'duration_minutes', 'professional_id', 'status', 'valid_from', 'valid_until', 'version', 'starts_at',
]);
const CANCEL_FIELDS = new Set(['scope', 'occurrence_date', 'version']);

function validateDate(value, field) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(new Date(`${value}T00:00:00Z`).getTime())) {
    throw HttpError.badRequest(`invalid_${field}`, `${field} must be a valid YYYY-MM-DD date`);
  }
  return value;
}

function assertScope(scope) {
  if (!['THIS_OCCURRENCE', 'THIS_AND_FUTURE'].includes(scope)) {
    throw HttpError.badRequest('invalid_scope', 'scope must be THIS_OCCURRENCE or THIS_AND_FUTURE');
  }
  return scope;
}

export function validateSeriesCreate(body) {
  assertKnownFields(body, CREATE_FIELDS);
  const payload = {
    client_id: validateUuidField(body.client_id, 'client_id'),
    professional_id: validateUuidField(body.professional_id, 'professional_id'),
    service_id: validateUuidField(body.service_id, 'service_id'),
    unit_id: validateUuidField(body.unit_id, 'unit_id'),
    anchor_date: validateDate(body.anchor_date, 'anchor_date'),
    local_start_time: body.local_start_time,
    recurrence_days: body.recurrence_days,
    duration_minutes: body.duration_minutes,
    valid_from: validateDate(body.valid_from, 'valid_from'),
  };
  if (typeof payload.local_start_time !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(payload.local_start_time)) {
    throw HttpError.badRequest('invalid_local_start_time', 'local_start_time must be HH:MM');
  }
  if (!Array.isArray(payload.recurrence_days) || payload.recurrence_days.length === 0 || payload.recurrence_days.some((day) => !Number.isInteger(day) || day < 0 || day > 6)) {
    throw HttpError.badRequest('invalid_recurrence_days', 'recurrence_days must be a non-empty array of weekdays 0-6');
  }
  if (!Number.isInteger(payload.duration_minutes) || payload.duration_minutes <= 0) {
    throw HttpError.badRequest('invalid_duration_minutes', 'duration_minutes must be a positive integer');
  }
  if (body.recurrence_interval_weeks !== undefined) {
    if (!Number.isInteger(body.recurrence_interval_weeks) || body.recurrence_interval_weeks <= 0) {
      throw HttpError.badRequest('invalid_recurrence_interval_weeks', 'recurrence_interval_weeks must be a positive integer');
    }
    payload.recurrence_interval_weeks = body.recurrence_interval_weeks;
  }
  if (body.valid_until !== undefined) payload.valid_until = validateDate(body.valid_until, 'valid_until');
  return payload;
}

export function validateSeriesExtend(body) {
  assertKnownFields(body, EXTEND_FIELDS);
  return body.as_of_date === undefined ? {} : { as_of_date: validateDate(body.as_of_date, 'as_of_date') };
}

export function validateSeriesUpdate(body) {
  assertKnownFields(body, UPDATE_FIELDS);
  const payload = { ...body, scope: assertScope(body.scope) };
  if (payload.occurrence_date !== undefined) payload.occurrence_date = validateDate(payload.occurrence_date, 'occurrence_date');
  if (payload.valid_from !== undefined) payload.valid_from = validateDate(payload.valid_from, 'valid_from');
  if (payload.valid_until !== undefined && payload.valid_until !== null) payload.valid_until = validateDate(payload.valid_until, 'valid_until');
  if (payload.professional_id !== undefined) payload.professional_id = validateUuidField(payload.professional_id, 'professional_id');
  return payload;
}

export function validateSeriesCancel(body) {
  assertKnownFields(body, CANCEL_FIELDS);
  const payload = { ...body, scope: assertScope(body.scope) };
  if (payload.occurrence_date !== undefined) payload.occurrence_date = validateDate(payload.occurrence_date, 'occurrence_date');
  return payload;
}

export function validateConflictId(value) {
  return validateId(value);
}

export function validateSeriesId(value) {
  return validateId(value);
}
