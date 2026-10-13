# 6. Gorjeta Fora da Base de Comissão e Distinção Void/Refund no Motivo do Estorno

Date: 2026-07-15

## Status

Accepted

## Context

A Fase 9 (`PLANEJAMENTO_EXECUCAO_UNIFICADO.md`) deixou duas decisões em aberto que o ADR 0005 não cobria: (1) se a gorjeta entra na base sobre a qual a comissão percentual do serviço incide; (2) como distinguir, na captura do motivo de um estorno, uma desistência/inadimplência real do cliente de uma correção de erro operacional da recepção.

Seguindo a regra de pesquisar o mercado global antes de decidir (`PLANEJAMENTO_EXECUCAO_UNIFICADO.md §1`):

**1. Gorjeta.** A pesquisa em Trinks e concorrentes diretos do nicho mostrou que a gorjeta é aplicada como um valor dirigido diretamente ao(s) profissional(is) que o cliente escolhe no fechamento ("deixar troco como gorjeta" → seleciona profissional(is) e valor) — um repasse à parte, não uma soma que entra no faturamento de serviço sobre o qual o percentual de comissão incide. Zenoti, Vagaro e Boulevard tratam tip como um componente de payroll automatizado e distinto da comissão de serviço, reforçando o mesmo padrão. Isso confirma o comportamento que a migration da Fase 9 (`20260715103200_fase9_foundation.sql`) já tinha implicitamente (comissão calculada sobre `total_cents - discount_cents`, sem somar `tip_cents`).

**2. Motivo do estorno.** A pesquisa no mercado de POS geral (Clover, Lightspeed) mostrou uma distinção formal consolidada entre **void** (cancelamento antes do fechamento/liquidação, sem repasse externo de dinheiro) e **refund** (reversão após a venda já liquidada, dinheiro já saiu do caixa). Essa distinção mapeia diretamente para o problema já identificado no ADR 0005 (§4) e na investigação de concorrentes diretos do nicho (AppBarber/Trinks — reabertura de comanda condicionada à sessão de caixa ainda aberta): correção operacional é estruturalmente um **void** (a comanda nunca deveria ter fechado daquele jeito; nenhum dinheiro externo circulou), enquanto desistência/inadimplência do cliente é um **refund** real (dinheiro que precisa ser devolvido ou uma dívida que precisa ser baixada).

## Decision

**Gorjeta**: permanece 100% fora da base de cálculo da comissão por serviço, paga integralmente ao(s) profissional(is) selecionado(s) no fechamento da comanda. Nenhuma mudança de código é necessária — o comportamento atual da migration é adotado como decisão definitiva, não mais implícita.

**Motivo do estorno**: dois fluxos permanecem estruturalmente distintos, nunca compartilhando a mesma RPC:
- **Correção operacional** (erro de recepção: serviço/profissional errado) é um **void** — nunca usa `order_refund`. Só é possível enquanto a sessão de caixa que contém a comanda ainda está aberta (dependência: `cash_sessions`, ver decisão de escopo abaixo). Nenhum lançamento de caixa é criado — a comanda é reaberta, corrigida e refechada.
- **Desistência/inadimplência real do cliente** é um **refund** — usa `order_refund`, exige motivo obrigatório no payload (`customer_cancellation` | `customer_default`, taxonomia mínima a formalizar na migration que materializar esta decisão), e gera o lançamento de caixa `kind='refund'` que já existe.

## Consequences

- **Positivo**: elimina a ambiguidade de reusar `order_refund` para corrigir erro de digitação — evita lançamentos de caixa fantasma e mantém `order_refund` semanticamente limpo para o caso legal que o ADR 0005 já regula (comissão não revertida automaticamente).
- **Positivo**: a captura de motivo (`customer_cancellation`/`customer_default`) em `order_refund` já deixa o dado pronto para quando a classificação do profissional (ADR 0005) permitir automatizar reversão de comissão só no caso de inadimplência — sem precisar de migração de dados retroativa.
- **Trade-off**: o fluxo de correção operacional (void) depende de `cash_sessions`, que **não está mais no escopo da Fase 9** (decisão registrada em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md` Fase 9, 2026-07-15) — vira fase própria, ainda sem número alocado. Até essa fase existir, correção de erro operacional não tem caminho no sistema (só correção manual fora do sistema, mesmo estado atual).
- Este ADR não introduz mudança de schema por si só; a coluna/enum de motivo em `order_refund` é implementada quando a Fase 9 for materializada no backend (testes pgTAP + wiring), não neste ADR.
