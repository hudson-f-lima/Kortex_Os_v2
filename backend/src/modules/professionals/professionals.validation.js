import { HttpError } from '../../shared/httpError.js';

const ALLOWED_FIELDS = new Set(['name', 'user_id', 'active']);
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validateProfessionalId(id) {
  if (typeof id !== 'string' || !UUID_RE.test(id)) {
    throw HttpError.badRequest('invalid_id', 'id must be a uuid');
  }
  return id;
}

export function validateProfessionalPayload(body, { requireName = true } = {}) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const unknown = Object.keys(body).filter((key) => !ALLOWED_FIELDS.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  const patch = {};

  if (requireName || body.name !== undefined) {
    const name = typeof body.name === 'string' ? body.name.trim() : '';
    if (name.length < 1 || name.length > 160) {
      throw HttpError.badRequest('invalid_name', 'name must be between 1 and 160 characters');
    }
    patch.name = name;
  }

  if (body.user_id !== undefined) {
    if (body.user_id !== null && !UUID_RE.test(body.user_id)) {
      throw HttpError.badRequest('invalid_user_id', 'user_id must be a uuid or null');
    }
    patch.user_id = body.user_id;
  }

  if (body.active !== undefined) {
    if (typeof body.active !== 'boolean') {
      throw HttpError.badRequest('invalid_active', 'active must be a boolean');
    }
    patch.active = body.active;
  }

  if (Object.keys(patch).length === 0) {
    throw HttpError.badRequest('empty_payload', 'at least one field must be provided');
  }

  return patch;
}
