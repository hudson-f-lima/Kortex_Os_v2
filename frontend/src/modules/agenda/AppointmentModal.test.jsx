import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { AppointmentModal } from './AppointmentModal.jsx';
import { ApiError } from '../../shared/apiClient.js';

const apiClientMock = { get: vi.fn(), post: vi.fn(), patch: vi.fn(), delete: vi.fn() };
const onSaved = vi.fn();
const onClose = vi.fn();
const onClientCreated = vi.fn();

const PROFESSIONALS = [
  { id: 'prof-1', name: 'Ana' },
  { id: 'prof-2', name: 'Beatriz' },
];
const SERVICES = [{ id: 'svc-1', name: 'Corte', duration_minutes: 30 }];
const CLIENTS = [{ id: 'client-1', name: 'Carla' }];

function renderModal(props) {
  return render(
    <MemoryRouter>
      <AppointmentModal
        professionals={PROFESSIONALS}
        services={SERVICES}
        clients={CLIENTS}
        canWrite
        apiClient={apiClientMock}
        onClose={onClose}
        onSaved={onSaved}
        onClientCreated={onClientCreated}
        {...props}
      />
    </MemoryRouter>,
  );
}

const EDIT_INITIAL_VALUES = {
  id: 'appt-1',
  client_id: 'client-1',
  professional_id: 'prof-1',
  service_id: 'svc-1',
  starts_at: new Date('2026-08-10T10:00:00Z'),
  status: 'scheduled',
  version: 1,
};

