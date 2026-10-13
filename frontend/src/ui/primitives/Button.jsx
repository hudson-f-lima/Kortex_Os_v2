
import './Button.css';

export function Button({
  variant = 'primary',
  size = 'md',
  isLoading = false,
  leftIcon,
  rightIcon,
  children,
  className = '',
  disabled,
  type = 'button',
  ...props
}) {
  const baseClass = 'k-button';
  const variantClass = `k-button--${variant}`;
  const sizeClass = `k-button--${size}`;
  const loadingClass = isLoading ? 'k-button--loading' : '';
  const finalClassName = [baseClass, variantClass, sizeClass, loadingClass, className].filter(Boolean).join(' ');

  return (
    <button
      type={type}
      className={finalClassName}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading && <span className="k-button__spinner" aria-hidden="true" />}
      {!isLoading && leftIcon && <span className="k-button__icon">{leftIcon}</span>}
      <span className="k-button__text">{children}</span>
      {!isLoading && rightIcon && <span className="k-button__icon">{rightIcon}</span>}
    </button>
  );
}
