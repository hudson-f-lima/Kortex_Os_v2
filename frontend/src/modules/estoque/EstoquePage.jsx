import { useCallback, useEffect, useState } from 'react';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/OrganizationContext.jsx';
import { formatCents } from '../../shared/money.js';
import { AdjustmentModal } from './AdjustmentModal.jsx';

// Mirrors backend/src/modules/inventory/inventory.route.js ADJUST_ROLES/
// READ_ROLES (owner/admin/manager, no reception) — products themselves stay
// readable to any active member, so reception sees stock levels read-only.
const MANAGE_ROLES = ['owner', 'admin', 'manager'];

const REASON_LABELS = { purchase: 'Compra', adjustment: 'Ajuste', return: 'Devolução', sale: 'Venda' };

function messageForListError(err) {
  if (err instanceof ApiError) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

function reasonLabel(reason) {
  return REASON_LABELS[reason] ?? reason;
}

export function EstoquePage() {
  const { role } = useOrganization();
  const apiClient = useApiClient();
  const canManage = MANAGE_ROLES.includes(role);

  const [products, setProducts] = useState([]);
  const [movements, setMovements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showInactive, setShowInactive] = useState(false);
  const [adjustingProduct, setAdjustingProduct] = useState(null);
  const [selectedProductId, setSelectedProductId] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const query = showInactive ? '' : '?active=true';
      const { products: data } = await apiClient.get(`/products${query}`);
      setProducts(data);
      if (canManage) {
        const { movements: movementData } = await apiClient.get('/inventory/movements');
        setMovements(movementData);
      }
    } catch (err) {
      setError(messageForListError(err));
    } finally {
      setLoading(false);
    }
  }, [apiClient, showInactive, canManage]);

  useEffect(() => {
    load();
  }, [load]);

  function handleAdjusted() {
    setAdjustingProduct(null);
    load();
  }

  function productName(id) {
    return products.find((product) => product.id === id)?.name ?? '—';
  }

  const filteredMovements = selectedProductId
    ? movements.filter((movement) => movement.product_id === selectedProductId)
    : movements;

  if (loading) return <p>Carregando estoque…</p>;

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
    <div className="estoque-page">
      <h1>Estoque</h1>

      {!canManage && <p className="section-hint">Seu papel só pode visualizar os níveis de estoque nesta organização.</p>}

      <div className="list-toolbar">
        <label className="inline-checkbox">
          <input type="checkbox" checked={showInactive} onChange={(event) => setShowInactive(event.target.checked)} />
          Mostrar inativos
        </label>
      </div>

      {products.length === 0 && (
        <p className="list-empty">Nenhum produto cadastrado ainda. Cadastre produtos no módulo Catálogo.</p>
      )}

      <ul className="record-list">
        {products.map((product) => (
          <li key={product.id} className="record-list-item">
            <span className="record-list-main">
              <strong>{product.name}</strong>
              <span>
                {product.sku} · {formatCents(product.price_cents)} · estoque: {product.stock_on_hand}
              </span>
              {!product.active && <span className="tag-inactive">inativo</span>}
            </span>
            {canManage && (
              <button type="button" className="link-button" onClick={() => setAdjustingProduct(product)}>
                Ajustar estoque
              </button>
            )}
          </li>
        ))}
      </ul>

      {canManage && (
        <section>
          <h2>Movimentações</h2>
          <select
            aria-label="Filtrar movimentações por produto"
            value={selectedProductId}
            onChange={(event) => setSelectedProductId(event.target.value)}
          >
            <option value="">Todos os produtos</option>
            {products.map((product) => (
              <option key={product.id} value={product.id}>
                {product.name}
              </option>
            ))}
          </select>

          {filteredMovements.length === 0 && <p className="list-empty">Nenhuma movimentação registrada ainda.</p>}

          <ul className="record-list">
            {filteredMovements.map((movement) => (
              <li key={movement.id} className="record-list-item">
                <span className="record-list-main">
                  <strong>{productName(movement.product_id)}</strong>
                  <span>
                    {movement.quantity_delta > 0 ? '+' : ''}
                    {movement.quantity_delta} · {reasonLabel(movement.reason)} · saldo: {movement.balance_after} ·{' '}
                    {new Date(movement.created_at).toLocaleString('pt-BR')}
                  </span>
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}

      {adjustingProduct && (
        <AdjustmentModal
          product={adjustingProduct}
          apiClient={apiClient}
          onClose={() => setAdjustingProduct(null)}
          onAdjusted={handleAdjusted}
        />
      )}
    </div>
  );
}
