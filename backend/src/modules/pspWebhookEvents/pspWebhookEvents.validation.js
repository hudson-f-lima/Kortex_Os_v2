import { HttpError } from '../../shared/httpError.js';

const STATUSES = ['requires_capture', 'captured', 'canceled', 'failed'];

function requireString(value, fieldName, { max }) {
  const str = typeof value === 'string' ? value.trim() : '';
  if (str.length < 1 || str.length > max) {
    throw HttpError.badRequest(`invalid_${fieldName}`, `${fieldName} must be between 1 and ${max} characters`);
  }
  return str;
}

// Unlike our own API payloads, this is a third-party envelope: unknown
// fields are expected (real PSPs send far more than we read) and the whole
// body is persisted as-is in psp_webhook_events.payload — this only pulls
// out and validates the fields the ingestion path routes on.
export function validatePspWebhookPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const provider = requireString(body.provider, 'provider', { max: 60 });
  const providerEventId = requireString(body.provider_event_id, 'provider_event_id', { max: 200 });
  const eventType = requireString(body.event_type, 'event_type', { max: 120 });
  const providerReference = requireString(body.provider_reference, 'provider_reference', { max: 200 });

  if (!STATUSES.includes(body.status)) {
    throw HttpError.badRequest('invalid_status', `status must be one of: ${STATUSES.join(', ')}`);
  }

  return {
    provider,
    providerEventId,
    eventType,
    providerReference,
    status: body.status,
  };
}
