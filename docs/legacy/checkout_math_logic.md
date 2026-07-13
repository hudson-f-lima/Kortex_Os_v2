# Lógica Matemática de Checkout (Portabilidade)

A lógica do checkout deste projeto foi projetada para ser robusta, não sofrer erros de arredondamento de ponto flutuante e suportar alocações proporcionais (ex: descontos, taxas de cartão, rateios de gorjetas). 

Toda a matemática foi isolada em "Engines" puras e utiliza **centavos inteiros** como base.

Abaixo estão todos os códigos fundamentais. Para portar para o seu novo projeto, basta copiar esses módulos e adequar as importações.

---

## 1. money.js
Utilitários base para tratamento financeiro seguro, convertendo e operando valores sempre na casa dos centavos.

```javascript
// money.js
function toCents(value) {
  if (value === null || value === undefined || value === '') return 0;
  if (Number.isInteger(value)) return value;
  if (typeof value === 'number') return Math.round(value * 100);
  const s = String(value).replace(/R\$/g, '').replace(/\s/g, '').replace(/\./g, '').replace(',', '.');
  const n = Number(s);
  if (!Number.isFinite(n)) return 0;
  return Math.round(n * 100);
}

function fromCents(cents) {
  return Math.round(Number(cents || 0)) / 100;
}

function roundCents(value) {
  return Math.round(Number(value || 0));
}

function sumCents(rows, keyOrFn) {
  return (rows || []).reduce((sum, row) => {
    const value = typeof keyOrFn === 'function' ? keyOrFn(row) : row[keyOrFn];
    return sum + roundCents(value || 0);
  }, 0);
}

module.exports = { toCents, fromCents, roundCents, sumCents };
```

---

## 2. allocation.js
Responsável pela **distribuição proporcional** (ex: como distribuir R$ 10 de desconto entre 3 serviços que têm preços diferentes sem sobrar ou faltar 1 centavo). Utiliza o algoritmo do "maior resto".

```javascript
// allocation.js
function allocateProportional(totalCents, rows, getWeight) {
  const total = Math.round(Number(totalCents || 0));
  if (!rows || rows.length === 0) return [];
  if (total === 0) return rows.map(() => 0);

  const weights = rows.map((row, index) => Math.max(0, Number(typeof getWeight === 'function' ? getWeight(row, index) : row[getWeight] || 0)));
  const weightSum = weights.reduce((a, b) => a + b, 0);

  if (weightSum <= 0) {
    const base = Math.floor(total / rows.length);
    const out = rows.map(() => base);
    let remainder = total - base * rows.length;
    for (let i = 0; i < Math.abs(remainder); i++) out[i % out.length] += remainder > 0 ? 1 : -1;
    return out;
  }

  const raw = weights.map(w => (total * w) / weightSum);
  const floors = raw.map(v => Math.floor(v));
  let remainder = total - floors.reduce((a, b) => a + b, 0);
  const order = raw
    .map((v, i) => ({ i, frac: v - Math.floor(v), weight: weights[i] }))
    .sort((a, b) => (b.frac - a.frac) || (b.weight - a.weight));

  for (let k = 0; k < remainder; k++) floors[order[k % order.length].i] += 1;
  return floors;
}

module.exports = { allocateProportional };
```

---

## 3. PaymentEngine.js
Trata a soma dos pagamentos e deduções das taxas (taxa % e taxa fixa) da forma de pagamento, alocando a taxa proporcionalmente para os serviços e para as gorjetas (se houver gorjeta paga no cartão, ela absorve parte da taxa).

