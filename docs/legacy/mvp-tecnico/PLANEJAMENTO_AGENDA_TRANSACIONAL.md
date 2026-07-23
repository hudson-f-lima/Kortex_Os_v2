# Planejamento — Agenda Dinâmica Transacional

Status: PROPOSTA — não aloca fase de execução; alocação oficial vive em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md`.
Supersede: nada. Referência de visão (não-autoridade técnica): `docs/legacy/KORTEXOS_5_1_1_MASTER_BRIEFING_CANONICO.md` §7.2, §7.8.

**Ordem de leitura antes deste documento:** `AGENTS.md` → `docs/PROJECT_STATE.md` → `docs/KORTEX_MVP_TECNICO.md` → `docs/PLANEJAMENTO_EXECUCAO_UNIFICADO.md` → `docs/PLANEJAMENTO_CALENDARIO_OPERACIONAL.md` (este documento consome `query_resolve_effective_availability` de lá).

Este documento cobre o **motor de mutação** de agendamentos: como um `appointment` muda de horário, profissional, serviço ou duração com segurança transacional. É o par do `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md` (que cobre configuração de disponibilidade).

---

## 1. Veredito executivo

O backend atual **delega 100% da validação de conflito ao banco** (a exclusion constraint) e **não deriva `ends_at` no servidor** — o achado mais sério desta auditoria: um cliente de API pode hoje enviar qualquer duração, independente do serviço vendido. Não há máquina de estados de status (um `completed` pode ser movido de volta para `scheduled`), não há lock otimista, não há auditoria de mutação de agenda. Nenhuma dessas lacunas é nova — os testes existentes (`appointments.test.js`) provam exatamente o que existe hoje (RBAC, validação de referência, conflito 409) e não testam o que não existe. A proposta aqui é fechar os três achados de hardening como extensão da Fase 10 (decisão já registrada em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md`) e desenhar o contrato de mutação completo (drag/resize/troca) como fase própria, consumindo a Availability Engine do documento irmão.

## 2. Estado real auditado — específico de mutação (a tabela completa vive em `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §2`)

| Capacidade | Estado | Evidência |
|---|---|---|
| `ends_at` calculado no backend a partir de `services.duration_minutes` | **AUSENTE — risco de integridade** | `appointments.validation.js:44-46` aceita qualquer `ends_at` desde que `> starts_at`; cálculo real só existe em `AppointmentModal.jsx:55-59` (frontend) |
| Validação de transição de status | **AUSENTE** | `appointments.validation.js:21-26` só valida pertença ao enum, nenhuma FSM; um `completed` pode voltar a `scheduled` |
| Lock otimista (`appointments.version`) | **AUSENTE** | Sem coluna; update é `UPDATE...SELECT()` direto (`appointments.service.js:75-87`), sem `expectedVersion` |
| Revalidação de conflito no `update()` | **Delegada ao banco, não à aplicação** | `appointments.service.js:75-87` não faz SELECT prévio de overlap; confia 100% na exclusion constraint, que dispara `23P01` → 409 (`postgresError.js:15-19`) |
| Auditoria de mutação (quem moveu o quê) | **AUSENTE** | 0 hits de `audit`/`history` em migrations |
| Idempotência em mutações de agenda | **AUSENTE** | `Idempotency-Key` só existe nas RPCs financeiras (`private.idempotency_keys`); `appointments.route.js` não usa |
| Drag-and-drop / resize na UI | **AUSENTE** | `AgendaPage.jsx` só tem `<button onClick>`; reagendar = abrir modal e editar campo |
| Sugestão de horário alternativo no conflito 409 | **AUSENTE** | Gap já reconhecido em `PWA_PLANEJAMENTO.md:125` |

## 3. Causa raiz

O MVP tratou "mover um agendamento" como "editar um registro" (PATCH genérico), não como uma operação de domínio com semântica própria. Isso é suficiente enquanto a única coisa que pode dar errado é sobreposição de horário (coberta pela constraint) — deixa de ser suficiente no momento em que mover um agendamento também deveria recalcular duração (profissional diferente pode ter buffer diferente, Fase 10), preço de referência e comissão, ou exigir confirmação por impacto (ex.: mudar o profissional de um cliente que tinha preferência).

