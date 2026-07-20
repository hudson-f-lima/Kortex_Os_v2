import { useState } from 'react';
import { NavLink } from 'react-router-dom';
import { ModuleIcons } from '../shared/icons.js';
import { Menu } from 'lucide-react';
import { PWAInstaller } from '../shared/PWAInstaller.jsx';
import './MobileTabBar.css';

export function MobileTabBar({ modules }) {
  const [isMoreOpen, setIsMoreOpen] = useState(false);
  const visibleModules = modules.slice(0, 4);
  const hiddenModules = modules.slice(4);

  return (
    <>
      <nav className="k-tabbar">
        {visibleModules.map((module) => {
          const Icon = ModuleIcons[module.slug];
          return (
            <NavLink 
              key={module.slug} 
              to={module.path} 
              className={({ isActive }) => `k-tabbar__link ${isActive ? 'k-tabbar__link--active' : ''}`}
            >
              {Icon && <Icon size={24} />}
              <span>{module.label}</span>
            </NavLink>
          );
        })}
        {hiddenModules.length > 0 && (
          <button 
            type="button" 
            className={`k-tabbar__link ${isMoreOpen ? 'k-tabbar__link--active' : ''}`}
            onClick={() => setIsMoreOpen(!isMoreOpen)}
          >
            <Menu size={24} />
            <span>Mais</span>
          </button>
        )}
      </nav>

      {isMoreOpen && hiddenModules.length > 0 && (
        <div className="k-tabbar__more-menu">
          {hiddenModules.map((module) => {
            const Icon = ModuleIcons[module.slug];
            return (
              <NavLink 
                key={module.slug} 
                to={module.path} 
                className="k-tabbar__more-item"
                onClick={() => setIsMoreOpen(false)}
              >
                {Icon && <Icon size={20} />}
                <span>{module.label}</span>
              </NavLink>
            );
          })}
          <div className="k-tabbar__more-item" style={{ justifyContent: 'center', marginTop: '8px' }}>
            <PWAInstaller variant="outline" className="w-full" />
          </div>
        </div>
      )}
    </>
  );
}
