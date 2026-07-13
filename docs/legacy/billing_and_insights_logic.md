# Lógica de Faturamento, Receitas e Repasses (Insights)

Além da matemática transacional (Checkout), o sistema Hope OS possui agregadores que geram os relatórios de faturamento por tipo, receita da empresa, impacto das taxas de cartão e repasses para o staff (receita do profissional).

Abaixo está o código que processa essas métricas a partir dos dados brutos das comandas. Pode ser levado diretamente para o seu novo projeto.

---

## 1. Finance Read Model (Totais e Repasses Base)
Esse serviço varre todas as comandas, itens, pagamentos e gorjetas de um período para fechar os totais. 
Ele divide o faturamento entre **Serviços** e **Produtos**, isola a receita da empresa e levanta as taxas.

```javascript
// FinanceReadModel.js
const { sumCents } = require('./money');

function buildFinanceReadModel(snapshot) {
  const comandos = snapshot.comandos || [];
  const pagamentos = snapshot.comandoPagamentos || [];
  const itens = snapshot.comandoItens || [];
  const gorjetas = snapshot.comandoGorjetas || [];
  
  // Faturamento por Tipos (Produtos vs Serviços)
  const produtosItens = itens.filter(i => (i.tipo || 'servico') === 'produto');
  const servicosItens = itens.filter(i => (i.tipo || 'servico') === 'servico');

  // Taxas e Faturamento Agrupado por Forma de Pagamento
  const porForma = Object.values(pagamentos.reduce((acc, p) => {
    const key = p.forma_code;
    if (!acc[key]) acc[key] = { formaCode: key, valorCentavos: 0, taxaCentavos: 0, taxaServicoCentavos: 0, taxaGorjetaCentavos: 0, count: 0 };
    acc[key].valorCentavos += p.valor_centavos || 0;
    acc[key].taxaCentavos += p.taxa_total_centavos || 0;
    acc[key].taxaServicoCentavos += p.taxa_servico_centavos || 0;
    acc[key].taxaGorjetaCentavos += p.taxa_gorjeta_centavos || 0;
    acc[key].count += 1;
    return acc;
  }, {}));

  // Receita Staff (Repasses por Profissional: Comissão + Gorjetas)
  const repassesPorProfissional = Object.values(itens.reduce((acc, item) => {
    const id = item.profissional_id;
    if (!id) return acc;
    if (!acc[id]) acc[id] = { profissionalId: id, comissaoCentavos: 0, gorjetaLiquidaCentavos: 0, servicosCentavos: 0, produtosCentavos: 0 };
    acc[id].comissaoCentavos += item.comissao_centavos || 0;
    if ((item.tipo || 'servico') === 'produto') {
      acc[id].produtosCentavos += item.valor_liquido_centavos || item.total_venda_centavos || 0;
    } else {
      acc[id].servicosCentavos += item.valor_liquido_centavos || 0;
    }
    return acc;
  }, {}));

  // Soma as gorjetas à Receita do Staff
  for (const tip of gorjetas) {
    let row = repassesPorProfissional.find(r => r.profissionalId === tip.profissional_id);
    if (!row) {
      row = { profissionalId: tip.profissional_id, comissaoCentavos: 0, gorjetaLiquidaCentavos: 0, servicosCentavos: 0, produtosCentavos: 0 };
      repassesPorProfissional.push(row);
    }
    row.gorjetaLiquidaCentavos += tip.valor_liquido_centavos || 0;
  }

  // Faturamento Final por Tipos
  const servicosLiquidosCentavos = sumCents(comandos, 'servicos_liquidos_centavos');
  const produtosLiquidosCentavos = sumCents(comandos, 'produtos_liquidos_centavos');
  const itensLiquidosCentavos = sumCents(comandos, row => row.itens_liquidos_centavos ?? ((row.servicos_liquidos_centavos || 0) + (row.produtos_liquidos_centavos || 0)));

  return {
    totals: {
      comandos: comandos.length,
      servicosLiquidosCentavos,            // Faturamento (Serviços)
      produtosLiquidosCentavos,            // Faturamento (Produtos)
      itensLiquidosCentavos,               // Faturamento Bruto (Serviços + Produtos)
      produtosCustoCentavos: sumCents(produtosItens, 'total_custo_centavos'),
      produtosLucroBrutoCentavos: sumCents(produtosItens, 'lucro_bruto_centavos'),
      totalRecebidoCentavos: sumCents(comandos, 'total_recebido_centavos'),
      
      taxaTotalCentavos: sumCents(comandos, 'taxa_total_centavos'),             // Total de Taxas da Empresa
      totalComissaoCentavos: sumCents(comandos, 'total_comissao_centavos'),     // Total pago aos Profissionais
      gorjetaLiquidaCentavos: sumCents(comandos, 'total_gorjeta_liquida_centavos'),
      
      receitaEmpresaCentavos: sumCents(comandos, 'receita_empresa_centavos')    // Receita Líquida da Empresa
    },
    porForma,
    repassesPorProfissional
  };
}

module.exports = { buildFinanceReadModel };
```

