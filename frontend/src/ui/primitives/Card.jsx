
import './Card.css';

export function Card({ 
  variant = 'default', 
  children, 
  className = '', 
  onClick,
  ...props 
}) {
  const isInteractive = onClick || variant === 'interactive';
  const baseClass = 'k-card';
  const variantClass = `k-card--${variant}`;
  const interactiveClass = isInteractive ? 'k-card--interactive' : '';
  const finalClass = [baseClass, variantClass, interactiveClass, className].filter(Boolean).join(' ');

  return (
    <div 
      className={finalClass} 
      onClick={onClick}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      {...props}
    >
      {children}
    </div>
  );
}
