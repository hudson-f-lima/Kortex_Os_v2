import { HttpError } from '../shared/httpError.js';

/**
 * Middleware for Dark Launching via Feature Flags (DEC-44).
 * Checks if the specified feature flag is enabled in the organization's settings JSONB.
 *
 * @param {string} flagName - The key in organization.settings (e.g. 'enable_sale_commission')
 */
export function requireFeatureFlag(flagName) {
  return function requireFeatureFlagMiddleware(req, res, next) {
    const settings = req.organizationContext?.organization?.settings || {};
    const isEnabled = Boolean(settings[flagName]);

    if (!isEnabled) {
      next(HttpError.forbidden('feature_disabled', `Feature '${flagName}' is disabled for this organization`));
      return;
    }
    next();
  };
}
