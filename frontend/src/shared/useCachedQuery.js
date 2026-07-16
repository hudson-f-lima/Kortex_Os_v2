import { useEffect, useState } from 'react';
import { getAllRecords } from './idb.js';
import { subscribeToStore } from './syncEngine.js';

export function useCachedQuery(storeName, filterFn) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  async function loadCache() {
    try {
      const records = await getAllRecords(storeName);
      setData(filterFn ? records.filter(filterFn) : records);
    } catch (err) {
      console.error(`Failed to load cache for ${storeName}`, err);
      setError(err);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadCache();

    const unsubscribe = subscribeToStore(storeName, () => {
      loadCache();
    });

    return () => {
      unsubscribe();
    };
  }, [storeName, filterFn]);

  return { data, loading, error, refetch: loadCache };
}