```javascript
// PaymentEngine.js
const { roundCents, sumCents } = require('./money');
const { allocateProportional } = require('./allocation');

function feeForPayment(payment, forma) {
  const pct = Number(forma?.taxa_pct ?? forma?.taxaPct ?? 0);
  const fixed = roundCents(forma?.taxa_fixa_centavos ?? forma?.taxaFixaCentavos ?? forma?.taxaFixa ?? 0);
  return roundCents((payment.valorCentavos * pct) / 100 + fixed);
}

function calculatePayments({ payments, formasPagamento, servicesNetCents, tipGrossCents }) {
  const normalized = (payments || []).map(p => ({
    formaCode: p.formaCode || p.formaId || p.code || p.id,
    valorCentavos: roundCents(p.valorCentavos ?? p.valor_centavos ?? p.valor ?? 0)
  })).filter(p => p.valorCentavos > 0);

  const expectedTotal = roundCents(servicesNetCents) + roundCents(tipGrossCents);
  const receivedTotal = sumCents(normalized, 'valorCentavos');

  if (receivedTotal !== expectedTotal) {
    throw new Error(`Pagamento inconsistente. Recebido=${receivedTotal} Esperado=${expectedTotal}`);
  }

  const formasByCode = new Map((formasPagamento || []).map(f => [f.code || f.id || f.formaCode, f]));
  const enriched = normalized.map(payment => {
    const forma = formasByCode.get(payment.formaCode);
    const taxaTotalCentavos = feeForPayment(payment, forma);
    
    // Divide o prejuízo da taxa de cartão entre o caixa da empresa e as gorjetas dos profissionais
    const [taxaServicoCentavos, taxaGorjetaCentavos] = allocateProportional(
      taxaTotalCentavos,
      [{ peso: servicesNetCents }, { peso: tipGrossCents }],
      'peso'
    );
    return {
      ...payment,
      taxaTotalCentavos,
      taxaServicoCentavos,
      taxaGorjetaCentavos
    };
  });

  return {
    payments: enriched,
    totalRecebidoCentavos: receivedTotal,
    taxaTotalCentavos: sumCents(enriched, 'taxaTotalCentavos'),
    taxaServicoCentavos: sumCents(enriched, 'taxaServicoCentavos'),
    taxaGorjetaCentavos: sumCents(enriched, 'taxaGorjetaCentavos')
  };
}

module.exports = { calculatePayments };
```

---

## 4. TipSplitEngine.js
Faz o rateio (divisão) das gorjetas de forma híbrida: leva em conta qual o valor monetário que cada profissional gerou na comanda, assim como o tempo de duração. Esse rateio evita injustiças com serviços longos porém mais baratos.

```javascript
// TipSplitEngine.js
const { roundCents, sumCents } = require('./money');
const { allocateProportional } = require('./allocation');

function groupItemsByProfessional(items) {
  const map = new Map();
  for (const item of items || []) {
    if (item.tipo && item.tipo !== 'servico') continue;
    const profissionalId = item.profissionalId;
    if (!profissionalId) continue;
    if (!map.has(profissionalId)) {
      map.set(profissionalId, { profissionalId, valorLiquidoCentavos: 0, duracaoMin: 0, itemCount: 0 });
    }
    const row = map.get(profissionalId);
    row.valorLiquidoCentavos += roundCents(item.valorLiquidoCentavos || 0);
    row.duracaoMin += Number(item.duracaoMin || 0);
    row.itemCount += 1;
  }
  return Array.from(map.values());
}

function splitTipsHybrid({ tipGrossCents, items, valueWeight = 0.70, timeWeight = 0.30 }) {
  const tip = roundCents(tipGrossCents);
  if (tip <= 0) return [];

  const groups = groupItemsByProfessional(items);
  if (groups.length === 0) throw new Error('Gorjeta sem profissional calculável.');
  if (groups.length === 1) return [{ ...groups[0], gorjetaBrutaCentavos: tip }];

  const totalValue = sumCents(groups, 'valorLiquidoCentavos');
  const totalTime = groups.reduce((s, g) => s + Number(g.duracaoMin || 0), 0);

  const weights = groups.map(g => {
    const valorShare = totalValue > 0 ? g.valorLiquidoCentavos / totalValue : 0;
    const tempoShare = totalTime > 0 ? g.duracaoMin / totalTime : 0;
    
    let final = 0;
    if (totalValue > 0 && totalTime > 0) final = (valorShare * valueWeight) + (tempoShare * timeWeight);
    else if (totalValue > 0) final = valorShare;
    else if (totalTime > 0) final = tempoShare;
    else final = 1 / groups.length;

    return { pesoFinal: final };
  });

  const allocations = allocateProportional(tip, weights, 'pesoFinal');
  return groups.map((g, i) => ({
    ...g,
    ...weights[i],
    gorjetaBrutaCentavos: allocations[i],
  }));
}

module.exports = { splitTipsHybrid, groupItemsByProfessional };
```

---

## 5. CommissionEngine.js
Calcula qual a base de cálculo e as comissões. Lida com modelos como `bruto_salao` (o salão absorve taxa do cartão) e `dividido` (a taxa do cartão é descontada antes de bater a comissão).

