import { useRegisterSW } from 'virtual:pwa-register/react';

// Nunca troca de bundle sozinho (skipWaiting silencioso) — indicador
// discreto + ação explícita de recarregar, conforme cache-policy.md e
// docs/PWA_PLANEJAMENTO.md §3.6.
export function UpdateBanner() {
  const { needRefresh: [needRefresh], updateServiceWorker } = useRegisterSW();

  if (!needRefresh) return null;

  return (
    <div className="update-banner" role="status">
      <span>Nova versão disponível.</span>
      <button type="button" onClick={() => updateServiceWorker(true)}>
        Recarregar
      </button>
    </div>
  );
}
