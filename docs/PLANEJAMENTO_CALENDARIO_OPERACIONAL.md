# Planejamento — Calendário Operacional & Availability Engine

Status: PROPOSTA — não aloca fase de execução; alocação oficial vive em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md`.
Supersede: nada. Referência de visão (não-autoridade técnica): `docs/legacy/KORTEXOS_5_1_1_MASTER_BRIEFING_CANONICO.md` §7, §6.3.

**Ordem de leitura antes deste documento:** `AGENTS.md` → `docs/PROJECT_STATE.md` → `docs/KORTEX_MVP_TECNICO.md` → `docs/PLANEJAMENTO_EXECUCAO_UNIFICADO.md`.

Este documento nasce de dois prompts consolidados do usuário exigindo auditoria + blueprint canônico de um "Calendário Operacional & Staff Availability" e de uma "Engine de Agenda Dinâmica". São domínios acoplados mas com ciclo de vida distinto: este documento cobre **configuração de disponibilidade** (o que existe/pode existir); `docs/PLANEJAMENTO_AGENDA_TRANSACIONAL.md` cobre **o motor de mutação** (como um agendamento muda de estado). O par espelha a relação já existente entre `PLANEJAMENTO_FINANCEIRO`/`PLANEJAMENTO_COMISSOES`.

---

## 1. Veredito executivo

A agenda real do MVP é um **CRUD de intervalos com uma única garantia forte**: exclusion constraint GiST por `(organization_id, professional_id, tstzrange)` para status ativos. Tudo que uma "Availability Engine" pressupõe — jornadas, exceções, feriados, bloqueios, pausas, timezone — está **AUSENTE**. Isso não é uma falha do MVP: os próprios docs (`KORTEX_MVP_TECNICO.md §5`, `PLANEJAMENTO_ROADMAP_POS_MVP.md` D07/D08) classificam essa constraint como a implementação suficiente da Fase 1-7, e reconhecem jornada/recursos como fora de escopo (D11). O que este documento faz é **desenhar o próximo degrau**, não corrigir um erro.

Achado que muda o desenho do briefing recebido: **não existe entidade "unidade" no schema** — tudo é `organization_id`-scoped (uma organização = um salão). O briefing assume múltiplas unidades por tenant. Isso vira decisão explícita (§5), não herança silenciosa.

## 2. Estado real auditado (evidência file:line)

Auditoria feita por agente Explore nesta sessão, cruzando migrations, backend, frontend e testes.

| Capacidade | Estado | Evidência |
|---|---|---|
| Tabela `appointments` (client/professional/service, starts_at/ends_at) | **REAL** | `supabase/migrations/20260712235319_mvp_baseline.sql:165-188` |
| Não-sobreposição por profissional (exclusion constraint GiST) | **REAL** | `mvp_baseline.sql:183-187` — `exclude using gist (organization_id =, professional_id =, tstzrange(starts_at,ends_at,'[)') &&) where status in ('scheduled','confirmed','in_service')` |
| Semântica half-open (`[)`, agendamentos costa-a-costa não colidem) | **REAL, provado** | pgTAP `rls_business_tables_test.sql:153` (`lives_ok` para 10:30 após 10:00-10:30) |
| Isolamento multi-tenant (FK composta) | **REAL** | `mvp_baseline.sql:179-182`; teste `rls_business_tables_test.sql:166` |
| Duração do serviço (`services.duration_minutes`) | **REAL** | `mvp_baseline.sql:143` |
| `ends_at` derivado da duração — no cliente, não no servidor | **PARCIAL/HARDCODED, risco** | Frontend `AppointmentModal.jsx:55-59`; backend aceita `ends_at` arbitrário (`appointments.validation.js:44-46`) — cliente de API pode enviar qualquer duração |
| Grade visual (granularidade, horário comercial) | **HARDCODED** | `dateUtils.js:5-7` — `SLOT_MINUTES=30`, `DAY_START_HOUR=7`, `DAY_END_HOUR=21`; comentário linhas 71-79 admite ser "piso fixo do MVP" |
| Timezone da organização | **AUSENTE** | 0 hits de `timezone` em migrations; `organizations` sem coluna tz |
| Template semanal de horário (unidade) | **AUSENTE** | Nenhuma tabela |
| Jornada semanal por profissional | **AUSENTE** | `professionals` só tem `user_id/name/active` (`mvp_baseline.sql:125-136`) |
| Exceções de data / feriados | **AUSENTE** | 0 hits |
| Bloqueios / pausas | **AUSENTE** | 0 hits |
| Ausências / férias | **AUSENTE** | 0 hits |
| Vínculo profissional×serviço (elegibilidade) | **PARCIAL — proposto, não implementado** | `professional_service_commissions` existe mas é override de *comissão*, não elegibilidade de capacidade; `professional_service_capabilities` é a Fase 10 do plano unificado, ainda não codificada |
| Resolução de disponibilidade (cálculo de slots livres) | **AUSENTE** | Nenhum endpoint; frontend só faz *placement* visual (`AgendaPage.jsx:350-364`), não calcula livre/ocupado além do que já está na tela |

## 3. Causa raiz

O MVP resolveu a agenda "de trás para frente": em vez de derivar disponibilidade de uma política declarada (jornada + exceções), ele valida apenas contra **appointments que já existem** — a exclusion constraint impede colisão entre agendamentos, mas nunca pergunta "esse horário está dentro do expediente de alguém?". Isso é suficiente para o MVP porque a recepção humana já sabe o expediente de cor; deixa de ser suficiente no momento em que o sistema precisa **responder sozinho** "quais horários estão livres" (portal do cliente, waitlist, sugestão de horário alternativo) — nenhum desses casos de uso tem hoje um numerador confiável do que é "aberto".

## 4. Pesquisa global (regra de ouro)

**Modelos de disponibilidade em produtos de scheduling geral:**
- **Cal.com** (open source, schema inspecionável): cada usuário tem um ou mais `Schedule`, cada `Schedule` tem `availability[]` (dia da semana + startTime/endTime) e `overrides[]` (data específica + startTime/endTime, ou fechado). Um `AvailableSlotsService` agrega: schedule do usuário + busy times (calendário/bookings) + limites de booking + recursos, para gerar slots. **Confirma exatamente a separação "template semanal" vs. "exceção de data" como duas coleções distintas, nunca uma reescrevendo a outra** — a mesma exigência do briefing recebido.
- **Google Calendar API**: `freeBusy` devolve só intervalos ocupados (busy), sem noção nativa de "horário de expediente" — quem calcula expediente × ocupação é a aplicação cliente. Confirma que "expediente" é responsabilidade de domínio, não do provedor de calendário.
- **Nicho direto (Brasil)**: Trinks documenta "Feriados e Horários Especiais" e "Liberações de Horários na Agenda" como funcionalidades **distintas** — feriado/exceção de unidade é uma tela, liberação pontual de horário do profissional é outra. Confirma a separação template×exceção também no nicho local, não só em produtos internacionais.

**Postgres — exclusion constraints e concorrência (já em uso no projeto):**
- Padrão confirmado: `EXCLUDE USING gist (recurso WITH =, tstzrange(...) WITH &&) WHERE (status = 'ativo')` é a "melhor prática" para não-sobreposição sob concorrência — não há caminho de escrita que escape da constraint, ao contrário de checagem em código de aplicação. **O projeto já faz isso certo** (`mvp_baseline.sql:183-187`); a extensão para jornada/recurso é aditiva, não uma correção.
- Coluna de versão (lock otimista) é complementar, não substituta, à exclusion constraint: a constraint impede sobreposição temporal; a versão protege contra dois updates concorrentes no mesmo registro que não conflitam temporalmente (ex.: duas edições simultâneas de observações do mesmo appointment).

**Recorrência (RRULE, RFC 5545):**
- A especificação completa de recorrência do iCalendar tem "dezenas de páginas"; escrever um expansor client-side correto "é um projeto, não uma função". Bibliotecas maduras (Cal.com, Nylas) preferem expandir server-side sob demanda, nunca client-side.
- **Conclusão para este documento**: jornada semanal de profissional não precisa de RRULE — é só "dia da semana → intervalos", igual ao Cal.com `Schedule.availability`. RRULE só se justificaria para **agendamentos recorrentes de cliente** (fora de escopo deste documento — é `PLANEJAMENTO_ROADMAP_POS_MVP.md` D09, Fase 14+ do horizonte reservado).

**Timezone e DST:**
- Melhor prática confirmada: armazenar timezone IANA (`America/Sao_Paulo`) por organização, nunca offset fixo; `timestamptz` para o materializado (appointments), horário local para a política recorrente (template semanal).
- **Simplificação relevante para este projeto**: o Brasil aboliu o horário de verão em 2019 — `America/Sao_Paulo` não tem mais transições DST correntes. O código deve ainda usar a biblioteca de timezone corretamente (não hardcode de offset), mas o risco prático de "hora que desaparece/duplica" é baixo no horizonte atual, ao contrário do que a pesquisa genérica de DST sugere para mercados que ainda praticam.

## 5. Decisões canônicas propostas (cada uma vira ADR quando o usuário fechar)

| # | Decisão | Recomendação (pesquisa) | Por quê |
|---|---|---|---|
| 1 | Timezone: por organização ou hardcode? | Coluna `organizations.timezone` (IANA, default `America/Sao_Paulo`) | Decisão ÚNICA compartilhada com a fronteira de mês da Fase 12 (comissão) — não pode ser decidida duas vezes em dois lugares |
| 2 | "Unidade" existe como entidade? | **Não agora.** MVP = unidade ≡ organização; desenho das novas tabelas usa `organization_id`, não `business_unit_id`, mas evita nomes/constraints que impeçam adicionar `business_unit_id` depois | O briefing assume multiunidade; o schema real não tem essa entidade e criá-la sem uso real é sofisticação sem evidência (violaria o próprio princípio de evolução do briefing, §3.2) |
| 3 | Template semanal e exceção de data são entidades separadas? | **Sim** — confirmado por Cal.com e por Trinks (nicho local) | Convergência de dois mercados diferentes na mesma separação |
| 4 | Usar RRULE para jornada de profissional? | **Não.** "Dia da semana → intervalos" simples, igual Cal.com `Schedule.availability` | RRULE é over-engineering para um padrão que se repete toda semana igual; a complexidade de implementação (dezenas de páginas de spec) não se paga aqui |
| 5 | Materializar slots previamente ou calcular sob demanda? | **Sob demanda.** Nenhuma tabela de "slots" persistidos | Nenhum produto pesquisado (Cal.com, Google) persiste slot — todos calculam na consulta a partir de janelas de trabalho menos ocupação |
| 6 | Precedência de resolução (quando regras conflitam) | Ver §6 abaixo — hierarquia determinística, nunca "última alteração vence" | Exigência explícita do briefing, e é o único jeito de a engine ser auditável |

## 6. Modelo de domínio proposto

**Entidades novas (todas `organization_id`-scoped, sem entidade "unidade" — decisão #2):**

- `business_hours_template` — template semanal da organização: dia da semana (0-6) + lista de intervalos `[hora_inicio, hora_fim)` locais. Múltiplos intervalos por dia (turno dividido) suportados nativamente pela lista, sem necessidade de linha "almoço" especial.
- `business_hours_exception` — exceção por data única: `date` + `status` (`closed` | `open_custom`) + intervalos quando `open_custom`. Fechar um feriado = uma linha `closed`; abrir excepcionalmente um domingo = uma linha `open_custom` com intervalos.
- `professional_working_hours_template` — mesmo formato do template da organização, mas por `professional_id`. Profissional sem linha = **decisão em aberto** (ver §5 item pendente: herda expediente da organização, ou fica indisponível por padrão? Recomendação: indisponível por padrão — "unidade aberta não implica profissional disponível", exigência textual do briefing).
- `professional_working_hours_exception` — mesmo formato, por profissional + data (folga pontual, jornada especial, atestado).

**Semântica temporal**: `date`+`time` local para as quatro tabelas acima (recorrentes/declarativas); `timestamptz` continua sendo a verdade materializada em `appointments` — igual à distinção Cal.com Schedule (local) vs. Google `freeBusy` (UTC/instante).

**Modelo de resolução (fórmula do briefing, adotada — é matematicamente correta e já é o padrão do mercado pesquisado):**

```text
disponibilidade_reservavel =
    horario_efetivo_organizacao
  ∩ horario_efetivo_profissional
  ∩ elegibilidade_servico_profissional        (Fase 10 — professional_service_capabilities)
  − ausencias_e_bloqueios
  − appointments_ativos                       (já garantido pela exclusion constraint)
  − buffers                                   (Fase 10 — duration_override/buffer da capacidade)