```javascript
// CommissionEngine.js
const { roundCents } = require('./money');

function calculateItemCommission(item) {
  const valor = roundCents(item.valorLiquidoCentavos || 0);
  const taxa = roundCents(item.taxaItemCentavos || 0);
  const custo = roundCents(item.totalCustoCentavos || 0);
  const pct = Number(item.comissaoPct || 0);
  const modelo = item.modeloComissao || 'bruto_salao';

  let baseCalculoCentavos = valor;
  let comissaoCentavos = 0;
  let receitaEmpresaCentavos = 0;

  if (modelo === 'bruto_salao') {
    baseCalculoCentavos = valor;
    comissaoCentavos = roundCents((baseCalculoCentavos * pct) / 100);
    receitaEmpresaCentavos = valor - comissaoCentavos - taxa - custo;
  } else if (modelo === 'dividido') {
    baseCalculoCentavos = Math.max(0, valor - taxa);
    comissaoCentavos = roundCents((baseCalculoCentavos * pct) / 100);
    receitaEmpresaCentavos = valor - comissaoCentavos - taxa - custo;
  } else if (modelo === 'bruto_staff') {
    baseCalculoCentavos = valor;
    comissaoCentavos = roundCents((baseCalculoCentavos * pct) / 100) - taxa;
    receitaEmpresaCentavos = valor - comissaoCentavos - taxa - custo;
  } else {
    throw new Error(`Modelo de comissão inválido: ${modelo}`);
  }

  return {
    ...item,
    modeloComissao: modelo,
    comissaoPct: pct,
    baseCalculoCentavos,
    comissaoCentavos,
    receitaEmpresaCentavos
  };
}

module.exports = { calculateItemCommission };
```

---

## 6. FinanceEngine.js (O Orquestrador)
Ele unifica tudo: desconta, aplica a taxa de cartão, comissiona, e divide as gorjetas.

```javascript
// FinanceEngine.js
const { roundCents, sumCents } = require('./money');
const { allocateProportional } = require('./allocation');
const { calculatePayments } = require('./PaymentEngine');
const { splitTipsHybrid } = require('./TipSplitEngine');
const { calculateItemCommission } = require('./CommissionEngine');

function previewCheckout({ rawItems, payments, formasPagamento, descontoCentavos = 0, gorjetaCentavos = 0 }) {
  // 1. Calcular o desconto
  const totalItensCentavos = sumCents(rawItems, 'valorBrutoCentavos');
  const desconto = Math.max(0, Math.min(roundCents(descontoCentavos), totalItensCentavos));
  const discountAllocations = allocateProportional(desconto, rawItems, 'valorBrutoCentavos');

  const itemNets = rawItems.map((item, i) => {
    const valorLiquidoCentavos = item.valorBrutoCentavos - discountAllocations[i];
    return {
      ...item,
      descontoCentavos: discountAllocations[i],
      valorLiquidoCentavos
    };
  });

  // 2. Pagamentos e Taxas do Cartão
  const itensLiquidosCentavos = sumCents(itemNets, 'valorLiquidoCentavos');
  const tipGross = roundCents(gorjetaCentavos || 0);

  const paymentResult = calculatePayments({
    payments,
    formasPagamento,
    servicesNetCents: itensLiquidosCentavos,
    tipGrossCents: tipGross
  });

  // 3. Ratear taxas de cartão para os Itens
  const itemFeeAllocations = allocateProportional(paymentResult.taxaServicoCentavos, itemNets, 'valorLiquidoCentavos');

  // 4. Calcular Comissões
  const itemCommissioned = itemNets
    .map((item, i) => ({ ...item, taxaItemCentavos: itemFeeAllocations[i] }))
    .map(calculateItemCommission);

  // 5. Calcular Gorjetas e Ratear a taxa do cartão sobre as gorjetas
  let tips = splitTipsHybrid({ tipGrossCents: tipGross, items: itemCommissioned });
  const tipFeeAllocations = allocateProportional(paymentResult.taxaGorjetaCentavos, tips, 'gorjetaBrutaCentavos');
  
  tips = tips.map((tip, i) => ({
    ...tip,
    taxaGorjetaCentavos: tipFeeAllocations[i],
    gorjetaLiquidaCentavos: tip.gorjetaBrutaCentavos - tipFeeAllocations[i]
  }));

  // Retornar Output Resumido
  return {
    ok: true,
    totals: {
      totalItensCentavos,
      descontoCentavos: desconto,
      itensLiquidosCentavos,
      gorjetaBrutaCentavos: tipGross,
      totalRecebidoCentavos: paymentResult.totalRecebidoCentavos,
      taxaTotalCentavos: paymentResult.taxaTotalCentavos,
      totalComissaoCentavos: sumCents(itemCommissioned, 'comissaoCentavos'),
      totalGorjetaLiquidaCentavos: sumCents(tips, 'gorjetaLiquidaCentavos'),
      receitaEmpresaCentavos: sumCents(itemCommissioned, 'receitaEmpresaCentavos')
    },
    itens: itemCommissioned,
    payments: paymentResult.payments,
    gorjetas: tips
  };
}

module.exports = { previewCheckout };
```
