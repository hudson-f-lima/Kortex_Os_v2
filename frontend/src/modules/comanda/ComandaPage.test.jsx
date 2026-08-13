import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent, within } from '@testing-library/react';
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
  useFeatureFlag: (flagName) => Boolean(useOrganizationMock().settings?.[flagName]),
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
    fireEvent.click(screen.getAllByText('Adicionar')[0]);

    const closeButton = screen.getByRole('button', { name: 'Fechar comanda' });
    expect(closeButton).toBeDisabled();

    // Adicionar um serviço abre automaticamente o modal de atribuição de profissional.
    fireEvent.change(screen.getByLabelText('Profissional'), { target: { value: 'prof-1' } });
    fireEvent.click(screen.getByText('Concluir'));
    expect(closeButton).not.toBeDisabled();
  });

  it('closes a comanda end-to-end with a reconciled payment and shows the confirmation', async () => {
    mockLists();
    apiClientMock.post.mockResolvedValue({ order_id: 'order-123456789', organization_id: 'org-1', total_cents: 5000, status: 'closed' });

    renderComanda();

    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getAllByText('Adicionar')[0]);
    fireEvent.change(screen.getByLabelText('Profissional'), { target: { value: 'prof-1' } });
    fireEvent.click(screen.getByText('Concluir'));

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
    fireEvent.click(screen.getAllByText('Adicionar')[1]);
    fireEvent.click(screen.getByText('Fechar comanda'));
    fireEvent.click(screen.getByText('Confirmar fechamento'));

    await waitFor(() =>
      expect(screen.getByText('Estoque insuficiente para um dos produtos da comanda.')).toBeInTheDocument(),
    );
  });

  it('applies discount and tip, recalculates the total, and sends them to checkout', async () => {
    mockLists();
    apiClientMock.post.mockResolvedValue({ order_id: 'order-987654321', organization_id: 'org-1', total_cents: 4500, status: 'closed' });

    renderComanda();

    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getAllByText('Adicionar')[0]);
    fireEvent.change(screen.getByLabelText('Profissional'), { target: { value: 'prof-1' } });
    fireEvent.click(screen.getByText('Concluir'));
    fireEvent.click(screen.getByText('Fechar comanda'));

    fireEvent.change(screen.getByLabelText('Desconto (R$)'), { target: { value: '10,00' } });
    fireEvent.change(screen.getByLabelText('Gorjeta (R$)'), { target: { value: '5,00' } });

    expect(screen.getByText('Total a pagar: R$ 45,00')).toBeInTheDocument();
    fireEvent.click(screen.getByText('Preencher restante'));
    fireEvent.click(screen.getByText('Confirmar fechamento'));

    await waitFor(() => expect(screen.getByText('Comanda fechada')).toBeInTheDocument());
    expect(apiClientMock.post).toHaveBeenCalledWith(
      '/checkout',
      expect.objectContaining({ discount_cents: 1000, tip_cents: 500 }),
      expect.anything(),
    );
  });

  it('disables the tip field and rejects a discount larger than the subtotal', async () => {
    mockLists();

    renderComanda();

    await waitFor(() => expect(screen.getByText('Shampoo', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getAllByText('Adicionar')[1]); // product only, no service line
    fireEvent.click(screen.getByText('Fechar comanda'));

    expect(screen.getByLabelText('Gorjeta (R$)')).toBeDisabled();
    expect(screen.getByText(/Gorjeta só pode ser aplicada/)).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText('Desconto (R$)'), { target: { value: '999,00' } });
    expect(screen.getByText(/O desconto deve ser um valor entre 0 e o subtotal/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Confirmar fechamento' })).toBeDisabled();
  });

  it('lists closed orders and refunds one with a required reason', async () => {
    mockLists();
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
      if (path.startsWith('/catalog')) return Promise.resolve({ items: CATALOG_ITEMS });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
      if (path === '/orders') {
        return Promise.resolve({
          orders: [{ id: 'order-abcdef123', status: 'closed', total_cents: 5000, created_at: '2026-07-15T12:00:00Z' }],
        });
      }
      throw new Error(`unexpected path: ${path}`);
    });
    apiClientMock.post.mockResolvedValue({ order_id: 'order-abcdef123', organization_id: 'org-1', status: 'refunded' });

    renderComanda();

    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getByText('Comandas fechadas'));
    await waitFor(() => expect(screen.getByText(/Pedido #order-ab/)).toBeInTheDocument());

    fireEvent.click(screen.getByText('Estornar'));
    const confirmButton = screen.getByRole('button', { name: 'Confirmar estorno' });
    expect(confirmButton).toBeDisabled();

    fireEvent.change(screen.getByLabelText('Motivo do estorno'), { target: { value: 'customer_cancellation' } });
    fireEvent.click(screen.getByText('Confirmar estorno'));

    await waitFor(() =>
      expect(apiClientMock.post).toHaveBeenCalledWith(
        '/orders/order-abcdef123/refund',
        { reason: 'customer_cancellation' },
        expect.objectContaining({ headers: expect.objectContaining({ 'Idempotency-Key': expect.any(String) }) }),
      ),
    );
  });

  it('hides the estornar action for reception (order_refund never included that role)', async () => {
    useOrganizationMock.mockReturnValue({ role: 'reception' });
    mockLists();
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
      if (path.startsWith('/catalog')) return Promise.resolve({ items: CATALOG_ITEMS });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
      if (path === '/orders') {
        return Promise.resolve({
          orders: [{ id: 'order-abcdef123', status: 'closed', total_cents: 5000, created_at: '2026-07-15T12:00:00Z' }],
        });
      }
      throw new Error(`unexpected path: ${path}`);
    });

    renderComanda();

    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getByText('Comandas fechadas'));
    await waitFor(() => expect(screen.getByText(/Pedido #order-ab/)).toBeInTheDocument());
    expect(screen.queryByText('Estornar')).not.toBeInTheDocument();
  });

  it('recloses a reopened order only through the dark-launched backend command', async () => {
    useOrganizationMock.mockReturnValue({ role: 'owner', settings: { checkout_reopen_enabled: true } });
    mockLists();
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
      if (path.startsWith('/catalog')) return Promise.resolve({ items: CATALOG_ITEMS });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
      if (path === '/orders') {
        return Promise.resolve({
          orders: [{ id: 'order-reclose-1', status: 'reopened', total_cents: 5000, created_at: '2026-08-13T12:00:00Z' }],
        });
      }
      if (path === '/orders/order-reclose-1') {
        return Promise.resolve({
          order: {
            id: 'order-reclose-1', client_id: 'client-1', status: 'reopened', reopen_attempt_id: 'attempt-1',
            total_cents: 5000, discount_cents: 0, tip_cents: 0,
            items: [{ id: 'item-1', product_id: 'prod-1', description: 'Shampoo', quantity: 1, total_cents: 5000 }],
            payments: [{ method: 'cash', amount_cents: 5000 }],
          },
        });
      }
      throw new Error(`unexpected path: ${path}`);
    });
    apiClientMock.post.mockResolvedValue({ order_id: 'order-reclose-1', status: 'closed', current_revision: 2 });

    renderComanda();

    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getByText('Comandas fechadas'));
    await waitFor(() => expect(screen.getByText('Refinalizar')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Refinalizar'));
    await waitFor(() => expect(screen.getByText('Total revisado: R$ 50,00')).toBeInTheDocument());
    fireEvent.click(screen.getByRole('button', { name: 'Confirmar refinalização' }));

    await waitFor(() =>
      expect(apiClientMock.post).toHaveBeenCalledWith(
        '/orders/order-reclose-1/reclose',
        {
          reopen_attempt_id: 'attempt-1', client_id: 'client-1',
          items: [{ kind: 'product', id: 'prod-1', quantity: 1 }],
          payments: [{ method: 'cash', amount_cents: 5000 }],
          discount_cents: 0, tip_cents: 0,
        },
        expect.objectContaining({ headers: expect.objectContaining({ 'Idempotency-Key': expect.any(String) }) }),
      ),
    );
  });

  it('reopens a closed order through the dark-launched server commands', async () => {
    useOrganizationMock.mockReturnValue({ role: 'owner', settings: { checkout_reopen_enabled: true } });
    mockLists();
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
      if (path.startsWith('/catalog')) return Promise.resolve({ items: CATALOG_ITEMS });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
      if (path === '/orders') return Promise.resolve({ orders: [{ id: 'order-reopen-1', status: 'closed', total_cents: 5000, created_at: '2026-08-13T12:00:00Z' }] });
      throw new Error(`unexpected path: ${path}`);
    });
    apiClientMock.post
      .mockResolvedValueOnce({ order_id: 'order-reopen-1', reopen_attempt_id: 'attempt-1', status: 'requested' })
      .mockResolvedValueOnce({ order_id: 'order-reopen-1', reopen_attempt_id: 'attempt-1', status: 'reopened' });

    renderComanda();
    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getByText('Comandas fechadas'));
    await waitFor(() => expect(screen.getByText('Reabrir')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Reabrir'));
    fireEvent.change(screen.getByLabelText('Descrição'), { target: { value: 'corrigir item' } });
    fireEvent.click(screen.getByRole('button', { name: 'Confirmar reabertura' }));

    await waitFor(() => expect(apiClientMock.post).toHaveBeenNthCalledWith(
      1, '/orders/order-reopen-1/reopen-request',
      { reason_code: 'item_correction', reason_detail: 'corrigir item' }, expect.anything(),
    ));
    expect(apiClientMock.post).toHaveBeenNthCalledWith(
      2, '/orders/order-reopen-1/reopen', { reopen_attempt_id: 'attempt-1' }, expect.anything(),
    );
  });

  it('discards an open reactivation through the dark-launched server command', async () => {
    useOrganizationMock.mockReturnValue({ role: 'owner', settings: { checkout_reopen_enabled: true } });
    mockLists();
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
      if (path.startsWith('/catalog')) return Promise.resolve({ items: CATALOG_ITEMS });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
      if (path === '/orders') return Promise.resolve({ orders: [{ id: 'order-discard-1', status: 'reopened', total_cents: 5000, created_at: '2026-08-13T12:00:00Z' }] });
      if (path === '/orders/order-discard-1') return Promise.resolve({ order: { id: 'order-discard-1', reopen_attempt_id: 'attempt-discard-1' } });
      throw new Error(`unexpected path: ${path}`);
    });
    apiClientMock.post.mockResolvedValue({ order_id: 'order-discard-1', status: 'closed' });

    renderComanda();
    await waitFor(() => expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument());
    fireEvent.click(screen.getByText('Comandas fechadas'));
    await waitFor(() => expect(screen.getByText('Descartar reabertura')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Descartar reabertura'));
    const dialog = await screen.findByRole('dialog');
    fireEvent.click(within(dialog).getByRole('button', { name: 'Descartar reabertura' }));

    await waitFor(() => expect(apiClientMock.post).toHaveBeenCalledWith(
      '/orders/order-discard-1/reopen-discard',
      { reopen_attempt_id: 'attempt-discard-1' },
      expect.objectContaining({ headers: expect.objectContaining({ 'Idempotency-Key': expect.any(String) }) }),
    ));
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

    await waitFor(() => expect(screen.getByRole('button', { name: 'Fechar comanda' })).not.toBeDisabled());
    expect(screen.getByLabelText('Selecionar cliente').value).toBe('client-1');
  });

  // ADR 0012: appointments agora exige Idempotency-Key + version no PATCH —
  // a marcação best-effort de "concluído" ao fechar a comanda precisa
  // carregar a version do agendamento pré-carregado, não só o status.
  it('marks the source appointment as completed with Idempotency-Key and version after closing', async () => {
    mockLists();
    apiClientMock.get.mockImplementation((path) => {
      if (path.startsWith('/professionals')) return Promise.resolve({ professionals: PROFESSIONALS });
      if (path.startsWith('/catalog')) return Promise.resolve({ items: CATALOG_ITEMS });
      if (path.startsWith('/clients')) return Promise.resolve({ clients: CLIENTS });
      if (path === '/appointments/appt-1') {
        return Promise.resolve({
          appointment: { id: 'appt-1', client_id: 'client-1', professional_id: 'prof-1', service_id: 'svc-1', status: 'scheduled', version: 3 },
        });
      }
      throw new Error(`unexpected path: ${path}`);
    });
    apiClientMock.post.mockResolvedValue({ order_id: 'order-appt1', organization_id: 'org-1', total_cents: 5000, status: 'closed' });
    apiClientMock.patch.mockResolvedValue({ appointment: { id: 'appt-1', status: 'completed', version: 4 } });

    renderComanda('/comanda?appointment_id=appt-1');

    await waitFor(() => expect(screen.getByRole('button', { name: 'Fechar comanda' })).not.toBeDisabled());
    fireEvent.click(screen.getByText('Fechar comanda'));
    fireEvent.click(screen.getByText('Confirmar fechamento'));

    await waitFor(() => expect(screen.getByText('Comanda fechada')).toBeInTheDocument());
    await waitFor(() =>
      expect(apiClientMock.patch).toHaveBeenCalledWith(
        '/appointments/appt-1',
        { status: 'completed', version: 3 },
        expect.objectContaining({ headers: expect.objectContaining({ 'Idempotency-Key': expect.any(String) }) }),
      ),
    );
  });
});
