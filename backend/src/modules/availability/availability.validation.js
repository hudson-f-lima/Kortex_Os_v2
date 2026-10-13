import { HttpError } from '../../shared/httpError.js';
import { UUID_RE } from '../../shared/validation.js';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const MAX_WINDOW_DAYS = 31;
const MS_PER_DAY = 86400000;

function parseCalendarDate(value, code, fieldName) {
  if (typeof value !== 'string' || !DATE_RE.test(value)) {
    throw HttpError.badRequest(code, `${fieldName} is required and must be YYYY-MM-DD`);
  }

  const parsed = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) {
    throw HttpError.badRequest(code, `${fieldName} must be a valid calendar date`);
  }

  return parsed;
}

export function validateAvailabilityQuery(query) {
  const serviceId = query.service_id;
  if (typeof serviceId !== 'string' || !UUID_RE.test(serviceId)) {
    throw HttpError.badRequest('invalid_service_id', 'service_id query param is required and must be a uuid');
  }

  let professionalId;
  if (query.professional_id !== undefined) {
    if (typeof query.professional_id !== 'string' || !UUID_RE.test(query.professional_id)) {
      throw HttpError.badRequest('invalid_professional_id', 'professional_id must be a uuid');
    }
    professionalId = query.professional_id;
  }

  const dateFrom = query.date_from;
  const dateTo = query.date_to;
  const from = parseCalendarDate(dateFrom, 'invalid_date_from', 'date_from');
  const to = parseCalendarDate(dateTo, 'invalid_date_to', 'date_to');
  if (to < from) {
    throw HttpError.badRequest('invalid_date_range', 'date_to must not be before date_from');
  }

  const days = Math.round((to.getTime() - from.getTime()) / MS_PER_DAY) + 1;
  if (days > MAX_WINDOW_DAYS) {
    throw HttpError.badRequest('date_range_too_large', `date_from/date_to must span at most ${MAX_WINDOW_DAYS} days`);
  }

  return { serviceId, professionalId, dateFrom, dateTo };
}

export function addDays(date, days) {
  const parsed = parseCalendarDate(date, 'invalid_date', 'date');
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().slice(0, 10);
}

export function dateRange(dateFrom, dateTo) {
  const dates = [];
  let current = parseCalendarDate(dateFrom, 'invalid_date_from', 'date_from').getTime();
  const end = parseCalendarDate(dateTo, 'invalid_date_to', 'date_to').getTime();
  while (current <= end) {
    dates.push(new Date(current).toISOString().slice(0, 10));
    current += MS_PER_DAY;
  }
  return dates;
}
