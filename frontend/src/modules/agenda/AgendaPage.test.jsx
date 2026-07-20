import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { AgendaPage } from './AgendaPage.jsx';
import { useState, useEffect } from 'react';

function renderAgenda() {
  return render(
    <MemoryRouter>
      <AgendaPage />
    </MemoryRouter>,
  );
}

const useAuthMock = vi.fn();
const useOrganizationMock = vi.fn();
const apiClientMock = {
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  delete: vi.fn(),
};

let currentProfessionals = [];
let currentServices = [];
let currentClients = [];
let currentAppointments = [];
let queryListeners = new Set();
let mockError = null;

function updateState(professionals, services, clients, appointments) {
  if (professionals !== undefined) currentProfessionals = professionals;
  if (services !== undefined) currentServices = services;
  if (clients !== undefined) currentClients = clients;
  if (appointments !== undefined) currentAppointments = appointments;
  queryListeners.forEach((listener) => listener());
}

vi.mock('../../shared/useAuth.js', () => ({
  useAuth: () => useAuthMock(),
}));
vi.mock('../../shared/useOrganization.js', () => ({
  useOrganization: () => useOrganizationMock(),
}));
vi.mock('../../shared/useApiClient.js', () => ({
  useApiClient: () => apiClientMock,
}));
vi.mock('../../shared/useCachedQuery.js', () => ({
  useCachedQuery: (storeName, filterFn) => {
    let initialData = [];
    if (storeName === 'professionals') initialData = currentProfessionals;
    else if (storeName === 'services') initialData = currentServices;
    else if (storeName === 'clients') initialData = currentClients;
    else if (storeName === 'appointments') initialData = currentAppointments;

    const [data, setData] = useState(initialData);

    useEffect(() => {
      const listener = () => {
        let current = [];
        if (storeName === 'professionals') current = currentProfessionals;
        else if (storeName === 'services') current = currentServices;
        else if (storeName === 'clients') current = currentClients;
        else if (storeName === 'appointments') current = currentAppointments;

        setData(filterFn ? current.filter(filterFn) : current);
      };
      queryListeners.add(listener);
      listener();
      return () => {
        queryListeners.delete(listener);
      };
    }, [storeName, filterFn]);

    const refetch = () => {
      let current = [];
      if (storeName === 'professionals') current = currentProfessionals;
      else if (storeName === 'services') current = currentServices;
      else if (storeName === 'clients') current = currentClients;
      else if (storeName === 'appointments') current = currentAppointments;
      setData(filterFn ? current.filter(filterFn) : current);
    };

    return { data, loading: false, error: mockError, refetch };
  },
}));

vi.mock('../../shared/idb.js', () => ({
  putRecord: vi.fn((store, record) => {
    if (store === 'appointments') {
      const exists = currentAppointments.some(a => a.id === record.id);
      const next = exists ? currentAppointments.map(a => a.id === record.id ? record : a) : [...currentAppointments, record];
      updateState(undefined, undefined, undefined, next);
    } else if (store === 'clients') {
      const exists = currentClients.some(c => c.id === record.id);
      const next = exists ? currentClients.map(c => c.id === record.id ? record : c) : [...currentClients, record];
      updateState(undefined, undefined, next, undefined);
    }
    return Promise.resolve();
  }),
}));

const PROFESSIONALS = [
  { id: 'prof-1', name: 'Ana', user_id: 'user-ana', active: true },
  { id: 'prof-2', name: 'Beatriz', user_id: 'user-beatriz', active: true },
];
const SERVICES = [{ id: 'svc-1', name: 'Corte', duration_minutes: 30, price_cents: 5000, active: true }];
const CLIENTS = [{ id: 'client-1', name: 'Carla', phone: '11999990000', active: true }];

function mockLists({ professionals = PROFESSIONALS, services = SERVICES, clients = CLIENTS, appointments = [] } = {}) {
  updateState(professionals, services, clients, appointments);
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/professionals')) return Promise.resolve({ professionals });
    if (path.startsWith('/services')) return Promise.resolve({ services });
    if (path.startsWith('/clients')) return Promise.resolve({ clients });
    if (path.startsWith('/appointments')) return Promise.resolve({ appointments });
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('AgendaPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useAuthMock.mockReturnValue({ user: { id: 'user-owner' } });
    useOrganizationMock.mockReturnValue({ role: 'owner' });
    mockError = null;
  });

  it('renders the day grid with professional columns and a fetched appointment', async () => {
    mockLists({
      appointments: [
        {
          id: 'appt-1',
          client_id: 'client-1',
          professional_id: 'prof-1',
          service_id: 'svc-1',
          starts_at: (() => {
            const d = new Date();
            d.setHours(9, 0, 0, 0);
            return d.toISOString();
          })(),
          ends_at: (() => {
            const d = new Date();
            d.setHours(10, 0, 0, 0);
            return d.toISOString();
          })(),
          status: 'scheduled',
        },
      ],
    });

    renderAgenda();

    await waitFor(() => expect(screen.getAllByText('Ana').length).toBeGreaterThan(0));
    // Timeline Vertical (redesign) troca colunas por profissional por um filtro
    // único — Beatriz aparece como opção no <select>, não como cabeçalho de coluna.
    expect(screen.getByRole('option', { name: 'Beatriz' })).toBeInTheDocument();
    expect(screen.getByText('Carla', { exact: false })).toBeInTheDocument();
    expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument();
  });

  it('shows an empty-org message when there are no professionals', async () => {
    mockLists({ professionals: [], services: [], clients: [], appointments: [] });

    renderAgenda();

    await waitFor(() =>
      expect(screen.getByText(/Nenhum profissional cadastrado. Cadastre/)).toBeInTheDocument(),
    );
  });

  it('shows a recoverable error state with retry when the lists fail to load', async () => {
    mockError = new Error('network down');

    renderAgenda();

    await waitFor(() =>
      expect(screen.getByText('network down')).toBeInTheDocument(),
    );
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('hides mutation affordances for the professional role (read-only recorte próprio)', async () => {
    useAuthMock.mockReturnValue({ user: { id: 'user-ana' } });
    useOrganizationMock.mockReturnValue({ role: 'professional' });
    mockLists();

    renderAgenda();

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    expect(screen.queryByText('Beatriz')).not.toBeInTheDocument();
    expect(screen.queryByText('+ Novo')).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Filtrar por profissional')).not.toBeInTheDocument();
  });

  it('opens the create modal when clicking "+ Novo"', async () => {
    mockLists();

    renderAgenda();

    await waitFor(() => expect(screen.getByText('+ Novo')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Novo'));

    expect(screen.getByText('Novo agendamento')).toBeInTheDocument();
  });
});
