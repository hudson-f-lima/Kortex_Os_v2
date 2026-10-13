import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { AgendaPage } from './AgendaPage.jsx';
import { ApiError } from '../../shared/apiClient.js';
import { useState, useEffect } from 'react';

// Retângulos estáveis de coluna pro drag-to-reschedule (jsdom não faz
// layout de verdade): prof-1 ocupa 0-200px, prof-2 ocupa 200-400px.
const COLUMN_RECTS = {
  'prof-1': { left: 0, right: 200, top: 0, bottom: 1000, width: 200, height: 1000 },
  'prof-2': { left: 200, right: 400, top: 0, bottom: 1000, width: 200, height: 1000 },
};

function stubColumnRects() {
  return vi.spyOn(Element.prototype, 'getBoundingClientRect').mockImplementation(function stubbed() {
    return COLUMN_RECTS[this.dataset?.professionalId] ?? { left: 0, right: 0, top: 0, bottom: 0, width: 0, height: 0 };
  });
}

// jsdom não implementa PointerEvent (nem setPointerCapture) — fireEvent.pointerX
// do testing-library cai no construtor genérico Event, que descarta
// clientX/clientY/pointerId do init dict. Disparamos manualmente com essas
// propriedades atribuídas via Object.assign: React lê o valor por acesso
// direto (não por instanceof), então o handler nativo em window (pointermove/
// pointerup) e o onPointerDown sintético do React recebem os valores certos.
function firePointerEvent(target, type, { clientX = 0, clientY = 0, pointerId = 1 } = {}) {
  const event = new Event(type, { bubbles: true, cancelable: true });
  Object.assign(event, { clientX, clientY, pointerId, button: 0 });
  // fireEvent(target, event) (não target.dispatchEvent direto) pra passar pelo
  // eventWrapper/act() do testing-library — senão o setDrag() de beginDrag não
  // é flushado antes do próximo dispatch síncrono do teste, e o useEffect que
  // anexa os listeners de pointermove/pointerup em window ainda não rodou.
  fireEvent(target, event);
}

function renderAgenda() {
  return render(
    <MemoryRouter>
      <AgendaPage />
    </MemoryRouter>,
  );
}

const useAuthMock = vi.fn();
const useOrganizationMock = vi.fn();
const apiClientMock = {
  get: vi.fn(),
  post: vi.fn(),
  patch: vi.fn(),
  delete: vi.fn(),
};

let currentProfessionals = [];
let currentServices = [];
let currentClients = [];
let currentAppointments = [];
let queryListeners = new Set();
let mockError = null;

function updateState(professionals, services, clients, appointments) {
  if (professionals !== undefined) currentProfessionals = professionals;
  if (services !== undefined) currentServices = services;
  if (clients !== undefined) currentClients = clients;
  if (appointments !== undefined) currentAppointments = appointments;
  queryListeners.forEach((listener) => listener());
}

vi.mock('../../shared/useAuth.js', () => ({
  useAuth: () => useAuthMock(),
}));
vi.mock('../../shared/useOrganization.js', () => ({
  useOrganization: () => useOrganizationMock(),
}));
vi.mock('../../shared/useApiClient.js', () => ({
  useApiClient: () => apiClientMock,
}));
vi.mock('../../shared/useCachedQuery.js', () => ({
  useCachedQuery: (storeName, filterFn) => {
    let initialData = [];
    if (storeName === 'professionals') initialData = currentProfessionals;
    else if (storeName === 'services') initialData = currentServices;
    else if (storeName === 'clients') initialData = currentClients;
    else if (storeName === 'appointments') initialData = currentAppointments;

    const [data, setData] = useState(initialData);

    useEffect(() => {
      const listener = () => {
        let current = [];
        if (storeName === 'professionals') current = currentProfessionals;
        else if (storeName === 'services') current = currentServices;
        else if (storeName === 'clients') current = currentClients;
        else if (storeName === 'appointments') current = currentAppointments;

        setData(filterFn ? current.filter(filterFn) : current);
      };
      queryListeners.add(listener);
      listener();
      return () => {
        queryListeners.delete(listener);
      };
    }, [storeName, filterFn]);

    const refetch = () => {
      let current = [];
      if (storeName === 'professionals') current = currentProfessionals;
      else if (storeName === 'services') current = currentServices;
      else if (storeName === 'clients') current = currentClients;
      else if (storeName === 'appointments') current = currentAppointments;
      setData(filterFn ? current.filter(filterFn) : current);
    };

    return { data, loading: false, error: mockError, refetch };
  },
}));

