import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { CatalogoPage } from './CatalogoPage.jsx';
import { ApiError } from '../../shared/apiClient.js';

const useOrganizationMock = vi.fn();
const apiClientMock = {
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  delete: vi.fn(),
};

vi.mock('../../shared/OrganizationContext.jsx', () => ({
  useOrganization: () => useOrganizationMock(),
}));
vi.mock('../../shared/useApiClient.js', () => ({
  useApiClient: () => apiClientMock,
}));

const GROUPS = [{ id: 'group-1', name: 'Cabelo', default_commission_type: 'percentage', default_commission_value: 1000, active: true }];
const SERVICES = [
  { id: 'svc-1', name: 'Corte', price_cents: 5000, duration_minutes: 30, service_group_id: 'group-1', commission_type: null, commission_value: null, active: true },
];
const PRODUCTS = [{ id: 'prod-1', sku: 'SKU1', name: 'Shampoo', price_cents: 3000, cost_cents: 1000, stock_on_hand: 5, active: true }];
const PACKAGES = [{ id: 'pkg-1', name: 'Combo', price_cents: 8000, active: true }];

function mockLists({ groups = GROUPS, services = SERVICES, products = PRODUCTS, packages = PACKAGES } = {}) {
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/service-groups')) return Promise.resolve({ service_groups: groups });
    if (path.startsWith('/services')) return Promise.resolve({ services });
    if (path.startsWith('/products')) return Promise.resolve({ products });
    if (path.startsWith('/packages')) return Promise.resolve({ packages });
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('CatalogoPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useOrganizationMock.mockReturnValue({ role: 'owner' });
  });

  it('renders the services tab by default with the group name resolved', async () => {
    mockLists();
    render(<CatalogoPage />);

    await waitFor(() => expect(screen.getByText('Corte')).toBeInTheDocument());
    expect(screen.getByText(/Cabelo/)).toBeInTheDocument();
  });

  it('switches to the products tab and shows stock on hand', async () => {
    mockLists();
    render(<CatalogoPage />);

    await waitFor(() => expect(screen.getByText('Corte')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Produtos'));

    expect(screen.getByText(/estoque: 5/)).toBeInTheDocument();
  });

  it('shows a recoverable error state with retry when the lists fail to load', async () => {
    apiClientMock.get.mockRejectedValue(new Error('network down'));
    render(<CatalogoPage />);

    await waitFor(() => expect(screen.getByText('Sem conexão. Verifique sua internet e tente novamente.')).toBeInTheDocument());
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('hides mutation affordances for reception (read-only catalog browsing)', async () => {
    useOrganizationMock.mockReturnValue({ role: 'reception' });
    mockLists();
    render(<CatalogoPage />);

    await waitFor(() => expect(screen.getByText('Corte')).toBeInTheDocument());
    expect(screen.queryByText('+ Novo serviço')).not.toBeInTheDocument();
    expect(screen.queryByText('Editar')).not.toBeInTheDocument();
    expect(screen.queryByText('Remover')).not.toBeInTheDocument();
  });

  it('hints to create a service group before a service can be created', async () => {
    mockLists({ groups: [] });
    render(<CatalogoPage />);

    await waitFor(() => expect(screen.getByText('Cadastre um grupo de serviço antes de criar serviços.')).toBeInTheDocument());
    expect(screen.queryByText('+ Novo serviço')).not.toBeInTheDocument();
  });

  it('creates a service group through the modal', async () => {
    mockLists({ groups: [] });
    apiClientMock.post.mockResolvedValue({
      service_group: { id: 'group-new', name: 'Unhas', default_commission_type: 'percentage', default_commission_value: 1500, active: true },
    });
    render(<CatalogoPage />);

    await waitFor(() => expect(screen.getByText('Grupos de serviço')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Grupos de serviço'));
    fireEvent.click(screen.getByText('+ Novo grupo'));
    fireEvent.change(screen.getByLabelText('Nome'), { target: { value: 'Unhas' } });
    fireEvent.change(screen.getByLabelText(/Comissão padrão/), { target: { value: '15' } });
    fireEvent.click(screen.getByText('Criar grupo'));

    await waitFor(() => expect(screen.getByText('Unhas')).toBeInTheDocument());
    expect(apiClientMock.post).toHaveBeenCalledWith('/service-groups', {
      name: 'Unhas',
      default_commission_type: 'percentage',
      default_commission_value: 1500,
    });
  });

  it('maps a 409 conflict on group removal to a Portuguese message', async () => {
    mockLists();
    apiClientMock.delete.mockRejectedValue(new ApiError(409, 'referenced_by_other_records', 'group is referenced', 'req-1'));
    render(<CatalogoPage />);

    await waitFor(() => expect(screen.getByText('Corte')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Grupos de serviço'));
    fireEvent.click(screen.getByText('Remover'));
    fireEvent.click(screen.getByText('Sim'));

    await waitFor(() =>
      expect(screen.getByText('Este grupo tem serviços vinculados — desative em vez de excluir.')).toBeInTheDocument(),
    );
  });
});
