import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const metaStore = new Map();

vi.mock('./idb.js', () => ({
  getMeta: vi.fn((key) => Promise.resolve(metaStore.get(key) ?? null)),
  putMeta: vi.fn((key, value) => {
    metaStore.set(key, value);
    return Promise.resolve();
  }),
  putRecord: vi.fn(() => Promise.resolve()),
  deleteRecord: vi.fn(() => Promise.resolve()),
}));

import { createSyncEngine } from './syncEngine.js';

function readerThatFails() {
  return { read: () => Promise.reject(new Error('network drop')) };
}

function readerThatEndsImmediately() {
  return { read: () => Promise.resolve({ done: true, value: undefined }), cancel: () => {} };
}

describe('syncEngine', () => {
  let apiClient;

  beforeEach(() => {
    vi.useFakeTimers();
    metaStore.clear();
    apiClient = { get: vi.fn().mockResolvedValue({ events: [] }) };
    vi.stubGlobal('fetch', vi.fn());
    vi.stubEnv('VITE_API_BASE_URL', 'https://api.test');
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
    vi.useRealTimers();
  });

  // ADR 0015: a reconexão do SSE precisa refazer o catch-up por cursor antes
  // de reabrir o stream — sem isso, deltas gerados durante a desconexão
  // ficavam permanentemente ausentes do cliente.
  it('re-runs the cursor catch-up before reopening the SSE stream after a reconnect', async () => {
    fetch
      .mockResolvedValueOnce({ ok: true, body: { getReader: readerThatFails } })
      .mockResolvedValueOnce({ ok: true, body: { getReader: readerThatEndsImmediately } });

    const engine = createSyncEngine({ apiClient, organizationId: 'org-1', getAccessToken: () => 'token' });

    await engine.start();
    expect(apiClient.get).toHaveBeenCalledTimes(1);
    expect(apiClient.get).toHaveBeenNthCalledWith(1, '/sync?since=0');

    await vi.advanceTimersByTimeAsync(5000);

    expect(apiClient.get).toHaveBeenCalledTimes(2);
    expect(apiClient.get).toHaveBeenNthCalledWith(2, '/sync?since=0');
    expect(fetch).toHaveBeenCalledTimes(2);

    engine.stop();
  });
});
