import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { RouterProvider } from 'react-router-dom';
import { AuthProvider } from './shared/AuthContext.jsx';
import { OrganizationProvider } from './shared/OrganizationContext.jsx';
import { UpdateBanner } from './shared/UpdateBanner.jsx';
import { router } from './app/routes.jsx';
import './styles.css';

// UpdateBanner (registro do service worker) fica no topo, fora de qualquer
// gate de autenticação/organização — precisa registrar e cachear o shell
// desde a primeira visita (mesmo na tela de login), não só após entrar.
createRoot(document.getElementById('root')).render(
  <StrictMode>
    <UpdateBanner />
    <AuthProvider>
      <OrganizationProvider>
        <RouterProvider router={router} />
      </OrganizationProvider>
    </AuthProvider>
  </StrictMode>,
);
