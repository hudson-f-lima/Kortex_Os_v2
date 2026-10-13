import { useEffect } from 'react';

/**
 * Shared Adaptive Modal Shell (Kortex Design System).
 * Supports sizes: 'sm' (400px), 'md' (540px), 'lg' (720px), 'xl' (900px).
 * Transforms into a responsive Bottom-Sheet on mobile viewports (< 640px).
 *
 * @param {Object} props
 * @param {Function} props.onClose - Callback on close request (Escape, overlay click, close X)
 * @param {string} [props.title] - Optional header title
 * @param {'sm'|'md'|'lg'|'xl'} [props.size='md'] - Adaptive modal width
 * @param {string} [props.className] - Additional CSS class names
 * @param {React.ReactNode} props.children - Modal content
 */
export function Modal({ onClose, title, size = 'md', children, className }) {
  useEffect(() => {
    function handleKeyDown(event) {
      if (event.key === 'Escape') onClose();
    }
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const sizeClass = size ? `modal-card--${size}` : '';
  const cardClasses = ['modal-card', sizeClass, className].filter(Boolean).join(' ');

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className={cardClasses}>
        {title && (
          <div className="modal-header">
            <h3>{title}</h3>
            <button
              type="button"
              className="modal-close-btn"
              onClick={onClose}
              aria-label="Fechar modal"
            >
              ✕
            </button>
          </div>
        )}
        {children}
      </div>
    </div>
  );
}
