const LISTENERS = new Set();

// ADR 0015 (Blue Team #4): apiClient.js é um módulo simples, sem acesso ao
// AuthContext — este pub/sub é o canal para avisar "a sessão expirou" sem
// acoplar o cliente HTTP ao React. AuthContext assina isso e força signOut,
// o que já cascateia para a limpeza de IndexedDB existente (Blue Team #3).
export function notifySessionExpired() {
  LISTENERS.forEach((callback) => {
    try {
      callback();
    } catch (e) {
      console.error('Error in session-expired listener', e);
    }
  });
}

export function onSessionExpired(callback) {
  LISTENERS.add(callback);
  return () => LISTENERS.delete(callback);
}
