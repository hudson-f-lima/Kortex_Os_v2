import { useState } from 'react';
import { Modal } from '../../shared/Modal.jsx';
import { reaisToCents } from '../../shared/money.js';
import { messageForError, FORBIDDEN_MESSAGE } from '../../shared/apiErrorMessage.js';

// stock_on_hand é somente leitura por design (products.validation.js) — só
// inventory_adjust/checkout_close alteram saldo, então não há campo de
// estoque neste formulário; ajustes acontecem no módulo Estoque.
export function ProductModal({ mode, product, apiClient, onClose, onSaved }) {
  const [sku, setSku] = useState(product?.sku ?? '');
  const [name, setName] = useState(product?.name ?? '');
  const [priceReais, setPriceReais] = useState(product ? (product.price_cents / 100).toFixed(2) : '');
  const [costReais, setCostReais] = useState(
    product?.cost_cents !== undefined && product?.cost_cents !== null ? (product.cost_cents / 100).toFixed(2) : '',
  );
  const [active, setActive] = useState(product?.active ?? true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(event) {
    event.preventDefault();
    const priceCents = reaisToCents(priceReais);
    const costCents = costReais.trim() ? reaisToCents(costReais) : undefined;
    if (!sku.trim() || !name.trim() || priceCents === null || (costReais.trim() && costCents === null)) {
      setError('Preencha SKU, nome e preço válidos.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const payload = {
        sku: sku.trim(),
        name: name.trim(),
        price_cents: priceCents,
        ...(costCents !== undefined ? { cost_cents: costCents } : {}),
        ...(mode === 'edit' ? { active } : {}),
      };
      const { product: saved } =
        mode === 'edit' ? await apiClient.patch(`/products/${product.id}`, payload) : await apiClient.post('/products', payload);
      onSaved(saved);
    } catch (err) {
      setError(
        messageForError(err, {
          statuses: { 403: FORBIDDEN_MESSAGE, 409: 'Já existe um produto com este SKU nesta organização.' },
        }),
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal onClose={onClose}>
      <h2>{mode === 'edit' ? 'Editar produto' : 'Novo produto'}</h2>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            SKU
            <input value={sku} onChange={(event) => setSku(event.target.value)} required />
          </label>
          <label>
            Nome
            <input value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label>
            Preço de venda (R$)
            <input inputMode="decimal" value={priceReais} onChange={(event) => setPriceReais(event.target.value)} required />
          </label>
          <label>
            Custo (R$, opcional)
            <input inputMode="decimal" value={costReais} onChange={(event) => setCostReais(event.target.value)} />
          </label>

          {mode === 'edit' && (
            <>
              <p className="section-hint">Estoque atual: {product.stock_on_hand} (ajuste no módulo Estoque)</p>
              <label className="inline-checkbox">
                <input type="checkbox" checked={active} onChange={(event) => setActive(event.target.checked)} />
                Ativo
              </label>
            </>
          )}

          {error && <p className="form-error">{error}</p>}

          <div className="modal-actions">
            <button type="button" className="link-button" onClick={onClose}>
              Fechar
            </button>
            <button type="submit" disabled={submitting}>
              {mode === 'edit' ? 'Salvar' : 'Criar produto'}
            </button>
          </div>
        </form>
    </Modal>
  );
}
