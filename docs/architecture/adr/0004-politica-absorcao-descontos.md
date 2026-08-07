# 4. Política de Absorção de Descontos

Date: 2026-07-13

## Status

Proposed

## Context

Quando um cliente recebe descontos ou usa vouchers, o profissional muitas vezes se sente lesado se a sua comissão for reduzida sem acordo prévio. A falta de regras claras sobre "quem paga pelo desconto" causa atritos contínuos em salões de beleza. 

## Decision

Para evitar debates de balcão, foi instituída a **Política de Descontos** no nível da Organização. O dono do salão escolhe, por sistema, quem absorve o desconto ou custo, através de uma configuração (flag) que dita como o cálculo da comissão se comporta na transação:
- **Net Split (Preço Líquido):** Prejuízo dividido. O desconto é abatido do bruto antes do cálculo da comissão.
- **Gross Split (Salão Absorve):** O salão assume 100% da perda promocional, e a comissão do profissional é calculada sobre a tabela bruta.

## Consequences

- **Positivo:** Clareza financeira, fim dos cálculos manuais em planilhas para corrigir valores de descontos ou estornos. Flexibilidade para o gestor negociar modelos de aluguel de cadeira vs CLT.
- **Negativo/Trade-off:** Mais complexidade na rotina de fechamento de carrinho e estornos. A RPC de checkout precisa saber a política ativa da organização antes de calcular a comissão final do item.
