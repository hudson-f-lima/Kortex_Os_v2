import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ComandaPage } from './ComandaPage.jsx';
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

const PROFESSIONALS = [{ id: 'prof-1', name: 'Ana', active: true }];
const CATALOG_ITEMS = [
  { kind: 'service', id: 'svc-1', name: 'Corte', price_cents: 5000, duration_minutes: 30, active: true },
  { kind: 'product', id: 'prod-1', name: 'Shampoo', price_cents: 3000, stock_on_hand: 5, active: true },
];
const CLIENTS = [{ id: 'client-1', name: 'Carla', phone: '11999990000', active: true }];

function mockLists() {
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
    if (path.startsWith('/catalog')) return Promise.resolve({ items: CATALOG_ITEMS });
    if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
    throw new Error(`unexpected path: ${path}`);
  });
}

function renderComanda(initialEntry = '/comanda') {
  return render(
    <MemoryRouter initialEntries={[initialEntry]}>
      <ComandaPage />
    </MemoryRouter>,
  );
}

describe('ComandaPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useOrganizationMock.mockReturnValue({ role: 'owner' });
  });

  it('shows an unavailable message for the professional role instead of the builder', () => {
    useOrganizationMock.mockReturnValue({ role: 'professional' });

    renderComanda();

    expect(screen.getByText(/Seu papel não pode abrir ou fechar comandas/)).toBeInTheDocument();
    expect(apiClientMock.get).not.toHaveBeenCalled();
  });

  it('shows an empty-catalog message when there are no items to sell', async () => {
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: [] });
      if (path.startsWith('/catalog')) return Promise.resolve({ items: [] });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: [] });
      throw new Error(`unexpected path: ${path}`);
    });

    renderComanda();

    await waitFor(() => expect(screen.getByText(/Nenhum item no catálogo ainda/)).toBeInTheDocument());
  });

  it('requires a professional on a service line before allowing checkout to proceed', async () => {
    mockLists();

    renderComanda();

    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getAllByText('+ Adicionar')[0]);

    const closeButton = screen.getByText('Fechar comanda');
    expect(closeButton).toBeDisabled();

    fireEvent.change(screen.getByLabelText('Profissional para Corte'), { target: { value: 'prof-1' } });
    expect(closeButton).not.toBeDisabled();
  });

  it('closes a comanda end-to-end with a reconciled payment and shows the confirmation', async () => {
    mockLists();
    apiClientMock.post.mockResolvedValue({ order_id: 'order-123456789', organization_id: 'org-1', total_cents: 5000, status: 'closed' });

    renderComanda();

    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getAllByText('+ Adicionar')[0]);
    fireEvent.change(screen.getByLabelText('Profissional para Corte'), { target: { value: 'prof-1' } });

    fireEvent.click(screen.getByText('Fechar comanda'));

    expect(screen.getByText('Total a pagar: R$ 50,00')).toBeInTheDocument();
    fireEvent.click(screen.getByText('Confirmar fechamento'));

    await waitFor(() => expect(screen.getByText('Comanda fechada')).toBeInTheDocument());
    expect(apiClientMock.post).toHaveBeenCalledWith(
      '/checkout',
      expect.objectContaining({
        items: [{ kind: 'service', id: 'svc-1', quantity: 1, professional_id: 'prof-1' }],
        payments: [{ method: 'cash', amount_cents: 5000 }],
      }),
      expect.objectContaining({ headers: expect.objectContaining({ 'Idempotency-Key': expect.any(String) }) }),
    );
  });

  it('maps an insufficient-stock conflict from checkout_close to a Portuguese message', async () => {
    mockLists();
    apiClientMock.post.mockRejectedValue(new ApiError(409, 'operation_rejected', 'insufficient stock', 'req-1'));

    renderComanda();

    await waitFor(() => expect(screen.getByText('Shampoo', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getAllByText('+ Adicionar')[1]);
    fireEvent.click(screen.getByText('Fechar comanda'));
    fireEvent.click(screen.getByText('Confirmar fechamento'));

    await waitFor(() =>
      expect(screen.getByText('Estoque insuficiente para um dos produtos da comanda.')).toBeInTheDocument(),
    );
  });

  it('prefills client and service from an appointment_id query param', async () => {
    mockLists();
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
      if (path.startsWith('/catalog')) return Promise.resolve({ items: CATALOG_ITEMS });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
      if (path === '/appointments/appt-1') {
        return Promise.resolve({
          appointment: { id: 'appt-1', client_id: 'client-1', professional_id: 'prof-1', service_id: 'svc-1', status: 'scheduled' },
        });
      }
      throw new Error(`unexpected path: ${path}`);
    });

    renderComanda('/comanda?appointment_id=appt-1');

    await waitFor(() => expect(screen.getByText('Fechar comanda')).not.toBeDisabled());
    expect(screen.getByLabelText('Selecionar cliente').value).toBe('client-1');
  });
});
