import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { CapabilitiesTab } from './CapabilitiesTab.jsx';
import { ApiError } from '../../shared/apiClient.js';

const apiClientMock = {
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  delete: vi.fn(),
};

vi.mock('../../shared/useApiClient.js', () => ({
  useApiClient: () => apiClientMock,
}));

const PROFESSIONALS = [{ id: 'prof-1', name: 'Ana' }];
const SERVICES = [{ id: 'svc-1', name: 'Corte' }];
const CAPABILITIES = [
  {
    id: 'cap-1',
    professional_id: 'prof-1',
    service_id: 'svc-1',
    duration_override_minutes: 45,
    buffer_before_min: 10,
    buffer_after_min: 5,
    price_override_cents: 6000,
  },
];

function mockList(capabilities = CAPABILITIES) {
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/professional-service-capabilities')) {
      return Promise.resolve({ professional_service_capabilities: capabilities });
    }
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('CapabilitiesTab', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders capabilities with resolved professional/service names', async () => {
    mockList();
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="owner" />);

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    expect(screen.getByText('Corte')).toBeInTheDocument();
    expect(screen.getByText('45min')).toBeInTheDocument();
    expect(screen.getByText('R$ 60.00')).toBeInTheDocument();
  });

  it('shows an empty message when there are no capabilities', async () => {
    mockList([]);
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="owner" />);

    await waitFor(() => expect(screen.getByText('Nenhuma capacidade configurada ainda.')).toBeInTheDocument());
  });

  it('shows a recoverable error state with retry when the list fails to load', async () => {
    apiClientMock.get.mockRejectedValue(new Error('network down'));
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="owner" />);

    await waitFor(() => expect(screen.getByText('Sem conexão. Verifique sua internet e tente novamente.')).toBeInTheDocument());
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('hides write/delete affordances for a role without them (reception)', async () => {
    mockList();
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="reception" />);

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    expect(screen.queryByText('+ Adicionar capacidade')).not.toBeInTheDocument();
    expect(screen.queryByText('Editar')).not.toBeInTheDocument();
    expect(screen.queryByText('Remover')).not.toBeInTheDocument();
  });

  it('shows edit but not delete for manager (delete requires owner/admin)', async () => {
    mockList();
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="manager" />);

    await waitFor(() => expect(screen.getByText('Editar')).toBeInTheDocument());
    expect(screen.queryByText('Remover')).not.toBeInTheDocument();
  });

  it('creates a capability through the modal', async () => {
    mockList([]);
    apiClientMock.post.mockResolvedValue({
      professional_service_capability: {
        id: 'cap-new',
        professional_id: 'prof-1',
        service_id: 'svc-1',
        duration_override_minutes: 40,
        buffer_before_min: 0,
        buffer_after_min: 0,
        price_override_cents: null,
      },
    });
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="owner" />);

    await waitFor(() => expect(screen.getByText('+ Adicionar capacidade')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Adicionar capacidade'));

    fireEvent.change(screen.getByLabelText('Profissional'), {
      target: { value: 'prof-1' },
    });
    fireEvent.change(screen.getByLabelText('Serviço'), {
      target: { value: 'svc-1' },
    });
    fireEvent.change(screen.getByLabelText('Duração customizada (minutos)'), {
      target: { value: '40' },
    });
    fireEvent.click(screen.getByText('Salvar'));

    await waitFor(() => expect(apiClientMock.post).toHaveBeenCalledWith('/professional-service-capabilities', {
      professional_id: 'prof-1',
      service_id: 'svc-1',
      duration_override_minutes: 40,
      buffer_before_min: 0,
      buffer_after_min: 0,
      price_override_cents: null,
    }));
    await waitFor(() => expect(screen.getByText('40min')).toBeInTheDocument());
  });

  it('maps a duplicate (already_exists) conflict to a Portuguese message', async () => {
    mockList([]);
    apiClientMock.post.mockRejectedValue(new ApiError(409, 'already_exists', 'a record already exists', 'req-1'));
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="owner" />);

    await waitFor(() => expect(screen.getByText('+ Adicionar capacidade')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Adicionar capacidade'));
    fireEvent.change(screen.getByLabelText('Profissional'), {
      target: { value: 'prof-1' },
    });
    fireEvent.change(screen.getByLabelText('Serviço'), {
      target: { value: 'svc-1' },
    });
    fireEvent.click(screen.getByText('Salvar'));

    await waitFor(() =>
      expect(screen.getByText('Este profissional já tem uma capacidade cadastrada para este serviço.')).toBeInTheDocument(),
    );
  });

  it('removes a capability after inline confirmation', async () => {
    mockList();
    apiClientMock.delete.mockResolvedValue(undefined);
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="owner" />);

    await waitFor(() => expect(screen.getByText('Remover')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Remover'));
    expect(screen.getByText('Confirma?')).toBeInTheDocument();
    fireEvent.click(screen.getByText('Sim'));

    await waitFor(() => expect(apiClientMock.delete).toHaveBeenCalledWith('/professional-service-capabilities/cap-1'));
    await waitFor(() => expect(screen.getByText('Nenhuma capacidade configurada ainda.')).toBeInTheDocument());
  });

  it('client-side validation rejects an out-of-range buffer before calling the API', async () => {
    mockList();
    render(<CapabilitiesTab professionals={PROFESSIONALS} services={SERVICES} currentRole="owner" />);

    // Editing an existing capability skips professional/service selection —
    // those fields are disabled on edit (identity is immutable) — isolating
    // the buffer validation from the create flow's extra steps.
    await waitFor(() => expect(screen.getByText('Editar')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Editar'));

    fireEvent.change(screen.getByLabelText('Buffer antes (minutos)'), {
      target: { value: '500' },
    });
    fireEvent.click(screen.getByText('Salvar'));

    await waitFor(() =>
      expect(screen.getByText('Buffer antes deve ser um número inteiro entre 0 e 480 minutos.')).toBeInTheDocument(),
    );
    expect(apiClientMock.patch).not.toHaveBeenCalled();
  });
});
