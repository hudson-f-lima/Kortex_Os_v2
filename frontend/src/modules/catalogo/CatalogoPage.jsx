import { useCallback, useEffect, useState } from 'react';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { formatCents } from '../../shared/money.js';
import { messageForError, OFFLINE_FALLBACK } from '../../shared/apiErrorMessage.js';
import { formatPercent } from './commission.js';
import { ServiceGroupModal } from './ServiceGroupModal.jsx';
import { ServiceModal } from './ServiceModal.jsx';
import { ProductModal } from './ProductModal.jsx';
import { PackageModal } from './PackageModal.jsx';

// Mirrors the WRITE_ROLES/DELETE_ROLES shared by services/products/
// service-groups/packages routes (owner/admin/manager write, owner/admin
// delete) — reads are open to any active member (reception sees a
// browse-only catalog, matching Comanda's per-role treatment).
const WRITE_ROLES = ['owner', 'admin', 'manager'];
const DELETE_ROLES = ['owner', 'admin'];

const TABS = [
  { key: 'servicos', label: 'Serviços' },
  { key: 'produtos', label: 'Produtos' },
  { key: 'pacotes', label: 'Pacotes' },
  { key: 'grupos', label: 'Grupos de serviço' },
];

const CONFLICT_MESSAGES = {
  group: 'Este grupo tem serviços vinculados — desative em vez de excluir.',
  service: 'Este serviço está vinculado a agendamentos ou pacotes — desative em vez de excluir.',
  product: 'Este produto está vinculado a pedidos ou movimentos de estoque — desative em vez de excluir.',
  package: 'Este pacote está vinculado a pedidos — desative em vez de excluir.',
};

const REMOVE_PATHS = { group: 'service-groups', service: 'services', product: 'products', package: 'packages' };

function messageForActionError(err, type) {
  return messageForError(err, { statuses: { 409: CONFLICT_MESSAGES[type] } });
}

function upsertSorted(list, saved) {
  const exists = list.some((item) => item.id === saved.id);
  const next = exists ? list.map((item) => (item.id === saved.id ? saved : item)) : [...list, saved];
  return next.sort((a, b) => a.name.localeCompare(b.name));
}

