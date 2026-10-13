---
title: "ADR 0022 - Onda 4 Calendar Policy, Availability Resolver & Resource Orchestration"
status: "ACCEPTED"
stage: "ADR"
governance_ref: ["DEC-49"]
upstream_doc: "docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md"
last_updated: "2026-07-29"
---

# ADR 0022: Onda 4 — Calendar Policy, Availability Resolver & Resource Orchestration (Fundação sem Ativação)

## Status
**Accepted (DEC-49, 2026-07-29).** Decisões de desenho fechadas por interview (`$grill-me`) antes da redação. Red Team de **desenho** em 2 rodadas — 1ª autoavaliação, 2 achados menores corrigidos; 2ª agente independente, verificação achado a achado contra o código real: `NO-GO` inicial com 6 achados de schema/RLS — ver Blueprint Onda 4 §3.1/§3.3/§3.8/§4 e o rodapé "RED TEAM DE DESENHO" para a lista completa. Todos corrigidos antes da aprovação. Aprovado pelo Platform Owner em 2026-07-29 — ver DEC-49 no Decision Log (SEÇÃO 15).

**Etapa 8 (SQL) autorizada e concluída localmente na mesma sessão.** Um segundo Red Team, desta vez de **implementação** (código real das 6 fatias, não só o desenho), achou 8 gaps adicionais que o Red Team de desenho não podia ver por não existir código ainda: bypass de unit scope na rota Express (`req.params.unitId` nunca comparado a `req.auth.unitId`), `resource_locks` e elegibilidade tri-state (ADR 0010) ignorados pelo Resolver, isenção de `exceptional_opening` no trigger de turno com erro conceitual (comparava só `HH:MI`, ignorando que uma exceção de data única não pode autorizar um padrão recorrente semanal — **removida**, não corrigida), timezone de feriado org-wide usando a unidade default para todas as unidades, `resource_lock_release` aceitando segunda liberação, FK de `calendar_exceptions(scope='professional')` sem exigir vínculo profissional↔unidade, e `search_path` não fixado em 2 funções. Todos os 8 corrigidos e reverificados. Auditoria final de fix corrigiu ainda validação estrita de datas civis, ocupação em timezone local da unidade no Resolver e dois achados de `db lint` (`record` em helper SQL e parâmetro `p_reason` sem uso). Evidência final: 764/764 pgTAP, 321/321 backend, `supabase db lint --local` sem erros — ver issues `023`-`028` para o detalhamento por fatia e `RED TEAM DE IMPLEMENTAÇÃO` no rodapé desta ADR.

**Onda relacionada:** [Onda 4 — Calendar Policy, Availability Resolver & Resource Orchestration](../../waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md) · [Migration Map](../../waves/KORTEXOS_5_1_2_MIGRATION_MAP.md)

## Date
2026-07-29

## Context

A Onda 4 (Migration Map v1.2 §3, D02/D07/D11) cobre o domínio mais citado como `AUSENTE` pelo Truth Map: não existe hoje, em nenhuma migration, tabela alguma para horário de funcionamento, turno, feriado ou recurso físico. A única proteção de conflito de agenda em produção é a exclusion constraint de `appointments` (profissional + intervalo de tempo) — não consulta calendário nenhum.

### Escopo aprovado

Exatamente a tabela da Onda 4 no Migration Map: `calendar_policies`, `professional_shifts` (dependem de `units`, não de `organizations` — DEC-27), `resources`, `resource_locks`, e o Availability Resolver (D07) como motor sem tabela própria (Migration Map §4, decisão 3). `availability_slot_cache` fica explicitamente fora de escopo (mesma decisão).

### Motivações

1. **Precedente de risco (DEC-36, fatia 004 da Onda 1):** tocar `checkout_close`/`create_appointment` produziu o único bug crítico pós-merge do projeto até hoje. As Ondas 2 (ADR 0019) e 3 (ADR 0020) já adotaram "fundação sem ativação" pelo mesmo motivo — esta Onda repete o padrão pela terceira vez.
2. **A regra CRÍTICO do Master (§2.4) é mais forte que o precedente de `staff_levels`:** "Política de calendário versionada com vigência; histórico reconstruível" exige que a própria configuração tenha histórico consultável e possa ser agendada para o futuro — diferente de `staff_levels`, onde bastava o snapshot no appointment (ADR 0011) para satisfazer "não retroage".
3. **Leitura é estruturalmente diferente de escrita:** o Availability Resolver não protege nenhuma invariante transacional multi-tabela (ao contrário de `checkout_close`/`create_appointment`), então o motivo que levou `appointments` à Rota B na ADR 0012 (RPC única para atomicidade) não se aplica aqui.