## 4. Pesquisa global (regra de ouro)

**Exclusion constraints + concorrência (Postgres):** confirmado como a prática correta — "o constraint e o lock são aplicados pelo único componente que todo caminho de escrita atravessa: o banco. Não há como esquecer, não há como pular via shell". O projeto já faz isso certo para sobreposição temporal. **Lock otimista via coluna de versão é complementar, não redundante**: a exclusion constraint resolve conflito *temporal*; a versão resolve conflito de *edição concorrente do mesmo registro* (ex.: duas recepções editando observações do mesmo appointment ao mesmo tempo, sem overlap de horário). Ambos coexistem sem se substituir — confirma a recomendação do briefing.

**Padrão de reserva em duas fases (hold→confirm):** a pesquisa direta em Calendly/OpenTable não achou documentação pública detalhada do mecanismo interno (conteúdo pago/não publicado), mas o princípio geral de "double-booking em escala" é confirmado por múltiplas fontes: o invariante central é *"para cada (recurso, intervalo), no máximo uma reserva confirmada"* — exatamente o que a exclusion constraint já garante. A pergunta relevante não é "temos hold?", é "a confirmação passa pelo mesmo caminho transacional sempre?" — que hoje é verdade (uma única RPC/endpoint), então o ganho de um `move-plan` explícito é **UX** (mostrar o antes/depois antes de comprometer), não integridade adicional — a integridade já está garantida pela constraint.

**Escala do problema (dimensionamento):** um salão único, poucos operadores simultâneos (recepção + gerente), não é o cenário de "duas recepções movendo appointments para o mesmo horário" em alta frequência que justificaria um token de plano persistido com TTL e garbage collection. Isso pauta a recomendação do §8.

**RRULE / iCalendar para recorrência:** não é sobre agenda transacional em si (é do doc irmão), mas confirma novamente: recorrência de agendamento (Fase 14+ do horizonte reservado) não deveria adotar o motor de recorrência-cliente completo do RFC 5545 sem necessidade demonstrada.

## 5. Decisões canônicas propostas

| # | Decisão | Recomendação | Por quê |
|---|---|---|---|
| 1 | `ends_at` calculado onde? | **Server-side**, a partir da resolução de duração (Fase 10 `professional_service_capabilities` → fallback `services.duration_minutes`). API para de aceitar `ends_at` livre. | Correção de segurança — hoje é contornável por qualquer cliente de API; não é feature nova, é fechar um buraco |
| 2 | Lock otimista? | **Sim** — coluna `appointments.version integer not null default 1`, incrementada a cada UPDATE; cliente envia `expected_version`; divergência → `APPOINTMENT_STALE` | Complementar à exclusion constraint (pesquisa §4); resolve a classe de conflito que a constraint não cobre |
| 3 | Validação de transição de status? | **Sim** — guard determinístico sobre o enum atual (`scheduled→confirmed→in_service→completed`, mais `cancelled`/`no_show` como saídas; `completed` é terminal, exceto reversão privilegiada auditada) | Fecha o achado "completed pode ser movido de volta" sem adotar os 8 estados do briefing de uma vez |
| 4 | Adotar os 8 estados do briefing (`DRAFT/HOLD/PENDING_PAYMENT/.../EXPIRED`)? | **Não agora — mapear, não adotar.** `HOLD`/`PENDING_PAYMENT`/`EXPIRED` pressupõem portal público de cliente e pagamento online, que são Fase 15+ (bloqueados hoje). Migração de enum é decisão cara e real, não deve ser feita por antecipação | Regra do repositório: "não preservar numeração/nomes de fontes externas sem justificativa técnica atual" — aplica-se igualmente a enums de fonte externa |
| 5 | Contrato de mutação: two-step `move-plan`→`move` com `planToken` persistido, ou single-step com revalidação total? | **Variante intermediária**: `move-plan` como endpoint de validação/preview **sem estado persistido no servidor** (calcula e devolve o plano, não gera token com TTL/GC); `move` é single-step, revalida tudo do zero na transação (o `expected_version` do §5.2 já é a proteção contra "tela desatualizada") | Na escala atual (§4), um token persistido é infraestrutura para um problema que a exclusion constraint + version já resolvem; a UX de "mostrar antes/depois antes de confirmar" não exige estado servidor — o preview pode ser recalculado sem custo |
| 6 | Auditoria como quantas tabelas? | **Uma** tabela append-only (`appointment_change_log`), não três (auditoria + history + outbox do briefing) | Mesma decisão do documento irmão (§9 de lá) — outbox sem consumidor real é tabela morta |

