import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

// Lê o .env/.env.example da raiz do repo (já populado com VITE_API_BASE_URL,
// VITE_SUPABASE_URL, VITE_SUPABASE_PUBLISHABLE_KEY) em vez de duplicar um
// segundo arquivo em frontend/. Seguro: o Vite só expõe ao bundle do
// cliente variáveis prefixadas VITE_ — os segredos do backend no mesmo
// arquivo (SUPABASE_SERVICE_ROLE_KEY etc.) nunca entram no build.
export default defineConfig({
  envDir: '..',
  plugins: [
    react(),
    VitePWA({
      registerType: 'prompt',
      injectRegister: null,
      manifest: {
        name: 'KortexOS',
        short_name: 'KortexOS',
        description: 'ERP vertical para beleza e bem-estar',
        theme_color: '#141414',
        background_color: '#141414',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: 'icon.svg', sizes: 'any', type: 'image/svg+xml' },
          { src: 'maskable-icon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'maskable' },
        ],
      },
      workbox: {
        // Classes de cache (docs/.agents/skills/kortex-pwa-architect/references/cache-policy.md):
        // - HTML/app shell: network-first, com fallback ao shell precacheado
        //   quando a rede falha (offline ou navegação direta a uma rota da
        //   SPA) — `navigateFallback` era `null` até a Fase 6.6 (bug: o
        //   comentário já afirmava "com fallback", mas nenhum existia,
        //   então uma recarga offline em qualquer rota falhava por inteiro).
        // - JS/CSS com hash: cache-first — já coberto pelo precache do
        //   `generateSW` (globPatterns), sem precisar de regra própria.
        // - ícones próprios: idem, precacheados (mais forte que
        //   stale-while-revalidate, adequado a asset versionado por build).
        //   Não há fontes/imagens carregadas em runtime nesta fase para
        //   justificar uma regra de stale-while-revalidate ainda.
        // - API autenticada e mutações: network-only, nunca
        //   cacheado/enfileirado (checkout/estoque/caixa exigem
        //   Idempotency-Key para retry seguro, não fila offline).
        cleanupOutdatedCaches: true,
        navigateFallback: 'index.html',
        navigateFallbackDenylist: [/^\/api\//],
        runtimeCaching: [
          {
            urlPattern: ({ request }) => request.mode === 'navigate',
            handler: 'NetworkFirst',
            options: { cacheName: 'html-shell' },
          },
          {
            urlPattern: ({ url }) => url.pathname.startsWith('/api/'),
            handler: 'NetworkOnly',
          },
        ],
      },
    }),
  ],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/setupTests.js'],
    globals: true,
  },
});
