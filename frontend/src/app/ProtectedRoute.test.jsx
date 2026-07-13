import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { ProtectedRoute } from './ProtectedRoute.jsx';

const useAuthMock = vi.fn();
vi.mock('../shared/AuthContext.jsx', () => ({
  useAuth: () => useAuthMock(),
}));

function renderAt(path) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/login" element={<div>Login Page</div>} />
        <Route element={<ProtectedRoute />}>
          <Route path="/agenda" element={<div>Secret Agenda</div>} />
        </Route>
      </Routes>
    </MemoryRouter>,
  );
}

describe('ProtectedRoute', () => {
  it('redirects to /login when there is no session', () => {
    useAuthMock.mockReturnValue({ session: null, loading: false });
    renderAt('/agenda');
    expect(screen.getByText('Login Page')).toBeInTheDocument();
  });

  it('renders the protected content when a session exists', () => {
    useAuthMock.mockReturnValue({ session: { user: { id: '1' } }, loading: false });
    renderAt('/agenda');
    expect(screen.getByText('Secret Agenda')).toBeInTheDocument();
  });

  it('shows a loading state before the session is resolved', () => {
    useAuthMock.mockReturnValue({ session: null, loading: true });
    renderAt('/agenda');
    expect(screen.queryByText('Secret Agenda')).not.toBeInTheDocument();
    expect(screen.queryByText('Login Page')).not.toBeInTheDocument();
  });
});
