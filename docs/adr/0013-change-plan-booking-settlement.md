# 13. Change Plan com Confirmação Explícita e Separação Booking × Settlement (Accepted)

Date: 2026-07-16

## Status

**Accepted (2026-07-16).** Itens 6 e 7 do plano de 7 ADRs, combinados neste documento porque o Change Plan (item 6) é a aplicação prática do princípio de separação Booking × Settlement (item 7) — não há uma decisão de arquitetura nova no item 7 além de nomear e formalizar algo que o código já faz. Depende do [ADR 0011](0011-snapshot-operacional-agendamento.md) (snapshot) e do [ADR 0012](0012-idempotencia-concorrencia-otimista-appointments.md) (versão obrigatória, Rota B), ambos Accepted — este ADR consome os dois. O fluxo escolhido é o two-step síncrono (seção "Decisão do usuário").

## Context

`docs/PROJECT_STATE.md` já lista como gap conhecido: troca de profissional/serviço em um agendamento existente não tem "fluxo de aprovação e diff" — hoje é um PATCH silencioso que (antes do [ADR 0011](0011-snapshot-operacional-agendamento.md)) recalcula a duração sem avisar ninguém, e mesmo depois do 0011 continuaria aplicando a reconfiguração sem o cliente confirmar que o novo horário/duração é aceitável.

Separadamente, a auditoria (§6.5) já confirmou que o sistema **já separa** dois momentos de resolução, mesmo sem nomear isso formalmente:
- **Booking** (agendamento): resolve duração e (com o ADR 0010) elegibilidade — acontece em `appointments.service.js`, nunca toca comissão.
- **Settlement** (checkout): resolve e congela comissão via `private.resolve_commission`, exclusivamente dentro de `checkout_close` (`order_items` frozen) — nunca acontece no agendamento.

Essa separação já é implementação real, não proposta — o único trabalho deste ADR nessa frente é documentá-la como princípio nomeado, para que resolvers futuros (ex.: se `price_override_cents` for finalmente consumido) saibam em qual fase devem viver, em vez de reabrir a pergunta caso a caso.

## Decision (proposta)

### 1. Nomear o princípio Booking × Settlement (ratificação, sem mudança de código)

> Todo campo resolvido para um agendamento pertence a exatamente uma fase: **Booking** (duração, elegibilidade, buffers — o que determina *se* e *quando* algo acontece) ou **Settlement** (preço, comissão — o que determina *quanto dinheiro* circula). Um resolver de Booking nunca lê estado de Settlement e vice-versa. `price_override_cents`, quando for consumido, precisa declarar explicitamente em qual fase entra — hoje é ambíguo (armazenado em `professional_service_capabilities`, uma tabela de Booking, mas nomeado como se fosse Settlement).

Nenhuma migration decorre diretamente deste item — é documentação de um invariante já respeitado no código, para orientar decisões futuras (ex.: quando o ADR 0008 Decisão 1 for finalmente implementado).

### 2. Change Plan: PATCH que reconfigura exige confirmação explícita de duas etapas

Aplica-se apenas quando `touchesConfig` (do [ADR 0011](0011-snapshot-operacional-agendamento.md): `professional_id` e/ou `service_id` mudam) — reagendamento de horário puro (`MOVE_TIME_ONLY`) não precisa de confirmação, porque não altera nada que o cliente já não tenha visto.

```
PATCH /appointments/:id { professional_id: novo, version: N }        (sem confirm)
  → servidor resolve o NOVO snapshot (duração, elegibilidade) mas NÃO aplica
  → 409 confirmation_required, corpo:
      { current: {...snapshot atual...}, proposed: {...novo snapshot...}, diff: [...campos que mudam...] }

PATCH /appointments/:id { professional_id: novo, version: N, confirm: true }
  → servidor re-resolve (idempotente — mesmo cálculo) e aplica, gravando o novo snapshot
  → version (ADR 0012) segue validado normalmente; se divergir, 409 version_conflict prevalece sobre o fluxo de confirmação
```

Two-step síncrono, não um workflow assíncrono de aprovação (a auditoria lista "Approval workflow" como componente separado da Opção C — modelar uma fila de aprovação com outro ator revisando é trabalho substancialmente maior, fora do que o MVP atual precisa; a confirmação aqui é do próprio operador que está fazendo o PATCH, não de um terceiro).

### 3. PWA: `AppointmentModal` precisa de uma tela de diff

Fora do escopo de backend deste ADR, mas registrado como dependência: ao receber `409 confirmation_required`, a PWA deve mostrar o `diff` (ex.: "Duração muda de 30min para 60min, novo horário de término 15:00") antes de reenviar com `confirm: true`. Sem essa tela, a API fica tecnicamente correta mas inutilizável — um cliente ingênuo poderia simplesmente sempre mandar `confirm: true` de cara, esvaziando o propósito. Recomendo que isso vá junto na mesma fase de implementação do backend, não depois.

## Decisão do usuário (2026-07-16)

- **Two-step síncrono aprovado como está** — o próprio operador que faz o PATCH confirma o diff na hora; nenhum workflow de aprovação assíncrona (outro ator revisando) é escopado por este ADR. Se isso vier a ser necessário no futuro, é um ADR novo.
- `price_override_cents` permanece formalmente marcado como "fase ambígua, resolver na hora de implementar" — não foi forçada uma classificação Booking/Settlement antecipada sem uso real para testá-la.

## Consequences

### Positivo
- Fecha o gap "aprovação e diff ao alterar profissional/serviço" do `docs/PROJECT_STATE.md` com um design mínimo (two-step PATCH), sem workflow assíncrono.
- Nomeia um princípio já respeitado no código, prevenindo que uma implementação futura (ex.: `price_override_cents`) misture as duas fases por falta de um nome para a regra.
- Reaproveita 100% da infraestrutura dos ADRs 0010-0012 (snapshot para calcular o diff, `version` para garantir que o diff mostrado ainda é válido) — nenhuma peça nova de infraestrutura, só orquestração.

### Trade-off
- Exige que a PWA implemente uma tela de diff antes do fluxo ser realmente seguro — se o backend for entregue sem a UI correspondente, o `confirm: true` pode virar um parâmetro que os clientes simplesmente sempre enviam, anulando a proteção.
- Two-step síncrono não serve um caso de uso onde *outra pessoa* (não quem está editando) precisa aprovar a mudança — se isso for necessário no futuro, é um ADR novo, não uma extensão deste.
- Depende de dois ADRs anteriores (0011, 0012) estarem implementados primeiro — é o último elo de uma cadeia de 4, não uma peça isolada.

## References
- `docs/PROJECT_STATE.md` — gap "fluxo de aprovação e diff ao alterar profissional/serviço"
- `docs/audit_global/SERVICE_PROFESSIONAL_OPTION_C_AUDIT.md` §6.5, §9 — separação booking/settlement já observada; "Approval workflow" e "Diff + confirmação" como componentes distintos da matriz de completude
- `supabase/migrations/20260713060000_professional_commissions_checkout.sql` — `private.resolve_commission`, único ponto de resolução de Settlement, nunca chamado fora de `checkout_close`
- [ADR 0011 — Snapshot Operacional](0011-snapshot-operacional-agendamento.md) — fornece o "current" do diff
- [ADR 0012 — Idempotência e Concorrência Otimista](0012-idempotencia-concorrencia-otimista-appointments.md) — fornece `version`, pré-requisito para o diff ser confiável
