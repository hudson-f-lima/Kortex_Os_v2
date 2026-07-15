import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { OrganizacaoPage } from './OrganizacaoPage.jsx';

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

const ORGANIZATIONS = [
  { id: 'org-1', name: 'Salão Principal', slug: 'salao-principal', role: 'owner' },
  { id: 'org-2', name: 'Filial Norte', slug: 'filial-norte', role: 'admin' },
];

function baseContext(overrides = {}) {
  return {
    organizations: ORGANIZATIONS,
    organizationId: 'org-1',
    role: 'owner',
    selectOrganization: vi.fn(),
    refresh: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

describe('OrganizacaoPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('shows the current organization and the full list of organizations', () => {
    useOrganizationMock.mockReturnValue(baseContext());
    render(<OrganizacaoPage />);

    expect(screen.getAllByText('Salão Principal').length).toBeGreaterThan(0);
    expect(screen.getByText('Filial Norte')).toBeInTheDocument();
    expect(screen.getByText('organização atual')).toBeInTheDocument();
  });

  it('switches to another organization when "Trocar para esta" is clicked', () => {
    const context = baseContext();
    useOrganizationMock.mockReturnValue(context);
    render(<OrganizacaoPage />);

    fireEvent.click(screen.getByText('Trocar para esta'));

    expect(context.selectOrganization).toHaveBeenCalledWith('org-2');
  });

  it('documents the missing email-invite flow instead of faking one', () => {
    useOrganizationMock.mockReturnValue(baseContext());
    render(<OrganizacaoPage />);

    expect(screen.getByText(/Ainda não existe convite por e-mail no backend/)).toBeInTheDocument();
  });

  it('creates an additional organization through the modal and switches to it', async () => {
    const context = baseContext();
    useOrganizationMock.mockReturnValue(context);
    apiClientMock.post.mockResolvedValue({ organization: { id: 'org-new', name: 'Nova Filial', slug: 'nova-filial' }, role: 'owner' });
    render(<OrganizacaoPage />);

    fireEvent.click(screen.getByText('+ Nova organização'));
    fireEvent.change(screen.getByLabelText('Nome'), { target: { value: 'Nova Filial' } });
    fireEvent.click(screen.getByText('Criar organização'));

    await waitFor(() => expect(context.refresh).toHaveBeenCalled());
    expect(context.selectOrganization).toHaveBeenCalledWith('org-new');
    expect(apiClientMock.post).toHaveBeenCalledWith('/organizations', { name: 'Nova Filial', slug: 'nova-filial' });
  });
});
