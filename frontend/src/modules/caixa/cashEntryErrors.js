import { ApiError } from '../../shared/apiClient.js';

// cash_entry_manual/order_refund devolvem mensagens em inglês já seguras
// para exibir (ver backend/src/shared/rpcError.js) — mesmo padrão de
// comandaErrors.js/inventoryErrors.js: mapeamos por substring as mais
// prováveis no dia a dia, o resto cai no texto original.
const MESSAGE_PATTERNS = [
  ['idempotency key reused with different payload', 'Esta tentativa expirou. Feche e abra o lançamento novamente.'],
  ['insufficient organization permission', 'Seu papel não tem permissão para lançar no caixa.'],
];

export function messageForCashEntryError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    const match = MESSAGE_PATTERNS.find(([pattern]) => err.message?.toLowerCase().includes(pattern));
    return match ? match[1] : err.message;
  }
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}
