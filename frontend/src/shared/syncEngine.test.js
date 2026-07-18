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

import { createSyncEngine, retryDelayFor } from './syncEngine.js';

function readerThatFails() {
  return { read: () => Promise.reject(new Error('network drop')) };
}

function readerThatEndsImmediately() {
  return { read: () => Promise.resolve({ done: true, value: undefined }), cancel: () => {} };
}

// Conecta, entrega um evento (read() resolve normalmente — reseta o
// backoff), depois cai de novo no read seguinte.
function readerThatSucceedsOnceThenFails() {
  let calls = 0;
  const encoder = new TextEncoder();
  return {
    read: () => {
      calls += 1;
      if (calls === 1) return Promise.resolve({ done: false, value: encoder.encode('data: {"id":1}\n\n') });
      return Promise.reject(new Error('network drop'));
    },
    cancel: () => {},
  };
}

// ADR 0015 (Blue Team #2): substitui o backoff fixo de 5s por exponencial
// com teto de 30s e "full jitter" — testado isoladamente como função pura,
// sem depender de fake timers.
describe('retryDelayFor', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('grows exponentially with the attempt number, capped at 30s', () => {
    vi.spyOn(Math, 'random').mockReturnValue(1); // jitter máximo == teto exato
    expect(retryDelayFor(0)).toBe(1000);
    expect(retryDelayFor(1)).toBe(2000);
    expect(retryDelayFor(2)).toBe(4000);
    expect(retryDelayFor(5)).toBe(30000); // 1000*2^5 = 32000, teto em 30000
    expect(retryDelayFor(10)).toBe(30000); // continua no teto, não cresce sem limite
  });

  it('never returns a delay above the cap for that attempt, even with jitter', () => {
    vi.spyOn(Math, 'random').mockReturnValue(0.5);
    expect(retryDelayFor(0)).toBe(500);
    expect(retryDelayFor(3)).toBe(4000); // 0.5 * min(30000, 1000*2^3=8000)
  });
});

describe('syncEngine', () => {
  let apiClient;

  beforeEach(() => {
    vi.useFakeTimers();
    metaStore.clear();
    apiClient = { get: vi.fn().mockResolvedValue({ events: [] }) };
    vi.stubGlobal('fetch', vi.fn());
    vi.stubEnv('VITE_API_BASE_URL', 'https://api.test');
    vi.spyOn(Math, 'random').mockReturnValue(1); // jitter máximo == teto exato, delay previsível
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
    vi.useRealTimers();
    vi.restoreAllMocks();
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

    // 1ª tentativa de retry (attempt=0): teto de 1000ms com jitter máximo mockado.
    await vi.advanceTimersByTimeAsync(1000);

    expect(apiClient.get).toHaveBeenCalledTimes(2);
    expect(apiClient.get).toHaveBeenNthCalledWith(2, '/sync?since=0');
    expect(fetch).toHaveBeenCalledTimes(2);

    engine.stop();
  });

  it('increases the retry delay on consecutive failures', async () => {
    fetch
      .mockResolvedValueOnce({ ok: true, body: { getReader: readerThatFails } }) // attempt 0 -> falha, sem read bem-sucedido
      .mockResolvedValueOnce({ ok: true, body: { getReader: readerThatFails } }); // attempt 1 -> falha de novo

    const engine = createSyncEngine({ apiClient, organizationId: 'org-1', getAccessToken: () => 'token' });
    await engine.start();

    await vi.advanceTimersByTimeAsync(1000); // teto do attempt 0 (1000ms)
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(apiClient.get).toHaveBeenCalledTimes(2); // catch-up refeito na reconexão

    // Se o backoff não tivesse crescido, o attempt 1 tentaria de novo em 1000ms
    // (ainda não passou o suficiente para o teto real de 2000ms).
    await vi.advanceTimersByTimeAsync(1000);
    expect(fetch).toHaveBeenCalledTimes(2);

    await vi.advanceTimersByTimeAsync(1000); // completa os 2000ms do attempt 1
    expect(fetch).toHaveBeenCalledTimes(3);

    engine.stop();
  });

  it('resets the backoff after a read() succeeds, so a later drop retries at the base delay again', async () => {
    fetch
      .mockResolvedValueOnce({ ok: true, body: { getReader: readerThatFails } }) // attempt 0 -> falha (1000ms)
      .mockResolvedValueOnce({ ok: true, body: { getReader: readerThatFails } }) // attempt 1 -> falha (2000ms)
      .mockResolvedValueOnce({ ok: true, body: { getReader: readerThatSucceedsOnceThenFails } }) // conecta de verdade -> reseta, depois cai nesta mesma reconexão
      .mockResolvedValueOnce({ ok: true, body: { getReader: readerThatEndsImmediately } });

    const engine = createSyncEngine({ apiClient, organizationId: 'org-1', getAccessToken: () => 'token' });
    await engine.start();

    await vi.advanceTimersByTimeAsync(1000); // completa o teto do attempt 0
    expect(fetch).toHaveBeenCalledTimes(2);

    await vi.advanceTimersByTimeAsync(2000); // completa o teto do attempt 1; esta reconexão lê 1 evento (reseta) e cai de novo
    expect(fetch).toHaveBeenCalledTimes(3);

    // Sem o reset, a próxima tentativa esperaria o teto do attempt 2 (4000ms).
    // Com o reset (por causa do read() bem-sucedido acima), volta ao teto do
    // attempt 0 — chega em só 1000ms.
    await vi.advanceTimersByTimeAsync(1000);
    expect(fetch).toHaveBeenCalledTimes(4);

    engine.stop();
  });
});
