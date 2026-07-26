## Parent Blueprint

`docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1_DRAFT.md` (DEC-34), §3.1, §3.3, §7.1.

## ⚠️ HITL — maior risco desta Onda

O próprio Blueprint (§6) classifica esta fatia como a de maior risco: toca `checkout_close`, a RPC financeira mais crítica do sistema (150+ linhas, coberta por pgTAP, usada em produção). Exige revisão humana antes de integrar — não é AFK.

## What to build

`checkout_close` ganha uma responsabilidade nova e isolada: ao fechar o pedido de um agendamento que tem um `deposit_hold` ativo, reconcilia — abate o valor retido do total cobrado (mecânica `hold`) ou registra o valor já cobrado como adiantamento (mecânica `immediate_charge`) — e marca o hold como `captured_checkout`. Essa reconciliação é a **única** mudança na função; nenhuma outra lógica de `checkout_close` é tocada.

Inclui a trava de concorrência (CAS `UPDATE deposit_holds SET status = 'captured_checkout' WHERE id = ... AND status = 'active'`, mesma disciplina da ADR 0012) e o tratamento de overflow (`min(deposit_amount, order_total)`, excedente segue o estorno já existente via ADR 0006/0007 — nunca um sistema de crédito novo).

## Acceptance criteria

- [ ] `checkout_close` (`supabase/migrations/20260713060000_professional_commissions_checkout.sql:200-230`) recebe a chamada de reconciliação sem nenhuma outra linha alterada
- [ ] Reconciliação usa CAS (`WHERE status = 'active'`) — se zero linhas afetadas (hold já capturado por outro caminho), a reconciliação não executa, sem erro fatal
- [ ] Valor aplicado do depósito nunca excede `order_total` (`min(deposit_amount, order_total)`); excedente vira estorno pelo mecanismo existente (ADR 0006/0007), nunca saldo/crédito novo
- [ ] **Toda a suíte pgTAP existente (346 testes) continua passando sem nenhuma regressão** — evidência obrigatória antes de integrar, comando real executado e conferido, não relato resumido
- [ ] pgTAP novo: reconciliação aplica valor correto pras duas mecânicas (`hold`/`immediate_charge`); CAS bloqueia dupla captura simulando corrida com a fatia 005; overflow gera estorno, não saldo negativo
- [ ] Teste de integração backend: checkout de agendamento com depósito ativo fecha com o valor correto; checkout de agendamento sem depósito continua idêntico ao comportamento atual

## Blocked by

- Blocked by `issues/003-deposit-holds-creation.md` (precisa de hold existente pra reconciliar)

## Seções do Blueprint endereçadas

- §3.1 (reconciliação de depósito no checkout; overflow)
- §3.3 (trava de concorrência — achado #3 da 1ª rodada de Red Team)
- §7.1 (autorização — herda a de `checkout_close`, sem mudança)