```

**Precedência (adaptada — sem "recursos" nem "múltiplas unidades", que não existem no schema real):**

```text
1. timezone da organização
2. template semanal da organização
3. exceção da organização por data
4. template semanal do profissional
5. exceção individual do profissional por data
6. elegibilidade serviço × profissional (Fase 10)
7. appointments/holds existentes (exclusion constraint)
```

Regras incompatíveis na mesma camada (ex.: duas exceções de data para o mesmo profissional na mesma data) devem gerar erro de constraint (`UNIQUE(organization_id, professional_id, date)` na tabela de exceção) — nunca "a última salva vence" silenciosamente, exigência textual do briefing e trivial de garantir com `UNIQUE`.

## 7. Matriz de conflitos (config, não mutação — a matriz de mutação de appointment vive no doc Transacional)

| Código | Descrição | Decisão |
|---|---|---|
| `ORG_HOURS_EXCEPTION_DUPLICATE` | Duas exceções de organização na mesma data | Bloqueado por `UNIQUE` |
| `STAFF_HOURS_EXCEPTION_DUPLICATE` | Duas exceções do mesmo profissional na mesma data | Bloqueado por `UNIQUE` |
| `STAFF_HOURS_OUTSIDE_ORG_HOURS` | Jornada do profissional definida fora do expediente da organização | Permitido para registrar (ex.: profissional que abre a loja sozinho é uma decisão de produto, não erro de dado) — mas resolvido pela interseção no cálculo, nunca vira agendamento reservável |
| `ORG_CLOSED_STAFF_STILL_WORKING` | Unidade fechada (exceção `closed`) mas profissional tem jornada ativa naquele dia | Resolução: interseção é vazia — "profissional não pode abrir sozinho uma unidade fechada" é garantido pela própria fórmula (∩), não precisa de regra extra |

## 8. Contratos propostos (leitura; mutação de appointment fica no doc Transacional)

```text
query_operational_calendar(organization_id, professional_id?, period_start, period_end)
  → devolve templates + exceções efetivas no período (para renderizar a UI de configuração)

