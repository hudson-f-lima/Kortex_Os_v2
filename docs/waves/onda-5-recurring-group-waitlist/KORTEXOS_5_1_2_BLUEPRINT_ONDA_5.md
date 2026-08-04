---
title: "Blueprint Onda 5 — Recurring, Group Booking, Waitlist"
status: "APROVADO"
stage: "BLUEPRINT"
governance_ref: ["DEC-24", "DEC-27", "DEC-28", "DEC-44", "DEC-51", "DEC-52", "ADR-0023"]
upstream_doc: "docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md"
last_updated: "2026-08-04"
---

# KortexOS 5.1.2 — Blueprint Onda 5: Recurring, Group Booking, Waitlist

**Status:** APROVADO pelo Platform Owner em 2026-08-04, após entrevista de desenho, benchmark comparativo e gate de desenho `GO` do Red Team. Etapa 8 local autorizada por DEC-52; ainda não executada.

**Etapa:** 7 concluída. A Etapa 8 (SQL, migrations, RPCs executáveis e testes) está autorizada exclusivamente em ambiente local/descartável, fatia por fatia, sob DEC-52.

**Escopo:** os três objetos canônicos da Onda 5 no Migration Map — `appointment_series`, `appointment_participants` e `waitlist_entries` — mais objetos de apoio necessários para tornar o contrato íntegro: `appointment_groups`, `appointment_series_conflicts`, `waitlist_entry_professionals` e `waitlist_offers`.

**Regra de benchmark:** dúvidas de produto desta Onda foram confrontadas primeiro com o Booksy, depois com players de agenda/booking e, quando útil, com padrões cross-industry. Booksy foi adotado como referência normativa específica para waitlist; os demais precedentes serviram para validar riscos e alternativas, não para ampliar o escopo sem decisão explícita.

## 1. Autoridade e limites

Este Blueprint materializa o Migration Map aprovado por DEC-24/DEC-27/DEC-28, a governança de pipeline de DEC-44 e as regras do Master Briefing para recorrência, group booking e waitlist. Ele não altera o Migration Map, não cria domínio financeiro, não altera `checkout_close`, não cria UI, não integra diretamente WhatsApp/e-mail e não contém SQL executável.

`organization_id` é a fronteira primária de tenant. `unit_id` é obrigatório em todo objeto transacional novo e em toda extensão transacional desta Onda. Toda escrita passa por RPC/backend server-owned; nenhum cliente escolhe o tenant por body ou query.

O Blueprint mantém `appointments` como única fonte de verdade de ocupação. Série, grupo e waitlist são mecanismos de criação/orquestração; nenhum deles mantém um calendário paralelo.

### 1.1 Benchmark e decisões de produto incorporadas

