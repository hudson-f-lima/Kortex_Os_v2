import { PackageOpen } from 'lucide-react';
import { Button } from './Button.jsx';
import './EmptyState.css';

export function EmptyState({ 
  icon: Icon = PackageOpen, 
  title = 'Nenhum registro encontrado', 
  description = 'Não há itens para exibir nesta lista.', 
  actionLabel, 
  onAction 
}) {
  return (
    <div className="k-empty-state">
      <div className="k-empty-state__icon-wrapper">
        <Icon size={48} className="k-empty-state__icon" strokeWidth={1.5} />
      </div>
      <h3 className="k-empty-state__title">{title}</h3>
      <p className="k-empty-state__description">{description}</p>
      
      {actionLabel && onAction && (
        <Button onClick={onAction} className="k-empty-state__action">
          {actionLabel}
        </Button>
      )}
    </div>
  );
}
