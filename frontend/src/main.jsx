import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { RouterProvider } from 'react-router-dom';
import { AuthProvider } from './shared/AuthContext.jsx';
import { OrganizationProvider } from './shared/OrganizationContext.jsx';
import { ToastProvider } from './shared/ToastContext.jsx';
import { onLCP, onINP } from 'web-vitals';
import { AcceptInvitePage } from './pages/AcceptInvitePage.jsx';
import { router } from './app/routes.jsx';
import './ui/foundations/reset.css';
import './ui/foundations/tokens.css';
import './ui/foundations/typography.css';
import './ui/foundations/motion.css';
import './ui/foundations/utilities.css';
import './styles.css';

// Convite por e-mail (Fase 11 / ADR 0014) redireciona para a RAIZ do site
// com `#access_token=...&type=invite` no fragmento — checado aqui, síncrono,
// antes que o AuthClient (supabaseClient.js, detectSessionInUrl: true)
// consuma o hash. Não é uma rota do react-router (evitaria o mesmo 404 de
// GitHub Pages em rota aninhada que essa escolha de redirectTo já contorna).
const isInviteCallback = window.location.hash.includes('type=invite');

// Monitoramento de Performance (Onda 5)
// Reporta as métricas Core Web Vitals (LCP e INP) no console
if (import.meta.env.DEV) {
  onLCP(console.log);
  onINP(console.log);
}
createRoot(document.getElementById('root')).render(
  <StrictMode>
    {isInviteCallback ? (
      <AcceptInvitePage />
    ) : (
      <AuthProvider>
        <OrganizationProvider>
          <ToastProvider>
            <RouterProvider router={router} />
          </ToastProvider>
        </OrganizationProvider>
      </AuthProvider>
    )}
  </StrictMode>,
);
