// Composição de navegação por papel (docs/PWA_PLANEJAMENTO.md §4.1/§4.2):
// recepção/owner/admin veem o conjunto completo; manager idem sem
// organização; professional vê só o recorte próprio (agenda + comanda).
export const MODULES = [
  { slug: 'agenda', label: 'Agenda', path: '/agenda' },
  { slug: 'comanda', label: 'Comanda', path: '/comanda' },
  { slug: 'clientes', label: 'Clientes', path: '/clientes' },
  { slug: 'equipe', label: 'Equipe', path: '/equipe' },
  { slug: 'catalogo', label: 'Catálogo', path: '/catalogo' },
  { slug: 'estoque', label: 'Estoque', path: '/estoque' },
  { slug: 'caixa', label: 'Caixa', path: '/caixa' },
  { slug: 'organizacao', label: 'Organização', path: '/organizacao' },
];

const ROLE_MODULES = {
  owner: ['agenda', 'comanda', 'clientes', 'equipe', 'catalogo', 'estoque', 'caixa', 'organizacao'],
  admin: ['agenda', 'comanda', 'clientes', 'equipe', 'catalogo', 'estoque', 'caixa', 'organizacao'],
  manager: ['agenda', 'comanda', 'clientes', 'equipe', 'catalogo', 'estoque', 'caixa'],
  reception: ['agenda', 'comanda', 'clientes', 'catalogo', 'estoque', 'caixa'],
  professional: ['agenda', 'comanda'],
};

export function modulesForRole(role) {
  const slugs = ROLE_MODULES[role] ?? [];
  return MODULES.filter((module) => slugs.includes(module.slug));
}
