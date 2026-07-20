import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { reaisToCents } from '../../shared/money.js';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';
import { Button } from '../../ui/primitives/Button.jsx';
import { Input } from '../../ui/primitives/Input.jsx';
import { Select } from '../../ui/primitives/Select.jsx';

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
          <Input label="Nome" value={name} onChange={(event) => setName(event.target.value)} required />
          <Input label="Preço do pacote (R$)" inputMode="decimal" value={priceReais} onChange={(event) => setPriceReais(event.target.value)} required />

          <p className="section-hint">Composição (serviços inclusos)</p>
          {items.map((item) => (
            <div className="inline-row" key={item.key}>
              <Select
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
              </Select>
              <Input
                type="number"
                min="1"
                aria-label="Quantidade do componente"
                value={item.quantity}
                onChange={(event) => updateItem(item.key, { quantity: event.target.value })}
              />
              {items.length > 1 && (
                <Button variant="link" onClick={() => removeItem(item.key)}>
                  Remover
                </Button>
              )}
            </div>
          ))}
          <Button variant="link" onClick={addItem}>
            + Serviço na composição
          </Button>

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
              {mode === 'edit' ? 'Salvar' : 'Criar pacote'}
            </Button>
          </div>
        </form>
    </Modal>
  );
}
