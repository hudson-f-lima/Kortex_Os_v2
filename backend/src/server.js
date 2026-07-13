import { loadEnv } from './config/env.js';
import { createSupabaseAdmin } from './shared/supabaseAdmin.js';
import { createApp } from './app.js';
import { logger } from './shared/logger.js';

const env = loadEnv();
const supabaseAdmin = createSupabaseAdmin(env);
const app = createApp(env, supabaseAdmin);

app.listen(env.port, () => {
  logger.info('server_started', { port: env.port, nodeEnv: env.nodeEnv });
});
