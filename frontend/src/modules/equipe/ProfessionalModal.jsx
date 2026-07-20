import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';
import { Button } from '../../ui/primitives/Button.jsx';
import { Input } from '../../ui/primitives/Input.jsx';
import { Select } from '../../ui/primitives/Select.jsx';

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
          <Input label="Nome" value={name} onChange={(event) => setName(event.target.value)} required />
          <Select label="Login individual (opcional)" value={userId} onChange={(event) => setUserId(event.target.value)}>
            <option value="">Nenhum (sem login individual)</option>
            {memberships.map((membership) => (
              <option key={membership.user_id} value={membership.user_id}>
                {membership.user_id.slice(0, 8)}… ({membership.role})
              </option>
            ))}
          </Select>

          {mode === 'edit' && (
            <label className="inline-checkbox">
              <input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />
              Ativo
            </label>
          )}

          {error && <p className="form-error" role="alert">{error}</p>}

          <div className="modal-actions">
            <Button variant="secondary" onClick={onClose}>
              Fechar
            </Button>
            <Button type="submit" disabled={submitting}>
              {mode === 'edit' ? 'Salvar' : 'Criar profissional'}
            </Button>
          </div>
        </form>
    </Modal>
  );
}
