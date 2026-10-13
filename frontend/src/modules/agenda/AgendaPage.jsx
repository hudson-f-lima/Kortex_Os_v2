import { useCallback, useMemo, useRef, useState, useEffect } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { useAuth } from '../../shared/useAuth.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { useCachedQuery } from '../../shared/useCachedQuery.js';
import { Modal } from '../../shared/Modal.jsx';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';
import { newIdempotencyKey } from '../../shared/idempotencyKey.js';
import { AppointmentModal } from './AppointmentModal.jsx';
import { ChangeDiff } from './ChangeDiff.jsx';
import { APPOINTMENT_ERROR_MESSAGES } from './appointmentErrorMessages.js';
import { BLOCKING_STATUSES } from './appointmentStatus.js';
import { SmartStrip } from '../../ui/domain/SmartStrip.jsx';
import { AppointmentCard } from '../../ui/domain/AppointmentCard.jsx';
import { Button } from '../../ui/primitives/Button.jsx';
import { Plus } from 'lucide-react';
import {
  addDays,
  addMinutes,
  clamp,
  dateKey,
  dayRange,
  formatDateHeading,
  formatDayLabel,
  formatTime,
  snapMinutes,
  startOfDay,
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

  // Drag-to-reschedule (ver TimelineView): id do agendamento com PATCH em
  // voo, erro de rede/negócio pra mostrar num banner, e a confirmação
  // pendente quando o PATCH responde 409 confirmation_required (ADR 0013).
  const [savingAppointmentId, setSavingAppointmentId] = useState(null);
  const [dragError, setDragError] = useState(null);
  const [pendingDragChange, setPendingDragChange] = useState(null);

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

  async function submitAppointmentPatch(appointmentId, patch) {
    const result = await apiClient.patch(`/appointments/${appointmentId}`, patch, {
      headers: { 'Idempotency-Key': newIdempotencyKey() },
    });
    return result.appointment;
  }

  // Drag-to-reschedule da grade: mesmo PATCH que o AppointmentModal usa
  // (version + confirmation_required do ADR 0013), só disparado por arrastar
  // o card em vez de editar o formulário. `changes` só carrega os campos que
  // de fato mudaram (starts_at e/ou professional_id) — arrastar nunca manda
  // duração/ends_at, que o backend recusa (ver appointments.validation.js).
  async function handleReschedule(appointment, changes) {
    setDragError(null);
    setSavingAppointmentId(appointment.id);
    try {
      const updated = await submitAppointmentPatch(appointment.id, { version: appointment.version, ...changes });
      handleSaved(updated);
    } catch (err) {
      if (err instanceof ApiError && err.code === 'confirmation_required') {
        setPendingDragChange({ appointment, patch: { version: appointment.version, ...changes }, diff: err.details });
        return;
      }
      setDragError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE }, codes: APPOINTMENT_ERROR_MESSAGES }));
      loadAppointments(); // volta a grade pra posição real depois de um erro
    } finally {
      setSavingAppointmentId(null);
    }
  }

  async function handleConfirmDragChange() {
    const pending = pendingDragChange;
    if (!pending) return;
    setSavingAppointmentId(pending.appointment.id);
    try {
      const updated = await submitAppointmentPatch(pending.appointment.id, { ...pending.patch, confirm: true });
      handleSaved(updated);
      setPendingDragChange(null);
    } catch (err) {
      setPendingDragChange(null);
      setDragError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE }, codes: APPOINTMENT_ERROR_MESSAGES }));
      loadAppointments();
    } finally {
      setSavingAppointmentId(null);
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
        {dragError && (
          <div className="k-agenda__drag-error" role="alert">
            <span>{dragError}</span>
            <button type="button" onClick={() => setDragError(null)} aria-label="Fechar aviso">✕</button>
          </div>
        )}

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
                canDrag={canWrite}
                savingAppointmentId={savingAppointmentId}
                onReschedule={handleReschedule}
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

      {pendingDragChange && (
        <Modal onClose={() => setPendingDragChange(null)} title="Confirmar alteração">
          <ChangeDiff
            diff={pendingDragChange.diff}
            professionals={professionals}
            services={services}
            submitting={savingAppointmentId === pendingDragChange.appointment.id}
            onConfirm={handleConfirmDragChange}
            onCancel={() => setPendingDragChange(null)}
          />
        </Modal>
      )}
    </div>
  );
}

