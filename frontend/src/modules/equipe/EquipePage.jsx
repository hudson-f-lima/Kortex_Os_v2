import { useCallback, useEffect, useState } from 'react';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { messageForError, OFFLINE_FALLBACK } from '../../shared/apiErrorMessage.js';
import { ProfessionalModal } from './ProfessionalModal.jsx';
import { InviteModal } from './InviteModal.jsx';
import { MembershipRow } from './MembershipRow.jsx';
import { CapabilitiesTab } from './CapabilitiesTab.jsx';
import { Button } from '../../ui/primitives/Button.jsx';
import { Badge } from '../../ui/primitives/Badge.jsx';

// Mirrors backend/src/modules/professionals/professionals.route.js
// WRITE_ROLES/DELETE_ROLES. memberships.route.js SET_ROLES is owner-only.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

export function EquipePage() {
  const { role } = useOrganization();
  const apiClient = useApiClient();
  const canWrite = WRITE_ROLES.includes(role);
  const canDelete = DELETE_ROLES.includes(role);
  const canSetRole = role === 'owner';

  const [professionals, setProfessionals] = useState([]);
  const [services, setServices] = useState([]);
  const [memberships, setMemberships] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showInactive, setShowInactive] = useState(false);
  const [modal, setModal] = useState(null);
  const [removeError, setRemoveError] = useState(null);
  const [confirmingRemoveId, setConfirmingRemoveId] = useState(null);
  const [inviteModalOpen, setInviteModalOpen] = useState(false);
  const [inviteNotice, setInviteNotice] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const query = showInactive ? '' : '?active=true';
      const [professionalsRes, membershipsRes, servicesRes] = await Promise.all([
        apiClient.get(`/professionals${query}`),
        apiClient.get('/memberships'),
        apiClient.get('/services'),
      ]);
      setProfessionals(professionalsRes.professionals);
      setMemberships(membershipsRes.memberships);
      setServices(servicesRes.services);
    } catch (err) {
      setError(messageForError(err, { fallback: OFFLINE_FALLBACK }));
    } finally {
      setLoading(false);
    }
  }, [apiClient, showInactive]);

  useEffect(() => {
    load();
  }, [load]);

  function handleSaved(professional) {
    setProfessionals((current) => {
      const exists = current.some((item) => item.id === professional.id);
      const next = exists ? current.map((item) => (item.id === professional.id ? professional : item)) : [...current, professional];
      return next.sort((a, b) => a.name.localeCompare(b.name));
    });
    setModal(null);
  }

  async function handleRemove(professional) {
    setRemoveError(null);
    try {
      await apiClient.delete(`/professionals/${professional.id}`);
      setProfessionals((current) => current.filter((item) => item.id !== professional.id));
      setConfirmingRemoveId(null);
    } catch (err) {
      setRemoveError(
        messageForError(err, {
          fallback: 'Erro inesperado ao remover profissional.',
          statuses: { 409: 'Este profissional tem agendamentos vinculados — desative em vez de excluir.' },
        }),
      );
    }
  }

  function handleMembershipSaved(membership) {
    setMemberships((current) => current.map((item) => (item.user_id === membership.user_id ? membership : item)));
  }

  function handleInvited(invite) {
    setMemberships((current) => [
      ...current,
      { user_id: invite.userId, role: invite.role, active: true, created_at: new Date().toISOString() },
    ]);
    if (invite.professional) {
      setProfessionals((current) => {
        const exists = current.some((item) => item.id === invite.professional.id);
        const next = exists
          ? current.map((item) => (item.id === invite.professional.id ? invite.professional : item))
          : [...current, invite.professional];
        return next.sort((a, b) => a.name.localeCompare(b.name));
      });
    }
    setInviteModalOpen(false);
    setInviteNotice(`Convite enviado para ${invite.email}.`);
  }

  if (loading) return <p>Carregando equipe…</p>;

  if (error) {
    return (
      <div className="full-page-error">
        <p>{error}</p>
        <Button onClick={load}>Tentar novamente</Button>
      </div>
    );
  }

  return (
    <div className="equipe-page">
      <h1>Equipe</h1>

      <section>
        <div className="list-toolbar">
          <h2>Profissionais</h2>
          <label className="inline-checkbox">
            <input type="checkbox" checked={showInactive} onChange={(event) => setShowInactive(event.target.checked)} />
            Mostrar inativos
          </label>
          {canWrite && (
            <Button onClick={() => setModal({ mode: 'create' })}>
              + Novo profissional
            </Button>
          )}
        </div>

        {removeError && <p className="form-error" role="alert">{removeError}</p>}

        {professionals.length === 0 && <p className="list-empty">Nenhum profissional cadastrado ainda.</p>}

        <ul className="record-list">
          {professionals.map((professional) => (
            <li key={professional.id} className="record-list-item">
              <span className="record-list-main">
                <strong>{professional.name}</strong>
                {professional.user_id && <span className="tag-muted">vinculado a um usuário</span>}
                {!professional.active && <Badge variant="neutral">inativo</Badge>}
              </span>
              {canWrite && (
                <Button variant="link" onClick={() => setModal({ mode: 'edit', professional })}>
                  Editar
                </Button>
              )}
              {canDelete && confirmingRemoveId !== professional.id && (
                <Button variant="link" onClick={() => setConfirmingRemoveId(professional.id)}>
                  Remover
                </Button>
              )}
              {canDelete && confirmingRemoveId === professional.id && (
                <>
                  <span>Confirma?</span>
                  <Button variant="danger" onClick={() => handleRemove(professional)}>
                    Sim
                  </Button>
                  <Button variant="link" onClick={() => setConfirmingRemoveId(null)}>
                    Não
                  </Button>
                </>
              )}
            </li>
          ))}
        </ul>
      </section>

      <section>
        <div className="list-toolbar">
          <h2>Papéis da equipe</h2>
          {canSetRole && (
            <Button onClick={() => setInviteModalOpen(true)}>
              + Convidar membro
            </Button>
          )}
        </div>
        <p className="section-hint">
          {canSetRole
            ? 'Altere o papel ou a atividade de um membro pelo identificador de usuário.'
            : 'Somente o owner da organização pode alterar papéis.'}
        </p>
        {inviteNotice && <p className="form-success" role="status">{inviteNotice}</p>}
        <ul className="record-list">
          {memberships.map((membership) => (
            <MembershipRow
              key={membership.user_id}
              membership={membership}
              canSetRole={canSetRole}
              apiClient={apiClient}
              onSaved={handleMembershipSaved}
            />
          ))}
        </ul>
      </section>

      <section>
        <h2>Capacidades por Profissional</h2>
        <p className="section-hint">
          Configure duração, preço e buffers customizados para cada profissional por serviço.
        </p>
        <CapabilitiesTab professionals={professionals} services={services} currentRole={role} />
      </section>

      {modal && (
        <ProfessionalModal
          mode={modal.mode}
          professional={modal.professional}
          memberships={memberships}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={handleSaved}
        />
      )}

      {inviteModalOpen && (
        <InviteModal
          apiClient={apiClient}
          unlinkedProfessionals={professionals.filter((professional) => !professional.user_id)}
          onClose={() => setInviteModalOpen(false)}
          onInvited={handleInvited}
        />
      )}
    </div>
  );
}
