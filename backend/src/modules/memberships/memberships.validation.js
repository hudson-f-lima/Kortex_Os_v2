import { HttpError } from '../../shared/httpError.js';

export const MEMBERSHIP_ROLES = ['owner', 'admin', 'manager', 'reception', 'professional'];

export function validateMembershipPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const allowed = new Set(['role', 'active']);
  const unknown = Object.keys(body).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  if (typeof body.role !== 'string' || !MEMBERSHIP_ROLES.includes(body.role)) {
    throw HttpError.badRequest('invalid_role', `role must be one of: ${MEMBERSHIP_ROLES.join(', ')}`);
  }

  let active = true;
  if (body.active !== undefined) {
    if (typeof body.active !== 'boolean') {
      throw HttpError.badRequest('invalid_active', 'active must be a boolean');
    }
    active = body.active;
  }

  return { role: body.role, active };
}
