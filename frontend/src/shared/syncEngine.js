import * as idb from './idb.js';

const LISTENERS = new Map(); // Map<tableName, Set<callback>>

export function subscribeToStore(tableName, callback) {
  if (!LISTENERS.has(tableName)) {
    LISTENERS.set(tableName, new Set());
  }
  LISTENERS.get(tableName).add(callback);
  return () => {
    LISTENERS.get(tableName)?.delete(callback);
  };
}

function notifySubscribers(tableName) {
  LISTENERS.get(tableName)?.forEach((cb) => {
    try {
      cb();
    } catch (e) {
      console.error(`Error in sync listener for ${tableName}`, e);
    }
  });
}

// Maps DB table names to IndexedDB stores (ignoring those we do not cache)
const TABLE_TO_STORE = {
  clients: 'clients',
  professionals: 'professionals',
  services: 'services',
  products: 'products',
  packages: 'packages',
  service_groups: 'service_groups',
  appointments: 'appointments',
};

async function applyEvent(event) {
  const storeName = TABLE_TO_STORE[event.table_name];
  if (!storeName) return; // Ignore tables we do not cache (e.g. cash_entries, orders)

  if (event.action === 'INSERT' || event.action === 'UPDATE') {
    await idb.putRecord(storeName, event.payload);
  } else if (event.action === 'DELETE') {
    await idb.deleteRecord(storeName, event.record_id);
  }

  notifySubscribers(storeName);
}

export function createSyncEngine({ apiClient, organizationId, getAccessToken }) {
  let isRunning = false;
  let activeReader = null;
  let retryTimeout = null;

  async function performCatchUp() {
    const metaKey = `lastSyncId_${organizationId}`;
    const lastSyncId = (await idb.getMeta(metaKey)) ?? 0;

    try {
      const res = await apiClient.get(`/sync?since=${lastSyncId}`);
      if (res && res.events) {
        let maxId = lastSyncId;
        for (const event of res.events) {
          await applyEvent(event);
          if (event.id > maxId) {
            maxId = event.id;
          }
        }
        if (maxId > lastSyncId) {
          await idb.putMeta(metaKey, maxId);
        }
      }
    } catch (err) {
      console.error('Catch-up sync failed', err);
    }
  }

  async function runSSE() {
    if (!isRunning) return;

    const url = `${import.meta.env.VITE_API_BASE_URL}/sync/stream`;
    const token = getAccessToken();

    try {
      const response = await fetch(url, {
        headers: {
          Authorization: `Bearer ${token}`,
          'X-Organization-Id': organizationId,
        },
      });

      if (!response.ok) {
        throw new Error(`SSE stream returned status ${response.status}`);
      }

      if (!response.body) {
        throw new Error('SSE response body is null or undefined');
      }

      const reader = response.body.getReader();
      activeReader = reader;
      const decoder = new TextDecoder('utf-8');
      let buffer = '';

      while (isRunning) {
        const { value, done } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const dataStr = line.slice(6).trim();
            try {
              const event = JSON.parse(dataStr);
              await applyEvent(event);

              // Update the last sync ID in meta
              const metaKey = `lastSyncId_${organizationId}`;
              await idb.putMeta(metaKey, event.id);
            } catch (e) {
              console.error('Failed to parse SSE event payload', e);
            }
          }
        }
      }
    } catch (err) {
      console.error('SSE sync connection lost, retrying in 5s...', err);
      if (isRunning) {
        retryTimeout = setTimeout(runSSE, 5000);
      }
    }
  }

  return {
    async start() {
      if (isRunning) return;
      isRunning = true;

      // 1. Catch up on any missing changes while offline
      await performCatchUp();

      // 2. Start realtime stream
      runSSE();
    },

    stop() {
      isRunning = false;
      if (activeReader) {
        try {
          activeReader.cancel();
        } catch (e) {
          // reader may already be closed; nothing to do
        }
        activeReader = null;
      }
      if (retryTimeout) {
        clearTimeout(retryTimeout);
        retryTimeout = null;
      }
    },
  };
}
