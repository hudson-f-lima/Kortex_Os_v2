# 3. Comissões Escalonadas e Política de Descontos

Date: 2026-07-13

## Status

Accepted

## Context

O modelo inicial e tradicional de salões de beleza era o repasse fixo 50/50 (metade para o profissional, metade para o salão). No entanto, a análise dos players globais do estado da arte (Zenoti, Vagaro, Phorest) demonstrou que isso é insuficiente para reter talentos seniores e causa sérios atritos quando um cliente recebe descontos ou usa vouchers. O profissional muitas vezes se sente lesado.

## Decision

Adotamos a **Regra do "Mais Específico Vence" com Escalonamento (Tiering)**:
1. O comissionamento ocorrerá através de faixas (`commission_tiers`), incentivando o profissional a vender mais para desbloquear repasses percentuais maiores no mês (ex: 40% até 5k, 45% acima).
2. Para evitar debates de balcão, foi instituída a `Política de Descontos` no nível da Organização. O dono do salão escolhe, por sistema, quem absorve o desconto ou custo:
   - **Net Split:** Prejuízo dividido (desconto abatido do bruto antes do cálculo).
   - **Gross Split:** Salão absorve 100% da perda (comissão sobre tabela bruta).

## Consequences

- **Positivo:** Alinhamento imediato com as melhores práticas de retenção de talentos de salões High-End.
- **Positivo:** Fim dos cálculos manuais em planilhas para ajustar taxas ou corrigir descontos.
- **Negativo/Trade-off:** A RPC `checkout_close` ganha complexidade, pois precisará ler o faturamento acumulado dinâmico do profissional no mês vigente durante os milissegundos da transação.
