import { useMemo } from 'react';
import { createApiClient } from './apiClient.js';
import { useAuth } from './AuthContext.jsx';
import { useOrganization } from './OrganizationContext.jsx';

// Cliente completo (Authorization + X-Organization-Id) para uso dentro dos
// módulos de domínio (6.2+). OrganizationProvider usa seu próprio cliente
// interno mais enxuto para o bootstrap (ver OrganizationContext.jsx).
export function useApiClient() {
  const { accessToken } = useAuth();
  const { organizationId } = useOrganization();

  return useMemo(
    () => createApiClient({ getAccessToken: () => accessToken, getOrganizationId: () => organizationId }),
    [accessToken, organizationId],
  );
}
