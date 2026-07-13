import { useState } from 'react';
import { ApiError } from '../shared/apiClient.js';
import { useAuth } from '../shared/AuthContext.jsx';
import { useOrganization } from '../shared/OrganizationContext.jsx';
import { createApiClient } from '../shared/apiClient.js';
import { slugify } from '../shared/slugify.js';

// Bootstrap mínimo (nome + slug) para o shell ter algo a mostrar quando o
// usuário não tem nenhuma organização ainda. Criar uma organização adicional
// (usuário que já tem uma) vive em OrganizacaoPage (Fase 6.5), reaproveitando
// o mesmo slugify.
export function CreateOrganizationPage() {
  const { accessToken, signOut } = useAuth();
  const { refresh } = useOrganization();
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');
  const [slugTouched, setSlugTouched] = useState(false);
  const [error, setError] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const client = createApiClient({ getAccessToken: () => accessToken });

  function handleNameChange(value) {
    setName(value);
    if (!slugTouched) setSlug(slugify(value));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      await client.post('/organizations', { name: name.trim(), slug });
      await refresh();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'erro inesperado ao criar organização');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="auth-screen">
      <form className="auth-form" onSubmit={handleSubmit}>
        <h1>Criar organização</h1>
        <p>Sua conta ainda não pertence a nenhuma organização.</p>
        <label>
          Nome
          <input value={name} onChange={(event) => handleNameChange(event.target.value)} required minLength={2} maxLength={120} />
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
        <button type="submit" disabled={submitting}>
          {submitting ? 'Criando…' : 'Criar organização'}
        </button>
        <button type="button" className="link-button" onClick={signOut}>
          Sair
        </button>
      </form>
    </div>
  );
}
