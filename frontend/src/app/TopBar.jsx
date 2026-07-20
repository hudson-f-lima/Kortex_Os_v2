
import { LogOut } from 'lucide-react';
import { useAuth } from '../shared/useAuth.js';
import { useOrganization } from '../shared/useOrganization.js';
import { Button } from '../ui/primitives/Button.jsx';
import { NetworkStatus } from '../shared/NetworkStatus.jsx';
import { UpdateBanner } from '../shared/UpdateBanner.jsx';
import './TopBar.css';

export function TopBar() {
  const { user, signOut } = useAuth();
  const { organizations, organizationId, selectOrganization } = useOrganization();
  const currentOrg = organizations.find((org) => org.id === organizationId);

  return (
    <header className="k-topbar">
      <div className="k-topbar__left">
        <NetworkStatus />
        <UpdateBanner />
      </div>

      <div className="k-topbar__right">
        {organizations.length > 1 ? (
          <select 
            className="k-topbar__org-select text-body"
            value={organizationId ?? ''} 
            onChange={(event) => selectOrganization(event.target.value)}
          >
            {organizations.map((org) => (
              <option key={org.id} value={org.id}>
                {org.name}
              </option>
            ))}
          </select>
        ) : (
          <span className="text-body k-topbar__org-name">{currentOrg?.name}</span>
        )}

        <div className="k-topbar__user">
          <span className="text-supporting k-topbar__email">{user?.email}</span>
          <Button variant="ghost" size="sm" onClick={signOut} title="Sair">
            <LogOut size={18} />
          </Button>
        </div>
      </div>
    </header>
  );
}
