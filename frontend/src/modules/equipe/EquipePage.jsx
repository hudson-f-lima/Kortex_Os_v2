import { useCallback, useEffect, useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { ProfessionalModal } from './ProfessionalModal.jsx';
import { MembershipRow } from './MembershipRow.jsx';

// Mirrors backend/src/modules/professionals/professionals.route.js
// WRITE_ROLES/DELETE_ROLES. memberships.route.js SET_ROLES is owner-only.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

function messageForListError(err) {
  if (err instanceof ApiError) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

function messageForRemoveError(err) {
  if (err instanceof ApiError) {
    if (err.status === 409) return 'Este profissional tem agendamentos vinculados — desative em vez de excluir.';
    return err.message;
  }
  return 'Erro inesperado ao remover profissional.';
}

export function EquipePage() {
  const { role } = useOrganization();
  const apiClient = useApiClient();
  const canWrite = WRITE_ROLES.includes(role);
  const canDelete = DELETE_ROLES.includes(role);
  const canSetRole = role === 'owner';

  const [professionals, setProfessionals] = useState([]);
  const [memberships, setMemberships] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showInactive, setShowInactive] = useState(false);
  const [modal, setModal] = useState(null);
  const [removeError, setRemoveError] = useState(null);
  const [confirmingRemoveId, setConfirmingRemoveId] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const query = showInactive ? '' : '?active=true';
      const [professionalsRes, membershipsRes] = await Promise.all([
        apiClient.get(`/professionals${query}`),
        apiClient.get('/memberships'),
      ]);
      setProfessionals(professionalsRes.professionals);
      setMemberships(membershipsRes.memberships);
    } catch (err) {
      setError(messageForListError(err));
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
      setRemoveError(messageForRemoveError(err));
    }
  }

  function handleMembershipSaved(membership) {
    setMemberships((current) => current.map((item) => (item.user_id === membership.user_id ? membership : item)));
  }

  if (loading) return <p>Carregando equipe…</p>;

  if (error) {
    return (
      <div className="full-page-error">
        <p>{error}</p>
        <button type="button" onClick={load}>
          Tentar novamente
        </button>
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
            <button type="button" onClick={() => setModal({ mode: 'create' })}>
              + Novo profissional
            </button>
          )}
        </div>

        {removeError && <p className="form-error">{removeError}</p>}

        {professionals.length === 0 && <p className="list-empty">Nenhum profissional cadastrado ainda.</p>}

        <ul className="record-list">
          {professionals.map((professional) => (
            <li key={professional.id} className="record-list-item">
              <span className="record-list-main">
                <strong>{professional.name}</strong>
                {professional.user_id && <span className="tag-muted">vinculado a um usuário</span>}
                {!professional.active && <span className="tag-inactive">inativo</span>}
              </span>
              {canWrite && (
                <button type="button" className="link-button" onClick={() => setModal({ mode: 'edit', professional })}>
                  Editar
                </button>
              )}
              {canDelete && confirmingRemoveId !== professional.id && (
                <button type="button" className="link-button" onClick={() => setConfirmingRemoveId(professional.id)}>
                  Remover
                </button>
              )}
              {canDelete && confirmingRemoveId === professional.id && (
                <>
                  <span>Confirma?</span>
                  <button type="button" className="danger-button" onClick={() => handleRemove(professional)}>
                    Sim
                  </button>
                  <button type="button" className="link-button" onClick={() => setConfirmingRemoveId(null)}>
                    Não
                  </button>
                </>
              )}
            </li>
          ))}
        </ul>
      </section>

      <section>
        <h2>Papéis da equipe</h2>
        <p className="section-hint">
          {canSetRole
            ? 'Altere o papel ou a atividade de um membro pelo identificador de usuário.'
            : 'Somente o owner da organização pode alterar papéis.'}
        </p>
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
    </div>
  );
}
