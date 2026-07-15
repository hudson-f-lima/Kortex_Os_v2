import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { CaixaPage } from './CaixaPage.jsx';

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

const ENTRIES = [
  { id: 'entry-1', order_id: 'order-1', kind: 'sale', amount_cents: 5000, description: 'Checkout', created_at: '2026-07-10T12:00:00Z' },
];

function mockEntries(entries = ENTRIES) {
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/cash-entries')) return Promise.resolve({ cash_entries: entries });
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('CaixaPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useOrganizationMock.mockReturnValue({ role: 'owner' });
  });

  it('renders cash entries once loaded', async () => {
    mockEntries();
    render(<CaixaPage />);

    await waitFor(() => expect(screen.getByText('R$ 50,00')).toBeInTheDocument());
    expect(screen.getByText(/Venda · Checkout/)).toBeInTheDocument();
  });

  it('shows an empty message when there are no entries', async () => {
    mockEntries([]);
    render(<CaixaPage />);

    await waitFor(() => expect(screen.getByText('Nenhum lançamento encontrado.')).toBeInTheDocument());
  });

  it('shows a recoverable error state with retry when the list fails to load', async () => {
    apiClientMock.get.mockRejectedValue(new Error('network down'));
    render(<CaixaPage />);

    await waitFor(() => expect(screen.getByText('Sem conexão. Verifique sua internet e tente novamente.')).toBeInTheDocument());
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('shows an unavailable message for reception instead of fetching (cash_entries_select never included that role)', () => {
    useOrganizationMock.mockReturnValue({ role: 'reception' });

    render(<CaixaPage />);

    expect(screen.getByText('Seu papel não pode visualizar o caixa nesta organização.')).toBeInTheDocument();
    expect(apiClientMock.get).not.toHaveBeenCalled();
  });

  it('refetches with the kind query param when the filter changes', async () => {
    mockEntries();
    render(<CaixaPage />);

    await waitFor(() => expect(screen.getByText('R$ 50,00')).toBeInTheDocument());
    fireEvent.change(screen.getByLabelText('Filtrar por tipo'), { target: { value: 'expense' } });

    await waitFor(() => expect(apiClientMock.get).toHaveBeenCalledWith('/cash-entries?kind=expense'));
  });

  it('creates a manual entry through the modal with an Idempotency-Key header, then refetches', async () => {
    mockEntries();
    apiClientMock.post.mockResolvedValue({ cash_entry_id: 'entry-2', organization_id: 'org-1', status: 'success' });
    render(<CaixaPage />);

    await waitFor(() => expect(screen.getByText('R$ 50,00')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Novo lançamento'));
    fireEvent.change(screen.getByLabelText('Tipo'), { target: { value: 'expense' } });
    fireEvent.change(screen.getByLabelText('Valor (R$)'), { target: { value: '35,00' } });
    fireEvent.change(screen.getByLabelText('Descrição'), { target: { value: 'Compra de material' } });
    fireEvent.click(screen.getByText('Confirmar lançamento'));

    await waitFor(() =>
      expect(apiClientMock.post).toHaveBeenCalledWith(
        '/cash-entries/manual',
        { kind: 'expense', amount_cents: 3500, description: 'Compra de material' },
        expect.objectContaining({ headers: expect.objectContaining({ 'Idempotency-Key': expect.any(String) }) }),
      ),
    );
    await waitFor(() => expect(apiClientMock.get).toHaveBeenCalledTimes(2));
  });

  it('hides the manual entry action for reception (cash_entry_manual never included that role)', () => {
    useOrganizationMock.mockReturnValue({ role: 'reception' });
    render(<CaixaPage />);

    expect(screen.queryByText('+ Novo lançamento')).not.toBeInTheDocument();
  });
});
