import { useState } from 'react';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { OrganizationModal } from './OrganizationModal.jsx';
import { Button } from '../../ui/primitives/Button.jsx';
import { Badge } from '../../ui/primitives/Badge.jsx';

// nav.js só mostra este módulo para owner/admin — RoleGatedRoute já cobre o
// caso de acesso indevido por URL, então esta página não repete a checagem.
export function OrganizacaoPage() {
  const { organizations, organizationId, role, selectOrganization, refresh } = useOrganization();
  const apiClient = useApiClient();
  const [showCreateModal, setShowCreateModal] = useState(false);

  const currentOrg = organizations.find((org) => org.id === organizationId);

  async function handleCreated(organization) {
    await refresh();
    selectOrganization(organization.id);
    setShowCreateModal(false);
  }

  return (
    <div className="organizacao-page">
      <h1>Organização</h1>

      <section>
        <h2>Organização atual</h2>
        {currentOrg ? (
          <ul className="record-list">
            <li className="record-list-item">
              <span className="record-list-main">
                <strong>{currentOrg.name}</strong>
                <span>
                  {currentOrg.slug} · seu papel: {role}
                </span>
              </span>
            </li>
          </ul>
        ) : (
          <p className="list-empty">Nenhuma organização selecionada.</p>
        )}
      </section>

      <section>
        <div className="list-toolbar">
          <h2>Suas organizações</h2>
          <Button onClick={() => setShowCreateModal(true)}>
            + Nova organização
          </Button>
        </div>
        <ul className="record-list">
          {organizations.map((org) => (
            <li key={org.id} className="record-list-item">
              <span className="record-list-main">
                <strong>{org.name}</strong>
                <span>
                  {org.slug} · papel: {org.role}
                </span>
              </span>
              {org.id === organizationId ? (
                <Badge variant="neutral">organização atual</Badge>
              ) : (
                <Button variant="link" onClick={() => selectOrganization(org.id)}>
                  Trocar para esta
                </Button>
              )}
            </li>
          ))}
        </ul>
      </section>

      <section>
        <h2>Convidar membro</h2>
        <p className="section-hint">
          Ainda não existe convite por e-mail no backend. Peça para a pessoa criar uma conta e compartilhar o
          identificador de usuário com o owner — o papel dela pode então ser definido no módulo Equipe.
        </p>
      </section>

      {showCreateModal && (
        <OrganizationModal apiClient={apiClient} onClose={() => setShowCreateModal(false)} onCreated={handleCreated} />
      )}
    </div>
  );
}