vi.mock('../../shared/idb.js', () => ({
  putRecord: vi.fn((store, record) => {
    if (store === 'appointments') {
      const exists = currentAppointments.some(a => a.id === record.id);
      const next = exists ? currentAppointments.map(a => a.id === record.id ? record : a) : [...currentAppointments, record];
      updateState(undefined, undefined, undefined, next);
    } else if (store === 'clients') {
      const exists = currentClients.some(c => c.id === record.id);
      const next = exists ? currentClients.map(c => c.id === record.id ? record : c) : [...currentClients, record];
      updateState(undefined, undefined, next, undefined);
    }
    return Promise.resolve();
  }),
}));

const PROFESSIONALS = [
  { id: 'prof-1', name: 'Ana', user_id: 'user-ana', active: true },
  { id: 'prof-2', name: 'Beatriz', user_id: 'user-beatriz', active: true },
];
const SERVICES = [{ id: 'svc-1', name: 'Corte', duration_minutes: 30, price_cents: 5000, active: true }];
const CLIENTS = [{ id: 'client-1', name: 'Carla', phone: '11999990000', active: true }];

function mockLists({ professionals = PROFESSIONALS, services = SERVICES, clients = CLIENTS, appointments = [] } = {}) {
  updateState(professionals, services, clients, appointments);
  apiClientMock.get.mockImplementation((path) => {
    if (path.startsWith('/professionals')) return Promise.resolve({ professionals });
    if (path.startsWith('/services')) return Promise.resolve({ services });
    if (path.startsWith('/clients')) return Promise.resolve({ clients });
    if (path.startsWith('/appointments')) return Promise.resolve({ appointments });
    throw new Error(`unexpected path: ${path}`);
  });
}

