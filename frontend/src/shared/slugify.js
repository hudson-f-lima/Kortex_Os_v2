// Espelha o CHECK constraint de organizations.slug (lowercase alfanumérico
// separado por hífen simples) — usado tanto no bootstrap (CreateOrganizationPage)
// quanto na criação de uma organização adicional (OrganizacaoPage, Fase 6.5).
export function slugify(name) {
  return name
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(new RegExp('[\\u0300-\\u036f]', 'g'), '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
