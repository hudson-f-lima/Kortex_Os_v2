import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';

// Cria/edita profissionais; user_id (login individual) é opcional e só pode
// referenciar uma membership já existente na organização (professionals.service.js
// pré-valida isso com invalid_user_id em vez de depender só da FK).
export function ProfessionalModal({ mode, professional, memberships, apiClient, onClose, onSaved }) {
  const [name, setName] = useState(professional?.name ?? '');
  const [userId, setUserId] = useState(professional?.user_id ?? '');
  const [active, setActive] = useState(professional?.active ?? true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    if (!name.trim()) {
      setError('Informe o nome do profissional.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const payload = {
        name: name.trim(),
        user_id: userId || null,
        ...(mode === 'edit' ? { active } : {}),
      };
      const { professional: saved } =
        mode === 'edit'
          ? await apiClient.patch(`/professionals/${professional.id}`, payload)
          : await apiClient.post('/professionals', payload);
      onSaved(saved);
    } catch (err) {
      setError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE } }));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal onClose={onClose}>
      <h2>{mode === 'edit' ? 'Editar profissional' : 'Novo profissional'}</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Nome
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label>
            Login individual (opcional)
            <select value={userId} onChange={(event) => setUserId(event.target.value)}>
              <option value="">Nenhum (sem login individual)</option>
              {memberships.map((membership) => (
                <option key={membership.user_id} value={membership.user_id}>
                  {membership.user_id.slice(0, 8)}… ({membership.role})
                </option>
              ))}
            </select>
          </label>

          {mode === 'edit' && (
            <label className="inline-checkbox">
              <input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />
              Ativo
            </label>
          )}

          {error && <p className="form-error" role="alert">{error}</p>}

          <div className="modal-actions">
            <button type="button" className="link-button" onClick={onClose}>
              Fechar
            </button>
            <button type="submit" disabled={submitting}>
              {mode === 'edit' ? 'Salvar' : 'Criar profissional'}
            </button>
          </div>
        </form>
    </Modal>
  );
}
