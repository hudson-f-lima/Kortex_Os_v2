# 2. Checkout Atômico e Idempotente via Server-Side

Date: 2026-07-13

## Status

Accepted

## Context

O KortexOS processa finanças (pedidos, itens, comissões e baixa de estoque) em um ambiente de PWA onde a rede pode ser instável (offline temporário, falhas de conexão de 4G no salão). 
A abordagem clássica de PWA "Offline-First" (onde o IndexedDB local grava a venda e sincroniza para a nuvem quando a rede volta) é perigosa em ERPs, pois permite conflitos destrutivos (venda do mesmo produto para dois clientes simultâneos ou furos no caixa). 

## Decision

Decidimos que **toda a lógica transacional do Checkout (comissões, alocação de pacotes e baixa de estoque) acontecerá estritamente em uma única RPC (Remote Procedure Call) no Supabase PostgreSQL (`checkout_close`)**. 

Adicionalmente, optamos por adotar o padrão **Idempotency Key**. O client (PWA) gera um UUID único (`Idempotency-Key`) no momento em que tenta fechar a conta. Se a rede cair e ele tentar de novo, o banco reconhece a chave na tabela `private.idempotency_keys` e apenas devolve o resultado da transação anterior, impedindo cobranças duplicadas.

## Consequences

- **Positivo:** Risco zero de race conditions ou overselling. Resolução atômica: se falhar o estoque, a venda inteira faz rollback.
- **Positivo:** Replay seguro em conexões móveis lentas.
- **Negativo/Trade-off:** O checkout não funciona estritamente offline. Se o salão perder a internet no momento de clicar em "Pagar", a PWA deve barrar a ação informando erro de rede, exigindo que o caixa aguarde a conexão.