describe('AgendaPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useAuthMock.mockReturnValue({ user: { id: 'user-owner' } });
    useOrganizationMock.mockReturnValue({ role: 'owner' });
    mockError = null;
  });

  it('renders the day grid with professional columns and a fetched appointment', async () => {
    mockLists({
      appointments: [
        {
          id: 'appt-1',
          client_id: 'client-1',
          professional_id: 'prof-1',
          service_id: 'svc-1',
          starts_at: (() => {
            const d = new Date();
            d.setHours(9, 0, 0, 0);
            return d.toISOString();
          })(),
          ends_at: (() => {
            const d = new Date();
            d.setHours(10, 0, 0, 0);
            return d.toISOString();
          })(),
          status: 'scheduled',
        },
      ],
    });

    renderAgenda();

    await waitFor(() => expect(screen.getAllByText('Ana').length).toBeGreaterThan(0));
    // Timeline Vertical (redesign) troca colunas por profissional por um filtro
    // único — Beatriz aparece como opção no <select>, não como cabeçalho de coluna.
    expect(screen.getByRole('option', { name: 'Beatriz' })).toBeInTheDocument();
    expect(screen.getByText('Carla', { exact: false })).toBeInTheDocument();
    expect(screen.getByText('Corte', { exact: false })).toBeInTheDocument();
  });

  it('shows an empty-org message when there are no professionals', async () => {
    mockLists({ professionals: [], services: [], clients: [], appointments: [] });

    renderAgenda();

    await waitFor(() =>
      expect(screen.getByText(/Nenhum profissional cadastrado. Cadastre/)).toBeInTheDocument(),
    );
  });

  it('shows a recoverable error state with retry when the lists fail to load', async () => {
    mockError = new Error('network down');

    renderAgenda();

    await waitFor(() =>
      expect(screen.getByText('network down')).toBeInTheDocument(),
    );
    expect(screen.getByText('Tentar novamente')).toBeInTheDocument();
  });

  it('hides mutation affordances for the professional role (read-only recorte próprio)', async () => {
    useAuthMock.mockReturnValue({ user: { id: 'user-ana' } });
    useOrganizationMock.mockReturnValue({ role: 'professional' });
    mockLists();

    renderAgenda();

    await waitFor(() => expect(screen.getByText('Ana')).toBeInTheDocument());
    expect(screen.queryByText('Beatriz')).not.toBeInTheDocument();
    expect(screen.queryByText('+ Novo')).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Filtrar por profissional')).not.toBeInTheDocument();
  });

  it('opens the create modal when clicking "+ Novo"', async () => {
    mockLists();

    renderAgenda();

    await waitFor(() => expect(screen.getByText('+ Novo')).toBeInTheDocument());
    fireEvent.click(screen.getByText('+ Novo'));

    expect(screen.getByText('Novo agendamento')).toBeInTheDocument();
  });

  describe('drag-to-reschedule', () => {
    function appointmentAt(hour, overrides = {}) {
      const starts = new Date();
      starts.setHours(hour, 0, 0, 0);
      const ends = new Date(starts);
      ends.setHours(hour + 1, 0, 0, 0);
      return {
        id: 'appt-1',
        client_id: 'client-1',
        professional_id: 'prof-1',
        service_id: 'svc-1',
        starts_at: starts.toISOString(),
        ends_at: ends.toISOString(),
        status: 'scheduled',
        version: 3,
        ...overrides,
      };
    }

    afterEach(() => {
      vi.restoreAllMocks();
    });

    it('drags a card to a new time in the same column and PATCHes only starts_at', async () => {
      stubColumnRects();
      mockLists({ appointments: [appointmentAt(9)] });
      apiClientMock.patch.mockResolvedValue({ appointment: appointmentAt(10) });

      renderAgenda();
      await waitFor(() => expect(screen.getByText('Carla', { exact: false })).toBeInTheDocument());
      const card = screen.getByText('Carla', { exact: false }).closest('button');

      // 09:00 (top=60px, START_HOUR=8) -> +60px = 10:00, mesma coluna (x=50 o tempo todo).
      firePointerEvent(card, 'pointerdown', { clientX: 50, clientY: 100 });
      firePointerEvent(window, 'pointermove', { clientX: 50, clientY: 160 });
      firePointerEvent(window, 'pointerup', { clientX: 50, clientY: 160 });

      await waitFor(() => expect(apiClientMock.patch).toHaveBeenCalled());
      const [path, body] = apiClientMock.patch.mock.calls[0];
      expect(path).toBe('/appointments/appt-1');
      expect(body.version).toBe(3);
      expect(body.professional_id).toBeUndefined();
      expect(new Date(body.starts_at).getHours()).toBe(10);
    });

    it('drags a card into another professional column and PATCHes professional_id', async () => {
      stubColumnRects();
      mockLists({ appointments: [appointmentAt(9)] });
      apiClientMock.patch.mockResolvedValue({ appointment: appointmentAt(9, { professional_id: 'prof-2' }) });

      renderAgenda();
      await waitFor(() => expect(screen.getByText('Carla', { exact: false })).toBeInTheDocument());
      const card = screen.getByText('Carla', { exact: false }).closest('button');

      // Sem deslocamento vertical (mesmo horário), só muda de coluna: x=50 (prof-1) -> x=250 (prof-2).
      firePointerEvent(card, 'pointerdown', { clientX: 50, clientY: 100 });
      firePointerEvent(window, 'pointermove', { clientX: 250, clientY: 100 });
      firePointerEvent(window, 'pointerup', { clientX: 250, clientY: 100 });

      await waitFor(() => expect(apiClientMock.patch).toHaveBeenCalled());
      const [, body] = apiClientMock.patch.mock.calls[0];
      expect(body.professional_id).toBe('prof-2');
      expect(body.starts_at).toBeUndefined();
    });

    it('does not reschedule on a plain click (no movement) — the modal opens instead', async () => {
      stubColumnRects();
      mockLists({ appointments: [appointmentAt(9)] });

      renderAgenda();
      await waitFor(() => expect(screen.getByText('Carla', { exact: false })).toBeInTheDocument());
      const card = screen.getByText('Carla', { exact: false }).closest('button');

      firePointerEvent(card, 'pointerdown', { clientX: 50, clientY: 100 });
      firePointerEvent(window, 'pointerup', { clientX: 50, clientY: 100 });
      fireEvent.click(card);

      expect(apiClientMock.patch).not.toHaveBeenCalled();
      expect(screen.getByText('Editar agendamento')).toBeInTheDocument();
    });

    it('shows the ADR 0013 diff and only PATCHes with confirm:true after the user confirms', async () => {
      stubColumnRects();
      mockLists({ appointments: [appointmentAt(9)] });
      apiClientMock.patch.mockRejectedValueOnce(
        new ApiError(409, 'confirmation_required', 'needs confirmation', 'req-1', {
          current: { professional_id: 'prof-1', service_id: 'svc-1', resolved_duration_minutes: 30, ends_at: appointmentAt(9).ends_at },
          proposed: { professional_id: 'prof-2', service_id: 'svc-1', resolved_duration_minutes: 30, ends_at: appointmentAt(9).ends_at },
        }),
      );
      apiClientMock.patch.mockResolvedValueOnce({ appointment: appointmentAt(9, { professional_id: 'prof-2', version: 4 }) });

      renderAgenda();
      await waitFor(() => expect(screen.getByText('Carla', { exact: false })).toBeInTheDocument());
      const card = screen.getByText('Carla', { exact: false }).closest('button');

      firePointerEvent(card, 'pointerdown', { clientX: 50, clientY: 100 });
      firePointerEvent(window, 'pointermove', { clientX: 250, clientY: 100 });
      firePointerEvent(window, 'pointerup', { clientX: 250, clientY: 100 });

      await waitFor(() => expect(screen.getByText('Confirmar alteração')).toBeInTheDocument());
      fireEvent.click(screen.getByText('Confirmar mudança'));

      await waitFor(() => expect(apiClientMock.patch).toHaveBeenCalledTimes(2));
      const [, secondBody] = apiClientMock.patch.mock.calls[1];
      expect(secondBody.confirm).toBe(true);
      expect(secondBody.professional_id).toBe('prof-2');
    });
  });
});
