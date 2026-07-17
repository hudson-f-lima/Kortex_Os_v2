import { useCallback, useEffect, useState } from 'react';
import { getAllRecords } from './idb.js';
import { subscribeToStore } from './syncEngine.js';
import { useOrganization } from './useOrganization.js';

export function useCachedQuery(storeName, filterFn) {
  const { organizationId } = useOrganization();
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadCache = useCallback(async () => {
    try {
      const records = await getAllRecords(storeName);
      const tenantRecords = organizationId
        ? records.filter((record) => record.organization_id === organizationId)
        : [];
      setData(filterFn ? tenantRecords.filter(filterFn) : tenantRecords);
    } catch (err) {
      console.error(`Failed to load cache for ${storeName}`, err);
      setError(err);
    } finally {
      setLoading(false);
    }
  }, [filterFn, organizationId, storeName]);

  useEffect(() => {
    loadCache();

    const unsubscribe = subscribeToStore(storeName, () => {
      loadCache();
    });

    return () => {
      unsubscribe();
    };
  }, [loadCache, storeName]);

  return { data, loading, error, refetch: loadCache };
}
