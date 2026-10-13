import { HttpError } from '../shared/httpError.js';

// Dark Launching gate (DEC-44 item 1). Corrected during the Onda 4
// implementation (2026-07-29): the original version read
// `req.organizationContext.organization.settings`, a shape the real
// middleware chain never produces — `organizationContext` (see
// `middleware/organizationContext.js`) populates `req.auth.organizationId`,
// not `req.organizationContext`. Because no route used this middleware yet
// (Onda 3's flags were written without a route to guard — Blueprint Onda 3
// §3.7), the bug was never exercised end-to-end; only its own unit test,
// which mocked the same wrong shape, ever ran. Fixed to look up
// `organizations.settings` from the database via the authenticated
// membership's `organizationId`, matching how every other piece of
// tenant-scoped state is resolved in this codebase.
export function requireFeatureFlag(supabaseAdmin, flagKey) {
  return async function requireFeatureFlagMiddleware(req, res, next) {
    try {
      const { data, error } = await supabaseAdmin
        .from('organizations')
        .select('settings')
        .eq('id', req.auth.organizationId)
        .single();
      if (error) throw error;

      const enabled = data?.settings?.[flagKey] === true;
      if (!enabled) {
        next(HttpError.forbidden('feature_disabled', `feature "${flagKey}" is not enabled for this organization`));
        return;
      }
      next();
    } catch (err) {
      next(err);
    }
  };
}
