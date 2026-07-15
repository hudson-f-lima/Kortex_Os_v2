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
  ['discount cannot exceed subtotal', 'O desconto não pode ser maior que o total da comanda.'],
  ['cannot apply discount or tip to empty order', 'Adicione itens à comanda antes de aplicar desconto ou gorjeta.'],
  ['cannot apply tip without service items', 'A gorjeta só pode ser aplicada quando a comanda tem algum serviço.'],
  ['discount and tip must be positive', 'Desconto e gorjeta não podem ser negativos.'],
];

// order_refund (ADR 0006) devolve as mesmas mensagens seguras via
// backend/src/shared/rpcError.js.
const REFUND_MESSAGE_PATTERNS = [
  ['order already refunded', 'Esta comanda já foi estornada.'],
  ['only closed orders can be refunded', 'Só é possível estornar comandas já fechadas.'],
  ['order not found', 'Comanda não encontrada.'],
  ['reason must be customer_cancellation or customer_default', 'Selecione um motivo para o estorno.'],
  ['insufficient organization permission', 'Seu papel não tem permissão para estornar comandas.'],
];

export function messageForRefundError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    const match = REFUND_MESSAGE_PATTERNS.find(([pattern]) => err.message?.toLowerCase().includes(pattern));
    return match ? match[1] : err.message;
  }
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

export function messageForCheckoutError(err) {
  if (err instanceof ApiError) {
    if (err.status === 403) return 'Seu papel não tem permissão para esta ação.';
    const match = MESSAGE_PATTERNS.find(([pattern]) => err.message?.toLowerCase().includes(pattern));
    return match ? match[1] : err.message;
  }
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}
