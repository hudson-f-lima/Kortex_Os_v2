import { useCallback, useEffect, useState } from 'react';
import { useApiClient } from '../../shared/useApiClient.js';
import { messageForError, OFFLINE_FALLBACK } from '../../shared/apiErrorMessage.js';
import { CapabilityModal } from './CapabilityModal.jsx';

// Mirrors backend/src/modules/professionalServiceCapabilities/professionalServiceCapabilities.route.js
// WRITE_ROLES/DELETE_ROLES. Read is open to any active member (professional
// included), unlike financial data such as cash_entries.
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

export function CapabilitiesTab({ professionals, services, currentRole }) {
  const apiClient = useApiClient();
  const canWrite = WRITE_ROLES.includes(currentRole);
  const canDelete = DELETE_ROLES.includes(currentRole);

  const [capabilities, setCapabilities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [modal, setModal] = useState(null);
  const [removeError, setRemoveError] = useState(null);
  const [confirmingRemoveId, setConfirmingRemoveId] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { professional_service_capabilities: data } = await apiClient.get('/professional-service-capabilities');
      setCapabilities(data);
    } catch (err) {
      setError(messageForError(err, { fallback: OFFLINE_FALLBACK }));
    } finally {
      setLoading(false);
    }
  }, [apiClient]);

  useEffect(() => {
    load();
  }, [load]);

  function handleSaved(capability) {
    setCapabilities((current) => {
      const exists = current.some((item) => item.id === capability.id);
      return exists ? current.map((item) => (item.id === capability.id ? capability : item)) : [...current, capability];
    });
    setModal(null);
  }

  async function handleRemove(capability) {
    setRemoveError(null);
    try {
      await apiClient.delete(`/professional-service-capabilities/${capability.id}`);
      setCapabilities((current) => current.filter((item) => item.id !== capability.id));
      setConfirmingRemoveId(null);
    } catch (err) {
      setRemoveError(messageForError(err, { fallback: 'Erro inesperado ao remover capacidade.' }));
    }
  }

  const getProName = (id) => professionals?.find((p) => p.id === id)?.name || id;
  const getServiceName = (id) => services?.find((s) => s.id === id)?.name || id;

  if (loading) return <p>Carregando capacidades…</p>;

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
    <div>
      {canWrite && (
        <div className="list-toolbar">
          <button type="button" onClick={() => setModal({ capability: null })}>
            + Adicionar capacidade
          </button>
        </div>
      )}

      {removeError && <p className="form-error">{removeError}</p>}

      {capabilities.length === 0 && <p className="list-empty">Nenhuma capacidade configurada ainda.</p>}

      {capabilities.length > 0 && (
        <table className="data-table">
          <thead>
            <tr>
              <th>Profissional</th>
              <th>Serviço</th>
              <th>Duração</th>
              <th>Preço</th>
              <th>Buffer antes</th>
              <th>Buffer depois</th>
              {(canWrite || canDelete) && <th>Ações</th>}
            </tr>
          </thead>
          <tbody>
            {capabilities.map((cap) => (
              <tr key={cap.id}>
                <td>{getProName(cap.professional_id)}</td>
                <td>{getServiceName(cap.service_id)}</td>
                <td>{cap.duration_override_minutes ? `${cap.duration_override_minutes}min` : '—'}</td>
                <td>{cap.price_override_cents ? `R$ ${(cap.price_override_cents / 100).toFixed(2)}` : '—'}</td>
                <td>{cap.buffer_before_min}min</td>
                <td>{cap.buffer_after_min}min</td>
                {(canWrite || canDelete) && (
                  <td>
                    {canWrite && (
                      <button type="button" className="link-button" onClick={() => setModal({ capability: cap })}>
                        Editar
                      </button>
                    )}
                    {canDelete && confirmingRemoveId !== cap.id && (
                      <button type="button" className="link-button" onClick={() => setConfirmingRemoveId(cap.id)}>
                        Remover
                      </button>
                    )}
                    {canDelete && confirmingRemoveId === cap.id && (
                      <>
                        <span>Confirma?</span>
                        <button type="button" className="danger-button" onClick={() => handleRemove(cap)}>
                          Sim
                        </button>
                        <button type="button" className="link-button" onClick={() => setConfirmingRemoveId(null)}>
                          Não
                        </button>
                      </>
                    )}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {modal && (
        <CapabilityModal
          capability={modal.capability}
          professionals={professionals}
          services={services}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={handleSaved}
        />
      )}
    </div>
  );
}
