import { AuthClient } from '@supabase/auth-js';

// Só Auth (login/sessão) — todo domínio de negócio passa pela API Express
// (AGENTS.md: "PWA não recebe service_role e não escreve diretamente
// verdade financeira"; nenhuma tabela é consultada por este cliente).
//
// @supabase/auth-js é usado diretamente em vez do @supabase/supabase-js
// completo (Fase 6.6, orçamento de performance do PWA_PLANEJAMENTO.md §7):
// o cliente completo embute PostgREST/Realtime/Storage/Functions, código
// morto aqui já que nenhuma tabela é consultada por ele. `storageKey`
// replica exatamente o default que o supabase-js computava
// (`sb-<host>-auth-token`) para não invalidar sessões já persistidas no
// navegador de quem já estava logado antes da troca.
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_PUBLISHABLE_KEY = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
const storageKey = `sb-${new URL(SUPABASE_URL).hostname.split('.')[0]}-auth-token`;

const authClient = new AuthClient({
  url: `${SUPABASE_URL}/auth/v1`,
  headers: { Authorization: `Bearer ${SUPABASE_PUBLISHABLE_KEY}`, apikey: SUPABASE_PUBLISHABLE_KEY },
  storageKey,
  autoRefreshToken: true,
  persistSession: true,
  detectSessionInUrl: true,
  flowType: 'implicit',
});

// Mantém o formato `supabase.auth.*` que AuthContext.jsx já usa, sem exigir
// nenhuma mudança lá.
export const supabase = { auth: authClient };
