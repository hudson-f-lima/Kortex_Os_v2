---
title: "ADR 0023 - Onda 5 Recurring, Group Booking & Waitlist"
status: "ACCEPTED"
stage: "ADR"
governance_ref: ["DEC-51", "DEC-52"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-04"
---

# ADR 0023: Onda 5 — Recurring, Group Booking & Waitlist

## Status

**Accepted (DEC-51, 2026-08-04).** O Platform Owner aprovou o Blueprint depois de entrevista de desenho, benchmark Booksy → players de mercado → cross-industry e gate adversarial de desenho `GO`. A Etapa 8 local foi autorizada por DEC-52, sem autorização de `staging`, `main` ou produção.

## Contexto

A Onda 5 materializa `appointment_series`, `appointment_participants` e `waitlist_entries` sobre a fundação de agenda existente. A agenda possui uma única fonte de verdade em `appointments`, exclusion constraint por profissional/intervalo, `version` para concorrência e o Availability Resolver da Onda 4. O desenho precisa estender essa fundação sem criar calendário paralelo, bypass de tenant ou uma segunda trilha de hold.

O benchmark foi obrigatório nesta rodada. Booksy foi consultado primeiro: recurring trata ocorrências individualmente; Group Booking agenda reservas simultâneas; waitlist notifica e deixa o cliente concluir a reserva sem hold automático. Square, Vagaro, Eventbrite e padrões cross-industry foram usados para comparar links de booking, deduplicação, múltiplos profissionais, janelas de resposta e a separação entre booking e checkout.

## Decisão

### Recurring

Usar materialização antecipada em janela rolante de oito semanas. `appointment_series` guarda `anchor_date`, `local_start_time`, dias da semana, intervalo em semanas, duração congelada, unidade e estado. Ocorrências são criadas somente por `create_appointment`, que será estendido com metadados server-owned para unidade, série, duração snapshot e origem; ocorrências de série e waitlist são obrigadas a passar pelo Availability Resolver.

Cada ocorrência é processada independentemente. Válidas são persistidas; conflitos são registrados em `appointment_series_conflicts`, com idempotência por `series_id + occurrence_date`, e podem ser reprocessados isoladamente. Edição e cancelamento permitem a ocorrência atual ou esta e as próximas; passado não é reescrito. O titular (`appointments.client_id`) é imutável.

### Group Booking

Usar `appointment_groups` como agregado-pai e um appointment filho por participante. O grupo aceita 2–10 participantes, todos na mesma unidade, serviço e hora de início, mas cada filho pode ter profissional próprio. A criação e a alteração do conjunto são atômicas; alteração de filho é independente. Cada filho preserva seu próprio checkout e status. Não haverá consolidação financeira nem alteração de `checkout_close`.

`appointment_participants` é a fonte única de presença de cada filho, com linha automática do titular e backfill idempotente dos appointments existentes. O requester vê o agregado, cada participante vê somente seu filho e staff autorizado vê o grupo completo. Notificações são pós-commit e reprocessáveis.

### Waitlist

Adotar o modelo Booksy: matcher cria uma onda simultânea para todos os candidatos elegíveis; primeiro cliente que conclui vence; o slot não é segurado antes do clique. `HOLDING` é somente um estado transitório dentro da confirmação atômica e não cria appointment de hold persistente.

Cada oferta aponta para slot, profissional, serviço e unidade exatos, usa token opaco de uso único armazenado como hash, expira em 30 minutos por padrão e exige sessão autenticada ou OTP. Expiração/recusa retorna a entrada para `ACTIVE` e aplica cooldown de seis horas para a mesma entrada e slot. A aceitação usa `offer_id` + CAS em `status = 'OFFERED'`, chama `create_appointment` e confirma oferta/entrada numa transação única. As demais ofertas da onda tornam-se `SUPERSEDED`; a entrada vencedora vira `BOOKED` e não é reativada por cancelamento posterior.

### Tenant, unidade e governança

Todo objeto transacional novo carrega `organization_id` e `unit_id`; FKs cruzadas incluem ambos. RLS usa `private.can_access_fact_unit`, nunca somente `is_member`. DML direto é revogado; RPCs `security definer` fixam `search_path`, derivam actor de membership e são idempotentes. Feature flag em `organizations.settings` mantém os novos caminhos desligados por padrão.

## Alternativas rejeitadas

### Recorrência lazy

Rejeitada porque criaria uma segunda fonte de verdade de agenda até a consulta/materialização. A janela rolante mantém appointments reais como autoridade.

### All-or-nothing para toda a série

Rejeitada porque um conflito de uma ocorrência não deve impedir as demais. O modelo adotado trata ocorrências como unidades independentes, preservando conflitos explicitamente.

### Hold persistente antes da confirmação da waitlist

Rejeitada por contradizer o benchmark Booksy e por reservar capacidade para clientes que ainda não iniciaram a reserva. A proteção contra corrida é transacional no clique.

### Oferta sequencial obrigatória

Rejeitada. A onda simultânea reduz latência e segue o padrão first-come-first-served observado em Booksy/Square/bsport; a vitória é decidida por CAS e conflito real em `appointments`.

### Um único appointment com múltiplos profissionais

Rejeitado. A modelagem pai + filhos preserva o contrato atual de `appointments`, permite profissionais diferentes e mantém checkout/status por participante.

### Checkout consolidado do grupo

Adiado. Vagaro e Square mostram que consolidação é uma decisão financeira independente; nesta Onda `payer`/`beneficiary` é metadado operacional e cada filho fecha seu próprio checkout.

## Consequências

- A Onda 5 precisa endurecer `create_appointment` e `update_appointment`, mas preserva o caminho único de escrita e as chamadas legadas.
- O schema ganha objetos de apoio além dos três nomes canônicos do Migration Map; todos permanecem no mesmo domínio e existem para conflitos, agregação de grupo, preferências relacionais e auditoria de oferta.
- A materialização parcial exige UI/relatório futuro para conflitos e uma RPC explícita de retry; não há skip silencioso.
- A ausência de hold persistente simplifica expiração, mas exige token, CAS, idempotência e teste de concorrência no caminho de aceitação.
- Notificações não são verdade transacional da Onda; KortexLink/outbox deve tratar entrega, retry e falha pós-commit.

## Red Team de desenho

O gate encontrou e corrigiu: contrato antigo de `create_appointment` sem unidade/série/duração; ausência de consulta ao Availability Resolver; ausência de âncora temporal; FKs sem amarração de unidade; titular mutável e sem backfill; hold persistente incompatível com Booksy; oferta sem token/`offer_id`; expiração sem cooldown; matcher sem idempotência; e estado concorrente sem `SUPERSEDED`. Após as correções, o desenho foi classificado `GO`.

Nenhum teste de implementação foi executado porque ainda não existe código da Onda 5. DEC-52 autoriza iniciar a Etapa 8 local; cada fatia só poderá avançar mediante evidência própria de testes e Red Team de implementação.

## Referências

- [Blueprint Onda 5](../../waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md)
- [Migration Map](../../waves/KORTEXOS_5_1_2_MIGRATION_MAP.md)
- [Booksy Waitlist](https://support.booksy.com/hc/en-us/articles/16463469277714-How-does-the-waitlist-work)
- [Booksy Recurring Bookings](https://biz.booksy.com/blog/creating-a-recurring-booking-is-easy-with-booksy)
- [Booksy Group Booking](https://support.booksy.com/hc/en-us/articles/16459393119634-Can-I-schedule-group-bookings)
- [Square multi-staff appointments](https://squareup.com/help/us/en/article/7238-multi-staff-appointment-staff-scheduling)
