# 3. Comissões Escalonadas (Tiering)

Date: 2026-07-13

## Status

Proposed

## Context

O modelo inicial e tradicional de salões de beleza era o repasse fixo 50/50 (metade para o profissional, metade para o salão). No entanto, a análise dos players globais do estado da arte (Zenoti, Vagaro, Phorest) demonstrou que isso é insuficiente para reter talentos seniores. O profissional não tem incentivo direto e contínuo para aumentar a venda de serviços no fim do mês.

## Decision

Adotamos a **Regra do "Mais Específico Vence" com Escalonamento (Tiering)**:
O comissionamento ocorrerá através de faixas (`commission_tiers`), incentivando o profissional a vender mais para desbloquear repasses percentuais maiores no mês (ex: 40% até 5k, 45% acima).

## Consequences

- **Positivo:** Alinhamento imediato com as melhores práticas de retenção de talentos de salões High-End.
- **Negativo/Trade-off:** A RPC `checkout_close` ganha complexidade, pois precisará ler o faturamento acumulado dinâmico do profissional no mês vigente durante os milissegundos da transação. Questões de concorrência e fuso horário precisarão ser tratadas.