query_resolve_effective_availability(organization_id, professional_id, service_id, date)
  → devolve os intervalos livres do dia, já aplicando toda a precedência do §6
  → ESTE é o endpoint que substitui o cálculo hoje inexistente; consumido pelo doc Transacional
    para oferecer horários e pela futura Waitlist (Fase 16)

command_update_business_hours_template(organization_id, template[])
command_update_staff_working_hours_template(organization_id, professional_id, template[])
command_create_hours_exception(organization_id, professional_id?, date, status, intervals?)
command_revert_hours_exception(organization_id, exception_id)
```

Todos os `command_*` exigem papel `owner/admin/manager` (mesmo gate de `WRITE_ROLES` já usado em `appointments.route.js:15`), auditados (autor + antes/depois — ver §9), idempotentes por natureza (são `UPSERT` por dia/data, não replay de evento).

**Sobre Change Sets (preview/apply/revert em lote) do briefing**: **não recomendado para o MVP deste domínio.** É uma máquina de staging pesada (DRAFT→PREVIEWED→APPLIED→PARTIALLY_FAILED→REVERTED→CANCELLED) sem caso de uso demonstrado num salão único com poucos operadores. A alternativa proposta: edição direta template/exceção + auditoria append-only (§9) cobre o mesmo resultado prático ("consigo ver o que mudou e desfazer") com uma fração da complexidade. Fica registrado como decisão em aberto — se o volume de mudanças em lote (ex.: fechar a semana inteira do Carnaval) justificar, Change Set volta à mesa como extensão, não como base.

## 9. Auditoria

Uma tabela append-only (`calendar_change_log` ou equivalente), não três (auditoria + history + outbox do briefing) — não existe hoje nenhum consumidor de evento no sistema (a mensageria da Fase 13 é manual via `wa.me`, não hoowanto assíncrono) para justificar um outbox: outbox sem consumidor é tabela morta. Quando o primeiro consumidor de evento real existir (ex.: notificação automática de fechamento excepcional), o outbox nasce junto com ele, não antes.

## 10. Red team do próprio desenho (incl. blind spots do briefing)

1. **Ausência de "unidade" não é um placeholder esquecido, é uma decisão consciente (§5 item 2).** Se o produto crescer para multiunidade, `organization_id` vira o nível "empresa" e precisa de uma entidade nova — migração real, não uma coluna a mais. Registrado, não resolvido aqui.
2. **`staff_service_override` do briefing (duração/buffers/preço por profissional×serviço) NÃO é uma tabela nova deste documento — é a Fase 10 já planejada (`professional_service_capabilities`).** Duplicar seria violar a regra "não crie segunda fonte de verdade" do próprio briefing. Este documento consome a saída da Fase 10, não a redesenha.
3. **Profissional sem jornada cadastrada:** decisão em aberto explícita — default "indisponível" é mais seguro (nunca oferece um horário que ninguém confirmou), mas pode surpreender quem espera "se não configurei, assume o expediente da loja". Fica para o usuário decidir antes de a Fase 14 começar.
4. **Exceção de organização que fecha um dia com appointments confirmados já marcados:** este documento não resolve "o que fazer com os appointments existentes" — é comportamento de **mutação**, tratado no doc Transacional (`GRANDFATHER_EXISTING` vs. `STRICT` do briefing). Aqui só fica registrado que a query de impacto (`appointments afetados por uma mudança de config`) precisa existir antes de qualquer exceção de organização ser aplicada em produção — senão fecha-se a loja sem saber quem tem hora marcada.

## 11. Proposta de faseamento (mapeia o Pareto do briefing para fases do plano unificado — não numera aqui)

Ordem sugerida, herdando o Pareto do briefing (templates → exceções → individual → resolução → constraints → auditoria):
1. Timezone da organização (decisão #1, compartilhada com Fase 12).
2. `business_hours_template` + `professional_working_hours_template` (CRUD + RLS + pgTAP).
3. `business_hours_exception` + `professional_working_hours_exception`.
4. `query_resolve_effective_availability` (a Availability Engine propriamente dita).
5. Auditoria append-only das quatro tabelas.
6. UI de configuração (mini calendário, seleção de dia/semana) — só depois dos contratos fechados, igual o briefing exige ("não implementar UI antes de fechar contratos").

A alocação de número de fase (proposta: Fase 14) é registrada em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md §4`, não aqui.

