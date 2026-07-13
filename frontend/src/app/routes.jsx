import { lazy } from 'react';
import { createBrowserRouter } from 'react-router-dom';
import { App } from './App.jsx';
import { ProtectedRoute } from './ProtectedRoute.jsx';
import { RequireOrganization } from './RequireOrganization.jsx';
import { RoleGatedRoute } from './RoleGatedRoute.jsx';
import { LoginPage } from '../pages/LoginPage.jsx';
import { CreateOrganizationPage } from '../pages/CreateOrganizationPage.jsx';

// Cada módulo de domínio carrega sob demanda (code-splitting por rota,
// conforme .agents/skills/kortex-pwa-architect/SKILL.md ponto 2) — só o
// shell (App.jsx) e o módulo da rota atual entram no bundle inicial. App.jsx
// envolve o <Outlet/> num <Suspense/> com um fallback simples.
const AgendaPage = lazy(() => import('../modules/agenda/AgendaPage.jsx').then((m) => ({ default: m.AgendaPage })));
const ComandaPage = lazy(() => import('../modules/comanda/ComandaPage.jsx').then((m) => ({ default: m.ComandaPage })));
const ClientesPage = lazy(() => import('../modules/clientes/ClientesPage.jsx').then((m) => ({ default: m.ClientesPage })));
const EquipePage = lazy(() => import('../modules/equipe/EquipePage.jsx').then((m) => ({ default: m.EquipePage })));
const CatalogoPage = lazy(() => import('../modules/catalogo/CatalogoPage.jsx').then((m) => ({ default: m.CatalogoPage })));
const EstoquePage = lazy(() => import('../modules/estoque/EstoquePage.jsx').then((m) => ({ default: m.EstoquePage })));
const CaixaPage = lazy(() => import('../modules/caixa/CaixaPage.jsx').then((m) => ({ default: m.CaixaPage })));
const OrganizacaoPage = lazy(() => import('../modules/organizacao/OrganizacaoPage.jsx').then((m) => ({ default: m.OrganizacaoPage })));

export const router = createBrowserRouter([
  { path: '/login', element: <LoginPage /> },
  {
    element: <ProtectedRoute />,
    children: [
      {
        element: <RequireOrganization />,
        children: [
          { path: '/create-organization', element: <CreateOrganizationPage /> },
          {
            element: <App />,
            children: [
              { index: true, element: <RoleGatedRoute slug="agenda"><AgendaPage /></RoleGatedRoute> },
              { path: '/agenda', element: <RoleGatedRoute slug="agenda"><AgendaPage /></RoleGatedRoute> },
              { path: '/comanda', element: <RoleGatedRoute slug="comanda"><ComandaPage /></RoleGatedRoute> },
              { path: '/clientes', element: <RoleGatedRoute slug="clientes"><ClientesPage /></RoleGatedRoute> },
              { path: '/equipe', element: <RoleGatedRoute slug="equipe"><EquipePage /></RoleGatedRoute> },
              { path: '/catalogo', element: <RoleGatedRoute slug="catalogo"><CatalogoPage /></RoleGatedRoute> },
              { path: '/estoque', element: <RoleGatedRoute slug="estoque"><EstoquePage /></RoleGatedRoute> },
              { path: '/caixa', element: <RoleGatedRoute slug="caixa"><CaixaPage /></RoleGatedRoute> },
              { path: '/organizacao', element: <RoleGatedRoute slug="organizacao"><OrganizacaoPage /></RoleGatedRoute> },
            ],
          },
        ],
      },
    ],
  },
]);
