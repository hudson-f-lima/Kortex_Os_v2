import { HttpError } from '../shared/httpError.js';

const ORG_WIDE_ROLES = new Set(['owner', 'admin', 'manager']);
const UNIT_SCOPED_ROLES = new Set(['reception', 'professional']);

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
      .select('role, unit_id, organizations!inner(id, active)')
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

    if (ORG_WIDE_ROLES.has(data.role) && data.unit_id !== null) {
      next(HttpError.forbidden('invalid_membership_scope', 'organization-wide role cannot have a unit scope'));
      return;
    }
    if (UNIT_SCOPED_ROLES.has(data.role) && data.unit_id === null) {
      next(HttpError.forbidden('invalid_membership_scope', 'unit-scoped role requires an active unit'));
      return;
    }

    if (data.unit_id !== null) {
      const { data: unit, error: unitError } = await supabaseAdmin
        .from('units')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('id', data.unit_id)
        .eq('active', true)
        .maybeSingle();
      if (unitError) {
        next(unitError);
        return;
      }
      if (!unit) {
        next(HttpError.forbidden('inactive_unit_scope', 'membership unit is not active'));
        return;
      }
    }

    req.auth.organizationId = organizationId;
    req.auth.role = data.role;
    req.auth.unitId = data.unit_id ?? undefined;

    if (data.role === 'professional') {
      const professionalResult = await supabaseAdmin
        .from('professionals')
        .select('id')
        .eq('organization_id', organizationId)
        .eq('user_id', req.auth.userId)
        .eq('active', true)
        .maybeSingle();
      if (professionalResult.error) {
        next(professionalResult.error);
        return;
      }
      if (!professionalResult.data) {
        req.auth.permissions = [];
        req.auth.professionalId = undefined;
        next();
        return;
      }

      const [permissionsResult, unitLinkResult] = await Promise.all([
        supabaseAdmin
          .from('membership_permissions')
          .select('permission_code')
          .eq('organization_id', organizationId)
          .eq('user_id', req.auth.userId)
          .is('revoked_at', null),
        supabaseAdmin
          .from('professional_units')
          .select('professional_id')
          .eq('organization_id', organizationId)
          .eq('professional_id', professionalResult.data.id)
          .eq('unit_id', data.unit_id)
          .eq('active', true)
          .maybeSingle(),
      ]);
      if (permissionsResult.error) {
        next(permissionsResult.error);
        return;
      }
      if (unitLinkResult.error) {
        next(unitLinkResult.error);
        return;
      }
      if (!unitLinkResult.data) {
        req.auth.permissions = [];
        req.auth.professionalId = undefined;
        next();
        return;
      }
      req.auth.permissions = permissionsResult.data.map((row) => row.permission_code);
      req.auth.professionalId = professionalResult.data.id;
    } else {
      req.auth.permissions = [];
    }

    next();
  };
}
