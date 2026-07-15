import { Suspense } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../shared/useAuth.js';
import { useOrganization } from '../shared/useOrganization.js';
import { modulesForRole } from '../shared/nav.js';

export function App() {
  const { user, signOut } = useAuth();
  const { organizations, organizationId, role, selectOrganization } = useOrganization();
  const currentOrg = organizations.find((org) => org.id === organizationId);
  const modules = modulesForRole(role);

  return (
    <div className="shell">
      <header className="shell-header">
        <div className="shell-org">
          {organizations.length > 1 ? (
            <select value={organizationId ?? ''} onChange={(event) => selectOrganization(event.target.value)}>
              {organizations.map((org) => (
                <option key={org.id} value={org.id}>
                  {org.name}
                </option>
              ))}
            </select>
          ) : (
            <span>{currentOrg?.name}</span>
          )}
        </div>
        <div className="shell-user">
          <span>{user?.email}</span>
          <button type="button" onClick={signOut}>
            Sair
          </button>
        </div>
      </header>

      <nav className="shell-nav">
        {modules.map((module) => (
          <NavLink key={module.slug} to={module.path} className={({ isActive }) => (isActive ? 'active' : '')}>
            {module.label}
          </NavLink>
        ))}
      </nav>

      <main className="shell-content">
        <Suspense fallback={<p>Carregando módulo…</p>}>
          <Outlet />
        </Suspense>
      </main>
    </div>
  );
}
