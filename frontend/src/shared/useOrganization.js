import { createContext, useContext } from 'react';

export const OrganizationContext = createContext(null);

export function useOrganization() {
  const ctx = useContext(OrganizationContext);
  if (!ctx) throw new Error('useOrganization must be used within OrganizationProvider');
  return ctx;
}

/**
 * Custom React Hook to evaluate client-side Feature Flags (DEC-44).
 * Reads feature flags from active organization's settings JSONB.
 *
 * @param {string} flagName - Feature flag key (e.g. 'enable_sale_commission')
 * @returns {boolean} Whether the feature flag is enabled
 */
export function useFeatureFlag(flagName) {
  const { settings } = useOrganization();
  if (!settings) return false;
  return Boolean(settings[flagName]);
}
