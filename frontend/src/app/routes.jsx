import { createBrowserRouter } from 'react-router-dom';
import { App } from './App.jsx';
import { ProtectedRoute } from './ProtectedRoute.jsx';
import { RequireOrganization } from './RequireOrganization.jsx';
import { RoleGatedRoute } from './RoleGatedRoute.jsx';
import { LoginPage } from '../pages/LoginPage.jsx';
import { CreateOrganizationPage } from '../pages/CreateOrganizationPage.jsx';
import {
  AgendaPage,
  ComandaPage,
  ClientesPage,
  EquipePage,
  CatalogoPage,
  EstoquePage,
  CaixaPage,
  OrganizacaoPage,
} from './lazyModules.js';

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
], {
  basename: import.meta.env.BASE_URL
});
