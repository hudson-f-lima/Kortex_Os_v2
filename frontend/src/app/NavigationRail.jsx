
import { NavLink } from 'react-router-dom';
import { ModuleIcons } from '../shared/icons.js';
import './NavigationRail.css';

export function NavigationRail({ modules }) {
  return (
    <aside className="k-rail">
      <div className="k-rail__header">
        <span className="text-section-title" style={{ fontSize: '1rem' }}>K</span>
      </div>
      <nav className="k-rail__nav">
        {modules.map((module) => {
          const Icon = ModuleIcons[module.slug];
          return (
            <NavLink 
              key={module.slug} 
              to={module.path} 
              className={({ isActive }) => `k-rail__link ${isActive ? 'k-rail__link--active' : ''}`}
              title={module.label}
            >
              {Icon && <Icon size={24} className="k-rail__icon" />}
              <span className="text-metadata">{module.label}</span>
            </NavLink>
          );
        })}
      </nav>
    </aside>
  );
}