### Constraints

- **Não tocar `checkout_close` nem `create_appointment` nesta Onda.** Mesmo princípio das Ondas 2 e 3.
- **`calendar_policies`/`professional_shifts`/`resources`/`resource_locks` são transacionais, `unit_id` direto** (Migration Map, DEC-28) — já decidido, só aplicado.
- **RLS unit-aware obrigatório** para os 7 objetos novos que carregam `unit_id` — não basta `is_member` org-wide (achado do red team, ver abaixo).
- **DEC-44:** Feature Flag em `organizations.settings` (coluna já existe desde a Onda 3), Pre-flight Check por migration, TDD com pgTAP/`node --test`, rastreabilidade via `closes issues/NNN`.

## Decision

### Fundação sem ativação — Resolver exposto por rota nova isolada, não por reescrita de RPC crítica

`create_appointment`/`checkout_close` não mudam de comportamento. O Availability Resolver é exposto via `GET /units/:unitId/availability`, rota inteiramente nova, atrás de feature flag (`availability_resolver_enabled`) default `false`. `resource_locks` não nasce automaticamente de um `appointment` — só via RPC isolada (`resource_lock_create`), mesmo padrão de "RPC pronta, sem call site automático" já usado por `commission_sale_record_create` na Onda 3.

**Alternativa rejeitada:** ativar validação de calendário dentro de `create_appointment` já nesta Onda. Rejeitada pelo mesmo motivo que a Onda 3 rejeitou ativar a cascata de preço em `checkout_close` — dobraria o raio de explosão numa RPC já crítica, replicando exatamente o padrão de risco que a ADR 0019 nomeou primeiro.

### Vigência de `calendar_policies`/`professional_shifts`: linhas versionadas com `valid_from`/`valid_to`, não ponteiro simples

Diferente de `staff_levels` (Onda 3), o Master exige aqui histórico da própria configuração e a capacidade de agendar uma mudança futura sem aplicá-la hoje. Cada nova versão insere uma linha; um trigger `BEFORE INSERT` fecha a linha anteriormente aberta, validando ordem cronológica (correção do red team — a formulação original não validava e produziria um erro genérico de exclusion constraint em vez de um erro de domínio compreensível). Linha fechada é imutável (nenhum grant de `UPDATE`/`DELETE`).

**Alternativa rejeitada:** 1 linha mutável + log de auditoria separado (mesmo padrão do `staff_levels` + `unit_access_audit_events`). Rejeitada — não satisfaz "vigência" no sentido de agendar uma mudança futura sem aplicá-la agora.

### Arquitetura do Resolver: Rota A — Express orquestra, Postgres resolve política

Funções SQL pequenas e isoladas (`private.resolve_calendar_policy`, `private.resolve_professional_shift`, `private.resolve_calendar_overrides`), `stable security definer`, testáveis via pgTAP. O loop de datas, a precedência de 7 níveis (Master §2.3) e a subtração de ocupação rodam em Express, testados via `node --test` (DEC-44 item 3).

**Alternativa rejeitada:** função `plpgsql` única fazendo tudo (Rota B, mesmo padrão de `resolve_commission`). Rejeitada — é leitura pura sem invariante multi-tabela para proteger atomicamente (o motivo que justificou Rota B em `appointments`, ADR 0012, não se aplica), e um algoritmo iterativo de geração de slots é mais testável e depurável em Express do que em `plpgsql`.

### `resource_locks`: concorrência otimista completa (não só o incremento de `version`) + bloqueio manual

Replica a exclusion constraint GiST de `appointments` e o trigger de incremento de `version`. `resource_lock_release` compara explicitamente a `version` recebida contra a atual e rejeita com `errcode = 'P0004'` se divergir — mesmo contrato de `update_appointment`. `appointment_id` é nullable, aceitando bloqueio manual/manutenção (`lock_reason in ('maintenance','blocked')`), capability que o Migration Map já cita como responsabilidade do D11.

