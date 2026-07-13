import { HttpError } from '../../shared/httpError.js';

const ALLOWED_FIELDS = new Set(['name', 'phone', 'email', 'active']);
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validateClientId(id) {
  if (typeof id !== 'string' || !UUID_RE.test(id)) {
    throw HttpError.badRequest('invalid_id', 'id must be a uuid');
  }
  return id;
}

export function validateClientPayload(body, { requireName = true } = {}) {
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

  if (body.phone !== undefined) {
    patch.phone = body.phone === null ? null : String(body.phone).trim();
  }

  if (body.email !== undefined) {
    if (body.email !== null && !EMAIL_RE.test(body.email)) {
      throw HttpError.badRequest('invalid_email', 'email is not a valid address');
    }
    patch.email = body.email;
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
