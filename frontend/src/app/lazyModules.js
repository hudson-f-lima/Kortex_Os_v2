import { lazy } from 'react';

// Cada módulo de domínio carrega sob demanda (code-splitting por rota,
// conforme .agents/skills/kortex-pwa-architect/SKILL.md ponto 2) — só o
// shell (App.jsx) e o módulo da rota atual entram no bundle inicial.
export const AgendaPage = lazy(() => import('../modules/agenda/AgendaPage.jsx').then((m) => ({ default: m.AgendaPage })));
export const ComandaPage = lazy(() => import('../modules/comanda/ComandaPage.jsx').then((m) => ({ default: m.ComandaPage })));
export const ClientesPage = lazy(() => import('../modules/clientes/ClientesPage.jsx').then((m) => ({ default: m.ClientesPage })));
export const EquipePage = lazy(() => import('../modules/equipe/EquipePage.jsx').then((m) => ({ default: m.EquipePage })));
export const CatalogoPage = lazy(() => import('../modules/catalogo/CatalogoPage.jsx').then((m) => ({ default: m.CatalogoPage })));
export const EstoquePage = lazy(() => import('../modules/estoque/EstoquePage.jsx').then((m) => ({ default: m.EstoquePage })));
export const CaixaPage = lazy(() => import('../modules/caixa/CaixaPage.jsx').then((m) => ({ default: m.CaixaPage })));
export const OrganizacaoPage = lazy(() => import('../modules/organizacao/OrganizacaoPage.jsx').then((m) => ({ default: m.OrganizacaoPage })));
