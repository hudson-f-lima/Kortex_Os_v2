import { useEffect, useId, useRef } from 'react';

// Elementos que um teclado consegue alcançar via Tab — usado tanto para o
// foco inicial quanto para prender o Tab dentro do modal (sem isso, Tab
// escapa para a página por trás, invisível atrás do overlay).
const FOCUSABLE_SELECTOR =
  'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

function getFocusable(container) {
  return container ? Array.from(container.querySelectorAll(FOCUSABLE_SELECTOR)) : [];
}

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
  const titleId = useId();
  const cardRef = useRef(null);

  // Escape fecha; Tab/Shift+Tab ficam presos ao conteúdo do modal (foco não
  // vaza para a página por trás, que segue interativa atrás do overlay).
  useEffect(() => {
    function handleKeyDown(event) {
      if (event.key === 'Escape') {
        onClose();
        return;
      }
      if (event.key !== 'Tab') return;
      const focusable = getFocusable(cardRef.current);
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  // Foco inicial no primeiro campo real do conteúdo (pula o X do header, que
  // é chrome do modal, não o começo da tarefa); ao desmontar, devolve o foco
  // para quem tinha antes de o modal abrir.
  useEffect(() => {
    const previouslyFocused = document.activeElement;
    const focusable = getFocusable(cardRef.current);
    const preferred = focusable.find((el) => !el.classList.contains('modal-close-btn')) ?? focusable[0];
    (preferred ?? cardRef.current)?.focus();
    return () => {
      if (previouslyFocused instanceof HTMLElement) previouslyFocused.focus();
    };
  }, []);

  const sizeClass = size ? `modal-card--${size}` : '';
  const cardClasses = ['modal-card', sizeClass, className].filter(Boolean).join(' ');

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby={title ? titleId : undefined}
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className={cardClasses} ref={cardRef} tabIndex={-1}>
        {title && (
          <div className="modal-header">
            <h3 id={titleId}>{title}</h3>
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
