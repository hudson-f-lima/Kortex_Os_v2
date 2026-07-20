import { useState, useEffect } from 'react';
import { Download } from 'lucide-react';
import { Button } from '../ui/primitives/Button.jsx';

export function PWAInstaller({ variant = 'default', className = '' }) {
  const [deferredPrompt, setDeferredPrompt] = useState(null);
  const [isInstallable, setIsInstallable] = useState(false);

  useEffect(() => {
    function handleBeforeInstallPrompt(e) {
      // Prevent the mini-infobar from appearing on mobile
      e.preventDefault();
      // Stash the event so it can be triggered later.
      setDeferredPrompt(e);
      // Update UI notify the user they can install the PWA
      setIsInstallable(true);
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    };
  }, []);

  async function handleInstallClick() {
    if (!deferredPrompt) return;
    
    // Show the install prompt
    deferredPrompt.prompt();
    
    // Wait for the user to respond to the prompt
    const { outcome } = await deferredPrompt.userChoice;
    
    // Optionally, send analytics event with outcome of user choice
    if (outcome === 'accepted') {
      console.log('User accepted the A2HS prompt');
      setIsInstallable(false); // Hide the install button once accepted
    } else {
      console.log('User dismissed the A2HS prompt');
    }
    
    // We've used the prompt, and can't use it again, throw it away
    setDeferredPrompt(null);
  }

  if (!isInstallable) return null;

  return (
    <Button 
      variant={variant} 
      onClick={handleInstallClick} 
      className={className} 
      title="Instalar App"
    >
      <Download size={18} style={{ marginRight: variant !== 'icon' ? '8px' : '0' }} />
      {variant !== 'icon' && 'Instalar App'}
    </Button>
  );
}
