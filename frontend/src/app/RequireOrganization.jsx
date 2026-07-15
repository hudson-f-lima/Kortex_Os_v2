import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useOrganization } from '../shared/useOrganization.js';

// Estados explícitos exigidos pela skill kortex-pwa-architect: loading,
// vazio (sem organização ainda) e erro recuperável.
export function RequireOrganization() {
  const { loading, error, organizationId, organizations, selectOrganization, refresh } = useOrganization();
  const location = useLocation();

  if (loading) return <div className="full-page-loading">Carregando organizações…</div>;

  if (error) {
    return (
      <div className="full-page-error">
        <p>Não foi possível carregar suas organizações.</p>
        <button type="button" onClick={refresh}>
          Tentar novamente
        </button>
      </div>
    );
  }

  if (organizations.length === 0 && location.pathname !== '/create-organization') {
    return <Navigate to="/create-organization" replace />;
  }

  if (organizationId && location.pathname === '/create-organization') {
    return <Navigate to="/agenda" replace />;
  }

  if (!organizationId && organizations.length > 0) {
    return (
      <div className="auth-screen">
        <div className="auth-form">
          <h1>Escolha uma organização</h1>
          {organizations.map((org) => (
            <button key={org.id} type="button" onClick={() => selectOrganization(org.id)}>
              {org.name}
            </button>
          ))}
        </div>
      </div>
    );
  }

  return <Outlet />;
}
