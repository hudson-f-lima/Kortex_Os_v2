---
title: "Onda 6 — hardening adversarial e Red Team de implementação"
status: "IMPLEMENTADA LOCALMENTE"
stage: "ISSUE"
governance_ref: ["DEC-62", "DEC-66", "ADR-0025"]
upstream_doc: "docs/waves/onda-6-checkout-reopen/BLUEPRINT_ONDA_6.md"
last_updated: "2026-08-13"
---

# 061 — Hardening adversarial e Red Team de implementação

Sétima e última fatia (Blueprint §6, item 7; critérios de aceitação §7). `$kortex-qa-redteam` ataca as fatias 055-060 já implementadas contra o schema/RPCs reais, não contra o desenho de papel: locks financeiros terminais e `action_request_required`, corrida entre o produtor de lock e `commission_sale_record_create` disputando o mesmo `FOR UPDATE` de pedido, payloads concorrentes em `order_reclose`, refunds proporcionais com múltiplos pagamentos parciais e arredondamento, regressão completa de `checkout_close`/`order_refund` com a flag desligada, chamada direta das primitives privadas por `authenticated`/`service_role`, e os Gates 10/11/12/14/18 citados no §7 do Blueprint (nomes exatos a confirmar no Master Briefing antes de escrever os testes — não inventar). Toda evidência é reexecutada pessoalmente pelo orquestrador (pgTAP completo + `node --test` do backend), nunca aceita como relato resumido de subagente.

Aceite: nenhum achado `CRÍTICO` sobrevive sem mitigação (um `CRÍTICO` sem mitigação é `NO-GO` automático); suíte pgTAP completa e `node --test` do backend sem regressão em nenhuma onda anterior; `supabase db lint --local` sem erros; veredito do Red Team de implementação registrado com DEC próprio antes de qualquer promoção a `staging`.

Type: HITL — achados de Red Team historicamente exigiram decisão do Platform Owner nas Ondas 3/4/5 (correções P1/P2/P3, emendas de ADR); esta fatia pode reabrir uma das 055-060 anteriores.
Blocked by: `issues/060-onda6-order-refund-ledger-compat.md`.

## Resultado de implementação (2026-08-13)

O Red Team de implementação encontrou um gap real de serialização: o produtor
de `order_financial_locks` e `commission_sale_record_create` não disputavam de
forma uniforme a linha viva de `orders`. A migration
`20260813150720_onda6_adversarial_hardening.sql` corrige o desvio sem alterar
o contrato legado: o trigger privado do produtor trava o pedido, exige
`status='closed'` e rejeita revisão obsoleta; a RPC de comissão passa a fazer
o mesmo `FOR UPDATE` antes de validar e inserir o fato.

O novo pgTAP cobre Gates 10 (Checkout Integrity), 11 (Ledger Balance), 12
(Payment Allocation), 14 (Commission Privacy & Accuracy) e 18 (Cash Register
Integrity), além de chamadas diretas a primitives privadas por `authenticated`
e `service_role`. Evidência reproduzida em reset limpo: 1.060/1.060 pgTAP
antes e depois de 328/328 testes de backend, 117/117 PWA e `supabase db lint
--local` sem achados.

**Veredito:** `GO LOCAL`. Não houve ativação de feature flag, deploy ou
promoção. O DEC pós-Red-Team exigido para qualquer proposta de `staging`,
somado aos gates de Environment Guardian, homologação e Delivery Guardian,
permanece pendente e fora desta fatia.
