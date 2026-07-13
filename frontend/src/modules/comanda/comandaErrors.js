import { ApiError } from '../../shared/apiClient.js';

// checkout_close devolve mensagens em inglês já seguras para exibir (ver
// backend/src/shared/rpcError.js) — mapeamos por substring as mais prováveis
// de aparecer no dia a dia da recepção; o resto cai no texto original.
const MESSAGE_PATTERNS = [
  ['insufficient stock', 'Estoque insuficiente para um dos produtos da comanda.'],
  ['payments do not reconcile with order total', 'O total dos pagamentos não bate com o total da comanda.'],
  ['payment must be positive', 'Cada pagamento deve ter um valor maior que zero.'],
  ['idempotency key reused with different payload', 'Esta tentativa de fechamento expirou. Volte e tente fechar novamente.'],
  ['professionals must map exactly the package components', 'Selecione um profissional para cada item do pacote.'],
  ['active product not found', 'Um produto da comanda não está mais disponível. Atualize a página e tente novamente.'],
  ['active service not found', 'Um serviço da comanda não está mais disponível. Atualize a página e tente novamente.'],
  ['active package not found', 'Um pacote da comanda não está mais disponível. Atualize a página e tente novamente.'],
  ['active professional not found', 'Um profissional selecionado não está mais disponível.'],
  ['insufficient organization permission', 'Seu papel não tem permissão para fechar comandas.'],
];

export function messageForCheckoutError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    const match = MESSAGE_PATTERNS.find(([pattern]) => err.message?.toLowerCase().includes(pattern));
    return match ? match[1] : err.message;
  }
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}