**Correção de achado do Red Team:** a formulação original descrevia só o incremento de `version`, sem o passo de comparação/rejeição — exatamente a lacuna que a ADR 0012 diagnosticou e corrigiu para `appointments.version` antes de a correção existir. `resource_lock_create`/`resource_lock_release` não tinham contrato nenhum documentado apesar de referenciados em prosa; corrigido com assinatura completa no Blueprint §4.

**Alternativa rejeitada:** `appointment_id not null`. Rejeitada — deixaria "manutenção" (citada no Migration Map) sem materialização nenhuma nesta Onda.

### Fila de conflitos: trigger automático, nunca varredura manual

Master §2.4 (CRÍTICO): mudança de política não altera `appointments` confirmados — gera fila para resolução humana via Command. Um trigger `AFTER INSERT` em `calendar_policies`/`professional_shifts`/`calendar_holidays`/`calendar_exceptions`/`calendar_time_off` varre appointments confirmados que ficaram fora da nova janela e grava em `calendar_policy_conflicts`.

**Alternativa rejeitada:** RPC de varredura sob demanda. Rejeitada por interview — deixaria a fila "quebrada silenciosamente" até alguém lembrar de rodar.

### `calendar_holidays`: cadastro manual, sem seed de calendário nacional

Calcular datas móveis brasileiras (Páscoa/Carnaval/Corpus Christi) e cobertura estadual/municipal automática é fonte de verdade externa própria — mesmo racional já usado pelo Migration Map para adiar `availability_slot_cache`.

## Alternatives Considered

Ver seção "Decision" acima — cada decisão já documenta a alternativa rejeitada e o porquê, mesmo formato da ADR 0020.

## Consequences

### Aplicação
- **Imediato:** schema completo dos 8 objetos de política do Master §2.2 (consolidados em 6 tabelas, ver Blueprint §4 "Mapeamento do objeto Bloqueios pontuais"), `resources`/`resource_locks` e o Resolver, todos testáveis isoladamente via pgTAP/`node --test` antes de qualquer ativação.
- **RLS unit-aware desde o desenho:** os 7 objetos com `unit_id` usam `private.can_access_fact_unit`, não `is_member`. Corrigido 2 vezes na prática: no Red Team de desenho (antes de qualquer SQL existir) e de novo no Red Team de implementação, que achou um bypass equivalente na camada Express (a rota nunca comparava `req.params.unitId` a `req.auth.unitId` — `supabaseAdmin` usa `service_role` e ignora RLS, então nada mais protegia isso).
- **Deployment:** 6 migrations aditivas (uma por fatia vertical), nenhuma com split aditiva+hardening — não há dado MVP equivalente para backfillar.
- **Rollback:** todas as tabelas desta Onda são folha; nenhum objeto de Onda anterior ou futura depende delas.

### Código
- **Backend:** primeiro módulo desta trilha com lógica de orquestração real em Express testada via `node --test` (`backend/src/modules/availability/`) — as Ondas 2/3 só produziram funções SQL.
- **Frontend:** nenhuma UI nesta Onda.
- **Gates:** Gate 03 (Smart Availability) alcançável só no sentido restrito de "Resolver calcula candidatos corretos quando consultado"; Gates 04/08/09 permanecem `BLOQUEADO` por desenho — dependem de ativação futura, registrado explicitamente no Blueprint §3.6, não uma pendência silenciosa.

