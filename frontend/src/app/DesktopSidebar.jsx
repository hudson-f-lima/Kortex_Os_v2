
import { NavLink } from 'react-router-dom';
import { ModuleIcons } from '../shared/icons.js';
import { PWAInstaller } from '../shared/PWAInstaller.jsx';
import './DesktopSidebar.css';

export function DesktopSidebar({ modules }) {
  return (
    <aside className="k-sidebar">
      <div className="k-sidebar__header">
        <h1 className="text-section-title">KortexOS</h1>
      </div>
      <nav className="k-sidebar__nav">
        {modules.map((module) => {
          const Icon = ModuleIcons[module.slug];
          return (
            <NavLink 
              key={module.slug} 
              to={module.path} 
              className={({ isActive }) => `k-sidebar__link ${isActive ? 'k-sidebar__link--active' : ''}`}
            >
              {Icon && <Icon size={20} className="k-sidebar__icon" />}
              <span className="text-body">{module.label}</span>
            </NavLink>
          );
        })}
      </nav>
      <div style={{ marginTop: 'auto', padding: '16px' }}>
        <PWAInstaller variant="outline" className="w-full" />
      </div>
    </aside>
  );
}
