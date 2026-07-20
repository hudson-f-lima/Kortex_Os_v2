import { useCallback, useEffect, useState } from 'react';
import { useApiClient } from '../../shared/useApiClient.js';
import { useCachedQuery } from '../../shared/useCachedQuery.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { formatCents } from '../../shared/money.js';
import { messageForError, OFFLINE_FALLBACK } from '../../shared/apiErrorMessage.js';
import { formatPercent } from './commission.js';
import { ServiceGroupModal } from './ServiceGroupModal.jsx';
import { ServiceModal } from './ServiceModal.jsx';
import { ProductModal } from './ProductModal.jsx';
import { PackageModal } from './PackageModal.jsx';
import { Button } from '../../ui/primitives/Button.jsx';
import { Badge } from '../../ui/primitives/Badge.jsx';
import { EmptyState } from '../../ui/primitives/EmptyState.jsx';
import { Settings, Scissors, PackageOpen, Layers } from 'lucide-react';

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
  const { data: groups, loading: groupsLoading, error: groupsError } = useCachedQuery('service_groups');
  const { data: services, loading: servicesLoading, error: servicesError } = useCachedQuery('services');
  const { data: products, loading: productsLoading, error: productsError } = useCachedQuery('products');
  const { data: packages, loading: packagesLoading, error: packagesError } = useCachedQuery('packages');

  const loading = groupsLoading || servicesLoading || productsLoading || packagesLoading;
  const error = groupsError || servicesError || productsError || packagesError;

  const [modal, setModal] = useState(null);
  const [actionError, setActionError] = useState(null);
  const [confirmingRemove, setConfirmingRemove] = useState(null);

  function groupName(id) {
    return groups.find((group) => group.id === id)?.name ?? '—';
  }

  async function handleRemove(type, id) {
    setActionError(null);
    try {
      await apiClient.delete(`/${REMOVE_PATHS[type]}/${id}`);
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

  if (loading) return null; // Será instantâneo, evitamos piscar a tela

  if (error) {
    return (
      <div className="full-page-error">
        <p>{error}</p>
        <Button onClick={load}>Tentar novamente</Button>
      </div>
    );
  }

  return (
    <div className="catalogo-page">
      <h1>Catálogo</h1>

      <div className="agenda-view-toggle">
        {TABS.map((item) => (
          <Button key={item.key} variant={tab === item.key ? 'primary' : 'ghost'} onClick={() => setTab(item.key)}>
            {item.label}
          </Button>
        ))}
      </div>

      {actionError && <p className="form-error" role="alert">{actionError}</p>}

      {tab === 'servicos' && (
        <section>
          {canWrite && groups.length === 0 && (
            <p className="section-hint">Cadastre um grupo de serviço antes de criar serviços.</p>
          )}
          {canWrite && groups.length > 0 && (
            <Button onClick={() => setModal({ type: 'service', mode: 'create' })}>
              + Novo serviço
            </Button>
          )}
          {services.length === 0 ? (
            <EmptyState
              icon={Scissors}
              title="Nenhum serviço cadastrado"
              description="Cadastre os serviços que o seu estabelecimento oferece."
              actionLabel={canWrite && groups.length > 0 ? "Criar Serviço" : null}
              onAction={canWrite && groups.length > 0 ? () => setModal({ type: 'service', mode: 'create' }) : null}
            />
          ) : (
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
                  {!service.active && <Badge variant="neutral">inativo</Badge>}
                </span>
                {canWrite && (
                  <Button variant="link" onClick={() => setModal({ type: 'service', mode: 'edit', service })}>
                    Editar
                  </Button>
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
          )}
        </section>
      )}

      {tab === 'produtos' && (
        <section>
          {canWrite && (
            <Button onClick={() => setModal({ type: 'product', mode: 'create' })}>
              + Novo produto
            </Button>
          )}
          {products.length === 0 ? (
            <EmptyState
              icon={PackageOpen}
              title="Nenhum produto cadastrado"
              description="Cadastre os produtos para revenda ou uso interno."
              actionLabel={canWrite ? "Criar Produto" : null}
              onAction={canWrite ? () => setModal({ type: 'product', mode: 'create' }) : null}
            />
          ) : (
            <ul className="record-list">
            {products.map((product) => (
              <li key={product.id} className="record-list-item">
                <span className="record-list-main">
                  <strong>{product.name}</strong>
                  <span>
                    {product.sku} · {formatCents(product.price_cents)} · estoque: {product.stock_on_hand}
                  </span>
                  {!product.active && <Badge variant="neutral">inativo</Badge>}
                </span>
                {canWrite && (
                  <Button variant="link" onClick={() => setModal({ type: 'product', mode: 'edit', product })}>
                    Editar
                  </Button>
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
          )}
        </section>
      )}

      {tab === 'pacotes' && (
        <section>
          {canWrite && services.length === 0 && (
            <p className="section-hint">Cadastre serviços antes de montar um pacote.</p>
          )}
          {canWrite && services.length > 0 && (
            <Button onClick={() => setModal({ type: 'package', mode: 'create' })}>
              + Novo pacote
            </Button>
          )}
          {packages.length === 0 ? (
            <EmptyState
              icon={Layers}
              title="Nenhum pacote cadastrado"
              description="Crie combos de serviços por um preço promocional."
              actionLabel={canWrite && services.length > 0 ? "Criar Pacote" : null}
              onAction={canWrite && services.length > 0 ? () => setModal({ type: 'package', mode: 'create' }) : null}
            />
          ) : (
            <ul className="record-list">
            {packages.map((pkg) => (
              <li key={pkg.id} className="record-list-item">
                <span className="record-list-main">
                  <strong>{pkg.name}</strong>
                  <span>{formatCents(pkg.price_cents)}</span>
                  {!pkg.active && <Badge variant="neutral">inativo</Badge>}
                </span>
                {canWrite && (
                  <Button variant="link" onClick={() => openEditPackage(pkg)}>
                    Editar
                  </Button>
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
          )}
        </section>
      )}

      {tab === 'grupos' && (
        <section>
          {canWrite && (
            <Button onClick={() => setModal({ type: 'group', mode: 'create' })}>
              + Novo grupo
            </Button>
          )}
          {groups.length === 0 ? (
            <EmptyState
              icon={Settings}
              title="Nenhum grupo de serviço"
              description="Os grupos organizam seus serviços e podem definir regras de comissão."
              actionLabel={canWrite ? "Criar Grupo" : null}
              onAction={canWrite ? () => setModal({ type: 'group', mode: 'create' }) : null}
            />
          ) : (
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
                  {!group.active && <Badge variant="neutral">inativo</Badge>}
                </span>
                {canWrite && (
                  <Button variant="link" onClick={() => setModal({ type: 'group', mode: 'edit', group })}>
                    Editar
                  </Button>
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
          )}
        </section>
      )}

      {modal?.type === 'group' && (
        <ServiceGroupModal
          mode={modal.mode}
          group={modal.group}
          apiClient={apiClient}
          onClose={() => setModal(null)}
          onSaved={() => {
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
          onSaved={() => {
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
          onSaved={() => {
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
          onSaved={() => {
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
      <Button variant="link" onClick={() => setConfirmingRemove({ type, id })}>
        Remover
      </Button>
    );
  }
  return (
    <>
      <span>Confirma?</span>
      <Button variant="danger" onClick={onRemove}>
        Sim
      </Button>
      <Button variant="link" onClick={() => setConfirmingRemove(null)}>
        Não
      </Button>
    </>
  );
}
