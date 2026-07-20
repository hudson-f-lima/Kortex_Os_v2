import { X, Sparkles, Bell, Clock, AlertTriangle } from 'lucide-react';
import './SmartStrip.css';
import { useState } from 'react';

// Tipos: 'insight' (IA), 'alert' (Atrasos), 'info' (Espaço livre), 'conflict' (Conflito)
export function SmartStrip({ message, type = 'insight', actionLabel, onAction, onClose }) {
  const [isVisible, setIsVisible] = useState(true);

  if (!isVisible || !message) return null;

  const handleClose = () => {
    setIsVisible(false);
    if (onClose) onClose();
  };

  const getIcon = () => {
    switch (type) {
      case 'insight': return <Sparkles size={18} className="k-smartstrip__icon k-smartstrip__icon--ai" />;
      case 'alert': return <Clock size={18} className="k-smartstrip__icon k-smartstrip__icon--warning" />;
      case 'conflict': return <AlertTriangle size={18} className="k-smartstrip__icon k-smartstrip__icon--danger" />;
      default: return <Bell size={18} className="k-smartstrip__icon k-smartstrip__icon--info" />;
    }
  };

  return (
    <div className={`k-smartstrip k-smartstrip--${type}`}>
      <div className="k-smartstrip__content">
        {getIcon()}
        <span className="text-body k-smartstrip__message">{message}</span>
      </div>
      <div className="k-smartstrip__actions">
        {actionLabel && onAction && (
          <button type="button" className="k-smartstrip__action-btn" onClick={onAction}>
            {actionLabel}
          </button>
        )}
        <button type="button" className="k-smartstrip__close-btn" onClick={handleClose} aria-label="Fechar aviso">
          <X size={18} />
        </button>
      </div>
    </div>
  );
}
