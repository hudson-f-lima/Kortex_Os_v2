import { useState, useEffect } from 'react';
import { WifiOff } from 'lucide-react';
import { Badge } from '../ui/primitives/Badge.jsx';

export function NetworkStatus() {
  const [isOffline, setIsOffline] = useState(!navigator.onLine);

  useEffect(() => {
    function handleOnline() {
      setIsOffline(false);
    }
    
    function handleOffline() {
      setIsOffline(true);
    }

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  if (!isOffline) return null;

  return (
    <Badge variant="danger" title="Você está offline. Verifique sua conexão.">
      <WifiOff size={14} style={{ marginRight: '4px' }} />
      Offline
    </Badge>
  );
}