export function CatalogoPage() {
  const { role } = useOrganization();
  const apiClient = useApiClient();
  const canWrite = WRITE_ROLES.includes(role);
  const canDelete = DELETE_ROLES.includes(role);

  const [tab, setTab] = useState('servicos');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [groups, setGroups] = useState([]);
  const [services, setServices] = useState([]);
  const [products, setProducts] = useState([]);
  const [packages, setPackages] = useState([]);
  const [modal, setModal] = useState(null);
  const [actionError, setActionError] = useState(null);
  const [confirmingRemove, setConfirmingRemove] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [groupsRes, servicesRes, productsRes, packagesRes] = await Promise.all([
        apiClient.get('/service-groups'),
        apiClient.get('/services'),
        apiClient.get('/products'),
        apiClient.get('/packages'),
      ]);
      setGroups(groupsRes.service_groups);
      setServices(servicesRes.services);
      setProducts(productsRes.products);
      setPackages(packagesRes.packages);
    } catch (err) {
      setError(messageForError(err, { fallback: OFFLINE_FALLBACK }));
    } finally {
      setLoading(false);
    }
  }, [apiClient]);

  useEffect(() => {
    load();
  }, [load]);

  function groupName(id) {
    return groups.find((group) => group.id === id)?.name ?? '—';
  }

  async function handleRemove(type, id) {
    setActionError(null);
    try {
      await apiClient.delete(`/${REMOVE_PATHS[type]}/${id}`);
      const setters = { group: setGroups, service: setServices, product: setProducts, package: setPackages };
      setters[type]((current) => current.filter((item) => item.id !== id));
      setConfirmingRemove(null);
    } catch (err) {
      setActionError(messageForActionError(err, type));
    }
  }

  async function openEditPackage(pkg) {
    setActionError(null);
    try {
      const { package: full } = await apiClient.get(`/packages/${pkg.id}`);
      setModal({ type: 'package', mode: 'edit', pkg: full });
    } catch (err) {
      setActionError(messageForActionError(err, 'package'));
    }
  }

  if (loading) return <p>Carregando catálogo…</p>;

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
    <div className="catalogo-page">
      <h1>Catálogo</h1>

      <div className="agenda-view-toggle">
        {TABS.map((item) => (
          <button key={item.key} type="button" className={tab === item.key ? 'active' : ''} onClick={() => setTab(item.key)}>
            {item.label}
          </button>
        ))}
      </div>

      {actionError && <p className="form-error">{actionError}</p>}

      {tab === 'servicos' && (
        <section>
          {canWrite && groups.length === 0 && (
            <p className="section-hint">Cadastre um grupo de serviço antes de criar serviços.</p>
          )}
          {canWrite && groups.length > 0 && (
            <button type="button" onClick={() => setModal({ type: 'service', mode: 'create' })}>
              + Novo serviço
            </button>
          )}
          {services.length === 0 && <p className="list-empty">Nenhum serviço cadastrado ainda.</p>}
          <ul className="record-list">
            {services.map((service) => (
              <li key={service.id} className="record-list-item">
                <span className="record-list-main">
                  <strong>{service.name}</strong>
                  <span>
                    {formatCents(service.price_cents)} · {service.duration_minutes} min · {groupName(service.service_group_id)}
                  </span>
                  {service.commission_type && (
                    <span className="tag-muted">
                      comissão própria:{' '}
                      {service.commission_type === 'percentage'
                        ? formatPercent(service.commission_value)
                        : formatCents(service.commission_value)}
                    </span>
                  )}
                  {!service.active && <span className="tag-inactive">inativo</span>}
                </span>
                {canWrite && (
                  <button type="button" className="link-button" onClick={() => setModal({ type: 'service', mode: 'edit', service })}>
                    Editar
                  </button>
                )}
                {canDelete && (
                  <RemoveControl
                    id={service.id}
                    type="service"
                    confirmingRemove={confirmingRemove}
                    setConfirmingRemove={setConfirmingRemove}
                    onRemove={() => handleRemove('service', service.id)}
                  />
                )}
              </li>
            ))}
          </ul>
        </section>
      )}

      {tab === 'produtos' && (
        <section>
          {canWrite && (
            <button type="button" onClick={() => setModal({ type: 'product', mode: 'create' })}>
              + Novo produto
            </button>
          )}
          {products.length === 0 && <p className="list-empty">Nenhum produto cadastrado ainda.</p>}
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
                {canWrite && (
                  <button type="button" className="link-button" onClick={() => setModal({ type: 'product', mode: 'edit', product })}>
                    Editar
                  </button>
                )}
                {canDelete && (
                  <RemoveControl
                    id={product.id}
                    type="product"
                    confirmingRemove={confirmingRemove}
                    setConfirmingRemove={setConfirmingRemove}
                    onRemove={() => handleRemove('product', product.id)}
                  />
                )}
              </li>
            ))}
          </ul>
        </section>
      )}

      {tab === 'pacotes' && (
        <section>
          {canWrite && services.length === 0 && (
            <p className="section-hint">Cadastre serviços antes de montar um pacote.</p>
          )}
          {canWrite && services.length > 0 && (
            <button type="button" onClick={() => setModal({ type: 'package', mode: 'create' })}>
              + Novo pacote
            </button>
          )}
          {packages.length === 0 && <p className="list-empty">Nenhum pacote cadastrado ainda.</p>}
          <ul className="record-list">
            {packages.map((pkg) => (
              <li key={pkg.id} className="record-list-item">
                <span className="record-list-main">
                  <strong>{pkg.name}</strong>
                  <span>{formatCents(pkg.price_cents)}</span>
                  {!pkg.active && <span className="tag-inactive">inativo</span>}
                </span>
                {canWrite && (
                  <button type="button" className="link-button" onClick={() => openEditPackage(pkg)}>
                    Editar
                  </button>
                )}
                {canDelete && (
                  <RemoveControl
                    id={pkg.id}
                    type="package"
                    confirmingRemove={confirmingRemove}
                    setConfirmingRemove={setConfirmingRemove}
                    onRemove={() => handleRemove('package', pkg.id)}
                  />
                )}
              </li>
            ))}
          </ul>
        </section>
      )}

      {tab === 'grupos' && (
        <section>
          {canWrite && (
            <button type="button" onClick={() => setModal({ type: 'group', mode: 'create' })}>
              + Novo grupo
            </button>
          )}
          {groups.length === 0 && <p className="list-empty">Nenhum grupo de serviço cadastrado ainda.</p>}
          <ul className="record-list">
            {groups.map((group) => (
              <li key={group.id} className="record-list-item">
                <span className="record-list-main">
                  <strong>{group.name}</strong>
                  <span>
                    {group.default_commission_type === 'percentage'
                      ? formatPercent(group.default_commission_value)
                      : formatCents(group.default_commission_value)}
                  </span>
                  {!group.active && <span className="tag-inactive">inativo</span>}
                </span>
                {canWrite && (
                  <button type="button" className="link-button" onClick={() => setModal({ type: 'group', mode: 'edit', group })}>
                    Editar
                  </button>
                )}
                {canDelete && (
                  <RemoveControl
                    id={group.id}
                    type="group"
                    confirmingRemove={confirmingRemove}
                    setConfirmingRemove={setConfirmingRemove}
                    onRemove={() => handleRemove('group', group.id)}
                  />
                )}
              </li>
            ))}
          </ul>
        </section>
      )}

      {modal?.type === 'group' && (
        <ServiceGroupModal
          mode={modal.mode}
          group={modal.group}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={(saved) => {
            setGroups((current) => upsertSorted(current, saved));
            setModal(null);
          }}
        />
      )}
      {modal?.type === 'service' && (
        <ServiceModal
          mode={modal.mode}
          service={modal.service}
          groups={groups}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={(saved) => {
            setServices((current) => upsertSorted(current, saved));
            setModal(null);
          }}
        />
      )}
      {modal?.type === 'product' && (
        <ProductModal
          mode={modal.mode}
          product={modal.product}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={(saved) => {
            setProducts((current) => upsertSorted(current, saved));
            setModal(null);
          }}
        />
      )}
      {modal?.type === 'package' && (
        <PackageModal
          mode={modal.mode}
          pkg={modal.pkg}
          services={services}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={(saved) => {
            setPackages((current) => upsertSorted(current, saved));
            setModal(null);
          }}
        />
      )}
    </div>
  );
}

function RemoveControl({ id, type, confirmingRemove, setConfirmingRemove, onRemove }) {
  const confirming = confirmingRemove?.type === type && confirmingRemove?.id === id;
  if (!confirming) {
    return (
      <button type="button" className="link-button" onClick={() => setConfirmingRemove({ type, id })}>
        Remover
      </button>
    );
  }
  return (
    <>
      <span>Confirma?</span>
      <button type="button" className="danger-button" onClick={onRemove}>
        Sim
      </button>
      <button type="button" className="link-button" onClick={() => setConfirmingRemove(null)}>
        Não
      </button>
    </>
  );
}
