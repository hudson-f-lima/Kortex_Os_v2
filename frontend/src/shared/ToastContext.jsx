import { createContext, useContext, useState, useCallback, useMemo } from 'react';
import { Toast } from '../ui/primitives/Toast.jsx';

const ToastContext = createContext(null);

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);

  const removeToast = useCallback((id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const addToast = useCallback((toast) => {
    const id = Date.now().toString();
    setToasts((prev) => [...prev, { id, ...toast }]);

    if (toast.duration !== Infinity) {
      setTimeout(() => {
        removeToast(id);
      }, toast.duration || 5000);
    }
  }, [removeToast]);

  const success = useCallback((description, title = 'Sucesso') => {
    addToast({ title, description, variant: 'success' });
  }, [addToast]);

  const error = useCallback((description, title = 'Erro') => {
    addToast({ title, description, variant: 'danger' });
  }, [addToast]);

  const info = useCallback((description, title = 'Informação') => {
    addToast({ title, description, variant: 'default' });
  }, [addToast]);

  const value = useMemo(
    () => ({ addToast, success, error, info }),
    [addToast, success, error, info],
  );

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div 
        style={{
          position: 'fixed',
          top: '24px',
          right: '24px',
          display: 'flex',
          flexDirection: 'column',
          gap: '8px',
          zIndex: 9999,
          pointerEvents: 'none' // lets clicks pass through the container
        }}
      >
        {toasts.map((toast) => (
          <Toast key={toast.id} {...toast} onClose={removeToast} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error('useToast must be used within a ToastProvider');
  }
  return context;
}
