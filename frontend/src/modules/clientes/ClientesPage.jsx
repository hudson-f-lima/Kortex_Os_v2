import { useCallback, useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { useCachedQuery } from '../../shared/useCachedQuery.js';
import { messageForError } from '../../shared/apiErrorMessage.js';
import { ClientModal } from './ClientModal.jsx';
import { ClientHistory } from './ClientHistory.jsx';
import { Button } from '../../ui/primitives/Button.jsx';
import { Input } from '../../ui/primitives/Input.jsx';
import { Badge } from '../../ui/primitives/Badge.jsx';

import { EmptyState } from '../../ui/primitives/EmptyState.jsx';
import { Users } from 'lucide-react';

// Mirrors backend/src/modules/clients/clients.route.js READ_ROLES/WRITE_ROLES
// (owner/admin/manager/reception) and DELETE_ROLES (no reception).
const WRITE_ROLES = ['owner', 'admin', 'manager', 'reception'];
const DELETE_ROLES = ['owner', 'admin', 'manager'];

// Comportamento distinto do apiErrorMessage.js compartilhado — testado
// explicitamente em ClientesPage.test.jsx ("network down"): erros JS crus
// (não ApiError) devem surfacar err.message em vez do fallback genérico.
// Não generalizar (só este arquivo e AgendaPage.jsx têm esse terceiro branch).
function messageForListError(err) {
  if (err instanceof ApiError) return err.message;
  if (err?.message) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

export function ClientesPage() {
  const { role } = useOrganization();
  const apiClient = useApiClient();
  const canWrite = WRITE_ROLES.includes(role);
  const canDelete = DELETE_ROLES.includes(role);

  const [showInactive, setShowInactive] = useState(false);
  const [search, setSearch] = useState('');
  const [modal, setModal] = useState(null);
  const [historyClient, setHistoryClient] = useState(null);
  const [removeError, setRemoveError] = useState(null);
  const [confirmingRemoveId, setConfirmingRemoveId] = useState(null);

  const filterFn = useCallback((client) => {
    return showInactive || client.active;
  }, [showInactive]);

  const { data: cachedClients, loading, error, refetch: load } = useCachedQuery('clients', filterFn);

  const filtered = cachedClients
    .filter((client) => client.name.toLowerCase().includes(search.trim().toLowerCase()))
    .sort((a, b) => a.name.localeCompare(b.name));

  function handleSaved(client) {
    import('../../shared/idb.js').then(({ putRecord }) => {
      putRecord('clients', client)
        .then(() => load())
        .catch(console.error);
    });
    setModal(null);
  }

  async function handleRemove(client) {
    setRemoveError(null);
    try {
      await apiClient.delete(`/clients/${client.id}`);
      const { deleteRecord } = await import('../../shared/idb.js');
      await deleteRecord('clients', client.id);
      load();
      setConfirmingRemoveId(null);
    } catch (err) {
      setRemoveError(
        messageForError(err, {
          fallback: 'Erro inesperado ao remover cliente.',
          statuses: { 409: 'Este cliente tem agendamentos ou pedidos vinculados — desative em vez de excluir.' },
        }),
      );
    }
  }

  if (loading) return <p>Carregando clientes…</p>;

  if (error) {
    return (
      <div className="full-page-error">
        <p>{messageForListError(error)}</p>
        <Button onClick={load}>Tentar novamente</Button>
      </div>
    );
  }

  return (
    <div className="clientes-page">
      <h1>Clientes</h1>

      <div className="list-toolbar">
        <Input
          type="text"
          placeholder="Buscar por nome"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <label className="inline-checkbox">
          <input type="checkbox" checked={showInactive} onChange={(event) => setShowInactive(event.target.checked)} />
          Mostrar inativos
        </label>
        {canWrite && (
          <Button onClick={() => setModal({ mode: 'create' })}>
            + Novo cliente
          </Button>
        )}
      </div>

      {removeError && <p className="form-error" role="alert">{removeError}</p>}

      {filtered.length === 0 ? (
        <EmptyState 
          icon={Users}
          title="Nenhum cliente encontrado"
          description={search ? 'Não encontramos nenhum cliente com este nome.' : 'Você ainda não possui clientes cadastrados.'}
          actionLabel={canWrite && !search ? 'Cadastrar Primeiro Cliente' : null}
          onAction={canWrite && !search ? () => setModal({ mode: 'create' }) : null}
        />
      ) : (
        <ul className="record-list">
        {filtered.map((client) => (
          <li key={client.id} className="record-list-item">
            <button type="button" className="record-list-main record-list-link" onClick={() => setHistoryClient(client)}>
              <strong>{client.name}</strong>
              <span>{client.phone || client.email || '—'}</span>
              {!client.active && <Badge variant="neutral">inativo</Badge>}
            </button>
            {canWrite && (
              <Button variant="link" onClick={() => setModal({ mode: 'edit', client })}>
                Editar
              </Button>
            )}
            {canDelete && confirmingRemoveId !== client.id && (
              <Button variant="link" onClick={() => setConfirmingRemoveId(client.id)}>
                Remover
              </Button>
            )}
            {canDelete && confirmingRemoveId === client.id && (
              <>
                <span>Confirma?</span>
                <Button variant="danger" onClick={() => handleRemove(client)}>
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
      )}

      {modal && (
        <ClientModal
          mode={modal.mode}
          client={modal.client}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={handleSaved}
        />
      )}

      {historyClient && (
        <ClientHistory client={historyClient} apiClient={apiClient} onClose={() => setHistoryClient(null)} />
      )}
    </div>
  );
}
