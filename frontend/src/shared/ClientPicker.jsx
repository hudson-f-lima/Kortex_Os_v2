import { useMemo, useState } from 'react';
import { ApiError } from './apiClient.js';

// Busca/seleção de cliente + criação inline (nome + telefone), sem sair do
// fluxo de agendamento/comanda (docs/PWA_PLANEJAMENTO.md §5.3). Compartilhado
// entre Agenda (AppointmentModal) e Comanda — mesmo padrão de UX nos dois.
export function ClientPicker({ clients, value, onChange, apiClient, onClientCreated, disabled, noneLabel }) {
  const [query, setQuery] = useState('');
  const [showNewClient, setShowNewClient] = useState(false);
  const [newClientName, setNewClientName] = useState('');
  const [newClientPhone, setNewClientPhone] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  const filteredClients = useMemo(() => {
    const trimmed = query.trim().toLowerCase();
    if (!trimmed) return clients;
    return clients.filter((client) => client.name.toLowerCase().includes(trimmed));
  }, [query, clients]);

  async function handleCreateClient(event) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    try {
      const { client } = await apiClient.post('/clients', {
        name: newClientName.trim(),
        ...(newClientPhone.trim() ? { phone: newClientPhone.trim() } : {}),
      });
      onClientCreated(client);
      onChange(client.id);
      setShowNewClient(false);
      setNewClientName('');
      setNewClientPhone('');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'erro inesperado ao criar cliente');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="client-picker">
      <label>
        Cliente
        <input
          type="text"
          placeholder="Buscar cliente por nome"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          disabled={disabled}
        />
      </label>
      <select aria-label="Selecionar cliente" value={value} onChange={(event) => onChange(event.target.value)} disabled={disabled}>
        <option value="">{noneLabel ?? 'Selecione um cliente'}</option>
        {filteredClients.map((client) => (
          <option key={client.id} value={client.id}>
            {client.name}
          </option>
        ))}
      </select>

      {!disabled && !showNewClient && (
        <button type="button" className="link-button" onClick={() => setShowNewClient(true)}>
          + Novo cliente
        </button>
      )}

      {!disabled && showNewClient && (
        <div className="inline-form">
          <label>
            Nome do novo cliente
            <input value={newClientName} onChange={(event) => setNewClientName(event.target.value)} />
          </label>
          <label>
            Telefone (opcional)
            <input value={newClientPhone} onChange={(event) => setNewClientPhone(event.target.value)} />
          </label>
          {error && <p className="form-error" role="alert">{error}</p>}
          <button type="button" disabled={!newClientName.trim() || submitting} onClick={handleCreateClient}>
            Salvar cliente
          </button>
          <button type="button" className="link-button" onClick={() => setShowNewClient(false)}>
            Cancelar
          </button>
        </div>
      )}
    </div>
  );
}
