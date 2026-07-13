const BASE_URL = import.meta.env.VITE_API_BASE_URL;

// Espelha o contrato de erro do backend (backend/src/middleware/errorHandler.js):
// { code, message, request_id, details? }. Nunca stack/SQL/segredo.
export class ApiError extends Error {
  constructor(status, code, message, requestId, details) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.requestId = requestId;
    this.details = details;
  }
}

// Wrapper único de fetch: injeta Authorization/X-Organization-Id, mapeia o
// contrato de erro, nunca cacheia/persiste corpo de resposta
// (docs/PWA_PLANEJAMENTO.md §4.3 — cada leitura revalida contra o backend).
export function createApiClient({ getAccessToken, getOrganizationId }) {
  async function request(path, { method = 'GET', body, headers } = {}) {
    const accessToken = getAccessToken?.();
    const organizationId = getOrganizationId?.();

    const res = await fetch(`${BASE_URL}${path}`, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        ...(organizationId ? { 'X-Organization-Id': organizationId } : {}),
        ...headers,
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });

    if (res.status === 204) return null;

    const payload = await res.json().catch(() => null);

    if (!res.ok) {
      throw new ApiError(
        res.status,
        payload?.code ?? 'unknown_error',
        payload?.message ?? 'unexpected error',
        payload?.request_id,
        payload?.details,
      );
    }

    return payload;
  }

  return {
    get: (path, opts) => request(path, { ...opts, method: 'GET' }),
    post: (path, body, opts) => request(path, { ...opts, method: 'POST', body }),
    patch: (path, body, opts) => request(path, { ...opts, method: 'PATCH', body }),
    put: (path, body, opts) => request(path, { ...opts, method: 'PUT', body }),
    delete: (path, opts) => request(path, { ...opts, method: 'DELETE' }),
  };
}
