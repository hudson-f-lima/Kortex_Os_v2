import { X } from 'lucide-react';
import { Button } from './Button.jsx';
import './Toast.css';

export function Toast({ id, title, description, variant = 'default', onClose }) {
  return (
    <div className={`k-toast k-toast--${variant}`} role="alert">
      <div className="k-toast__content">
        {title && <strong className="k-toast__title">{title}</strong>}
        {description && <span className="k-toast__description">{description}</span>}
      </div>
      <Button variant="ghost" size="sm" onClick={() => onClose(id)} className="k-toast__close">
        <X size={16} />
      </Button>
    </div>
  );
}
