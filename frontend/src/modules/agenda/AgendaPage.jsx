import { useCallback, useMemo, useState, useEffect } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { useAuth } from '../../shared/useAuth.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { useCachedQuery } from '../../shared/useCachedQuery.js';
import { AppointmentModal } from './AppointmentModal.jsx';
import { SmartStrip } from '../../ui/domain/SmartStrip.jsx';
import { AppointmentCard } from '../../ui/domain/AppointmentCard.jsx';
import { Button } from '../../ui/primitives/Button.jsx';
import { Plus } from 'lucide-react';
import {
  addDays,
  dateKey,
  dayRange,
  formatDateHeading,
  formatDayLabel,
  startOfWeek,
  weekDays,
} from './dateUtils.js';

import './AgendaPage.css';

const WRITE_ROLES = ['owner', 'admin', 'manager', 'reception'];


function messageForListError(err) {
  if (err instanceof ApiError) return err.message;
  if (err?.message) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

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

  // Always 'day' view as per instructions for the Timeline
  const [anchorDate, setAnchorDate] = useState(() => new Date());
  const [professionalFilter, setProfessionalFilter] = useState('all');
  const [modal, setModal] = useState(null);

  // Mocks para o SmartStrip (Tela Deus)
  const [smartStripVisible, setSmartStripVisible] = useState(true);

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
    const { from, to } = dayRange(anchorDate);
    const fromTime = new Date(from).getTime();
    const toTime = new Date(to).getTime();
    const apptTime = apptDate.getTime();

    const timeMatch = apptTime >= fromTime && apptTime < toTime;
    const profMatch = !effectiveProfessionalId || appt.professional_id === effectiveProfessionalId;

    return timeMatch && profMatch;
  }, [anchorDate, effectiveProfessionalId, isProfessional, ownProfessional]);

  const { data: appointments, loading: appointmentsLoading, error: appointmentsError, refetch: loadAppointments } = useCachedQuery('appointments', filterAppointments);

  function clientName(id) {
    return clients.find((client) => client.id === id)?.name ?? '—';
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
        version: appointment.version,
      },
    });
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

  // Render Weekly Strip
  const renderWeeklyStrip = () => {
    const days = weekDays(startOfWeek(anchorDate));
    return (
      <div className="k-agenda__weekly-strip">
        {days.map(day => {
          const isSelected = dateKey(day) === dateKey(anchorDate);
          return (
            <button 
              key={dateKey(day)} 
              type="button" 
              className={`k-agenda__day-btn ${isSelected ? 'k-agenda__day-btn--active' : ''}`}
              onClick={() => setAnchorDate(day)}
            >
              <span className="k-agenda__day-name">{formatDayLabel(day).substring(0, 3)}</span>
              <span className="k-agenda__day-num">{day.getDate()}</span>
            </button>
          );
        })}
      </div>
    );
  };

  return (
    <div className="k-agenda">
      {/* Topbar/Toolbar */}
      <div className="k-agenda__toolbar">
        <div className="k-agenda__nav-group">
          <Button variant="ghost" size="sm" onClick={() => setAnchorDate(addDays(anchorDate, -1))}>‹</Button>
          <Button variant="ghost" size="sm" onClick={() => setAnchorDate(new Date())}>Hoje</Button>
          <Button variant="ghost" size="sm" onClick={() => setAnchorDate(addDays(anchorDate, 1))}>›</Button>
          <span className="k-agenda__date-label">{formatDateHeading(anchorDate)}</span>
        </div>

        <div className="k-agenda__nav-group">
          {!isProfessional && (
            <select
              aria-label="Filtrar por profissional"
              style={{ padding: '6px', borderRadius: '4px', border: '1px solid var(--color-border)' }}
              value={professionalFilter}
              onChange={(event) => setProfessionalFilter(event.target.value)}
            >
              <option value="all">Equipe Inteira</option>
              {professionals.map((professional) => (
                <option key={professional.id} value={professional.id}>
                  {professional.name}
                </option>
              ))}
            </select>
          )}
          {canWrite && (
            <Button className="hide-on-mobile" onClick={() => openCreateAt(effectiveProfessionalId ?? '', defaultStartFor(anchorDate))}>
              + Novo
            </Button>
          )}
        </div>
      </div>

      {renderWeeklyStrip()}

      {smartStripVisible && !listsLoading && !listsError && (
        <SmartStrip 
          type="insight" 
          message="Movimento tranquilo hoje. Que tal enviar uma campanha para clientes inativos?" 
          actionLabel="Ver Campanha" 
          onAction={() => window.alert('Feature futura: Kortex IA Marketing')}
          onClose={() => setSmartStripVisible(false)}
        />
      )}

      <div className="k-agenda__main">
        {listsLoading && <div style={{ padding: '24px' }}>Carregando agenda…</div>}

        {!listsLoading && listsError && (
          <div style={{ padding: '24px' }}>
            <p>{messageForListError(listsError)}</p>
            <Button onClick={loadLists}>Tentar novamente</Button>
          </div>
        )}

        {!listsLoading && !listsError && professionalUnlinked && (
          <div style={{ padding: '24px' }}>
            <p>Seu usuário não está vinculado a um profissional nesta organização.</p>
          </div>
        )}

        {!listsLoading && !listsError && noProfessionalsAtAll && (
          <div style={{ padding: '24px' }}>
            <p>Nenhum profissional cadastrado. Cadastre no módulo Equipe para começar a agendar.</p>
          </div>
        )}

        {!listsLoading && !listsError && !noProfessionalsAtAll && !professionalUnlinked && (
          <>
            {appointmentsLoading && <div style={{ padding: '24px' }}>Carregando agendamentos…</div>}

            {!appointmentsLoading && appointmentsError && (
              <div style={{ padding: '24px' }}>
                <p>{messageForListError(appointmentsError)}</p>
                <Button onClick={loadAppointments}>Tentar novamente</Button>
              </div>
            )}

            {!appointmentsLoading && !appointmentsError && (
              <TimelineView 
                anchorDate={anchorDate}
                professionals={professionalsForGrid}
                appointments={appointments}
                clientName={clientName}
                serviceName={serviceName}
                onAppointmentClick={openAppointment}
                onSlotClick={openCreateAt}
              />
            )}
          </>
        )}

        {/* FAB on mobile */}
        {canWrite && (
          <button 
            type="button" 
            className="k-agenda__fab" 
            onClick={() => openCreateAt(effectiveProfessionalId ?? '', defaultStartFor(anchorDate))}
            aria-label="Novo Agendamento"
          >
            <Plus size={24} />
          </button>
        )}
      </div>

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

function TimelineView({ anchorDate, professionals, appointments, clientName, serviceName, onAppointmentClick, onSlotClick }) {
  // Timeline hours from 8:00 to 22:00
  const START_HOUR = 8;
  const END_HOUR = 22;
  const hours = Array.from({ length: END_HOUR - START_HOUR + 1 }, (_, i) => START_HOUR + i);
  
  const [nowOffset, setNowOffset] = useState(null);

  useEffect(() => {
    const updateNow = () => {
      const now = new Date();
      if (dateKey(now) === dateKey(anchorDate)) {
        const hour = now.getHours();
        const min = now.getMinutes();
        if (hour >= START_HOUR && hour <= END_HOUR) {
          const offset = ((hour - START_HOUR) * 60) + min;
          setNowOffset(offset);
        } else {
          setNowOffset(null);
        }
      } else {
        setNowOffset(null);
      }
    };
    updateNow();
    const interval = window.setInterval(updateNow, 60000);
    return () => window.clearInterval(interval);
  }, [anchorDate]);

  return (
    <div className="k-agenda__scroll-area">
      <div className="k-agenda__prof-headers">
        <div className="k-agenda__time-gutter-header" />
        {professionals.map(prof => (
          <div key={prof.id} className="k-agenda__prof-header">
            <div className="k-agenda__prof-avatar">
              {prof.name.charAt(0).toUpperCase()}
            </div>
            <div className="k-agenda__prof-info">
              <span className="k-agenda__prof-name">{prof.name}</span>
            </div>
          </div>
        ))}
      </div>

      <div className="k-agenda__timeline">
        {nowOffset !== null && (
          <div className="k-agenda__now-line" style={{ top: `${nowOffset}px` }} />
        )}

        <div className="k-agenda__time-gutter">
          {hours.map((hour, index) => (
            <div key={hour} className="k-agenda__time-slot">
              {index > 0 && <span className="k-agenda__time-label">{`${hour.toString().padStart(2, '0')}:00`}</span>}
            </div>
          ))}
        </div>

        <div className="k-agenda__columns">
          {professionals.map(prof => {
            const profAppts = appointments.filter(a => a.professional_id === prof.id);

            return (
              <div key={prof.id} className="k-agenda__prof-column" onClick={(e) => {
                // Approximate time clicked based on Y position (if clicking empty space)
                const rect = e.currentTarget.getBoundingClientRect();
                const y = e.clientY - rect.top;
                const totalMinutes = y; // since 1px = 1min
                const clickedHour = Math.floor(totalMinutes / 60) + START_HOUR;
                const clickedMin = totalMinutes % 60 < 30 ? 0 : 30; // snap to 30 min
                const start = new Date(anchorDate);
                start.setHours(clickedHour, clickedMin, 0, 0);
                onSlotClick(prof.id, start);
              }}>
                {profAppts.map(appt => {
                  const start = new Date(appt.starts_at);
                  const end = new Date(appt.ends_at);
                  
                  const startMinutes = (start.getHours() * 60) + start.getMinutes();
                  const endMinutes = (end.getHours() * 60) + end.getMinutes();
                  
                  const topOffset = startMinutes - (START_HOUR * 60);
                  const duration = endMinutes - startMinutes;

                  // Se o agendamento for antes das 8h ou depois das 22h, ele não aparecerá perfeitamente aqui.
                  // Para o MVP assumimos dentro da janela ou ocultamos
                  if (topOffset < 0 || topOffset > (END_HOUR - START_HOUR) * 60) return null;

                  return (
                    <AppointmentCard 
                      key={appt.id}
                      appointment={appt}
                      clientName={clientName(appt.client_id)}
                      serviceName={serviceName(appt.service_id)}
                      onAppointmentClick={(e) => {
                        e.stopPropagation();
                        onAppointmentClick(appt);
                      }}
                      top={`${topOffset}px`}
                      height={`${duration}px`}
                    />
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