## 12. Gates e testes mínimos

- pgTAP: abrir domingo fechado; abrir feriado; fechar dia normalmente aberto; jornada especial individual; múltiplos intervalos no mesmo dia; profissional com jornada em dia que a unidade está fechada (interseção vazia); exceção duplicada rejeitada por `UNIQUE`; isolamento multi-tenant (mesmo padrão de `rls_business_tables_test.sql`).
- Teste de timezone: jornada declarada 09:00-18:00 America/Sao_Paulo resolve para o `timestamptz` correto sem depender do timezone do servidor.
- Teste de resolução: serviço de 45 min só oferece início às 09:10 se a grade de exibição permitir clique em 09:10 (ver doc Transacional para a separação grid×duração) — cruza os dois documentos, teste vive em ambos.

## 13. Rollback

Todas as tabelas novas são aditivas (não alteram `appointments` nem a exclusion constraint existente); rollback = `DROP TABLE` reversível sem perda de dados de negócio já existentes, porque nenhuma tabela nova é referenciada por `appointments` nesta fase (a Availability Engine é consumida, não é dependência de escrita).

## 14. Critério de aceite documental

Este documento está pronto para virar fase executável quando: (a) o usuário decidir os itens do §5; (b) `PLANEJAMENTO_EXECUCAO_UNIFICADO.md` alocar o número de fase; (c) a Fase 9 fechar seu próprio gate (pré-requisito transversal já registrado no plano unificado).