- **Waitlist:** o Booksy notifica clientes quando surge uma vaga, não segura o slot antes do clique e deixa o primeiro cliente que conclui a reserva vencer. KortexOS adota esse modelo: `HOLDING` existe somente durante a transação de confirmação, nunca como hold persistente pré-clique. Ver [Booksy Waitlist](https://support.booksy.com/hc/en-us/articles/16463469277714-How-does-the-waitlist-work).
- **Recurring:** o Booksy trata ocorrências como appointments editáveis/canceláveis individualmente ou em conjunto. KortexOS materializa ocorrências e suporta edição/cancelamento da ocorrência ou desta e das próximas. Ver [Booksy Recurring Bookings](https://biz.booksy.com/blog/creating-a-recurring-booking-is-easy-with-booksy).
- **Group Booking:** o Booksy permite reservas simultâneas para grupos, com controle individual dos appointments. KortexOS amplia a modelagem com uma entidade-pai e um appointment filho por participante, permitindo profissionais diferentes sem consolidar checkout. Ver [Booksy Group Booking](https://support.booksy.com/hc/en-us/articles/16459393119634-Can-I-schedule-group-bookings).
- **Comparativos:** Square confirma o uso de links de booking, deduplicação de notificações e appointments com múltiplos profissionais; Vagaro e Square demonstram que pagamento consolidado é uma decisão financeira separada. Esse Blueprint mantém checkout por appointment e deixa consolidação para Onda futura.

## 2. Escopo de dados

| Objeto | Contrato | Estado |
|---|---|---|
| `appointment_series` | Padrão simples de recorrência de um cliente, serviço, profissional e unidade; guarda âncora local, horário local, intervalo, duração congelada e estado da série. | Novo |
| `appointments.series_id` | Referência nullable e unit-safe à série que materializou a ocorrência. | Extensão aditiva |
| `appointment_series_conflicts` | Registro durável de ocorrências que não puderam ser materializadas; permite exibir e reprocessar somente conflitos. | Apoio novo |
| `appointment_groups` | Agregado-pai operacional de um Group Booking, com requester, unidade e estado agregado. | Apoio novo |
| `appointments.group_id` | Referência nullable e unit-safe ao grupo-pai; cada participante é um appointment filho independente. | Extensão aditiva |
| `appointment_participants` | Fonte única de pessoas presentes em cada appointment; o titular sempre nasce com linha própria. | Novo |
| `waitlist_entries` | Pedido de vaga por cliente, serviço, unidade, janela de datas e preferências. | Novo |
| `waitlist_entry_professionals` | Preferências relacionais de profissionais; zero linhas significa qualquer profissional elegível. | Apoio novo |
| `waitlist_offers` | Oferta individual dentro de uma onda simultânea, com slot exato, token hash, expiração, cooldown e estado de concorrência. | Apoio novo |
| `organizations.settings` | Chaves de dark launch e parâmetros operacionais da waitlist. | Extensão de uso |

### 2.1 Simplificações deliberadas

- Recorrência usa dias da semana, intervalo em semanas, `anchor_date` e `local_start_time`; RRULE/RFC 5545, recorrência mensal por dia do mês e padrões arbitrários ficam fora desta Onda.
- A janela rolante começa em 8 semanas. O valor é constante de código nesta versão; TTL da oferta e cooldown são configuráveis por organização em `organizations.settings`.
- Group Booking aceita 2–10 participantes, todos para o mesmo serviço, unidade e início; cada participante pode ter profissional diferente. Serviços diferentes, intervalos paralelos e recursos por participante ficam para evolução posterior.
- Não há tabela persistente de holds da waitlist. A confirmação usa a transação de `create_appointment`; `HOLDING` é estado transitório dentro da transação.

## 3. Integridade e invariantes

### 3.1 Recorrência

1. A criação da série materializa independentemente cada ocorrência da janela de 8 semanas.
2. Cada ocorrência usa a data e o horário local da série, convertidos pelo `units.timezone` vigente no momento da materialização.
3. Cada ocorrência é validada pelo Availability Resolver e pelo caminho único `create_appointment`; não existe atalho de inserção direta em `appointments`.
4. Uma ocorrência válida é persistida mesmo que outra ocorrência da mesma série conflite. Conflitos nunca são silenciosamente descartados: entram em `appointment_series_conflicts` com motivo, chave idempotente e estado `OPEN`.
5. A chave idempotente de ocorrência é determinística por `series_id + occurrence_date`; retries retornam a ocorrência ou o conflito existente.
6. Extensão de janela reprocessa somente datas ainda não materializadas e não reescreve appointments existentes.
7. Edição aceita os escopos `THIS_OCCURRENCE` e `THIS_AND_FUTURE`; edição de série recalcula apenas a janela futura. Ocorrências passadas são imutáveis.
8. Cancelamento aceita os mesmos escopos. Um skip individual cancela o appointment materializado; pausar a série impede novas materializações e cancela apenas ocorrências futuras ainda não iniciadas. Retomar começa em `valid_from` futuro.
9. `appointments.client_id` é o titular/requester e fica imutável depois da criação. Transferência de titular será comando futuro explícito, com auditoria e notificação; participantes são alterados em `appointment_participants`.

### 3.2 Group Booking

1. Um grupo possui 2–10 appointments filhos, um por participante, todos na mesma unidade, serviço e hora de início. Cada filho pode ter profissional próprio.
2. Criação inicial é atômica: ou todos os filhos passam por elegibilidade, Availability Resolver, conflitos e `create_appointment`, ou nenhum é persistido.
3. Cada filho tem seu próprio checkout, status, profissional, duração, cancelamento e histórico. Não há consolidação de comanda nem alteração de `checkout_close` nesta Onda.
4. O grupo pode ser criado, editado e cancelado somente por staff autorizado, respeitando o mesmo permissionamento de agenda e o escopo de unidade existente.
5. Edição de um filho é independente; edição do grupo ou de filhos futuros é atômica no conjunto afetado. Adicionar participante cria novo filho sem alterar os existentes; falha no novo filho não desfaz o grupo.
6. Remover participante cancela o filho, nunca apaga histórico. O grupo fica ativo enquanto existir filho futuro confirmado; fica cancelado quando todos os filhos futuros forem cancelados.
7. O titular de cada filho é imutável. `appointment_participants` é a fonte única de presença daquele filho; `payer`/`beneficiary` são metadados operacionais por appointment, não faturamento consolidado.
8. O requester recebe o estado agregado; cada participante vê somente o próprio appointment; usuários internos autorizados veem o grupo completo. Falha de notificação não desfaz reservas confirmadas: o envio pertence a KortexLink/outbox e deve ser reprocessável.

### 3.3 Waitlist — modelo Booksy

1. O matcher consulta Availability Resolver e cria uma onda com todas as entradas `ACTIVE` elegíveis para o slot exato. O primeiro cliente que concluir vence; não existe escolha sequencial obrigatória.
2. A notificação não cria hold. `HOLDING` só pode existir durante a transação de confirmação atômica e não pode ser observado como hold persistente após commit.
3. Cada oferta é vinculada ao slot, profissional, serviço e unidade exatos. O link não permite trocar de horário ou de profissional.
4. A oferta vence em 30 minutos por padrão, configurável por organização. Expiração ou recusa retorna a entrada para `ACTIVE`, registra tentativa e aplica cooldown de 6 horas para a mesma entrada e o mesmo slot. A reserva de slot diferente continua elegível.
5. A aceitação exige `offer_id`, token opaco de uso único e validação de identidade por sessão autenticada ou OTP ao contato cadastrado. URL com `entry_id` visível não é autorização.
6. A confirmação bloqueia a entrada com CAS (`status = 'OFFERED'`), chama `create_appointment` e atualiza oferta/entrada na mesma transação. Qualquer erro faz rollback integral. O appointment só existe se a oferta vencedora também for registrada.
7. Ao vencer uma oferta, as demais da onda ficam `SUPERSEDED`. Entradas não vencedoras permanecem `ACTIVE`, sujeitas ao cooldown e a futuras ondas.
8. O matcher é idempotente: a mesma entrada não recebe duas ofertas abertas para o mesmo slot; retries retornam a oferta existente e não reenviam notificação.
9. Depois que a entrada vira `BOOKED`, ela é terminal. Cancelamento posterior do appointment não reativa a entrada; uma nova vaga pode disparar nova onda para entradas que ainda estejam `ACTIVE`.

## 4. Contrato físico de schema

### 4.1 `appointment_series`

Campos obrigatórios: `id`, `organization_id`, `unit_id`, `client_id`, `professional_id`, `service_id`, `anchor_date`, `local_start_time`, `recurrence_days` (`smallint[]` não vazio, 0=domingo…6=sábado), `recurrence_interval_weeks` (`smallint > 0`), `duration_minutes` (`integer > 0`, snapshot), `status` (`active|paused|cancelled`), `valid_from`, `valid_until`, `created_by`, timestamps.

`created_by` referencia `(organization_id, user_id)` em `memberships`. As FKs de cliente, profissional, serviço e unidade são tenant-safe; profissional e unidade também devem satisfazer o vínculo profissional↔unidade já existente. Há unicidade `(organization_id, id, unit_id)` para FKs compostas de ocorrências e RLS.

### 4.2 Extensões de `appointments`

Adicionar nullable `series_id` e nullable `group_id`. Cada uma referencia uma chave composta que inclui `organization_id`, id e `unit_id`, impedindo cruzamento de unidade mesmo com UUID válido. Criar/editar ocorrência passa sempre pelo `create_appointment` estendido; nenhuma inserção direta será concedida.

O contrato interno de `create_appointment` preserva a assinatura dos chamadores legados e aceita metadados opcionais server-owned no payload: `unit_id`, `series_id`, `group_id`, `duration_minutes` snapshot e `origin` (`direct|series|group|waitlist`). Para `series`, `group` e `waitlist`, `unit_id` e `origin` são obrigatórios, a unidade é validada contra membership/objetos relacionados e o Availability Resolver é obrigatório. Chamadores antigos preservam comportamento enquanto a flag da Onda estiver ausente/desligada.

`update_appointment` rejeita mudança de `client_id` após criação. Reagendamento, cancelamento e alterações autorizadas continuam incrementando `version` e respeitando CAS.

### 4.3 `appointment_series_conflicts`

Campos: `id`, `organization_id`, `unit_id`, `series_id`, `occurrence_date`, `candidate_starts_at`, `candidate_ends_at`, `reason_code`, `idempotency_key`, `status` (`OPEN|RESOLVED`), nullable `appointment_id`, timestamps. FKs de `series_id` e `appointment_id` incluem organização e unidade, com chaves únicas compostas correspondentes.

Unicidade por `(organization_id, series_id, occurrence_date)` e por chave idempotente. O reprocessamento aceita somente conflito aberto, revalida a política e chama `create_appointment`; resolução exige vínculo à ocorrência criada.

### 4.4 `appointment_groups`

Campos: `id`, `organization_id`, `unit_id`, `requester_client_id`, `status` (`DRAFT|SCHEDULED|PARTIAL|CANCELLED|COMPLETED`), `created_by` tenant-safe, timestamps. Há unicidade `(organization_id, id, unit_id)` para as FKs dos filhos. FKs são unit-safe quando apontam para requester/appointments. A cardinalidade 2–10 é garantida na RPC e por trigger/constraint de transição; nenhum filho pode apontar para grupo de outra organização/unidade.

`appointments.group_id` é o único vínculo necessário para descobrir membros: cada filho representa um participante e seu `client_id`; a linha titular em `appointment_participants` é criada automaticamente.

### 4.5 `appointment_participants`

Campos: `id`, `organization_id`, `unit_id`, `appointment_id`, `client_id`, `role` (`payer|beneficiary|payer_beneficiary`), timestamps. A FK de appointment inclui `(organization_id, appointment_id, unit_id)` e a FK de client inclui `(organization_id, client_id)`; unicidade `(organization_id, appointment_id, client_id)`.

Trigger `AFTER INSERT` em `appointments` cria a linha do titular com `role = payer_beneficiary`. A migration deve fazer backfill idempotente dos appointments existentes antes de declarar a fonte única completa; não haverá estado em que appointments legados fiquem sem titular por decisão de escopo.

### 4.6 `waitlist_entries` e preferências

`waitlist_entries` contém `id`, `organization_id`, `unit_id`, `client_id`, `service_id`, `date_from`, `date_to`, `status`, `consent_at`, `last_offered_at`, `cooldown_until`, `attempt_count`, timestamps. Estados: `ACTIVE|MATCHED|OFFERED|HOLDING|BOOKED|DECLINED|EXPIRED|SUPPRESSED`. Não há `hold_appointment_id` persistente: `HOLDING` é transacional e volta para `OFFERED` por rollback ou para `BOOKED` no commit.

`waitlist_entry_professionals` contém `organization_id`, `unit_id`, `waitlist_entry_id`, `professional_id`, com FKs compostas que amarram organização e unidade tanto à entrada quanto ao profissional, e unicidade por entrada/profissional. Zero linhas significa qualquer profissional elegível. A RPC também revalida elegibilidade tri-state e vínculo profissional↔unidade.

### 4.7 `waitlist_offers`

Campos: `id`, `organization_id`, `unit_id`, `waitlist_entry_id`, `offer_wave_id`, `candidate_starts_at`, `candidate_ends_at`, `candidate_professional_id`, `status` (`OFFERED|ACCEPTED|DECLINED|EXPIRED|SUPERSEDED`), `token_hash`, `expires_at`, `cooldown_until`, `idempotency_key`, `created_at`, `responded_at`. FKs de entrada e profissional incluem organização e unidade; a oferta não pode apontar para slot de outro tenant/unidade.

`token_hash` é armazenado, nunca o token bruto. Há unicidade por `idempotency_key` e por entrada + slot + profissional enquanto a oferta estiver aberta. `offer_wave_id` agrupa todas as ofertas simultâneas da vaga. O token é consumido uma única vez; replay retorna erro de domínio sem nova escrita.

### 4.8 Configuração e índices

Reutilizar `organizations.settings` com defaults ausentes/seguros: `recurring_group_waitlist_enabled=false`, `waitlist_offer_ttl_minutes=30` e `waitlist_offer_cooldown_hours=6`. A flag controla somente os novos caminhos; ausência ou `false` não altera booking legado.

Criar índices compostos para RLS/lookup por `(organization_id, unit_id)`, séries por janela futura, conflitos abertos por série, participantes por appointment, filhos por group, entradas `ACTIVE` por unidade/serviço/data e ofertas por onda/status/expiração. Nenhum índice pode omitir `organization_id` quando usado para autorização.

## 5. RPCs e compatibilidade

RPCs novas: `appointment_series_create`, `appointment_series_extend_window`, `appointment_series_update`, `appointment_series_cancel`, `appointment_series_conflict_retry`, `appointment_group_create`, `appointment_group_update`, `appointment_group_cancel`, `appointment_group_member_add`, `appointment_participant_add`, `waitlist_entry_create`, matcher idempotente nomeado na Etapa 8, `waitlist_offer_accept`, `waitlist_offer_decline` e `waitlist_offer_expire`.

`waitlist_offer_accept` não cria hold persistente: trava a entrada, valida token/OTP, executa CAS, chama `create_appointment` e confirma tudo na mesma transação. `waitlist_offer_expire` expira somente ofertas vencidas; não cancela appointment porque não há appointment de hold.

Todas as RPCs `security definer` fixam `search_path`, derivam o actor de membership, exigem `organization_id` consistente com o actor e aplicam escopo de unidade. Idempotência é obrigatória em criação de série, extensão, grupo, matcher e aceitação.

Chamadores existentes não recebem coluna obrigatória nova nem mudam sua assinatura pública. O trigger de titular e as extensões nullable são aditivas. O único comportamento existente deliberadamente endurecido é rejeitar mutação de `appointments.client_id`, porque a invariável de titular imutável foi aprovada e evita divergência entre appointment e participantes.

## 6. Execução e rollback

Dividir a Etapa 8 em migrations forward-only:

1. **Pre-flight, flag e schema aditivo:** validar organizações/unidades/memberships, criar chaves de settings, tabelas e extensões nullable, FKs unit-safe e índices básicos.
2. **Participantes e grupos:** criar trigger, executar backfill idempotente de titulares, criar `appointment_groups`, `group_id` e RPCs de criação/edição/cancelamento.
3. **Recorrência:** criar conflitos, estender `create_appointment`, RPCs de série e job contract de extensão, sem scheduler novo obrigatório.
4. **Waitlist:** criar entradas, preferências, ofertas, token hash, matcher, expiração e aceitação transacional; KortexLink permanece consumidor externo de notificações.
5. **RLS/grants/hardening:** policies unit-aware, `security definer` com `search_path` fixo, revoke de DML direto, pre-flight final e grants mínimos.

Rollback de schema é somente forward-only: não apagar dados de appointments existentes. Se uma etapa posterior falhar, a feature flag permanece `false`, RPCs sem grant de escrita e o schema aditivo fica inacessível ao cliente. Correções futuras usam migrations novas; não editar migrations aplicadas.

## 7. Matriz RLS e fronteiras

| Objeto | Leitura | Escrita |
|---|---|---|
| `appointment_series` | `private.can_access_fact_unit(organization_id, unit_id)` | Somente RPCs de série; staff autorizado na unidade e org-wide autorizado |
| `appointment_series_conflicts` | Mesmo escopo da série | Somente RPC de retry/serviço; nenhum DML direto |
| `appointment_groups` | `can_access_fact_unit` | RPCs de grupo, staff autorizado |
| `appointment_participants` | Via appointment + `unit_id` | Trigger e RPC de participante; sem grant direto |
| `waitlist_entries` | `can_access_fact_unit` e, em canal de cliente, somente a própria entrada | RPC de criação/declínio; matcher/aceitação server-owned |
| `waitlist_entry_professionals` | Via entrada | Somente RPC de preferência |
| `waitlist_offers` | Via entrada e, para cliente, somente oferta cujo token/identidade foi validado | Matcher e aceitação/declínio/expiração; sem DML direto |

Policies não usam somente `is_member`, pois isso permitiria vazamento entre unidades da mesma organização. FKs compostas amarram organização e unidade em cada relação cruzada. `organization_id` nunca vem isoladamente do cliente para autorizar acesso.

## 8. Gate de desenho e evidência

O Red Team de desenho revisou o schema real, o contrato de `create_appointment`, o padrão de RLS unit-aware da Onda 4, a exclusion constraint de appointments e os benchmarks Booksy/Square/Vagaro/Eventbrite. Dois achados críticos foram corrigidos antes deste veredito: (1) o contrato antigo não carregava unidade/série/duração nem consultava Availability Resolver; (2) o hold persistente da waitlist contradizia o modelo Booksy. Também foram corrigidos os gaps de FKs unit-safe, titular mutável, backfill ausente, oferta sem token/offer_id, deduplicação e estado concorrente sem `SUPERSEDED`.

**Veredito:** `GO` para desenho. DEC-52 autoriza a Etapa 8 exclusivamente em ambiente local/descartável, com pre-flight e testes pgTAP/Jest reais por fatia. Não autoriza `staging`, `main`, produção, deploy ou ativação da feature flag.

## 9. DOCUMENTATION_CHECK

- [x] Artefato classificado em `docs/waves/` e com frontmatter.
- [x] Migration Map, Master Briefing, Truth Map e precedentes reais consultados.
- [x] Issue rastreável e ADR/DEC atualizados no mesmo turno.
- [x] `docs/INDEX.md` atualizado para a nova onda.
- [x] Links locais afetados validados por busca/revisão; a Etapa 8 permanece explicitamente bloqueada.
