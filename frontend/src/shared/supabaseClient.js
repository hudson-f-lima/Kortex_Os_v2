import { createClient } from '@supabase/supabase-js';

// Só Auth (login/sessão) — todo domínio de negócio passa pela API Express
// (AGENTS.md: "PWA não recebe service_role e não escreve diretamente
// verdade financeira"; nenhuma tabela é consultada por este cliente).
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
);
