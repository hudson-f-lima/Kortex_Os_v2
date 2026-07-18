import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { reaisToCents } from '../../shared/money.js';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';

function newRowKey() {
  return crypto.randomUUID();
}

// Composição é escrita só via create_package/update_package (mutação
// multi-tabela atômica) — nunca insert direto; quando editada, o payload
// `items` substitui a composição inteira (delete+reinsert atômico no RPC).
export function PackageModal({ mode, pkg, services, apiClient, onClose, onSaved }) {
  const [name, setName] = useState(pkg?.name ?? '');
  const [priceReais, setPriceReais] = useState(pkg ? (pkg.price_cents / 100).toFixed(2) : '');
  const [active, setActive] = useState(pkg?.active ?? true);
  const [items, setItems] = useState(
    pkg?.items?.length
      ? pkg.items.map((item) => ({ key: newRowKey(), serviceId: item.service_id, quantity: item.quantity }))
      : [{ key: newRowKey(), serviceId: '', quantity: 1 }],
  );
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  function addItem() {
    setItems((current) => [...current, { key: newRowKey(), serviceId: '', quantity: 1 }]);
  }

  function removeItem(key) {
    setItems((current) => (current.length > 1 ? current.filter((item) => item.key !== key) : current));
  }

  function updateItem(key, patch) {
    setItems((current) => current.map((item) => (item.key === key ? { ...item, ...patch } : item)));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    const priceCents = reaisToCents(priceReais);
    const validItems = items.filter((item) => item.serviceId);
    if (!name.trim() || priceCents === null || validItems.length === 0) {
      setError('Preencha nome, preço e ao menos um serviço na composição.');
      return;
    }

    setSubmitting(true);
    setError(null);
    try {
      const payload = {
        name: name.trim(),
        price_cents: priceCents,
        items: validItems.map((item) => ({ service_id: item.serviceId, quantity: Number(item.quantity) || 1 })),
        ...(mode === 'edit' ? { active } : {}),
      };
      const { package: saved } =
        mode === 'edit' ? await apiClient.patch(`/packages/${pkg.id}`, payload) : await apiClient.post('/packages', payload);
      onSaved(saved);
    } catch (err) {
      setError(messageForError(err, { statuses: { 403: FORBIDDEN_MESSAGE } }));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal onClose={onClose}>
      <h2>{mode === 'edit' ? 'Editar pacote' : 'Novo pacote'}</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Nome
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label>
            Preço do pacote (R$)
            <input inputMode="decimal" value={priceReais} onChange={(event) => setPriceReais(event.target.value)} required />
          </label>

          <p className="section-hint">Composição (serviços inclusos)</p>
          {items.map((item) => (
            <div className="inline-row" key={item.key}>
              <select
                aria-label="Selecionar serviço do pacote"
                value={item.serviceId}
                onChange={(event) => updateItem(item.key, { serviceId: event.target.value })}
              >
                <option value="">Selecione um serviço</option>
                {services.map((service) => (
                  <option key={service.id} value={service.id}>
                    {service.name}
                  </option>
                ))}
              </select>
              <input
                type="number"
                min="1"
                aria-label="Quantidade do componente"
                value={item.quantity}
                onChange={(event) => updateItem(item.key, { quantity: event.target.value })}
              />
              {items.length > 1 && (
                <button type="button" className="link-button" onClick={() => removeItem(item.key)}>
                  Remover
                </button>
              )}
            </div>
          ))}
          <button type="button" className="link-button" onClick={addItem}>
            + Serviço na composição
          </button>

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
              {mode === 'edit' ? 'Salvar' : 'Criar pacote'}
            </button>
          </div>
        </form>
    </Modal>
  );
}
