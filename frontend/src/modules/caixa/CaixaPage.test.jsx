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
});
