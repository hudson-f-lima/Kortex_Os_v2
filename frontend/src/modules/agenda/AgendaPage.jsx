import { Fragment, useCallback, useEffect, useMemo, useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { useAuth } from '../../shared/useAuth.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { useCachedQuery } from '../../shared/useCachedQuery.js';
import { AppointmentModal } from './AppointmentModal.jsx';
import { statusLabel } from './appointmentStatus.js';
import {
  addDays,
  dateKey,
  daySlots,
  dayRange,
  formatDateHeading,
  formatDayLabel,
  formatTime,
  slotIndexForTime,
  startOfWeek,
  totalSlots,
  weekDays,
  weekRange,
} from './dateUtils.js';

const WRITE_ROLES = ['owner', 'admin', 'manager', 'reception'];
const SLOT_HEIGHT = '2.75rem';

function messageForListError(err) {
  if (err instanceof ApiError) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

// Próximo slot de 30min a partir de agora (se o dia âncora for hoje) ou 9h
// (se for outro dia) — só um ponto de partida razoável para o formulário,
// o usuário sempre pode trocar o horário.
function defaultStartFor(anchorDate) {
  const start = new Date(anchorDate);
  const now = new Date();
  if (dateKey(start) !== dateKey(now)) {
    start.setHours(9, 0, 0, 0);
    return start;
  }
  const roundedMinutes = now.getMinutes() < 30 ? 30 : 0;
  const hourAdjustment = now.getMinutes() < 30 ? 0 : 1;
  start.setHours(now.getHours() + hourAdjustment, roundedMinutes, 0, 0);
  return start;
}

export function AgendaPage() {
  const { user } = useAuth();
  const { role } = useOrganization();
  const apiClient = useApiClient();
  const canWrite = WRITE_ROLES.includes(role);
  const isProfessional = role === 'professional';

  const [view, setView] = useState('day');
  const [anchorDate, setAnchorDate] = useState(() => new Date());
  const [professionalFilter, setProfessionalFilter] = useState('all');
  const [modal, setModal] = useState(null);

  const filterActive = useCallback((item) => item.active, []);

  const { data: professionals, loading: professionalsLoading, error: professionalsError, refetch: refetchProfessionals } = useCachedQuery('professionals', filterActive);
  const { data: services, loading: servicesLoading, error: servicesError, refetch: refetchServices } = useCachedQuery('services', filterActive);
  const { data: clients, loading: clientsLoading, error: clientsError, refetch: refetchClients } = useCachedQuery('clients', filterActive);

  const loadLists = useCallback(() => {
    refetchProfessionals();
    refetchServices();
    refetchClients();
  }, [refetchProfessionals, refetchServices, refetchClients]);

  const listsLoading = professionalsLoading || servicesLoading || clientsLoading;
  const listsError = professionalsError || servicesError || clientsError;

  const ownProfessional = useMemo(
    () => professionals.find((professional) => professional.user_id === user?.id) ?? null,
    [professionals, user?.id],
  );

  const effectiveProfessionalId = isProfessional
    ? ownProfessional?.id
    : professionalFilter !== 'all'
      ? professionalFilter
      : undefined;

  const filterAppointments = useCallback((appt) => {
    if (isProfessional && !ownProfessional) return false;

    const apptDate = new Date(appt.starts_at);
    const { from, to } = view === 'day' ? dayRange(anchorDate) : weekRange(anchorDate);
    const fromTime = new Date(from).getTime();
    const toTime = new Date(to).getTime();
    const apptTime = apptDate.getTime();

    const timeMatch = apptTime >= fromTime && apptTime < toTime;
    const profMatch = !effectiveProfessionalId || appt.professional_id === effectiveProfessionalId;

    return timeMatch && profMatch;
  }, [view, anchorDate, effectiveProfessionalId, isProfessional, ownProfessional]);

  const { data: appointments, loading: appointmentsLoading, error: appointmentsError, refetch: loadAppointments } = useCachedQuery('appointments', filterAppointments);

  function clientName(id) {
    return clients.find((client) => client.id === id)?.name ?? '—';
  }

  function professionalName(id) {
    return professionals.find((professional) => professional.id === id)?.name ?? '—';
  }

  function serviceName(id) {
    return services.find((service) => service.id === id)?.name ?? '—';
  }

  function handleClientCreated(client) {
    import('../../shared/idb.js').then(({ putRecord }) => {
      putRecord('clients', client).catch(console.error);
    });
  }

  function handleSaved(appointment) {
    setModal(null);
    if (appointment) {
      import('../../shared/idb.js').then(({ putRecord }) => {
        putRecord('appointments', appointment).then(() => loadAppointments()).catch(console.error);
      });
    } else {
      loadAppointments();
    }
  }

  function openCreateAt(professionalId, startsAt) {
    if (!canWrite) return;
    setModal({
      mode: 'create',
      initialValues: { professional_id: professionalId ?? '', starts_at: startsAt },
    });
  }

  function openAppointment(appointment) {
    setModal({
      mode: 'edit',
      initialValues: {
        id: appointment.id,
        client_id: appointment.client_id,
        professional_id: appointment.professional_id,
        service_id: appointment.service_id,
        starts_at: new Date(appointment.starts_at),
        status: appointment.status,
      },
    });
  }

  function navigate(amount) {
    setAnchorDate((current) => addDays(current, view === 'day' ? amount : amount * 7));
  }

  const professionalsForGrid = isProfessional
    ? ownProfessional
      ? [ownProfessional]
      : []
    : professionalFilter === 'all'
      ? professionals
      : professionals.filter((professional) => professional.id === professionalFilter);

  const noProfessionalsAtAll = professionals.length === 0;
  const professionalUnlinked = isProfessional && !ownProfessional && !listsLoading;

  return (
    <div className="agenda-page">
      <div className="agenda-toolbar">
        <div className="agenda-view-toggle">
          <button type="button" className={view === 'day' ? 'active' : ''} onClick={() => setView('day')}>
            Dia
          </button>
          <button type="button" className={view === 'week' ? 'active' : ''} onClick={() => setView('week')}>
            Semana
          </button>
        </div>

        <div className="agenda-nav">
          <button type="button" onClick={() => navigate(-1)} aria-label="Anterior">
            ‹
          </button>
          <button type="button" onClick={() => setAnchorDate(new Date())}>
            Hoje
          </button>
          <button type="button" onClick={() => navigate(1)} aria-label="Próximo">
            ›
          </button>
          <span className="agenda-heading">
            {view === 'day' ? formatDateHeading(anchorDate) : `Semana de ${formatDayLabel(startOfWeek(anchorDate))}`}
          </span>
        </div>

        {!isProfessional && (
          <select
            aria-label="Filtrar por profissional"
            value={professionalFilter}
            onChange={(event) => setProfessionalFilter(event.target.value)}
          >
            <option value="all">Todos os profissionais</option>
            {professionals.map((professional) => (
              <option key={professional.id} value={professional.id}>
                {professional.name}
              </option>
            ))}
          </select>
        )}

        {canWrite && (
          <button type="button" onClick={() => openCreateAt(effectiveProfessionalId ?? '', defaultStartFor(anchorDate))}>
            + Novo agendamento
          </button>
        )}
      </div>

      {listsLoading && <p>Carregando agenda…</p>}

      {!listsLoading && listsError && (
        <div className="full-page-error">
          <p>{listsError?.message ?? String(listsError)}</p>
          <button type="button" onClick={loadLists}>
            Tentar novamente
          </button>
        </div>
      )}

      {!listsLoading && !listsError && professionalUnlinked && (
        <p>Seu usuário não está vinculado a um profissional nesta organização. Peça a um admin para vincular seu cadastro.</p>
      )}

      {!listsLoading && !listsError && noProfessionalsAtAll && (
        <p>Nenhum profissional cadastrado ainda. Cadastre profissionais no módulo Equipe para começar a agendar.</p>
      )}

      {!listsLoading && !listsError && !noProfessionalsAtAll && !professionalUnlinked && (
        <>
          {appointmentsLoading && <p>Carregando agendamentos…</p>}

          {!appointmentsLoading && appointmentsError && (
            <div className="full-page-error">
              <p>{appointmentsError?.message ?? String(appointmentsError)}</p>
              <button type="button" onClick={loadAppointments}>
                Tentar novamente
              </button>
            </div>
          )}

          {!appointmentsLoading && !appointmentsError && view === 'day' && (
            <DayGrid
              anchorDate={anchorDate}
              professionals={professionalsForGrid}
              appointments={appointments}
              canWrite={canWrite}
              onSlotClick={openCreateAt}
              onAppointmentClick={openAppointment}
              clientName={clientName}
              serviceName={serviceName}
            />
          )}

          {!appointmentsLoading && !appointmentsError && view === 'week' && (
            <WeekList
              anchorDate={anchorDate}
              appointments={appointments}
              canWrite={canWrite}
              defaultProfessionalId={effectiveProfessionalId ?? ''}
              onCreateForDay={openCreateAt}
              onAppointmentClick={openAppointment}
              clientName={clientName}
              professionalName={professionalName}
              serviceName={serviceName}
            />
          )}
        </>
      )}

      {modal && (
        <AppointmentModal
          mode={modal.mode}
          initialValues={modal.initialValues}
          professionals={professionals}
          services={services}
          clients={clients}
          canWrite={canWrite}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={handleSaved}
          onClientCreated={handleClientCreated}
        />
      )}
    </div>
  );
}

function DayGrid({ anchorDate, professionals, appointments, canWrite, onSlotClick, onAppointmentClick, clientName, serviceName }) {
  const slots = daySlots(anchorDate);
  const slotCount = totalSlots();

  if (professionals.length === 0) {
    return <p>Nenhum profissional para exibir com o filtro atual.</p>;
  }

  return (
    <div className="agenda-grid-wrapper">
      <div
        className="agenda-grid-header"
        style={{ gridTemplateColumns: `4rem repeat(${professionals.length}, minmax(150px, 1fr))` }}
      >
        <div />
        {professionals.map((professional) => (
          <div key={professional.id} className="agenda-grid-header-cell">
            {professional.name}
          </div>
        ))}
      </div>

      <div
        className="agenda-grid"
        style={{
          gridTemplateColumns: `4rem repeat(${professionals.length}, minmax(150px, 1fr))`,
          gridTemplateRows: `repeat(${slotCount}, minmax(${SLOT_HEIGHT}, auto))`,
        }}
      >
        {slots.map((slotDate, rowIndex) => (
          <div key={`time-${rowIndex}`} className="agenda-time-label" style={{ gridColumn: 1, gridRow: rowIndex + 1 }}>
            {rowIndex % 2 === 0 ? formatTime(slotDate) : ''}
          </div>
        ))}

        {professionals.map((professional, colIndex) => {
          const apptsForProfessional = appointments.filter((appt) => appt.professional_id === professional.id);
          const placements = apptsForProfessional.map((appt) => {
            const start = new Date(appt.starts_at);
            const end = new Date(appt.ends_at);
            const startIndex = Math.min(Math.max(slotIndexForTime(start, anchorDate), 0), slotCount - 1);
            const durationMinutes = (end.getTime() - start.getTime()) / 60000;
            const span = Math.max(1, Math.round(durationMinutes / 30));
            const clampedSpan = Math.min(span, slotCount - startIndex);
            return { appt, startIndex, span: clampedSpan };
          });
          const covered = new Set();
          placements.forEach(({ startIndex, span }) => {
            for (let i = startIndex; i < startIndex + span; i += 1) covered.add(i);
          });

          return (
            <Fragment key={professional.id}>
              {placements.map(({ appt, startIndex, span }) => (
                <button
                  type="button"
                  key={appt.id}
                  className={`agenda-appt agenda-appt--${appt.status}`}
                  style={{ gridColumn: colIndex + 2, gridRow: `${startIndex + 1} / span ${span}` }}
                  onClick={() => onAppointmentClick(appt)}
                >
                  <strong>{formatTime(new Date(appt.starts_at))}</strong> {clientName(appt.client_id)}
                  <br />
                  <span>{serviceName(appt.service_id)}</span>
                  <br />
                  <span className="agenda-appt-status">{statusLabel(appt.status)}</span>
                </button>
              ))}

              {canWrite &&
                slots.map((slotDate, rowIndex) =>
                  covered.has(rowIndex) ? null : (
                    <button
                      type="button"
                      key={`slot-${professional.id}-${rowIndex}`}
                      className="agenda-empty-slot"
                      style={{ gridColumn: colIndex + 2, gridRow: rowIndex + 1 }}
                      onClick={() => onSlotClick(professional.id, slotDate)}
                      aria-label={`Novo agendamento com ${professional.name} às ${formatTime(slotDate)}`}
                    />
                  ),
                )}
            </Fragment>
          );
        })}
      </div>
    </div>
  );
}

function WeekList({
  anchorDate,
  appointments,
  canWrite,
  defaultProfessionalId,
  onCreateForDay,
  onAppointmentClick,
  clientName,
  professionalName,
  serviceName,
}) {
  const days = weekDays(anchorDate);

  return (
    <div className="agenda-week">
      {days.map((day) => {
        const dayAppointments = appointments
          .filter((appt) => dateKey(new Date(appt.starts_at)) === dateKey(day))
          .sort((a, b) => new Date(a.starts_at) - new Date(b.starts_at));

        return (
          <div key={dateKey(day)} className="agenda-week-day">
            <div className="agenda-week-day-header">
              <strong>{formatDayLabel(day)}</strong>
              {canWrite && (
                <button
                  type="button"
                  className="link-button"
                  onClick={() => {
                    const start = new Date(day);
                    start.setHours(9, 0, 0, 0);
                    onCreateForDay(defaultProfessionalId, start);
                  }}
                >
                  + Agendamento
                </button>
              )}
            </div>

            {dayAppointments.length === 0 && <p className="agenda-week-empty">Sem agendamentos</p>}

            {dayAppointments.map((appt) => (
              <button
                type="button"
                key={appt.id}
                className={`agenda-week-item agenda-appt--${appt.status}`}
                onClick={() => onAppointmentClick(appt)}
              >
                {formatTime(new Date(appt.starts_at))} · {clientName(appt.client_id)} · {professionalName(appt.professional_id)} ·{' '}
                {serviceName(appt.service_id)} · {statusLabel(appt.status)}
              </button>
            ))}
          </div>
        );
      })}
    </div>
  );
}
