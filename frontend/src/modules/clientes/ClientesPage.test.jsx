import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { ClientesPage } from './ClientesPage.jsx';
import { ApiError } from '../../shared/apiClient.js';

import { useState, useEffect } from 'react';

const useOrganizationMock = vi.fn();
const apiClientMock = {
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  delete: vi.fn(),
};

let currentClients = [];
let queryListeners = new Set();

function updateClients(newClients) {
  currentClients = newClients;
  queryListeners.forEach((listener) => listener());
}

vi.mock('../../shared/useOrganization.js', () => ({
  useOrganization: () => useOrganizationMock(),
}));
vi.mock('../../shared/useApiClient.js', () => ({
  useApiClient: () => apiClientMock,
}));
let mockError = null;

vi.mock('../../shared/useCachedQuery.js', () => ({
  useCachedQuery: (storeName, filterFn) => {
    const [data, setData] = useState(currentClients);

    useEffect(() => {
      const listener = () => {
        setData(filterFn ? currentClients.filter(filterFn) : currentClients);
      };
      queryListeners.add(listener);
      return () => {
        queryListeners.delete(listener);
      };
    }, [filterFn]);

    const refetch = () => {
      setData(filterFn ? currentClients.filter(filterFn) : currentClients);
    };

    return { data, loading: false, error: mockError, refetch };
  },
}));

vi.mock('../../shared/idb.js', () => ({
  putRecord: vi.fn((store, record) => {
    const exists = currentClients.some(c => c.id === record.id);
    const next = exists ? currentClients.map(c => c.id === record.id ? record : c) : [...currentClients, record];
    updateClients(next);
    return Promise.resolve();
  }),
  deleteRecord: vi.fn((store, id) => {
    updateClients(currentClients.filter(c => c.id !== id));
    return Promise.resolve();
  }),
  getAllRecords: vi.fn(() => Promise.resolve([])),
}));

const CLIENTS = [
  { id: 'client-1', name: 'Carla', phone: '11999990000', email: null, active: true },
  { id: 'client-2', name: 'Beto', phone: null, email: 'beto@example.com', active: true },
];

function mockClients(clients = CLIENTS) {
  updateClients(clients);
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/clients')) return Promise.resolve({ clients });
    if (path.startsWith('/appointments')) return Promise.resolve({ appointments: [] });
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('ClientesPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useOrganizationMock.mockReturnValue({ role: 'owner' });
    mockError = null;
  });

  it('renders the client list once loaded', async () => {
    mockClients();
    render(<ClientesPage />);

    await waitFor(() => expect(screen.getByText('Carla')).toBeInTheDocument());
    expect(screen.getByText('Beto')).toBeInTheDocument();
  });

  it('shows an empty message when there are no clients', async () => {
    mockClients([]);
    render(<ClientesPage />);

    await waitFor(() => expect(screen.getByText('Nenhum cliente encontrado.')).toBeInTheDocument());
  });

  it('shows a recoverable error state with retry when the list fails to load', async () => {
    mockError = new Error('network down');
    render(<ClientesPage />);

    await waitFor(() => expect(screen.getByText('network down')).toBeInTheDocument());
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('hides the remove action for reception (DELETE_ROLES excludes it) but keeps edit', async () => {
    useOrganizationMock.mockReturnValue({ role: 'reception' });
    mockClients();
    render(<ClientesPage />);

    await waitFor(() => expect(screen.getByText('Carla')).toBeInTheDocument());
    expect(screen.getAllByText('Editar').length).toBe(2);
    expect(screen.queryByText('Remover')).not.toBeInTheDocument();
  });

  it('creates a client through the modal and shows it in the list', async () => {
    mockClients([]);
    apiClientMock.post.mockResolvedValue({ client: { id: 'client-new', name: 'Nova Cliente', phone: null, email: null, active: true } });
    render(<ClientesPage />);

    await waitFor(() => expect(screen.getByText('+ Novo cliente')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Novo cliente'));
    fireEvent.change(screen.getByLabelText('Nome'), { target: { value: 'Nova Cliente' } });
    fireEvent.click(screen.getByText('Criar cliente'));

    await waitFor(() => expect(screen.getByText('Nova Cliente')).toBeInTheDocument());
    expect(apiClientMock.post).toHaveBeenCalledWith('/clients', { name: 'Nova Cliente', phone: null, email: null });
  });

  it('maps a 409 conflict on removal to a Portuguese message instead of the raw backend text', async () => {
    mockClients();
    apiClientMock.delete.mockRejectedValue(new ApiError(409, 'referenced_by_other_records', 'client is referenced', 'req-1'));
    render(<ClientesPage />);

    await waitFor(() => expect(screen.getByText('Carla')).toBeInTheDocument());
    fireEvent.click(screen.getAllByText('Remover')[0]);
    fireEvent.click(screen.getByText('Sim'));

    await waitFor(() =>
      expect(screen.getByText('Este cliente tem agendamentos ou pedidos vinculados — desative em vez de excluir.')).toBeInTheDocument(),
    );
  });

  it('opens the appointment history when clicking a client', async () => {
    mockClients();
    render(<ClientesPage />);

    await waitFor(() => expect(screen.getByText('Carla')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Carla'));

    await waitFor(() => expect(screen.getByText('Histórico de agendamentos')).toBeInTheDocument());
    expect(screen.getByText('Nenhum agendamento ainda.')).toBeInTheDocument();
  });
});
