// Comissão percentual trafega em pontos-base no backend (10000 = 100%),
// espelhando a disciplina de centavos inteiros para dinheiro — nunca float
// na cascata profissional>serviço>grupo (docs/PLANEJAMENTO_COMISSOES.md §4.2).
// Estas são a única fronteira de conversão para exibir/ler o que o usuário
// digita como porcentagem.

export function basisPointsToPercentString(value) {
  return (value / 100).toString();
}

export function percentStringToBasisPoints(value) {
  const normalized = String(value).trim().replace(',', '.');
  if (normalized === '' || Number.isNaN(Number(normalized))) return null;
  const points = Math.round(Number(normalized) * 100);
  return Number.isFinite(points) && points >= 0 ? points : null;
}

export function formatPercent(basisPoints) {
  return `${(basisPoints / 100).toLocaleString('pt-BR')}%`;
}