---

## 2. Margens Analíticas e KPIs (margin.js)
Aqui a lógica detalha, por cada Serviço, Produto ou Profissional, o quanto de dinheiro "sobrou" pra empresa após pagar comissões e impostos (Receita da Empresa) e o Ticket Médio geral.

```javascript
// margin.js

function aggregateMarginByServico(comandoItens) {
  const map = {};
  comandoItens.forEach(item => {
    if (item.tipo !== 'servico' || !item.servico_id) return;
    const key = item.servico_id;
    
    if (!map[key]) {
      map[key] = {
        servicoId: key,
        producaoCentavos: 0,
        comissaoCentavos: 0,
        receitaEmpresaCentavos: 0, // A margem do salão nesse serviço específico
        n: 0
      };
    }
    map[key].producaoCentavos += item.valor_liquido_centavos || 0;
    map[key].comissaoCentavos += item.comissao_centavos || 0;
    map[key].receitaEmpresaCentavos += item.receita_empresa_centavos || 0;
    map[key].n += 1;
  });

  return Object.values(map).map(s => ({
    ...s,
    // Calcula quantos % da produção ficou como lucro pra empresa após pagar as taxas e o staff
    margemPct: s.producaoCentavos ? Math.round((s.receitaEmpresaCentavos / s.producaoCentavos) * 100 * 10) / 10 : 0
  }));
}

function aggregateMarginByProfissional(comandoItens, comandoGorjetas) {
  const servicos = {};
  const gorjetas = {};

  // Acumula o que o profissional produziu vs O que a empresa lucrou com ele vs A comissão dele
  comandoItens.forEach(item => {
    if (item.tipo !== 'servico' || !item.profissional_id) return;
    const key = item.profissional_id;
    if (!servicos[key]) {
      servicos[key] = {
        profissionalId: key,
        producaoCentavos: 0,
        comissaoCentavos: 0,
        receitaEmpresaCentavos: 0
      };
    }
    servicos[key].producaoCentavos += item.valor_liquido_centavos || 0;
    servicos[key].comissaoCentavos += item.comissao_centavos || 0;
    servicos[key].receitaEmpresaCentavos += item.receita_empresa_centavos || 0;
  });

  comandoGorjetas.forEach(g => {
    if (!g.profissional_id) return;
    const key = g.profissional_id;
    if (!gorjetas[key]) gorjetas[key] = 0;
    gorjetas[key] += g.valor_liquido_centavos || 0;
  });

  return Object.values(servicos).map(s => ({
    ...s,
    gorjetaLiquidaCentavos: gorjetas[s.profissionalId] || 0
  }));
}

function computeTicketMedio(comandos) {
  if (!comandos || comandos.length === 0) return 0;
  // O Ticket Médio usa o "total recebido", pois embute tanto faturamento quanto gorjeta agregada.
  const total = comandos.reduce((sum, c) => sum + (c.total_recebido_centavos || 0), 0);
  return Math.round(total / comandos.length);
}

module.exports = {
  aggregateMarginByServico,
  aggregateMarginByProfissional,
  computeTicketMedio
};
```
