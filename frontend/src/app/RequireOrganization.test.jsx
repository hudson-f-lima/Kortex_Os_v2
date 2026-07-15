import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { RequireOrganization } from './RequireOrganization.jsx';
import { OrganizationProvider } from '../shared/OrganizationContext.jsx';

const useAuthMock = vi.fn();
vi.mock('../shared/useAuth.js', () => ({
  useAuth: () => useAuthMock(),
}));

function renderWithOrgs(organizations) {
  global.fetch = vi.fn().mockResolvedValue({
    status: 200,
    ok: true,
    json: async () => ({ organizations }),
  });
  useAuthMock.mockReturnValue({ accessToken: 'token-123', user: { id: 'user-1' } });

  return render(
    <MemoryRouter initialEntries={['/agenda']}>
      <OrganizationProvider>
        <Routes>
          <Route path="/create-organization" element={<div>Create Organization Page</div>} />
          <Route element={<RequireOrganization />}>
            <Route path="/agenda" element={<div>Agenda Content</div>} />
          </Route>
        </Routes>
      </OrganizationProvider>
    </MemoryRouter>,
  );
}

describe('RequireOrganization', () => {
  beforeEach(() => {
    localStorage.clear();
  });

  it('redirects to /create-organization when the user has no organizations', async () => {
    renderWithOrgs([]);
    await waitFor(() => expect(screen.getByText('Create Organization Page')).toBeInTheDocument());
  });

  it('auto-selects and renders the route when there is exactly one organization', async () => {
    renderWithOrgs([{ id: 'org-1', name: 'Org Um', slug: 'org-um', role: 'owner' }]);
    await waitFor(() => expect(screen.getByText('Agenda Content')).toBeInTheDocument());
  });

  it('shows an organization picker when there is more than one and none stored', async () => {
    renderWithOrgs([
      { id: 'org-1', name: 'Org Um', slug: 'org-um', role: 'owner' },
      { id: 'org-2', name: 'Org Dois', slug: 'org-dois', role: 'manager' },
    ]);
    await waitFor(() => expect(screen.getByText('Escolha uma organização')).toBeInTheDocument());
    expect(screen.queryByText('Agenda Content')).not.toBeInTheDocument();
  });
});
