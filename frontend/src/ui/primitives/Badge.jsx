
import './Badge.css';

export function Badge({ 
  variant = 'neutral', 
  children, 
  className = '',
  ...props
}) {
  const baseClass = 'k-badge';
  const variantClass = `k-badge--${variant}`;
  const finalClass = [baseClass, variantClass, className].filter(Boolean).join(' ');

  return (
    <span className={finalClass} {...props}>
      {children}
    </span>
  );
}