describe('AppointmentModal', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('creates an appointment with an Idempotency-Key and without a client-supplied ends_at', async () => {
    apiClientMock.post.mockResolvedValue({ appointment: { id: 'appt-new', status: 'scheduled' } });

    renderModal({
      mode: 'create',
      initialValues: { professional_id: 'prof-1', starts_at: new Date('2026-08-10T10:00:00Z') },
    });

    fireEvent.change(screen.getByLabelText('Selecionar cliente'), { target: { value: 'client-1' } });
    fireEvent.change(screen.getByLabelText('Selecionar serviço'), { target: { value: 'svc-1' } });
    fireEvent.click(screen.getByText('Criar agendamento'));

    await waitFor(() => expect(onSaved).toHaveBeenCalledWith({ id: 'appt-new', status: 'scheduled' }));

    const [path, body, opts] = apiClientMock.post.mock.calls[0];
    expect(path).toBe('/appointments');
    expect(body).not.toHaveProperty('ends_at');
    expect(body).toMatchObject({ client_id: 'client-1', professional_id: 'prof-1', service_id: 'svc-1' });
    expect(opts.headers['Idempotency-Key']).toEqual(expect.any(String));
  });

  it('edit: only sends the fields that actually changed, plus version', async () => {
    apiClientMock.patch.mockResolvedValue({ appointment: { id: 'appt-1', status: 'confirmed', version: 2 } });

    renderModal({ mode: 'edit', initialValues: EDIT_INITIAL_VALUES });

    fireEvent.change(screen.getByLabelText('Status'), { target: { value: 'confirmed' } });
    fireEvent.click(screen.getByText('Salvar alterações'));

    await waitFor(() => expect(onSaved).toHaveBeenCalledWith({ id: 'appt-1', status: 'confirmed', version: 2 }));

    const [path, body, opts] = apiClientMock.patch.mock.calls[0];
    expect(path).toBe('/appointments/appt-1');
    expect(body).toEqual({ version: 1, status: 'confirmed' });
    expect(opts.headers['Idempotency-Key']).toEqual(expect.any(String));
  });

  it('edit: reconfiguring professional_id shows a diff instead of applying, then applies on confirm with a new Idempotency-Key', async () => {
    const diff = {
      current: { professional_id: 'prof-1', service_id: 'svc-1', ends_at: '2026-08-10T10:30:00Z', resolved_duration_minutes: 30 },
      proposed: { professional_id: 'prof-2', service_id: 'svc-1', ends_at: '2026-08-10T11:00:00Z', resolved_duration_minutes: 60 },
    };
    apiClientMock.patch
      .mockRejectedValueOnce(new ApiError(409, 'confirmation_required', 'needs confirmation', 'req-1', diff))
      .mockResolvedValueOnce({ appointment: { id: 'appt-1', professional_id: 'prof-2', version: 2 } });

    renderModal({ mode: 'edit', initialValues: EDIT_INITIAL_VALUES });

    fireEvent.change(screen.getByLabelText('Selecionar profissional'), { target: { value: 'prof-2' } });
    fireEvent.click(screen.getByText('Salvar alterações'));

    await waitFor(() => expect(screen.getByText('Confirmar alteração')).toBeInTheDocument());
    expect(screen.getByText('Ana')).toBeInTheDocument();
    expect(screen.getByText('Beatriz')).toBeInTheDocument();
    expect(onSaved).not.toHaveBeenCalled();

    fireEvent.click(screen.getByText('Confirmar mudança'));

    await waitFor(() => expect(onSaved).toHaveBeenCalledWith({ id: 'appt-1', professional_id: 'prof-2', version: 2 }));
    expect(apiClientMock.patch).toHaveBeenCalledTimes(2);

    const [, firstBody, firstOpts] = apiClientMock.patch.mock.calls[0];
    const [, secondBody, secondOpts] = apiClientMock.patch.mock.calls[1];
    expect(firstBody).toEqual({ version: 1, professional_id: 'prof-2' });
    expect(secondBody).toEqual({ version: 1, professional_id: 'prof-2', confirm: true });
    expect(secondOpts.headers['Idempotency-Key']).not.toBe(firstOpts.headers['Idempotency-Key']);
  });

  it('edit: going back from the diff returns to the editable form without submitting', async () => {
    const diff = {
      current: { professional_id: 'prof-1', service_id: 'svc-1', ends_at: '2026-08-10T10:30:00Z', resolved_duration_minutes: 30 },
      proposed: { professional_id: 'prof-2', service_id: 'svc-1', ends_at: '2026-08-10T11:00:00Z', resolved_duration_minutes: 60 },
    };
    apiClientMock.patch.mockRejectedValueOnce(new ApiError(409, 'confirmation_required', 'needs confirmation', 'req-1', diff));

    renderModal({ mode: 'edit', initialValues: EDIT_INITIAL_VALUES });

    fireEvent.change(screen.getByLabelText('Selecionar profissional'), { target: { value: 'prof-2' } });
    fireEvent.click(screen.getByText('Salvar alterações'));

    await waitFor(() => expect(screen.getByText('Confirmar alteração')).toBeInTheDocument());
    fireEvent.click(screen.getByText('Voltar'));

    expect(screen.getByText('Editar agendamento')).toBeInTheDocument();
    expect(apiClientMock.patch).toHaveBeenCalledTimes(1);
  });

  it('maps a version_conflict response to a Portuguese message', async () => {
    apiClientMock.patch.mockRejectedValue(new ApiError(409, 'version_conflict', 'stale version', 'req-1'));

    renderModal({ mode: 'edit', initialValues: EDIT_INITIAL_VALUES });

    fireEvent.change(screen.getByLabelText('Status'), { target: { value: 'confirmed' } });
    fireEvent.click(screen.getByText('Salvar alterações'));

    await waitFor(() =>
      expect(
        screen.getByText('Este agendamento foi alterado por outro usuário. Feche e abra de novo para ver a versão mais recente.'),
      ).toBeInTheDocument(),
    );
  });

  it('cancelling an appointment sends status=cancelled with version and an Idempotency-Key', async () => {
    apiClientMock.patch.mockResolvedValue({ appointment: { id: 'appt-1', status: 'cancelled', version: 2 } });

    renderModal({ mode: 'edit', initialValues: EDIT_INITIAL_VALUES });

    fireEvent.click(screen.getByText('Cancelar agendamento'));
    fireEvent.click(screen.getByText('Confirmar'));

    await waitFor(() => expect(onSaved).toHaveBeenCalledWith({ id: 'appt-1', status: 'cancelled', version: 2 }));
    const [path, body, opts] = apiClientMock.patch.mock.calls[0];
    expect(path).toBe('/appointments/appt-1');
    expect(body).toEqual({ status: 'cancelled', version: 1 });
    expect(opts.headers['Idempotency-Key']).toEqual(expect.any(String));
  });
});