function TimelineView({
  anchorDate,
  professionals,
  appointments,
  clientName,
  serviceName,
  onAppointmentClick,
  onSlotClick,
  canDrag = false,
  savingAppointmentId = null,
  onReschedule,
}) {
  // Timeline hours from 8:00 to 22:00
  const START_HOUR = 8;
  const END_HOUR = 22;
  const GRID_MINUTES = (END_HOUR - START_HOUR) * 60;
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

  // Drag-to-reschedule (copiado do comportamento grátis do plugin
  // `interaction` do FullCalendar — eventDrop — via Pointer Events, não
  // HTML5 drag-and-drop nativo, pra funcionar em touch). `drag` guarda a
  // pré-visualização (posição/coluna sob o ponteiro); `dragRef` espelha o
  // mesmo valor pra ser lido de dentro dos listeners de window sem precisar
  // reanexá-los a cada pixel de movimento. `justDraggedRef` evita que o
  // `click` sintético disparado pelo navegador logo após o pointerup reabra
  // o modal de edição quando o gesto foi, na verdade, um arraste.
  const columnRefs = useRef({});
  const dragRef = useRef(null);
  const justDraggedRef = useRef(false);
  const [drag, setDrag] = useState(null);
  dragRef.current = drag;

  const beginDrag = useCallback((appt, event) => {
    if (!canDrag) return;
    event.stopPropagation();
    const start = new Date(appt.starts_at);
    const end = new Date(appt.ends_at);
    const startMinutes = (start.getHours() * 60) + start.getMinutes();
    const originTop = startMinutes - START_HOUR * 60;
    const durationMinutes = Math.max(1, Math.round((end.getTime() - start.getTime()) / 60000));
    setDrag({
      appointment: appt,
      originTop,
      originProfessionalId: appt.professional_id,
      durationMinutes,
      startClientX: event.clientX,
      startClientY: event.clientY,
      previewTop: originTop,
      previewProfessionalId: appt.professional_id,
      moved: false,
    });
  }, [canDrag]);

  const isDragging = Boolean(drag);

  useEffect(() => {
    if (!isDragging) return undefined;

    function professionalAt(clientX) {
      for (const prof of professionals) {
        const node = columnRefs.current[prof.id];
        if (!node) continue;
        const rect = node.getBoundingClientRect();
        if (clientX >= rect.left && clientX <= rect.right) return prof.id;
      }
      return dragRef.current?.previewProfessionalId ?? null;
    }

    function handleMove(event) {
      const current = dragRef.current;
      if (!current) return;
      const deltaX = event.clientX - current.startClientX;
      const deltaY = event.clientY - current.startClientY;
      const moved = current.moved || Math.abs(deltaX) > 4 || Math.abs(deltaY) > 4;

      const maxTop = Math.max(GRID_MINUTES - current.durationMinutes, 0);
      const previewTop = clamp(snapMinutes(current.originTop + deltaY), 0, maxTop);

      setDrag((prev) => (prev ? {
        ...prev,
        moved,
        previewTop,
        previewProfessionalId: professionalAt(event.clientX),
      } : prev));
    }

    function handleUp() {
      const current = dragRef.current;
      setDrag(null);
      if (!current || !current.moved) return; // sem deslocamento real = deixa o click abrir o modal de edição

      justDraggedRef.current = true;

      const changes = {};
      if (current.previewTop !== current.originTop) {
        changes.starts_at = addMinutes(startOfDay(anchorDate), START_HOUR * 60 + current.previewTop).toISOString();
      }
      if (current.previewProfessionalId && current.previewProfessionalId !== current.originProfessionalId) {
        changes.professional_id = current.previewProfessionalId;
      }
      if (Object.keys(changes).length > 0) {
        onReschedule?.(current.appointment, changes);
      }
    }

    window.addEventListener('pointermove', handleMove);
    window.addEventListener('pointerup', handleUp);
    window.addEventListener('pointercancel', handleUp);
    return () => {
      window.removeEventListener('pointermove', handleMove);
      window.removeEventListener('pointerup', handleUp);
      window.removeEventListener('pointercancel', handleUp);
    };
  }, [isDragging, professionals, anchorDate, onReschedule, GRID_MINUTES]);

  const previewStart = drag?.moved
    ? addMinutes(startOfDay(anchorDate), START_HOUR * 60 + drag.previewTop)
    : null;

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
            const showDropPreview = drag?.moved && drag.previewProfessionalId === prof.id;

            return (
              <div
                key={prof.id}
                ref={(node) => { columnRefs.current[prof.id] = node; }}
                data-professional-id={prof.id}
                className="k-agenda__prof-column"
                onClick={(e) => {
                  // Approximate time clicked based on Y position (if clicking empty space)
                  const rect = e.currentTarget.getBoundingClientRect();
                  const y = e.clientY - rect.top;
                  const clickedMinutes = snapMinutes(y); // since 1px = 1min
                  const start = addMinutes(startOfDay(anchorDate), START_HOUR * 60 + clickedMinutes);
                  onSlotClick(prof.id, start);
                }}
              >
                {showDropPreview && (
                  <div
                    className="k-agenda__drop-preview"
                    style={{ top: `${drag.previewTop}px`, height: `${drag.durationMinutes}px` }}
                  >
                    {previewStart && formatTime(previewStart)}
                  </div>
                )}

                {profAppts.map(appt => {
                  const isDraggingThis = drag?.appointment.id === appt.id;
                  // Enquanto este card está sendo arrastado, ele fica oculto na
                  // posição de origem — quem representa a posição atual é o
                  // k-agenda__drop-preview acima, na coluna sob o ponteiro.
                  if (isDraggingThis && drag.moved) return null;

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
                        if (justDraggedRef.current) {
                          justDraggedRef.current = false;
                          return;
                        }
                        onAppointmentClick(appt);
                      }}
                      top={`${topOffset}px`}
                      height={`${duration}px`}
                      draggable={canDrag && BLOCKING_STATUSES.includes(appt.status)}
                      dragging={isDraggingThis}
                      saving={savingAppointmentId === appt.id}
                      onDragPointerDown={(e) => beginDrag(appt, e)}
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
