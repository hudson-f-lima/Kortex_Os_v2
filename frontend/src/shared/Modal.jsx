import { useEffect } from 'react';

// Casca compartilhada de modal (antes duplicada à mão em 13 arquivos):
// fecha com Esc e com clique fora do card, além do botão de fechar próprio
// de cada formulário. `onClose` deve ser um no-op enquanto o modal estiver
// em meio a um submit, se perder o trabalho em andamento não for aceitável
// para aquele formulário específico — decisão de cada chamador, não deste
// componente.
export function Modal({ onClose, children, className }) {
  useEffect(() => {
    function handleKeyDown(event) {
      if (event.key === 'Escape') onClose();
    }
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div className={className ? `modal-card ${className}` : 'modal-card'}>{children}</div>
    </div>
  );
}
