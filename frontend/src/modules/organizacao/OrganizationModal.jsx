import { useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { slugify } from '../../shared/slugify.js';

function messageForError(err) {
  if (err instanceof ApiError) {
    if (err.status === 409) return 'Já existe uma organização com este identificador.';
    return err.message;
  }
  return 'Erro inesperado. Tente novamente.';
}

// create_organization não depende de organizationContext (o ator ainda pode
// não ter nenhuma membership) — usado tanto no bootstrap de zero
// organizações (CreateOrganizationPage) quanto aqui, para um usuário que já
// tem uma organização e quer abrir outra (multi-negócio).
export function OrganizationModal({ apiClient, onClose, onCreated }) {
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');
  const [slugTouched, setSlugTouched] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  function handleNameChange(value) {
    setName(value);
    if (!slugTouched) setSlug(slugify(value));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      const { organization } = await apiClient.post('/organizations', { name: name.trim(), slug });
      onCreated(organization);
    } catch (err) {
      setError(messageForError(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h2>Nova organização</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Nome
            <input
              value={name}
              onChange={(event) => handleNameChange(event.target.value)}
              required
              minLength={2}
              maxLength={120}
            />
          </label>
          <label>
            Identificador (slug)
            <input
              value={slug}
              onChange={(event) => {
                setSlugTouched(true);
                setSlug(event.target.value);
              }}
              required
              pattern="^[a-z0-9]+(-[a-z0-9]+)*$"
            />
          </label>

          {error && <p className="form-error">{error}</p>}

          <div className="modal-actions">
            <button type="button" className="link-button" onClick={onClose}>
              Fechar
            </button>
            <button type="submit" disabled={submitting}>
              {submitting ? 'Criando…' : 'Criar organização'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
