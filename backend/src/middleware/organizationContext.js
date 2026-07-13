import { HttpError } from '../shared/httpError.js';

/**
 * Resolves organization context from an authenticated membership row.
 * X-Organization-Id alone never grants access: it only selects which
 * organization to check membership for; the database lookup decides.
 */
export function createOrganizationContextMiddleware(supabaseAdmin) {
  return async function organizationContext(req, res, next) {
    if (!req.auth?.userId) {
      next(HttpError.unauthorized('missing_auth_context', 'authentication must run before organization context'));
      return;
    }

    const organizationId = req.headers['x-organization-id'];
    if (!organizationId || typeof organizationId !== 'string') {
      next(HttpError.badRequest('missing_organization_id', 'X-Organization-Id header is required'));
      return;
    }

    const { data, error } = await supabaseAdmin
      .from('memberships')
      .select('role, organizations!inner(id, active)')
      .eq('organization_id', organizationId)
      .eq('user_id', req.auth.userId)
      .eq('active', true)
      .eq('organizations.active', true)
      .maybeSingle();

    if (error) {
      next(error);
      return;
    }
    if (!data) {
      next(HttpError.forbidden('not_a_member', 'no active membership for this organization'));
      return;
    }

    req.auth.organizationId = organizationId;
    req.auth.role = data.role;
    next();
  };
}
