// Dinheiro sempre em centavos (inteiro) no contrato com o backend — nunca
// float. Estas duas funções são a única fronteira de conversão para exibir
// e para ler o que o usuário digita em reais.

export function formatCents(cents) {
  return (cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

// Converte uma string de reais (ex.: "19,90" ou "19.90") em centavos
// inteiros via manipulação de string, não `valor * 100` (evita erro de
// ponto flutuante como 19.9 * 100 = 1989.9999999998).
export function reaisToCents(value) {
  const normalized = String(value).trim().replace(',', '.');
  if (normalized === '' || Number.isNaN(Number(normalized))) return null;
  const [wholePart, decimalPart = ''] = normalized.split('.');
  const cents = `${decimalPart}00`.slice(0, 2);
  const sign = wholePart.startsWith('-') ? -1 : 1;
  const digitsOnly = wholePart.replace('-', '') || '0';
  const total = Number(`${digitsOnly}${cents}`);
  if (!Number.isFinite(total)) return null;
  return sign * total;
}
