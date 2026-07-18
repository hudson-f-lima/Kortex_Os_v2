import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor } from '@testing-library/react';
import { AuthProvider } from './AuthContext.jsx';
import { notifySessionExpired } from './sessionExpired.js';

const authMock = vi.hoisted(() => ({
  getSession: vi.fn(),
  onAuthStateChange: vi.fn(),
  signOut: vi.fn(),
}));

vi.mock('./supabaseClient.js', () => ({
  supabase: { auth: authMock },
}));

// ADR 0015 (Blue Team #4): um 401 em qualquer chamada de API deve forçar
// logout local (via notifySessionExpired), não só surfar um erro genérico.
describe('AuthProvider — sessão expirada', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    authMock.onAuthStateChange.mockReturnValue({ data: { subscription: { unsubscribe: vi.fn() } } });
  });

  it('força signOut quando notifySessionExpired dispara com uma sessão ativa', async () => {
    authMock.getSession.mockResolvedValue({ data: { session: { access_token: 'tok', user: { id: 'user-1' } } } });

    render(<AuthProvider><div>content</div></AuthProvider>);
    await waitFor(() => expect(authMock.getSession).toHaveBeenCalled());

    notifySessionExpired();

    expect(authMock.signOut).toHaveBeenCalledTimes(1);
  });

  it('não chama signOut se não houver sessão ativa (evita chamada redundante)', async () => {
    authMock.getSession.mockResolvedValue({ data: { session: null } });

    render(<AuthProvider><div>content</div></AuthProvider>);
    await waitFor(() => expect(authMock.getSession).toHaveBeenCalled());

    notifySessionExpired();

    expect(authMock.signOut).not.toHaveBeenCalled();
  });
});
