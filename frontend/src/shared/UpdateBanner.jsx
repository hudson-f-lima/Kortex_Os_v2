import { useRegisterSW } from 'virtual:pwa-register/react';
import { Button } from '../ui/primitives/Button.jsx';
import { RefreshCw } from 'lucide-react';
import { Badge } from '../ui/primitives/Badge.jsx';

// Nunca troca de bundle sozinho (skipWaiting silencioso) — indicador
// discreto + ação explícita de recarregar, conforme cache-policy.md e
// docs/PWA_PLANEJAMENTO.md §3.6.
export function UpdateBanner() {
  const { needRefresh: [needRefresh], updateServiceWorker } = useRegisterSW();

  if (!needRefresh) return null;

  return (
    <Badge variant="warning" title="Nova versão do KortexOS disponível">
      <span>Atualização disponível</span>
      <Button variant="link" size="sm" onClick={() => updateServiceWorker(true)} style={{ padding: 0, marginLeft: '8px' }}>
        <RefreshCw size={14} style={{ marginRight: '4px' }} />
        Atualizar
      </Button>
    </Badge>
  );
}
