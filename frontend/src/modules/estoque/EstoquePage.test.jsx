import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { EstoquePage } from './EstoquePage.jsx';
import { ApiError } from '../../shared/apiClient.js';

const useOrganizationMock = vi.fn();
const apiClientMock = {
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  delete: vi.fn(),
};

vi.mock('../../shared/useOrganization.js', () => ({
  useOrganization: () => useOrganizationMock(),
}));
vi.mock('../../shared/useApiClient.js', () => ({
  useApiClient: () => apiClientMock,
}));

const PRODUCTS = [{ id: 'prod-1', sku: 'SKU1', name: 'Shampoo', price_cents: 3000, stock_on_hand: 5, active: true }];
const MOVEMENTS = [
  { id: 'move-1', product_id: 'prod-1', order_id: null, reason: 'purchase', quantity_delta: 10, balance_after: 10, created_at: '2026-07-01T10:00:00Z' },
];

function mockLists({ products = PRODUCTS, movements = MOVEMENTS } = {}) {
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/products')) return Promise.resolve({ products });
    if (path.startsWith('/inventory/movements')) return Promise.resolve({ movements });
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('EstoquePage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useOrganizationMock.mockReturnValue({ role: 'owner' });
  });

  it('renders products with stock levels and movements for a manage role', async () => {
    mockLists();
    render(<EstoquePage />);

    await waitFor(() => expect(screen.getAllByText('Shampoo').length).toBeGreaterThan(0));
    expect(screen.getByText(/estoque: 5/)).toBeInTheDocument();
    expect(screen.getByText(/saldo: 10/)).toBeInTheDocument();
  });

  it('shows an empty message when there are no products', async () => {
    mockLists({ products: [] });
    render(<EstoquePage />);

    await waitFor(() =>
      expect(screen.getByText('Nenhum produto cadastrado ainda. Cadastre produtos no módulo Catálogo.')).toBeInTheDocument(),
    );
  });

  it('shows a recoverable error state with retry when the lists fail to load', async () => {
    apiClientMock.get.mockRejectedValue(new Error('network down'));
    render(<EstoquePage />);

    await waitFor(() => expect(screen.getByText('Sem conexão. Verifique sua internet e tente novamente.')).toBeInTheDocument());
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('hides adjustment and movements for reception (inventory_adjust never included that role)', async () => {
    useOrganizationMock.mockReturnValue({ role: 'reception' });
    mockLists();
    render(<EstoquePage />);

    await waitFor(() => expect(screen.getByText('Shampoo')).toBeInTheDocument());
    expect(screen.getByText('Seu papel só pode visualizar os níveis de estoque nesta organização.')).toBeInTheDocument();
    expect(screen.queryByText('Ajustar estoque')).not.toBeInTheDocument();
    expect(screen.queryByText('Movimentações')).not.toBeInTheDocument();
    expect(apiClientMock.get).not.toHaveBeenCalledWith(expect.stringContaining('/inventory/movements'));
  });

  it('adjusts stock through the modal with an Idempotency-Key header', async () => {
    mockLists();
    apiClientMock.post.mockResolvedValue({ balance_after: 15 });
    render(<EstoquePage />);

    await waitFor(() => expect(screen.getAllByText('Shampoo').length).toBeGreaterThan(0));
    fireEvent.click(screen.getByText('Ajustar estoque'));
    fireEvent.change(screen.getByLabelText('Quantidade (negativa para saída)'), { target: { value: '10' } });
    fireEvent.click(screen.getByText('Confirmar ajuste'));

    await waitFor(() =>
      expect(apiClientMock.post).toHaveBeenCalledWith(
        '/inventory/adjustments',
        { product_id: 'prod-1', quantity_delta: 10, reason: 'purchase' },
        expect.objectContaining({ headers: expect.objectContaining({ 'Idempotency-Key': expect.any(String) }) }),
      ),
    );
  });

  it('rejects a negative quantity for purchase client-side, mirroring the RPC invariant', async () => {
    mockLists();
    render(<EstoquePage />);

    await waitFor(() => expect(screen.getAllByText('Shampoo').length).toBeGreaterThan(0));
    fireEvent.click(screen.getByText('Ajustar estoque'));
    fireEvent.change(screen.getByLabelText('Quantidade (negativa para saída)'), { target: { value: '-3' } });
    fireEvent.click(screen.getByText('Confirmar ajuste'));

    expect(
      screen.getByText('Compra e devolução só aceitam entrada de estoque (quantidade positiva). Use "Ajuste" para saída.'),
    ).toBeInTheDocument();
    expect(apiClientMock.post).not.toHaveBeenCalled();
  });

  it('maps an insufficient-stock conflict from inventory_adjust to a Portuguese message', async () => {
    mockLists();
    apiClientMock.post.mockRejectedValue(new ApiError(409, 'operation_rejected', 'insufficient stock', 'req-1'));
    render(<EstoquePage />);

    await waitFor(() => expect(screen.getAllByText('Shampoo').length).toBeGreaterThan(0));
    fireEvent.click(screen.getByText('Ajustar estoque'));
    fireEvent.change(screen.getByLabelText('Quantidade (negativa para saída)'), { target: { value: '-100' } });
    fireEvent.change(screen.getByLabelText('Motivo'), { target: { value: 'adjustment' } });
    fireEvent.click(screen.getByText('Confirmar ajuste'));

    await waitFor(() => expect(screen.getByText('Esse ajuste deixaria o estoque negativo.')).toBeInTheDocument());
  });
});
