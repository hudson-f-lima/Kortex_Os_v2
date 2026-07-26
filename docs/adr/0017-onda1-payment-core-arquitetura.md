# ADR 0017: Onda 1 — Arquitetura de Payment Core (Depósito, No-show e Reconciliação)

## Status
Accepted (DEC-34, 2026-07-25)

## Date
2026-07-25

## Context

A Onda 1 (Migration Map v1.2, D13) introduz pagamento mediado por PSP: depósito pré-reserva, cobrança de no-show e captura assíncrona via webhook. Diferente da Onda 0 (retrofit de fundação de tenant), esta é capability nova sobre uma base financeira já em produção (`orders`, `order_items`, `payments`, `checkout_close`) coberta por pgTAP.

### Motivações

1. **Redução de no-show:** depósito por política, já mapeado como prioridade P1 no Master Briefing
2. **Confiança operacional:** comissão de no-show precisa ser visível para o colaborador exatamente onde ele já verifica comissão hoje — não é opcional, é requisito confirmado por experiência real de operação (Booksy)
3. **Integridade financeira:** nenhuma captura de PSP pode duplicar dinheiro ou comissão, mesmo sob replay de webhook ou concorrência entre dois caminhos de captura

### Constraints

- **Não tocar `checkout_close` além do estritamente necessário** — função de 150+ linhas, coberta por pgTAP, mesma cautela já aplicada na Onda 0
- **`payments.order_id` e `order_items.order_id` são `NOT NULL`** (verificado diretamente no schema) — qualquer fluxo de dinheiro sem pedido precisa de solução que não afrouxe essas constraints
- **Comissão hoje só existe em `order_items.commission_cents`** — não há tabela de "comissão ganha" separada; qualquer dinheiro que precise contar como comissão precisa passar por um `order_item`
- **PSPs entregam webhook com garantia at-least-once** — replay não é hipotético, é padrão de mercado

## Decision

### Modelo de PSP: plataforma única, fornecedor deferido

KortexOS integra com **um único PSP como plataforma/marketplace** (padrão Stripe Connect "Separate Charges and Transfers", já benchmarcado no Global Benchmark Map), onde cada organização-cliente é uma subconta. **Qual PSP real (Mercado Pago, Pagar.me, outro) é decisão de implementação (Etapa 9)** — o schema fica agnóstico via coluna `provider`, sem adapter/abstração para múltiplos PSPs simultâneos.

**Alternativa rejeitada:** cada organização-cliente traz seu próprio PSP. Rejeitada porque exigiria N integrações de webhook/token diferentes sem ganho evidente — nenhum salão que hoje usa Stone/Cielo/Mercado Pago tem conta de marketplace/split configurada lá, então o onboarding seria trabalhoso do mesmo jeito com qualquer modelo.

### `payment_intents.order_id` nullable — depósito nasce sem pedido

Um depósito é cobrado no agendamento, antes de qualquer `order` existir. `payment_intents.order_id` é nullable; `checkout_close` ganha uma responsabilidade isolada e nova — reconciliar o `deposit_hold` ativo do agendamento ao fechar o pedido — sem tocar nenhuma outra lógica da função.

**Alternativas rejeitadas:**
- **Order rascunho vazio só para ter `order_id`:** contamina o conceito de `orders` (hoje = serviço/produto efetivamente vendido) com uma entidade que não é venda.
- **Depósito vira saldo em `client_wallets`:** mais simples, mas exige a Onda 2 (ainda não construída) e não é o que DEC-22 (06.3) já decidiu.

### No-show vira pedido sintético real, não comissão paralela

A cobrança de no-show gera um `order` mínimo real (via RPC nova, nunca `checkout_close`): um `order_item` com `service_id` do agendamento original e comissão calculada de `no_show_commission_type`/`value` (campo novo e independente do `commission_type` normal), e um `payment`.

**Por que não uma tabela de comissão separada:** o colaborador verifica saldo olhando `order_items.commission_cents` — não existe tela nem relatório paralelo hoje. Uma cobrança de no-show invisível ali geraria desconfiança real, não hipotética (confirmado pelo Platform Owner com base em experiência de operação). Reaproveitar o caminho existente custa uma RPC nova pequena; inventar visibilidade paralela custaria uma segunda fonte de verdade para o mesmo dado — exatamente o tipo de duplicação que o projeto evita.

**Por que não afrouxar `payments`/`order_items.order_id` (NOT NULL):** essas são as tabelas financeiras mais críticas do sistema, cobertas por pgTAP e usadas por `checkout_close` em produção. Um pedido sintético real resolve o mesmo problema sem tocar nenhuma constraint existente.

### Idempotência: dois níveis de unicidade, sem outbox genérico

- `psp_webhook_events.provider_event_id` com unicidade `(provider, provider_event_id)` — reentrega do mesmo evento vira conflito de INSERT, tratado como sucesso idempotente
- `payment_intents` com unicidade `(organization_id, provider, provider_reference)` — defesa em profundidade independente da unicidade do evento

**Alternativa rejeitada:** infraestrutura de outbox/retry genérica, reutilizável para outros domínios futuros. Rejeitada por falta de segundo caso de uso concreto hoje — exatamente o tipo de generalização especulativa que o projeto evita (YAGNI). O outbox desta onda é mínimo e específico de webhook de pagamento.

### Concorrência: CAS explícito, mesma disciplina da ADR 0012

