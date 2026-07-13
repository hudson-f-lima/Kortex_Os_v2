import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { AgendaPage } from './AgendaPage.jsx';

const useAuthMock = vi.fn();
const useOrganizationMock = vi.fn();
const apiClientMock = {
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  delete: vi.fn(),
};

vi.mock('../../shared/AuthContext.jsx', () => ({
  useAuth: () => useAuthMock(),
}));
vi.mock('../../shared/OrganizationContext.jsx', () => ({
  useOrganization: () => useOrganizationMock(),
}));
vi.mock('../../shared/useApiClient.js', () => ({
  useApiClient: () => apiClientMock,
}));

const PROFESSIONALS = [
  { id: 'prof-1', name: 'Ana', user_id: 'user-ana', active: true },
  { id: 'prof-2', name: 'Beatriz', user_id: 'user-beatriz', active: true },
];
const SERVICES = [{ id: 'svc-1', name: 'Corte', duration_minutes: 30, price_cents: 5000, active: true }];
const CLIENTS = [{ id: 'client-1', name: 'Carla', phone: '11999990000', active: true }];

function mockLists({ appointments = [] } = {}) {
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
    if (path.startsWith('/services')) return Promise.resolve({ services: SERVICES });
    if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
    if (path.startsWith('/appointments')) return Promise.resolve({ appointments });
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('AgendaPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useAuthMock.mockReturnValue({ user: { id: 'user-owner' } });
    useOrganizationMock.mockReturnValue({ role: 'owner' });
  });

  it('renders the day grid with professional columns and a fetched appointment', async () => {
    mockLists({
      appointments: [
        {
          id: 'appt-1',
          client_id: 'client-1',
          professional_id: 'prof-1',
          service_id: 'svc-1',
          starts_at: new Date(2026, 6, 15, 9, 0).toISOString(),
          ends_at: new Date(2026, 6, 15, 9, 30).toISOString(),
          status: 'scheduled',
        },
      ],
    });

    render(<AgendaPage />);

    await waitFor(() => expect(screen.getAllByText('Ana').length).toBeGreaterThan(0));
    expect(screen.getByText('Beatriz', { selector: '.agenda-grid-header-cell' })).toBeInTheDocument();
    expect(screen.getByText('Carla', { exact: false })).toBeInTheDocument();
    expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument();
  });

  it('shows an empty-org message when there are no professionals', async () => {
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: [] });
      if (path.startsWith('/services')) return Promise.resolve({ services: [] });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: [] });
      if (path.startsWith('/appointments')) return Promise.resolve({ appointments: [] });
      throw new Error(`unexpected path: ${path}`);
    });

    render(<AgendaPage />);

    await waitFor(() =>
      expect(screen.getByText(/Nenhum profissional cadastrado ainda/)).toBeInTheDocument(),
    );
  });

  it('shows a recoverable error state with retry when the lists fail to load', async () => {
    apiClientMock.get.mockRejectedValue(new Error('network down'));

    render(<AgendaPage />);

    await waitFor(() =>
      expect(screen.getByText('Sem conexão. Verifique sua internet e tente novamente.')).toBeInTheDocument(),
    );
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('hides mutation affordances for the professional role (read-only recorte próprio)', async () => {
    useAuthMock.mockReturnValue({ user: { id: 'user-ana' } });
    useOrganizationMock.mockReturnValue({ role: 'professional' });
    mockLists();

    render(<AgendaPage />);

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    expect(screen.queryByText('Beatriz')).not.toBeInTheDocument();
    expect(screen.queryByText('+ Novo agendamento')).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Filtrar por profissional')).not.toBeInTheDocument();
  });

  it('opens the create modal when clicking "+ Novo agendamento"', async () => {
    mockLists();

    render(<AgendaPage />);

    await waitFor(() => expect(screen.getByText('+ Novo agendamento')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Novo agendamento'));

    expect(screen.getByText('Novo agendamento')).toBeInTheDocument();
  });
});
