import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor } from '@testing-library/react';
import { OrganizationProvider } from './OrganizationContext.jsx';

const useAuthMock = vi.fn();
vi.mock('./useAuth.js', () => ({
  useAuth: () => useAuthMock(),
}));

const clearAllStoresMock = vi.fn().mockResolvedValue(undefined);
vi.mock('./idb.js', () => ({
  clearAllStores: (...args) => clearAllStoresMock(...args),
}));

const engineStart = vi.fn().mockResolvedValue(undefined);
const engineStop = vi.fn();
vi.mock('./syncEngine.js', () => ({
  createSyncEngine: vi.fn(() => ({ start: engineStart, stop: engineStop })),
}));

vi.mock('./apiClient.js', () => ({
  createApiClient: () => ({
    get: vi.fn().mockResolvedValue({ organizations: [{ id: 'org-1', name: 'Org', slug: 'org', role: 'owner' }] }),
  }),
}));

// ADR 0015 (Blue Team #3): verifica que o logout limpa a projeção local do
// IndexedDB (não deixar dados de uma sessão/tenant anterior acessíveis num
// dispositivo compartilhado) e que o sync engine para ANTES da limpeza —
// caso contrário um evento em voo poderia reescrever algo no IndexedDB logo
// após ele ser esvaziado.
describe('OrganizationProvider — limpeza de cache no logout', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    clearAllStoresMock.mockResolvedValue(undefined);
    engineStart.mockResolvedValue(undefined);
    localStorage.clear();
  });

  it('para o sync engine e limpa o IndexedDB quando o usuário desloga', async () => {
    useAuthMock.mockReturnValue({ accessToken: 'token-1', user: { id: 'user-1' } });

    const { rerender } = render(
      <OrganizationProvider>
        <div>content</div>
      </OrganizationProvider>,
    );

    await waitFor(() => expect(engineStart).toHaveBeenCalledTimes(1));
    // A seleção inicial da organização já limpa a projeção uma vez (troca de
    // organização/reset de cache) — isolar essa chamada da que o logout gera.
    const clearCallsBeforeLogout = clearAllStoresMock.mock.calls.length;

    useAuthMock.mockReturnValue({ accessToken: null, user: null });
    rerender(
      <OrganizationProvider>
        <div>content</div>
      </OrganizationProvider>,
    );

    await waitFor(() => expect(clearAllStoresMock.mock.calls.length).toBeGreaterThan(clearCallsBeforeLogout));
    expect(engineStop).toHaveBeenCalledTimes(1);

    const stopOrder = engineStop.mock.invocationCallOrder[0];
    const logoutClearOrder = clearAllStoresMock.mock.invocationCallOrder.at(-1);
    expect(stopOrder).toBeLessThan(logoutClearOrder);
  });
});
