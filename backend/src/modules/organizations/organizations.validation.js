import { HttpError } from '../../shared/httpError.js';

const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export function validateOrganizationPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const allowed = new Set(['name', 'slug']);
  const unknown = Object.keys(body).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  const name = typeof body.name === 'string' ? body.name.trim() : '';
  if (name.length < 2 || name.length > 120) {
    throw HttpError.badRequest('invalid_name', 'name must be between 2 and 120 characters');
  }

  const slug = typeof body.slug === 'string' ? body.slug.trim().toLowerCase() : '';
  if (!SLUG_RE.test(slug)) {
    throw HttpError.badRequest(
      'invalid_slug',
      'slug must be lowercase alphanumeric segments separated by single hyphens',
    );
  }

  return { name, slug };
}
