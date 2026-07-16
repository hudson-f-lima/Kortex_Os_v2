import { useEffect, useMemo, useState } from 'react';
import { createApiClient } from './apiClient.js';
import { useAuth } from './useAuth.js';
import { OrganizationContext } from './useOrganization.js';
import { clearAllStores } from './idb.js';
import { createSyncEngine } from './syncEngine.js';

const STORAGE_KEY = 'kortex.selectedOrganizationId';

export function OrganizationProvider({ children }) {
  const { accessToken, user } = useAuth();
  const [organizations, setOrganizations] = useState([]);
  const [organizationId, setOrganizationId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Bootstrap-only client: lista/cria organização não exige X-Organization-Id.
  const bootstrapClient = useMemo(
    () => createApiClient({ getAccessToken: () => accessToken }),
    [accessToken],
  );

  async function refresh() {
    setLoading(true);
    setError(null);
    try {
      const data = await bootstrapClient.get('/organizations');
      setOrganizations(data.organizations);

      const stored = localStorage.getItem(STORAGE_KEY);
      const match = data.organizations.find((org) => org.id === stored);
      if (match) {
        setOrganizationId(match.id);
      } else if (data.organizations.length === 1) {
        setOrganizationId(data.organizations[0].id);
        localStorage.setItem(STORAGE_KEY, data.organizations[0].id);
      } else {
        setOrganizationId(null);
      }
    } catch (err) {
      setError(err);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!user) return;
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]);

  useEffect(() => {
    if (!user) {
      clearAllStores().catch(console.error);
      return;
    }
  }, [user]);

  useEffect(() => {
    if (!accessToken || !organizationId) return;

    const apiClient = createApiClient({
      getAccessToken: () => accessToken,
      getOrganizationId: () => organizationId,
    });

    const engine = createSyncEngine({
      apiClient,
      organizationId,
      getAccessToken: () => accessToken,
    });

    engine.start();

    return () => {
      engine.stop();
    };
  }, [accessToken, organizationId]);

  function selectOrganization(id) {
    setOrganizationId(id);
    localStorage.setItem(STORAGE_KEY, id);
  }

  const current = organizations.find((org) => org.id === organizationId) ?? null;

  const value = {
    organizations,
    organizationId,
    role: current?.role ?? null,
    loading,
    error,
    selectOrganization,
    refresh,
  };

  return <OrganizationContext.Provider value={value}>{children}</OrganizationContext.Provider>;
}
