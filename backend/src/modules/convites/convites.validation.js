import { HttpError } from '../../shared/httpError.js';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Convidar um 'owner' não passa por este endpoint — transferência/adição de
// dono é sensível o bastante para exigir um fluxo próprio (fora do escopo da
// Fase 11); ver ADR 0014.
export const INVITE_ROLES = ['admin', 'manager', 'reception', 'professional'];

export function validateInvitePayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const allowed = new Set(['email', 'role', 'professionalId', 'professionalName']);
  const unknown = Object.keys(body).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  if (typeof body.email !== 'string' || !EMAIL_RE.test(body.email)) {
    throw HttpError.badRequest('invalid_email', 'email is not a valid address');
  }

  if (typeof body.role !== 'string' || !INVITE_ROLES.includes(body.role)) {
    throw HttpError.badRequest('invalid_role', `role must be one of: ${INVITE_ROLES.join(', ')}`);
  }

  if (body.professionalId !== undefined && body.professionalName !== undefined) {
    throw HttpError.badRequest(
      'conflicting_professional_fields',
      'provide at most one of professionalId or professionalName',
    );
  }

  if (body.professionalId !== undefined) {
    if (body.role !== 'professional') {
      throw HttpError.badRequest('professional_fields_require_role', 'professionalId requires role "professional"');
    }
    if (typeof body.professionalId !== 'string' || !UUID_RE.test(body.professionalId)) {
      throw HttpError.badRequest('invalid_professional_id', 'professionalId must be a uuid');
    }
  }

  if (body.professionalName !== undefined) {
    if (body.role !== 'professional') {
      throw HttpError.badRequest('professional_fields_require_role', 'professionalName requires role "professional"');
    }
    const name = typeof body.professionalName === 'string' ? body.professionalName.trim() : '';
    if (name.length < 1 || name.length > 160) {
      throw HttpError.badRequest('invalid_professional_name', 'professionalName must be between 1 and 160 characters');
    }
  }

  return {
    email: body.email.trim(),
    role: body.role,
    professionalId: body.professionalId,
    professionalName: typeof body.professionalName === 'string' ? body.professionalName.trim() : undefined,
  };
}
