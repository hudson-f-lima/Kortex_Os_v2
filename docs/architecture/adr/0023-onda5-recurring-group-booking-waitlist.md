---
title: "ADR 0023 - Onda 5 Recurring, Group Booking & Waitlist"
status: "ACCEPTED"
stage: "ADR"
governance_ref: ["DEC-51", "DEC-52", "DEC-54", "DEC-55", "DEC-56", "DEC-57"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# ADR 0023: Onda 5 — Recurring, Group Booking & Waitlist

## Status

**Accepted (DEC-51, 2026-08-04).** O Platform Owner aprovou o Blueprint depois de entrevista de desenho, benchmark Booksy → players de mercado → cross-industry e gate adversarial de desenho `GO`. A Etapa 8 local foi autorizada por DEC-52, sem autorização de `staging`, `main` ou produção. **Emendada por DEC-54 e DEC-55 (2026-08-05)**: DEC-54 abriu o plano corretivo pós-implementação das fatias 032-035; DEC-55 substitui, apenas para a identidade client-facing da oferta, o OTP decidido em DEC-54 por sessão autenticada no AppCliente e push FCM — ver seção "Emendas" abaixo. **Fechada localmente por DEC-57 (2026-08-06)**: Red Team final de implementação sobre 029-040 classificou `GO`; `staging`/`main`/produção continuam não autorizados sob DEC-52.

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

Cada oferta aponta para slot, profissional, serviço e unidade exatos, usa token opaco de uso único armazenado como hash, expira em 30 minutos por padrão e exige **sessão autenticada no AppCliente vinculada ao mesmo `clients.id` da `waitlist_entry`**. O token continua obrigatório como capacidade complementar do deep link, mas nunca é autorização suficiente; push FCM entrega a notificação e também não autoriza a operação. Expiração/recusa retorna a entrada para `ACTIVE` e aplica cooldown de seis horas para a mesma entrada e slot. A aceitação usa `offer_id` + CAS em `status = 'OFFERED'`, chama `create_appointment` e confirma oferta/entrada numa transação única. As demais ofertas da onda tornam-se `SUPERSEDED`; a entrada vencedora vira `BOOKED` e não é reativada por cancelamento posterior.

### Tenant, unidade e governança

Todo objeto transacional novo carrega `organization_id` e `unit_id`; FKs cruzadas incluem ambos. RLS usa `private.can_access_fact_unit`, nunca somente `is_member`. DML direto é revogado; RPCs `security definer` fixam `search_path`, derivam actor de membership e são idempotentes. Feature flag em `organizations.settings` mantém os novos caminhos desligados por padrão. **Achado corretivo (DEC-54): a implementação das fatias 032-035 não completou esses dois invariantes — `service_role` manteve DML herdado nas 7 tabelas novas, e as RPCs de escrita não verificam `unit_id` do objeto-alvo contra a unidade do actor. Ver seção "Emenda" abaixo.**

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

## Emenda (DEC-54, 2026-08-05)

**Contexto:** um Red Team de implementação sobre as fatias 032-035, já commitadas localmente, achou 5 gaps reais não visíveis ao Red Team de desenho (que avaliou o desenho antes de existir código): (1) `service_role` manteve `INSERT`/`UPDATE`/`DELETE`/`TRUNCATE` diretos nas 7 tabelas novas — contradizendo o invariante "DML direto é revogado" já registrado acima; (2) as RPCs de série, grupo e waitlist não verificam `unit_id` do objeto-alvo contra a unidade da membership do actor, só pertencimento à organização; (3) `waitlist_matcher_run` gera ofertas sem checar disponibilidade real do slot antes de ofertar, deixando toda a proteção de corrida para o aceite; (4) a identidade client-facing da aceitação seguia como lacuna aberta ("sessão autenticada ou OTP", sem decisão fechada); (5) o gate de ambiente de testes está degradado e 2 testes legados vazam `organization_id` entre fixtures.

**DEC-54** (Decision Log, SEÇÃO 20) aprova o plano corretivo forward-only — fatias 036 (revoga DML de `service_role`), 037 (guard unit-aware nas RPCs de escrita), 038 (verificação de slot disponível antes da oferta, `create_appointment` seguindo como proteção transacional final), 039 (identidade client-facing) e 040 (gate de ambiente + correção dos 2 testes legados) — sem alterar nenhuma migration já aplicada e sem reabrir o desenho de recorrência, group booking, ausência de hold persistente ou o mecanismo token+CAS+`SUPERSEDED`.


## Emenda (DEC-55, 2026-08-05)

**Escopo parcialmente superado:** a escolha de OTP no contato cadastrado feita por DEC-54 para a fatia 039. Todo o restante de DEC-54 — as fatias 036-038/040, forward-only, token+CAS+`SUPERSEDED`, ausência de hold persistente e limites de promoção — continua vigente.

**Benchmark e decisão:** Booksy continua sendo a referência de onda simultânea, porém notifica a lista por SMS e link. Square usa push para clientes do Square Go a fim de evitar duplicidade com SMS. Vagaro exige conta do cliente e permite notificação in-app para vaga de waitlist. Para o Kortex, o Platform Owner escolheu o caminho de menor custo variável: **AppCliente autenticado + push FCM**, sem OTP/SMS nesta fatia. O FCM não tem cobrança de uso; autenticação por telefone/SMS é cobrada por mensagem.

**Contrato de identidade e entrega:** cada conta do AppCliente é vinculada de modo tenant-safe a um único `clients.id`; a RPC/rota de aceite deriva `auth.uid()` do JWT, obtém esse vínculo no servidor e exige que corresponda ao `waitlist_entry.client_id`. `offer_id` e token opaco válido de uso único continuam obrigatórios para o deep link, mas não substituem a sessão. O push só é enviado pós-commit a dispositivos registrados pelo próprio cliente; a oferta permanece consultável na caixa de entrada do app até o TTL, pois push não é garantia de entrega. Nenhum identificador de cliente, organização ou unidade vindo do body autoriza a operação.

**Implementação local da fatia 039:** `client_app_identities` impõe um vínculo único por tenant entre o usuário Auth e `clients.id`; `client_push_devices` tem RLS e é registrado por RPC autenticada. `waitlist_offer_accept_client` consulta a oferta através desse vínculo, valida a capacidade opaca e chama o caminho canônico `create_appointment`; como `appointments.created_by` é deliberadamente FK de membership operacional, o usuário AppCliente é registrado separadamente em `client_booking_user_id`, por FK composta ao mesmo cliente/tenant. O matcher escreve um outbox privado por dispositivo na transação da oferta; `client_waitlist_offer_inbox` é o fallback autenticado e reemite a capacidade sem persistir token legível. Evidência: 12/12 pgTAP da fatia e 13/13 arquivos pgTAP da Onda 5 em reset limpo local. A infraestrutura de AppCliente, credenciais Firebase e worker que consome o outbox ainda não existe nesta base e continua fora da autorização de promoção.

**Backlog (DEC-56):** AppCliente runtime, rotas HTTP, magic link, worker FCM e credenciais são uma nova onda futura, isolada por `organizations.settings.app_cliente_waitlist_enabled` (default `false`). A flag não existe nem pode ser ligada antes daquela onda; a fatia 039 não é autorização de ativação.

## Red Team final (DEC-57, 2026-08-06)

Red Team de implementação sobre o código/migrations reais de 029-040 (não mais o desenho), executado via `$kortex-qa-redteam`, cobrindo Escopo/cânone, Tenant, Agenda, Supabase e Segredos da matriz de gates. Evidência reproduzida pessoalmente, comando real, reset limpo do zero: 908/908 pgTAP (57 arquivos, reconfirmado rodando a suíte antes e depois do backend), 325/325 backend, `supabase db lint --local` sem achados, `search_path` fixado 1:1 nas 40 funções `SECURITY DEFINER` novas, scan de segredos limpo, forward-only confirmado por `git status`.

Ataque adversarial aos caminhos negativos (bypass de tenant/unidade, replay de idempotência, corrida de slot, spoofing de identidade client-facing) não achou gap crítico ou alto. 4 achados de severidade baixa, todos registrados como risco aceito ou backlog, nenhum bloqueando o fechamento: oráculo de existência intra-tenant no guard da fatia 037 (42501 vs P0002 para reception do mesmo tenant); políticas RLS self-service mortas em `client_app_identities`/`client_push_devices` (cosmético, mais restritivo que necessário); ausência de checagem de feature flag inline nas 3 RPCs client-facing da fatia 039 (já coberto por DEC-56, hoje inerte sem caminho de self-signup); e lacuna de teste pgTAP cross-tenant dedicado para `waitlist_offer_accept_client` (só cross-client no mesmo tenant está provado).

**Veredito: `GO`.** DEC-57 fecha a Onda 5 localmente (fatias 029-040). `staging`, `main` e produção seguem não autorizados sob DEC-52 — a promoção é tarefa distinta, gated por Environment Guardian, homologação e Delivery Guardian.

**Hardening implementado (fatia 042, 2026-08-06):** o achado 1 (oráculo de existência intra-tenant) foi corrigido via `$tdd` em [issue 042](../../../issues/042-onda5-intra-tenant-existence-oracle-hardening.md) — normaliza para `P0002 'not found'` nas 10 operações de LOOKUP do dispatcher (série/conflito/grupo/oferta por ID existente); as 4 operações de CREATE mantêm `42501`, por decisão explícita, já que `unit_id` vem do próprio payload do actor e não há objeto oculto a proteger ali. Migration forward-only sobre a 037 já aplicada, `search_path` fixado, 908/908 pgTAP (mesma contagem, 9 asserções de lookup reescritas), lint sem achados. Não reabre o `GO` do DEC-57 nem qualquer permissão de owner/admin/manager/reception-da-unidade-correta.

**Promoção para staging (DEC-58, 2026-08-06):** o Platform Owner autorizou exclusivamente a promoção `feat/onda5-blueprint-and-fatia-029` → `staging`, condicionada a PR, CI verde e aos gates locais reproduzidos (908/908 pgTAP, 325/325 Express e lint). Não há autorização para `main`, produção ou ativação da feature flag; após o merge, a Onda continua sujeita à homologação em staging e ao Delivery Guardian antes de qualquer promoção posterior.

## Referências

- [Blueprint Onda 5](../../waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md)
- [Migration Map](../../waves/KORTEXOS_5_1_2_MIGRATION_MAP.md)
- [Booksy Waitlist](https://support.booksy.com/hc/en-us/articles/16463469277714-How-does-the-waitlist-work)
- [Vagaro — Waitlist para clientes](https://support.vagaro.com/hc/en-us/articles/360012490814-Join-a-Waitlist-for-Services-for-Customers-of-a-Vagaro-Business)
- [Square — notificações de appointments](https://squareup.com/help/us/en/article/6729-customer-confirmations-with-square-appointments)
- [Firebase — preços do Cloud Messaging](https://firebase.google.com/pricing)
- [Booksy Recurring Bookings](https://biz.booksy.com/blog/creating-a-recurring-booking-is-easy-with-booksy)
- [Booksy Group Booking](https://support.booksy.com/hc/en-us/articles/16459393119634-Can-I-schedule-group-bookings)
- [Square multi-staff appointments](https://squareup.com/help/us/en/article/7238-multi-staff-appointment-staff-scheduling)
