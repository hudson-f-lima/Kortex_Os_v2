import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor } from '@testing-library/react';
import { OrganizationProvider } from './OrganizationContext.jsx';

const useAuthMock = vi.fn();
vi.mock('./useAuth.js', () => ({
  useAuth: () => useAuthMock(),
}));

const clearAllStoresMock = vi.fn().mockResolvedValue(undefined);
const getMetaMock = vi.fn().mockResolvedValue(null);
const putMetaMock = vi.fn().mockResolvedValue(undefined);

vi.mock('./idb.js', () => ({
  clearAllStores: (...args) => clearAllStoresMock(...args),
  getMeta: (...args) => getMetaMock(...args),
  putMeta: (...args) => putMetaMock(...args),
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

describe('OrganizationProvider — limpeza de cache no logout', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    clearAllStoresMock.mockResolvedValue(undefined);
    getMetaMock.mockResolvedValue(null);
    putMetaMock.mockResolvedValue(undefined);
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

  it('Fase 1: preserva o cache (warm start) se o contexto (user + org) for idêntico', async () => {
    // Mock getMeta para simular que o contexto já estava salvo
    getMetaMock.mockImplementation((key) => {
      if (key === 'active_user_id') return Promise.resolve('user-1');
      if (key === 'active_organization_id') return Promise.resolve('org-1');
      if (key === 'active_schema_version') return Promise.resolve(1);
      return Promise.resolve(null);
    });

    useAuthMock.mockReturnValue({ accessToken: 'token-1', user: { id: 'user-1' } });

    render(
      <OrganizationProvider>
        <div>content</div>
      </OrganizationProvider>,
    );

    await waitFor(() => expect(engineStart).toHaveBeenCalledTimes(1));
    
    // clearAllStores não deve ter sido chamado, provando o warm start
    expect(clearAllStoresMock).not.toHaveBeenCalled();
  });

  it('Fase 1: limpa o cache se o contexto de organização ou usuário mudar', async () => {
    // Mock getMeta para simular que havia outro contexto salvo (diferente do atual org-1)
    getMetaMock.mockImplementation((key) => {
      if (key === 'active_user_id') return Promise.resolve('user-1');
      if (key === 'active_organization_id') return Promise.resolve('org-old'); // organização diferente
      if (key === 'active_schema_version') return Promise.resolve(1);
      return Promise.resolve(null);
    });

    useAuthMock.mockReturnValue({ accessToken: 'token-1', user: { id: 'user-1' } });

    render(
      <OrganizationProvider>
        <div>content</div>
      </OrganizationProvider>,
    );

    await waitFor(() => expect(engineStart).toHaveBeenCalledTimes(1));

    // clearAllStores deve ser chamado para evitar contaminação
    expect(clearAllStoresMock).toHaveBeenCalledTimes(1);
    // E deve persistir o novo contexto
    expect(putMetaMock).toHaveBeenCalledWith('active_user_id', 'user-1');
    expect(putMetaMock).toHaveBeenCalledWith('active_organization_id', 'org-1');
  });

  it('Fase 1: evita a inicialização de múltiplos sync engines concorrentes (StrictMode)', async () => {
    useAuthMock.mockReturnValue({ accessToken: 'token-1', user: { id: 'user-1' } });

    // Mock getMeta para demorar e simular concorrência
    let resolveGetMeta;
    const promise = new Promise((resolve) => {
      resolveGetMeta = resolve;
    });
    getMetaMock.mockReturnValue(promise);

    const { unmount } = render(
      <OrganizationProvider>
        <div>content</div>
      </OrganizationProvider>,
    );

    // Espera o getMeta ser chamado (o que prova que o effect do sync engine rodou)
    await waitFor(() => expect(getMetaMock).toHaveBeenCalled());

    // Desmonta simulando o unmount rápido do StrictMode
    unmount();
    
    // Resolve o getMeta
    resolveGetMeta('some-value');

    // Espera um pouco e garante que o motor não iniciou, mas foi parado (engineStop chamado)
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(engineStart).not.toHaveBeenCalled();
    expect(engineStop).toHaveBeenCalled();
  });
});