### Futuro
- **Onda de ativação:** bloquear escrita de `appointments` fora do turno/política, e produzir `resource_locks` automaticamente a partir de `create_appointment`, ficam para uma Onda própria futura — mesmo padrão de sequenciamento já usado 2 vezes.
- **Buffer/consumo técnico:** o Resolver v1 não consulta buffer de serviço (`PARCIAL` no Master §20.2) — limitação conhecida e registrada, não bloqueio.
- **`resource_locks` não reduz a disponibilidade retornada (limitação registrada, achado do Red Team de implementação):** nenhuma tabela do schema atual mapeia qual recurso um serviço/profissional exige — sem esse mapeamento, não há forma correta de saber que um `resource_lock` deveria afetar a agenda de QUAL profissional. Inventar uma regra agora (ex.: "bloqueia a unidade inteira") seria uma decisão de produto disfarçada de bugfix; decisão consciente do Platform Owner de não fazer isso nesta correção. `deposit_holds`, por outro lado, **é** coberto — estruturalmente não tem `starts_at`/`ends_at` próprios (`appointment_id not null`, sem colunas de intervalo), então sua ocupação já está inteiramente representada pela linha de `appointments` já consultada.
- **`private.resolve_calendar_overrides` retorna um booleano por dia, não uma janela (limitação registrada, achado do Red Team de implementação):** um fechamento ou folga que cobre só parte do dia (ex.: 2 horas) faz o dia inteiro ficar sem slots para aquele profissional, não só as horas realmente indisponíveis. Direção conservadora (mostra menos slots do que existem de verdade, nunca mais), mas é uma imprecisão real — corrigi-la exigiria a função retornar janelas, não um booleano, mudança de contrato maior que o escopo desta correção.
- **Seed de feriados:** revisitável se virar necessidade real comprovada.

## Related Decisions

- **DEC-24/27/28:** Migration Map v1.2 — Onda 4 mapeada, `calendar_policies`/`professional_shifts` dependem de `units` (DEC-27), classificação de escopo por unidade (DEC-28).
- **DEC-44:** protocolo de otimização de código (Dark Launching, Pre-flight Check, TDD, rastreabilidade) — segunda Onda a aplicá-lo integralmente (depois da Onda 3).
- **DEC-49:** aprovação formal deste Blueprint/ADR.
- **ADR 0012:** fork arquitetural Rota A/B — precedente direto para a decisão de arquitetura do Resolver (Rota A, motivo inverso: leitura pura, não escrita transacional).
- **ADR 0016 (Onda 0):** `units`/`professional_units`/`private.can_access_fact_unit` — fundação da qual `calendar_policies`/`professional_shifts` e o RLS unit-aware desta Onda dependem diretamente.
- **ADR 0019 (Onda 2), ADR 0020 (Onda 3):** precedentes de "fundação sem ativação" — terceira aplicação do mesmo padrão.

## Verification

**Corrigido em 2026-07-29** — esta seção dizia "nenhuma migration escrita ainda", desatualizada desde que a Etapa 8 foi autorizada e concluída na mesma sessão da aprovação do desenho; a versão anterior nunca foi atualizada, produzindo uma contradição com o Status (achado do Red Team de implementação, corrigido aqui).

✅ Red Team de **desenho**, 2 rodadas — 2ª rodada com verificação achado a achado contra o código real, citações mais carregadas reverificadas pessoalmente antes de aceitar. GO após 6 correções.
✅ Etapa 8 (SQL) autorizada pelo Platform Owner e concluída — 6 fatias (issues `023`-`028`), migrations `20260729010000`-`20260729060000`.
✅ Red Team de **implementação** (código real, pós-Etapa 8) — 8 achados adicionais (ver Status acima), todos corrigidos e reverificados pessoalmente contra o código antes de aceitar o relato.
✅ Auditoria final de fix: datas civis impossíveis agora são rejeitadas, appointments noturnos em unidades a oeste de UTC são subtraídos pela data local correta, `private.record_calendar_policy_conflict` não usa mais `record` e `resource_lock_create` valida `p_reason`.
✅ Suíte completa após todas as correções: pgTAP 764/764 (`supabase test db`), backend 321/321 (`node --test`) e `supabase db lint --local --schema public,private --level warning --fail-on error` sem erros — sem regressão.
✅ `search_path` confirmado fixado em `private.valid_weekly_schedule`/`public.local_time_to_utc` por consulta direta a `pg_proc.proconfig`, não só por inspeção do texto da migration.
⚠️ Nenhum chamador existente (`appointments.service.js`, `checkout.service.js`) foi modificado — confirmado por diff, não só por busca textual como na versão original desta seção.
⚠️ Ainda não commitada nem mesclada em `staging`/`main` — `NO-GO` para promoção até os gates de ambiente/entrega/homologação (mesmo estado de todas as Ondas anteriores desta trilha).
