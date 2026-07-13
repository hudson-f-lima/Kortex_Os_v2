import { ApiError } from '../../shared/apiClient.js';

// inventory_adjust devolve mensagens em inglês já seguras para exibir (ver
// backend/src/shared/rpcError.js) — mesmo padrão de comandaErrors.js:
// mapeamos por substring as mais prováveis no dia a dia, o resto cai no
// texto original.
const MESSAGE_PATTERNS = [
  ['insufficient stock', 'Esse ajuste deixaria o estoque negativo.'],
  ['active product not found', 'Este produto não está mais disponível. Atualize a página e tente novamente.'],
  ['idempotency key reused with different payload', 'Esta tentativa expirou. Feche e abra o ajuste novamente.'],
  ['insufficient organization permission', 'Seu papel não tem permissão para ajustar estoque.'],
];

export function messageForInventoryError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    const match = MESSAGE_PATTERNS.find(([pattern]) => err.message?.toLowerCase().includes(pattern));
    return match ? match[1] : err.message;
  }
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}
