const REQUIRED_VARS = [
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'SUPABASE_JWKS_URL',
  'CORS_ORIGINS',
  'SITE_URL',
];

export function loadEnv(source = process.env) {
  const missing = REQUIRED_VARS.filter((key) => !source[key] || source[key].trim() === '');
  if (missing.length > 0) {
    throw new Error(`missing required environment variables: ${missing.join(', ')}`);
  }

  const port = Number.parseInt(source.PORT ?? '3000', 10);
  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('PORT must be a positive integer');
  }

  const corsOrigins = source.CORS_ORIGINS.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (corsOrigins.length === 0) {
    throw new Error('CORS_ORIGINS must list at least one exact origin');
  }

  return {
    nodeEnv: source.NODE_ENV ?? 'development',
    port,
    logLevel: source.LOG_LEVEL ?? 'info',
    supabaseUrl: source.SUPABASE_URL,
    supabaseServiceRoleKey: source.SUPABASE_SERVICE_ROLE_KEY,
    supabaseJwksUrl: source.SUPABASE_JWKS_URL,
    corsOrigins,
    // Base pública do PWA (inclui o base path do GitHub Pages, ex.:
    // https://host/Kortex_Os_v2/) — usada como redirectTo do convite por
    // e-mail (auth.admin.inviteUserByEmail). Aponta para a raiz do app, não
    // para uma rota aninhada: GitHub Pages não faz rewrite server-side de
    // SPA, então qualquer rota aninhada 404 em acesso direto (ADR 0014,
    // "Blind Spot"); a raiz é sempre servida como index.html.
    siteUrl: source.SITE_URL,
  };
}
