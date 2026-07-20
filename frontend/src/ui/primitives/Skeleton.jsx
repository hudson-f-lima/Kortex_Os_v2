
import './Skeleton.css';

export function Skeleton({ 
  className = '', 
  width, 
  height, 
  variant = 'text',
  ...props 
}) {
  const baseClass = 'k-skeleton';
  const variantClass = `k-skeleton--${variant}`;
  const finalClass = [baseClass, variantClass, className].filter(Boolean).join(' ');

  return (
    <div 
      className={finalClass} 
      style={{ width, height, ...props.style }}
      aria-hidden="true"
      {...props}
    />
  );
}
