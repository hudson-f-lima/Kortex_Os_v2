import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createApiClient, ApiError } from './apiClient.js';

describe('apiClient', () => {
  beforeEach(() => {
    global.fetch = vi.fn();
  });

  it('injects Authorization and X-Organization-Id when available', async () => {
    global.fetch.mockResolvedValue({
      status: 200,
      ok: true,
      json: async () => ({ ok: true }),
    });

    const client = createApiClient({
      getAccessToken: () => 'token-123',
      getOrganizationId: () => 'org-456',
    });
    await client.get('/services');

    const [, options] = global.fetch.mock.calls[0];
    expect(options.headers.Authorization).toBe('Bearer token-123');
    expect(options.headers['X-Organization-Id']).toBe('org-456');
  });

  it('omits X-Organization-Id when no organization is selected', async () => {
    global.fetch.mockResolvedValue({ status: 200, ok: true, json: async () => ({}) });

    const client = createApiClient({ getAccessToken: () => 'token-123' });
    await client.get('/organizations');

    const [, options] = global.fetch.mock.calls[0];
    expect(options.headers['X-Organization-Id']).toBeUndefined();
  });

  it('maps a non-2xx JSON error body to a thrown ApiError', async () => {
    global.fetch.mockResolvedValue({
      status: 403,
      ok: false,
      json: async () => ({ code: 'insufficient_role', message: 'nope', request_id: 'req-1' }),
    });

    const client = createApiClient({ getAccessToken: () => 'token-123' });

    await expect(client.get('/cash-entries')).rejects.toThrow(ApiError);
    try {
      await client.get('/cash-entries');
    } catch (err) {
      expect(err.status).toBe(403);
      expect(err.code).toBe('insufficient_role');
      expect(err.requestId).toBe('req-1');
    }
  });

  it('returns null for a 204 response without parsing a body', async () => {
    global.fetch.mockResolvedValue({ status: 204, ok: true, json: async () => { throw new Error('should not be called'); } });

    const client = createApiClient({ getAccessToken: () => 'token-123' });
    const result = await client.delete('/clients/1');
    expect(result).toBeNull();
  });
});
