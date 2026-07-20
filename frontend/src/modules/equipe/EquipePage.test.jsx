import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { EquipePage } from './EquipePage.jsx';
import { ApiError } from '../../shared/apiClient.js';

const useOrganizationMock = vi.fn();
const apiClientMock = {
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  put: vi.fn(),
  delete: vi.fn(),
};

vi.mock('../../shared/useOrganization.js', () => ({
  useOrganization: () => useOrganizationMock(),
}));
vi.mock('../../shared/useApiClient.js', () => ({
  useApiClient: () => apiClientMock,
}));
vi.mock('../../shared/useCachedQuery.js', () => ({
  useCachedQuery: vi.fn(),
}));
import { useCachedQuery } from '../../shared/useCachedQuery.js';

const PROFESSIONALS = [{ id: 'prof-1', name: 'Ana', user_id: null, active: true }];
const MEMBERSHIPS = [{ user_id: 'user-owner-12345678', role: 'owner', active: true, created_at: '2026-01-01' }];
const SERVICES = [];

function mockLists({ professionals = PROFESSIONALS, memberships = MEMBERSHIPS, services = SERVICES } = {}) {
  useCachedQuery.mockImplementation((store) => {
    if (store === 'professionals') return { data: professionals, loading: false, error: null };
    if (store === 'services') return { data: services, loading: false, error: null };
    return { data: [], loading: false, error: null };
  });
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/professionals')) return Promise.resolve({ professionals });
    if (path.startsWith('/memberships')) return Promise.resolve({ memberships });
    if (path.startsWith('/services')) return Promise.resolve({ services });
    if (path.startsWith('/professional-service-capabilities')) return Promise.resolve({ professional_service_capabilities: [] });
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('EquipePage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useOrganizationMock.mockReturnValue({ role: 'owner' });
  });

  it('renders professionals and memberships once loaded', async () => {
    mockLists();
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    expect(screen.getByText('user-own…')).toBeInTheDocument();
  });

  it('shows an empty message when there are no professionals', async () => {
    mockLists({ professionals: [] });
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('Nenhum profissional cadastrado ainda.')).toBeInTheDocument());
  });

  it('shows a recoverable error state with retry when the lists fail to load', async () => {
    useCachedQuery.mockImplementation(() => ({ data: [], loading: false, error: 'network down' }));
    apiClientMock.get.mockRejectedValue(new Error('network down'));
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('network down')).toBeInTheDocument());
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('disables role editing for a manager (membership_set is owner-only)', async () => {
    useOrganizationMock.mockReturnValue({ role: 'manager' });
    mockLists();
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    expect(screen.getByText('Somente o owner da organização pode alterar papéis.')).toBeInTheDocument();
    expect(screen.getByLabelText(/Papel de/)).toBeDisabled();
  });

  it('lets the owner change a membership role and save it', async () => {
    mockLists();
    apiClientMock.put.mockResolvedValue({ membership: { user_id: 'user-owner-12345678', role: 'admin', active: true } });
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    fireEvent.change(screen.getByLabelText(/Papel de/), { target: { value: 'admin' } });
    fireEvent.click(screen.getByText('Salvar'));

    await waitFor(() =>
      expect(apiClientMock.put).toHaveBeenCalledWith('/memberships/user-owner-12345678', { role: 'admin', active: true }),
    );
  });

  it('creates a professional through the modal', async () => {
    mockLists({ professionals: [] });
    apiClientMock.post.mockResolvedValue({ professional: { id: 'prof-new', name: 'Beatriz', user_id: null, active: true } });
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('+ Novo profissional')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Novo profissional'));
    fireEvent.change(screen.getByLabelText('Nome'), { target: { value: 'Beatriz' } });
    fireEvent.click(screen.getByText('Criar profissional'));

    await waitFor(() => expect(apiClientMock.post).toHaveBeenCalledWith('/professionals', { name: 'Beatriz', user_id: null }));
  });

  it('lets the owner send an invite and appends the returned membership', async () => {
    mockLists();
    apiClientMock.post.mockResolvedValue({
      invite: { userId: 'user-new-12345678', email: 'nova@test.local', role: 'reception', professional: null },
    });
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('+ Convidar membro')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Convidar membro'));
    fireEvent.change(screen.getByLabelText('E-mail'), { target: { value: 'nova@test.local' } });
    fireEvent.click(screen.getByText('Enviar convite'));

    await waitFor(() => expect(screen.getByText('Convite enviado para nova@test.local.')).toBeInTheDocument());
    expect(apiClientMock.post).toHaveBeenCalledWith('/convites', { email: 'nova@test.local', role: 'reception' });
    expect(screen.getByText('user-new…')).toBeInTheDocument();
  });

  it('hides the invite button for a manager (convites is owner-only)', async () => {
    useOrganizationMock.mockReturnValue({ role: 'manager' });
    mockLists();
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    expect(screen.queryByText('+ Convidar membro')).not.toBeInTheDocument();
  });

  it('maps a 409 conflict on professional removal to a Portuguese message', async () => {
    mockLists();
    apiClientMock.delete.mockRejectedValue(new ApiError(409, 'referenced_by_other_records', 'professional is referenced', 'req-1'));
    render(<EquipePage />);

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Remover'));
    fireEvent.click(screen.getByText('Sim'));

    await waitFor(() =>
      expect(screen.getByText('Este profissional tem agendamentos vinculados — desative em vez de excluir.')).toBeInTheDocument(),
    );
  });
});
