## Parent Blueprint

`docs/waves/onda-1-payment-core/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1.md` (DEC-34), §2, §3.3, §4, §7.1.

## What to build

Schema de `deposit_holds` mais o caminho de criação de hold no fluxo de agendamento — quando um `appointment` é criado/confirmado para um serviço com política de depósito configurada (fatia 001), um `deposit_hold` nasce vinculado ao `appointment` e a um `payment_intent` (fatia 002), com os valores de política **snapshotados** no momento da criação (mesmo padrão de congelamento da ADR 0011 — nunca referência viva à configuração do serviço).

Aditiva por construção: é uma RPC nova, não uma modificação da RPC de criação de `appointment` existente.

## Acceptance criteria

- [x] Migration aditiva cria `deposit_holds` com índice único parcial: no máximo um `status = 'active'` por `appointment_id`
- [x] Criação de hold só acontece quando o serviço do agendamento tem `deposit_mechanic` configurado (fatia 001); agendamento de serviço sem política não cria hold nenhum
- [x] `amount_cents`, `no_show_commission_type`/`value` são copiados (snapshot) da política do serviço no momento da criação — mudança posterior na política do serviço não afeta holds já criados
- [x] Autorização da criação de hold: mesma regra que hoje já governa `create_appointment`/`update_appointment` (owner/admin/manager/reception, org-wide) — nenhuma superfície de autorização nova. Achado registrado em DEC-35: o texto do §7.1 descreve escopo por unidade para reception/professional, mas essa não é a regra real implementada hoje por nenhuma RPC de agendamento
- [x] `expires_at` preenchido quando `mechanic = 'hold'` (janela de autorização da rede de cartão); nulo quando `mechanic = 'immediate_charge'`
- [x] pgTAP: índice único parcial rejeita segundo hold ativo pro mesmo agendamento; snapshot confirmado (alterar a política do serviço depois não muda hold existente); RLS (mesmo padrão `can_access_fact_unit` da Onda 0)
- [x] Teste de integração backend: agendar serviço com depósito cria hold com valores corretos; agendar serviço sem depósito não cria hold

## Blocked by

- Blocked by `issues/001-services-deposit-policy.md` (precisa da política configurável)
- Blocked by `issues/002-payment-intents-webhook-outbox.md` (hold referencia `payment_intent_id`)

## Seções do Blueprint endereçadas

- §2 (escopo de dados de `deposit_holds`)
- §3.3 (exatamente um hold ativo por agendamento; janela de expiração)
- §4 (contrato físico de schema)
- §7.1 (autorização da criação de hold)