Reconciliação de checkout e liquidação de no-show são os dois únicos caminhos que capturam um `deposit_hold`, mutuamente exclusivos por `UPDATE ... WHERE status = 'active'` — se zero linhas forem afetadas, o caminho aborta sem criar `order`/`payment`. Mesma disciplina de concorrência otimista já aplicada a `appointments`.

### Expiração de hold: reativo + fallback, sem scheduler

Dois gatilhos, nenhuma infraestrutura nova: webhook reativo (se o provedor notificar expiração) e fallback preguiçoso (se uma tentativa de captura falhar porque a autorização já morreu no provedor, essa falha marca o hold como `expired` dentro da própria RPC que tentava capturar). Nenhum scheduler/job proativo — mesma decisão de não generalizar infraestrutura sem caso de uso comprovado.

### Overflow de reconciliação: cap + estorno existente

O valor aplicado do depósito é limitado a `min(deposit_amount, order_total)`. Excedente segue o estorno já existente (ADR 0006/0007, void/refund) — não é um sistema de crédito novo (isso é escopo de `client_wallets`, Onda 2, inexistente ainda).

### Escopo reduzido: dois objetos adiados

`card_on_file_tokens` (exige consentimento LGPD/D26, que não tem Migration Map nem código) e `pix_automatico_mandates` (depende de integração com Banco Central e do Subscription Engine/D18, sem Migration Map próprio) ficam fora desta onda — mesmo padrão que a Onda 4 aplicou a `availability_slot_cache`. Não são abandonados; entram como extensão aditiva quando D26/D18 existirem.

## Alternatives Considered

### A: Multi-PSP desde o início (coluna `provider` + adapter/interface genérica)
- **Pros:** flexibilidade se organizações diferentes precisarem de PSPs diferentes
- **Cons:** complexidade especulativa sem caso de uso real hoje; um único tenant real (Salão Esperança) e nenhum segundo PSP no horizonte
- **Rejected:** YAGNI — coluna `provider` já dá margem de evolução sem construir abstração não usada

### B: Afrouxar `payments.order_id`/`order_items.order_id` para NOT NULL → nullable
- **Pros:** no-show poderia gerar `payment`/`order_item` "direto", sem pedido sintético
- **Cons:** altera constraint de tabela financeira crítica em produção, coberta por pgTAP, usada por `checkout_close`
- **Rejected:** risco desproporcional ao ganho; pedido sintético resolve o mesmo problema sem tocar a constraint

### C: Tabela de comissão de no-show separada (paralela a `order_items`)
- **Pros:** não precisa de RPC nova nem de pedido sintético
- **Cons:** colaborador não veria a comissão onde já olha hoje; segunda fonte de verdade para o mesmo tipo de dado
- **Rejected:** risco de confiança confirmado como real pelo Platform Owner, não hipotético

### D: Scheduler/job assíncrono proativo para expiração de hold
- **Pros:** expira holds mortos de forma determinística, sem depender de webhook ou tentativa de captura
- **Cons:** infraestrutura nova sem segundo caso de uso comprovado; pior cenário sem ela é higiene de dado, não perda de dinheiro
- **Rejected:** mesma decisão já tomada para o outbox — sem infraestrutura genérica sem necessidade demonstrada

## Consequences

### Aplicação
- **Evidência:** 2 rodadas de `$kortex-qa-redteam` (design), 1ª NO-GO com 5 achados, 2ª GO após correção de todos com mecanismo concreto
- **Fatiamento (DEC-33):** 5 fatias verticais candidatas (`services` extensão → `payment_intents`/`psp_webhook_events` → `deposit_holds` → reconciliação em `checkout_close` → RPC de no-show), cada uma testável isoladamente via `$tdd`
- **Rollback:** 4 das 5 fatias são aditivas puras; só a reconciliação em `checkout_close` toca lógica financeira existente, e reverter é remover a chamada, não desfazer schema

### Código
- **`checkout_close`:** ganha uma chamada de reconciliação isolada, nenhuma outra linha alterada
- **RPC nova de no-show:** não reutiliza `resolve_commission()` nem `checkout_close` — caminho próprio e pequeno, deliberadamente isolado do código financeiro mais crítico do sistema
- **Frontend:** nenhuma UI nesta onda (mesma decisão da Onda 0 — timezone/config sem tela ainda)

### Futuro
- **Onda 2 (KortexFlow Ledger):** quando `client_wallets` existir, overflow de reconciliação pode evoluir de "estorno" para "crédito automático" — mudança aditiva, não redesenho
- **D26 (LGPD)/D18 (Subscription Engine):** quando tiverem Migration Map próprio, `card_on_file_tokens`/`pix_automatico_mandates` entram como extensão deste Blueprint

## Related Decisions

- **DEC-24:** Migration Map v1.2 define Onda 1 como Payment Core (D13)
- **DEC-22 (06.1-06.6):** decisões de produto sobre depósito/COF/no-show que este ADR materializa, nunca reabre
- **DEC-33:** reforma de processo (fatiamento, TDD, evidência) sob a qual este Blueprint foi desenhado — primeiro caso de uso real do novo fluxo
- **DEC-34:** aprovação formal deste Blueprint pelo Platform Owner
- **ADR 0006/0007:** distinção void/refund reaproveitada para overflow de reconciliação
- **ADR 0011:** padrão de snapshot (congelar valor de política no momento da criação) reaproveitado em `deposit_holds`
- **ADR 0012:** concorrência otimista reaproveitada como padrão CAS em `deposit_holds`
- **ADR 0016:** Onda 0 (units) — `unit_id` já em produção, aplicado a todos os objetos transacionais desta onda