## 15. Próxima ação única

Usuário resolve as decisões do §5 (especialmente #2 unidade e o default de profissional-sem-jornada do §10.3); depois disso, alocar Fase 14 em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md`.

## 16. Fontes

- [Cal.com Docs — Create a schedule](https://cal.com/docs/api-reference/v2/schedules/create-a-schedule)
- [Cal.com — Date Overrides vs. Out-of-Office Settings](https://cal.com/blog/mastering-cal-com-date-overrides-vs-out-of-office-settings)
- [Cal.com — What are Date Overrides](https://cal.com/blog/what-are-date-overrides-and-how-do-i-enable-them)
- [Google for Developers — Freebusy: query](https://developers.google.com/workspace/calendar/api/v3/reference/freebusy/query)
- [Trinks — Feriados e Horários Especiais](https://ajuda.trinks.com/feriados-e-hor%C3%A1rios-especiais-central-de-ajuda-do-trinks)
- [Trinks — Liberações de Horários na Agenda](https://ajuda.trinks.com/pt-BR/articles/5269519-liberacoes-de-horarios-na-agenda)
- [jusdb — PostgreSQL Range Types and Exclusion Constraints](https://www.jusdb.com/blog/postgresql-range-types-exclusion-constraints)
- [DEV Community — PostgreSQL EXCLUDE constraints for better concurrency](https://dev.to/franckpachot/postgresql-exclude-constraints-for-better-concurrency-than-serializable-pob)
- [dateutil — rrule documentation](https://dateutil.readthedocs.io/en/stable/rrule.html)
- [RFC 5545 — iCalendar](https://datatracker.ietf.org/doc/html/rfc5545)
- [datetimeapp — Handling Daylight Saving Time in Applications](https://www.datetimeapp.com/learn/handling-daylight-saving-time)
