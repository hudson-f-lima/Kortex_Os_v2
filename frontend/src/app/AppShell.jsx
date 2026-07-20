import { Suspense } from 'react';
import { Outlet } from 'react-router-dom';
import { useOrganization } from '../shared/useOrganization.js';
import { modulesForRole } from '../shared/nav.js';

import { DesktopSidebar } from './DesktopSidebar.jsx';
import { NavigationRail } from './NavigationRail.jsx';
import { MobileTabBar } from './MobileTabBar.jsx';
import { TopBar } from './TopBar.jsx';
import './AppShell.css';

import { PageSkeleton } from '../ui/primitives/PageSkeleton.jsx';

export function AppShell() {
  const { role } = useOrganization();
  const modules = modulesForRole(role);

  return (
    <div className="k-app-shell">
      <div className="k-app-shell__sidebar">
        <DesktopSidebar modules={modules} />
      </div>
      <div className="k-app-shell__rail">
        <NavigationRail modules={modules} />
      </div>
      
      <div className="k-app-shell__main">
        <div className="k-app-shell__topbar">
          <TopBar />
        </div>
        
        <main className="k-app-shell__content">
          <Suspense fallback={<PageSkeleton />}>
            <Outlet />
          </Suspense>
        </main>
        
        <div className="k-app-shell__bottom-nav">
          <MobileTabBar modules={modules} />
        </div>
      </div>
    </div>
  );
}
