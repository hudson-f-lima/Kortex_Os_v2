import { useCallback, useEffect, useMemo, useState } from 'react';
import { createApiClient } from './apiClient.js';
import { useAuth } from './useAuth.js';
import { OrganizationContext } from './useOrganization.js';
import { clearAllStores, getMeta, putMeta } from './idb.js';
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

  const refresh = useCallback(async function refresh() {
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
  }, [bootstrapClient]);

  useEffect(() => {
    if (!user) return;
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id, refresh]);

  useEffect(() => {
    if (!user) {
      clearAllStores().catch(console.error);
      return;
    }
  }, [user]);

  useEffect(() => {
    if (!accessToken || !organizationId || !user?.id) return;

    const apiClient = createApiClient({
      getAccessToken: () => accessToken,
      getOrganizationId: () => organizationId,
    });

    const engine = createSyncEngine({
      apiClient,
      organizationId,
      getAccessToken: () => accessToken,
    });

    let cancelled = false;

    async function initSync() {
      try {
        const savedUserId = await getMeta('active_user_id');
        const savedOrgId = await getMeta('active_organization_id');
        const savedSchemaVersion = await getMeta('active_schema_version');

        const CURRENT_SCHEMA_VERSION = 1;

        const contextMatches =
          savedUserId === user.id &&
          savedOrgId === organizationId &&
          savedSchemaVersion === CURRENT_SCHEMA_VERSION;

        if (!contextMatches) {
          await clearAllStores();

          if (!cancelled) {
            await putMeta('active_user_id', user.id);
            await putMeta('active_organization_id', organizationId);
            await putMeta('active_schema_version', CURRENT_SCHEMA_VERSION);
          }
        }

        if (!cancelled) {
          await engine.start();
        }
      } catch (err) {
        console.error('Failed to safely initialize organization sync engine', err);
      }
    }

    initSync();

    return () => {
      cancelled = true;
      engine.stop();
    };
  }, [accessToken, organizationId, user?.id]);

  const selectOrganization = useCallback((id) => {
    setOrganizationId(id);
    localStorage.setItem(STORAGE_KEY, id);
  }, []);

  const current = organizations.find((org) => org.id === organizationId) ?? null;
  const role = current?.role ?? null;

  const value = useMemo(
    () => ({
      organizations,
      organizationId,
      role,
      loading,
      error,
      selectOrganization,
      refresh,
    }),
    [organizations, organizationId, role, loading, error, selectOrganization, refresh],
  );

  return <OrganizationContext.Provider value={value}>{children}</OrganizationContext.Provider>;
}
