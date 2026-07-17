import { useCallback, useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { useCachedQuery } from '../../shared/useCachedQuery.js';
import { ClientModal } from './ClientModal.jsx';
import { ClientHistory } from './ClientHistory.jsx';

// Mirrors backend/src/modules/clients/clients.route.js READ_ROLES/WRITE_ROLES
// (owner/admin/manager/reception) and DELETE_ROLES (no reception).
const WRITE_ROLES = ['owner', 'admin', 'manager', 'reception'];
const DELETE_ROLES = ['owner', 'admin', 'manager'];

function messageForListError(err) {
  if (err instanceof ApiError) return err.message;
  if (err?.message) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

function messageForRemoveError(err) {
  if (err instanceof ApiError) {
    if (err.status === 409) return 'Este cliente tem agendamentos ou pedidos vinculados — desative em vez de excluir.';
    return err.message;
  }
  return 'Erro inesperado ao remover cliente.';
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
      setRemoveError(messageForRemoveError(err));
    }
  }

  if (loading) return <p>Carregando clientes…</p>;

  if (error) {
    return (
      <div className="full-page-error">
        <p>{messageForListError(error)}</p>
        <button type="button" onClick={load}>
          Tentar novamente
        </button>
      </div>
    );
  }

  return (
    <div className="clientes-page">
      <h1>Clientes</h1>

      <div className="list-toolbar">
        <input
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
          <button type="button" onClick={() => setModal({ mode: 'create' })}>
            + Novo cliente
          </button>
        )}
      </div>

      {removeError && <p className="form-error">{removeError}</p>}

      {filtered.length === 0 && <p className="list-empty">Nenhum cliente encontrado.</p>}

      <ul className="record-list">
        {filtered.map((client) => (
          <li key={client.id} className="record-list-item">
            <button type="button" className="record-list-main record-list-link" onClick={() => setHistoryClient(client)}>
              <strong>{client.name}</strong>
              <span>{client.phone || client.email || '—'}</span>
              {!client.active && <span className="tag-inactive">inativo</span>}
            </button>
            {canWrite && (
              <button type="button" className="link-button" onClick={() => setModal({ mode: 'edit', client })}>
                Editar
              </button>
            )}
            {canDelete && confirmingRemoveId !== client.id && (
              <button type="button" className="link-button" onClick={() => setConfirmingRemoveId(client.id)}>
                Remover
              </button>
            )}
            {canDelete && confirmingRemoveId === client.id && (
              <>
                <span>Confirma?</span>
                <button type="button" className="danger-button" onClick={() => handleRemove(client)}>
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
