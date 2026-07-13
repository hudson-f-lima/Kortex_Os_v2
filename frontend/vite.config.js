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
        // Navegação/HTML: network-first com fallback de shell seguro.
        // API autenticada e mutações: network-only, nunca cacheado/enfileirado
        // (docs/.agents/skills/kortex-pwa-architect/references/cache-policy.md).
        navigateFallback: null,
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
