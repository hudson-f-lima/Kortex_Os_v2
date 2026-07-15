import { useCallback, useEffect, useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { CapabilityModal } from './CapabilityModal.jsx';

function messageForError(err) {
  if (err instanceof ApiError) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

export function CapabilitiesTab({ professionals, services, currentRole }) {
  const api = useApiClient();
  const [capabilities, setCapabilities] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [selectedCapability, setSelectedCapability] = useState(null);

  const canEdit = ['owner', 'admin', 'manager'].includes(currentRole);
  const canDelete = ['owner', 'admin'].includes(currentRole);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await api.get('/professional-service-capabilities');
      setCapabilities(res.capabilities || []);
    } catch (err) {
      setError(messageForError(err));
    } finally {
      setLoading(false);
    }
  }, [api]);

  useEffect(() => {
    load();
  }, [load]);

  async function handleSave(capabilityData) {
    try {
      if (selectedCapability) {
        await api.patch(`/professional-service-capabilities/${selectedCapability.id}`, capabilityData);
      } else {
        await api.post('/professional-service-capabilities', capabilityData);
      }
      setShowModal(false);
      setSelectedCapability(null);
      load();
    } catch (err) {
      alert(messageForError(err));
    }
  }

  async function handleDelete(capability) {
    const confirmed = confirm('Tem certeza que deseja remover esta capacidade?');
    if (!confirmed) return;

    try {
      await api.delete(`/professional-service-capabilities/${capability.id}`);
      load();
    } catch (err) {
      alert(messageForError(err));
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
      {canEdit && (
        <div className="list-toolbar">
          <button type="button" onClick={() => setShowModal(true)}>
            + Adicionar capacidade
          </button>
        </div>
      )}

      {capabilities.length === 0 && (
        <p className="list-empty">Nenhuma capacidade configurada ainda.</p>
      )}

      {capabilities.length > 0 && (
        <table className="data-table">
          <thead>
            <tr>
              <th>Profissional</th>
              <th>Serviço</th>
              <th>Duração</th>
              <th>Preço</th>
              <th>Buffer Antes</th>
              <th>Buffer Depois</th>
              {canDelete && <th>Ação</th>}
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
                {canDelete && (
                  <td>
                    <button type="button" className="link-button" onClick={() => handleDelete(cap)}>
                      Remover
                    </button>
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      )}

      {showModal && (
        <CapabilityModal
          capability={selectedCapability}
          professionals={professionals}
          services={services}
          apiClient={api}
          onClose={() => {
            setShowModal(false);
            setSelectedCapability(null);
          }}
          onSaved={async (capabilityData) => {
            await handleSave(capabilityData);
          }}
        />
      )}
    </div>
  );
}
