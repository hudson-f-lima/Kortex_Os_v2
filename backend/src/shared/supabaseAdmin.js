import { createClient } from '@supabase/supabase-js';

export function createSupabaseAdmin(env) {
  return createClient(env.supabaseUrl, env.supabaseServiceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