## 6. Modelo de domínio proposto

**Distinções canônicas adotadas do briefing (corretas e não redundantes com nada existente):**

```text
display_grid_min      — divisão visual da agenda (hoje HARDCODED 30 em dateUtils.js:5)
snap_min               — precisão de clique/drag (hoje inexistente; UI não tem drag)
start_interval_min     — cadência de horários oferecíveis (pode ser diferente de duration_min)
duration_min           — vem da resolução Fase 10 (override) → fallback services.duration_minutes
buffer_before_min      — Fase 10, campo novo na capacidade (coordenar com doc irmão)
buffer_after_min       — idem
```

Regra vinculante (adotada): `display_grid_min ≠ duration_min`; um serviço de 45 min pode iniciar às 09:10 numa grade visual de 10 min, desde que `[início, fim)` completo esteja livre — `[)` semiaberto já é a semântica real do banco hoje, só falta a UI deixar de forçar clique só nas marcações de 30 em 30.

**Coluna nova em `appointments`:** `version integer not null default 1` (decisão #2). Nenhuma tabela nova além da de auditoria (decisão #6) — resize e troca de profissional continuam sendo `UPDATE` no mesmo `appointment`, não uma entidade `appointment_duration_override` separada como o briefing sugere: **essa distinção do briefing não se sustenta aqui** — o próprio briefing já disse "resize deve passar pela mesma engine transacional do reagendamento"; criar uma tabela paralela só para guardar duração-anterior/nova é o mesmo dado que a tabela de auditoria (decisão #6) já guarda no `before`/`after` de qualquer mutação. Duplicaria a fonte de verdade que o próprio briefing proíbe.

## 7. Matriz de conflitos (mutação de appointment)

| Código | Descrição | Decisão | Permissão para exceção |
|---|---|---|---|
| `APPOINTMENT_STALE` | `expected_version` divergente | Recalcular e devolver estado atual, sem aplicar | — |
| `APPOINTMENT_STATUS_IMMUTABLE` | Tentativa de mover/alterar um `completed` | Bloqueado | Reversão privilegiada, auditada (papel `owner`), fora do fluxo normal de drag |
| `STAFF_OVERLAP` | Profissional já ocupado no intervalo | Bloqueado — já garantido pela exclusion constraint (`23P01`→409) | Não — recurso fisicamente exclusivo (um profissional não está em dois lugares) |
| `OUTSIDE_WORKING_HOURS` | Fora do expediente resolvido (`query_resolve_effective_availability` do doc irmão) | Confirmação requerida por padrão | `agenda.override_working_hours` (papel gerente/dono) |
| `SERVICE_NOT_ALLOWED_FOR_STAFF` | Profissional sem elegibilidade para o serviço (Fase 10) | Bloqueado | Não — qualificação é restrição real, não política |
| `DURATION_CHANGED` | Troca de profissional muda a duração efetiva (override diferente) | Confirmação requerida — mostrar duração antiga vs. nova | — |
| `PRICE_REFERENCE_CHANGED` | Troca de profissional muda preço de referência | Confirmação requerida — preservar preço reservado por padrão (§8) | Reprecificação explícita |
| `TENANT_MISMATCH` | IDs referenciados de outra organização | Bloqueado, sempre | Nunca |

Catálogo completo de códigos fica versionado no contrato de API (§9) — o frontend nunca interpreta texto livre para decidir (exigência do briefing, e já é o padrão hoje: `AppointmentModal.jsx:16-22` mapeia por `err.code`, não por mensagem).

## 8. Política financeira ao trocar profissional

Adotada do briefing, sem alteração: **preservar por padrão o preço já reservado ao cliente**; mostrar preço reservado vs. preço de referência do profissional destino; reprecificação exige ação explícita. Comissão recalculada pela regra do profissional que efetivamente executa (cascata já existente — `private.resolve_commission`), nunca no frontend, nunca durante o drag em si — só no momento da confirmação transacional.

## 9. Contrato de API proposto

```http
POST /appointments/{id}/move-plan
```
Entrada: `{ targetStartsAt, targetProfessionalId?, targetServiceId?, operation: MOVE|RESIZE|CHANGE_SERVICE, expectedVersion }`
Saída: `{ decision: ALLOW|CONFIRM_REQUIRED|BLOCKED|STALE, before, after, changes[], conflicts[] }` — **sem `planToken` persistido** (decisão #5); é puramente uma simulação recalculável, idempotente por definição (mesma entrada → mesma saída).

```http
POST /appointments/{id}/move
```
Entrada: `{ targetStartsAt, targetProfessionalId?, targetServiceId?, operation, expectedVersion, idempotencyKey, exceptionReasonCode?, exceptionReasonText? }` — revalida tudo do zero na transação (não confia no `move-plan` anterior); usa o mesmo padrão de `private.idempotency_keys` já usado no domínio financeiro.

**Troca de cliente**: fora do escopo deste contrato — o briefing está correto em exigir um fluxo `Reatribuir cliente` separado e não permitido por drag; fica registrado como decisão em aberto para quando o portal do cliente (Fase 15+) tornar isso relevante, hoje a recepção já não faz essa operação via agenda.

## 10. Modelo transacional (fluxo mínimo dentro da RPC/endpoint `move`)

```text
validar tenant e papel do ator
bloquear appointment (SELECT ... FOR UPDATE)
validar expected_version → APPOINTMENT_STALE se divergente
validar status atual permite transição → APPOINTMENT_STATUS_IMMUTABLE se não
resolver duração/buffer efetivos (consulta Fase 10)
resolver disponibilidade (consulta query_resolve_effective_availability do doc irmão)
aplicar UPDATE (a exclusion constraint arbitra conflito físico → 23P01/409 se colidir)
incrementar version
registrar em appointment_change_log (before/after/ator/motivo)
commit
```

Duas requisições concorrentes para o mesmo appointment: a segunda falha em `expected_version` (barata, sem tocar o banco) OU na exclusion constraint (se o conflito for de horário) — nunca as duas aplicam.

## 11. UX (herdada do briefing, sem alteração — já é boa prática validada)

Durante o drag: preview local (ghost, sem chamada de rede). Ao soltar: `move-plan` síncrono. Decisão `ALLOW`: aplica direto + toast com desfazer (sem modal — evita fadiga de confirmação). `CONFIRM_REQUIRED`: modal com antes/depois consolidado (não pop-ups sequenciais). `BLOCKED`: explicar causa + alternativas (reforça o gap já conhecido de "sugerir próximo horário livre", que passa a ser possível com `query_resolve_effective_availability`).

## 12. Red team (blind spots do briefing confrontados)

1. **`planToken` persistido é over-engineering nesta escala** (§4, §5.4) — mitigado adotando a variante sem estado.
2. **`appointment_duration_override` como tabela separada duplicaria a auditoria** (§6) — mitigado: uma tabela de auditoria cobre o mesmo caso.
3. **Saga `EMERGENCY_CLOSURE`** (fechamento de emergência com comunicação em massa) pressupõe mensageria automática que não existe (a da Fase 13 é manual, humano-assistida). Escopo mínimo realista: a exceção de organização (doc irmão) + a query de impacto (`appointments afetados`) já dão à recepção a lista para contatar manualmente via `wa.me` — a "saga" automática fica registrada como não-objetivo até existir mensageria real.
4. **Modos `STRICT`/`GRANDFATHER_EXISTING`** do briefing (para mudança de config afetar agendamentos existentes) pertencem ao doc irmão (mutação de config), não a este — mas o **efeito** sobre appointments confirmados é executado por este motor (ex.: `GRANDFATHER_EXISTING` = não mexe nos appointments já confirmados mesmo que a config mude). Registrado como ponto de integração entre os dois documentos, a resolver quando ambos virarem fase.
5. **Chain booking / serviços encadeados / grupo / swap**: fora de escopo desta fase — nenhuma evidência de uso hoje (catálogo não modela serviços compostos além de `packages`, que já são cascata simples). Fica no horizonte reservado, não nesta fase.

## 13. Plano sequencial (mapeia para fases do plano unificado — não numera aqui)

- **P0 (hardening, absorvido pela Fase 10 já decidida no plano unificado)**: `ends_at` server-side, guard de transição de status, coluna `version`.
- **P1 (fase própria, proposta: Fase 15, depende da Fase 14 do doc irmão)**: contrato `move-plan`/`move`, matriz de conflitos, auditoria, UI de drag-and-drop consumindo disponibilidade real.
- **P2**: sugestão de horário alternativo no `BLOCKED` (usa `query_resolve_effective_availability`); troca de serviço como comando dedicado.
- **P3 (fora de escopo, sem evidência de necessidade)**: chain booking, swap, recorrência de agendamento — horizonte reservado.

## 14. Testes e gates

pgTAP/integração mínimos: grade de exibição 10 min com serviço de 45 (início 09:10, fim 09:55, sem colidir com grade); `expected_version` divergente → `APPOINTMENT_STALE`; `completed` rejeita mutação exceto reversão privilegiada auditada; troca de profissional recalcula duração/preço/comissão (nunca preserva silenciosamente os do profissional anterior); duas requisições concorrentes — só uma aplica; `ends_at` fora do backend não é mais aceito (teste de regressão do achado de segurança).

## 15. Rollback

Coluna `version` e tabela de auditoria são aditivas — reversível sem perda de appointments existentes. Mudança de comportamento de `ends_at` (servidor passa a ignorar o valor do cliente e recalcular) é a única mudança com efeito observável em clientes de API existentes — deve ser comunicada/versionada no contrato, não silenciosa.

## 16. Critério de aceite documental

Pronto para virar fase quando: (a) usuário decidir os itens do §5; (b) Fase 14 (doc irmão) tiver `query_resolve_effective_availability` disponível; (c) Fase 10 já tiver fechado o hardening P0.

## 17. Próxima ação única

Usuário resolve as decisões do §5 (especialmente #4, não adotar os 8 estados, e #5, contrato sem `planToken` persistido); depois, alocar Fase 15 em `PLANEJAMENTO_EXECUCAO_UNIFICADO.md`, dependente da Fase 14.

## 18. Fontes

- [jusdb — PostgreSQL Range Types and Exclusion Constraints](https://www.jusdb.com/blog/postgresql-range-types-exclusion-constraints)
- [DEV Community — PostgreSQL EXCLUDE constraints for better concurrency than serializable](https://dev.to/franckpachot/postgresql-exclude-constraints-for-better-concurrency-than-serializable-pob)
- [reintech — Implementing Optimistic Locking in PostgreSQL](https://reintech.io/blog/implementing-optimistic-locking-postgresql)
- [Medium — Solving Double Booking At Scale: 7 Battle-Tested Patterns](https://medium.com/@the_atomic_architect/solving-double-booking-at-scale-7-battle-tested-patterns-from-airbnb-calendly-and-stripe-b7739ca5c9b4) (invariante central acessível publicamente; patterns completos atrás de paywall — não citados sem confirmação de conteúdo)
- Cal.com, Google Calendar API — ver fontes em `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §16`
