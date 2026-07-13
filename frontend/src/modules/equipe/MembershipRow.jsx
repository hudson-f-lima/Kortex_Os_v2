import { useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { MEMBERSHIP_ROLES } from './membershipRoles.js';

function messageForError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    return err.message;
  }
  return 'Erro inesperado. Tente novamente.';
}

// PUT /memberships/:userId (membership_set) só aceita owner como ator
// (memberships.route.js SET_ROLES) — o backend não expõe e-mail/nome de um
// usuário arbitrário, então a linha só pode identificar o membro pelo user_id.
export function MembershipRow({ membership, canSetRole, apiClient, onSaved }) {
  const [role, setRole] = useState(membership.role);
  const [active, setActive] = useState(membership.active);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const dirty = role !== membership.role || active !== membership.active;

  async function handleSave() {
    setSubmitting(true);
    setError(null);
    try {
      const { membership: saved } = await apiClient.put(`/memberships/${membership.user_id}`, { role, active });
      onSaved(saved);
    } catch (err) {
      setError(messageForError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <li className="record-list-item">
      <span className="record-list-main">
        <strong>{`${membership.user_id.slice(0, 8)}…`}</strong>
      </span>
      <select
        aria-label={`Papel de ${membership.user_id}`}
        value={role}
        onChange={(event) => setRole(event.target.value)}
        disabled={!canSetRole}
      >
        {MEMBERSHIP_ROLES.map((value) => (
          <option key={value} value={value}>
            {value}
          </option>
        ))}
      </select>
      <label className="inline-checkbox">
        <input
          type="checkbox"
          checked={active}
          onChange={(event) => setActive(event.target.checked)}
          disabled={!canSetRole}
        />
        Ativo
      </label>
      {canSetRole && dirty && (
        <button type="button" disabled={submitting} onClick={handleSave}>
          Salvar
        </button>
      )}
      {error && <span className="form-error">{error}</span>}
    </li>
  );
}
