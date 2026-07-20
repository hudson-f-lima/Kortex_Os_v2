
import './Skeleton.css';

export function Skeleton({
  className = '',
  width,
  height,
  borderRadius,
  variant = 'text',
  style,
  ...props
}) {
  const baseClass = 'k-skeleton';
  const variantClass = `k-skeleton--${variant}`;
  const finalClass = [baseClass, variantClass, className].filter(Boolean).join(' ');

  return (
    <div
      className={finalClass}
      style={{ width, height, borderRadius, ...style }}
      aria-hidden="true"
      {...props}
    />
  );
}
