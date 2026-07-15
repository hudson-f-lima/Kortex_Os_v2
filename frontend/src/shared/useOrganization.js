import { createContext, useContext } from 'react';

export const OrganizationContext = createContext(null);

export function useOrganization() {
  const ctx = useContext(OrganizationContext);
  if (!ctx) throw new Error('useOrganization must be used within OrganizationProvider');
  return ctx;
}
