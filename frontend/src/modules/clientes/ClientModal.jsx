import { useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';

function messageForError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    return err.message;
  }
  return 'Erro inesperado. Tente novamente.';
}

// Cria/edita clientes (docs/PWA_PLANEJAMENTO.md §4.1/§6): só os campos que o
// backend expõe (name/phone/email/active) — sem preferências/observações,
// que não existem no schema de clients.
export function ClientModal({ mode, client, apiClient, onClose, onSaved }) {
  const [name, setName] = useState(client?.name ?? '');
  const [phone, setPhone] = useState(client?.phone ?? '');
  const [email, setEmail] = useState(client?.email ?? '');
  const [active, setActive] = useState(client?.active ?? true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    if (!name.trim()) {
      setError('Informe o nome do cliente.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const payload = {
        name: name.trim(),
        phone: phone.trim() || null,
        email: email.trim() || null,
        ...(mode === 'edit' ? { active } : {}),
      };
      const { client: saved } =
        mode === 'edit'
          ? await apiClient.patch(`/clients/${client.id}`, payload)
          : await apiClient.post('/clients', payload);
      onSaved(saved);
    } catch (err) {
      setError(messageForError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h2>{mode === 'edit' ? 'Editar cliente' : 'Novo cliente'}</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Nome
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label>
            Telefone
            <input value={phone} onChange={(event) => setPhone(event.target.value)} />
          </label>
          <label>
            E-mail
            <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} />
          </label>

          {mode === 'edit' && (
            <label className="inline-checkbox">
              <input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />
              Ativo
            </label>
          )}

          {error && <p className="form-error">{error}</p>}

          <div className="modal-actions">
            <button type="button" className="link-button" onClick={onClose}>
              Fechar
            </button>
            <button type="submit" disabled={submitting}>
              {mode === 'edit' ? 'Salvar' : 'Criar cliente'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
