import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { RouterProvider } from 'react-router-dom';
import { AuthProvider } from './shared/AuthContext.jsx';
import { OrganizationProvider } from './shared/OrganizationContext.jsx';
import { UpdateBanner } from './shared/UpdateBanner.jsx';
import { AcceptInvitePage } from './pages/AcceptInvitePage.jsx';
import { router } from './app/routes.jsx';
import './styles.css';

// Convite por e-mail (Fase 11 / ADR 0014) redireciona para a RAIZ do site
// com `#access_token=...&type=invite` no fragmento — checado aqui, síncrono,
// antes que o AuthClient (supabaseClient.js, detectSessionInUrl: true)
// consuma o hash. Não é uma rota do react-router (evitaria o mesmo 404 de
// GitHub Pages em rota aninhada que essa escolha de redirectTo já contorna).
const isInviteCallback = window.location.hash.includes('type=invite');

// UpdateBanner (registro do service worker) fica no topo, fora de qualquer
// gate de autenticação/organização — precisa registrar e cachear o shell
// desde a primeira visita (mesmo na tela de login), não só após entrar.
createRoot(document.getElementById('root')).render(
  <StrictMode>
    <UpdateBanner />
    {isInviteCallback ? (
      <AcceptInvitePage />
    ) : (
      <AuthProvider>
        <OrganizationProvider>
          <RouterProvider router={router} />
        </OrganizationProvider>
      </AuthProvider>
    )}
  </StrictMode>,
);
