---
title: "Blueprint Onda 7 — redimensionamento de agendamento"
status: "PROPOSED"
stage: "BLUEPRINT"
governance_ref: ["DEC-64", "DEC-65", "DEC-69", "ADR-0013"]
upstream_doc: "../KORTEXOS_5_1_2_MIGRATION_MAP.md"
last_updated: "2026-10-18"
---

# Blueprint — Onda 7, sub-item 2: redimensionamento

## 1. Autoridade e limites

Este rascunho parte do sub-item 2 da Onda 7, liberado pelo Migration Map v1.3 (DEC-64) e pela reconciliação DEC-65. O sub-item 1 (arraste/reagendamento) já está em `staging` e não será refeito. O Platform Owner ampliou o requisito em 2026-10-18: resize deve validar agenda completa e recursos devem ser associados aos serviços. Isso ultrapassa o escopo técnico original de DEC-64 (sem tabela nova e sem mexer no `create_appointment`); o adendo DEC-69 está registrado no Migration Map. A decisão de confirmação explícita para mudança de duração, encaixe deliberado e constraint como barreira final permanecem.

O adendo de escopo foi registrado por DEC-69; este contrato técnico ainda precisa de Red Team e verificação executada. Não muda preço, comissão, buffers, política de depósito ou status financeiro. `appointment_replan_with_hold` exige auditoria de integridade dos recursos, sem mudar sua regra financeira. `resolved_duration_minutes` continua sendo o snapshot da duração efetivamente aprovada, com `ends_at` calculado no servidor.

## 2. Escopo de dados

| Objeto | Estado | Contrato proposto |
|---|---|---|
| `public.appointments` | Extensão lógica | RPC existente passa a aceitar duração proposta em minutos; grava `resolved_duration_minutes` e calcula `ends_at = starts_at + duração` apenas após confirmação válida. Sem alteração de tabela. |
| `service_resource_requirement_sets` + `service_resource_requirements` (nomes propostos) | Novas | Conjuntos versionados por organização, unidade e serviço; linhas por tipo de recurso e quantidade positiva. Como `services` é org-wide e `resources` é unit-scoped, cada conjunto associa o serviço à unidade de execução. |
| `public.resource_locks` | Extensão de uso | Reservas automáticas dos recursos concretos vinculadas ao appointment e requisito que as gerou. Locks manuais anteriores não são liberados automaticamente. No resize, os locks automáticos são reconciliados na mesma transação; recurso indisponível retorna conflito específico. |
| `public.update_appointment(...)` | Extensão | Mantém parâmetros e envelope existentes; reconhece `duration_minutes` no `p_payload`. Mudança de duração retorna `confirmation_required`, no contrato Change Plan, com valores atuais/propostos e eventual conflito identificado. `confirm=true` confirma a proposta encaminhada e ainda sujeita a validações e exclusão concorrente. |
| `public.create_appointment(...)` | Extensão necessária | Ao criar agendamento para serviço com requisito de recurso, reserva atomicamente os recursos compatíveis da unidade. A disponibilidade do recurso é imposta por `resource_locks` e sua exclusion constraint, não por checagem somente no frontend. |
| Configuração de serviço | Extensão necessária | O owner/admin/manager define requisitos por unidade; alteração de requisitos precisa tratar appointments futuros já existentes e não pode deixar reservas antigas sem lock. |
| Express `PATCH /appointments/:id` | Extensão | Aceita/valida `duration_minutes` inteiro entre 5 e 1440, respeitando a constraint existente; não aceita `ends_at` nem duração negativa/fração. Apenas campos allowlisted chegam ao RPC. |
| PWA Agenda / `AppointmentModal` / card Timeline | Extensão | Campo de duração e alça de resize enviam a intenção, mostram confirmação/diff e revertem visualmente se houver erro/conflito. Grade visual permanece em 10 minutos; a duração obedece ao domínio já vigente (5–1440), sem arredondamento oculto. |
| Express `GET /units/:unitId/availability` | Extensão necessária | Os slots calculados para serviço/unidade/profissional verificam também a existência de `required_count` recursos concretos livres por tipo no intervalo. A disponibilidade exibida é informativa; a confirmação transacional decide a reserva final. |

## 3. Integridade e invariantes

1. Toda decisão de duração e término ocorre no backend/RPC; cliente nunca define `ends_at`.
2. Requisição exige `version` otimista e `Idempotency-Key`, usando exatamente a semântica existente de atualização.
3. Alteração de duração exige confirmação explícita; proposta nunca é mutação. Se versão, estado ou ocupação mudar antes da confirmação, o servidor recalcula/rejeita sem aplicar uma proposta obsoleta.
4. A agenda completa inclui sobreposição com appointment, horário da unidade, turno/folga/exceções/feriado e disponibilidade de recursos requeridos pelo serviço. A resposta identifica motivo, fonte e limite conflitante. A interface oferece **Cancelar alteração** ou **Encaixar até HH:MM** quando couber duração válida. Encaixar troca a duração proposta pela janela livre, mostra o novo diff e exige nova confirmação. Se não couber o mínimo de 5 minutos, não oferece encaixe. O servidor nunca encurta silenciosamente.
5. `max_fit_duration_minutes` é apenas informação para a interface. A constraint GiST de appointments continua autoridade final de não sobreposição, inclusive em corrida. Sem próximo agendamento conflitante, a capacidade restante é limitada pelo máximo de domínio vigente (1440 minutos).
6. A prévia aplica a precedência atual do Calendar Resolver no timezone da unidade e consulta os resource locks requeridos pelo serviço, excluindo os locks do próprio appointment da proposta. `resource_locks` não tem hoje mapeamento service→resource e a Onda 4 registrou essa limitação; a nova associação é condição necessária para a validação completa escolhida pelo Platform Owner.
7. A identidade do atendimento, elegibilidade, depósito/hold e autoria permanecem inalterados. Duração alterada não recalcula `commission_cents`.
8. Feature flag `agenda_full_validation_enabled` em `organizations.settings`, desligada por padrão, governa a exposição da UI e HTTP novos; após ativar requisitos, a integridade de reservas obrigatórias no banco independe da flag.

## 4. Contrato físico e transacional

O desenho aditivo proposto inclui um conjunto versionado (`organization_id`, `unit_id`, `service_id`, `version`, `status` draft/active/retired) e linhas de requisito (`resource_type`, `required_count >= 1`). Uma combinação org/unidade/serviço tem no máximo uma versão ativa. FKs compostas precisam validar serviço no tenant, unidade no tenant e linhas no conjunto da mesma unidade. `resource_locks` ganha identificação nullable da linha de requisito que originou cada lock automático; `NULL` preserva o significado dos locks manuais existentes. A tabela é configuração de capacidade; locks concretos são a fonte de ocupação. A constraint GiST atual é exclusiva por recurso, mesmo quando `resources.capacity > 1`; esta Onda não pode prometer compartilhamento de capacidade sem novo modelo e teste de concorrência.

A edição cria um novo conjunto draft. A ativação deve serializar por org/unidade/serviço, travar os appointments ocupantes com `ends_at > transaction_timestamp()` e tentar reservar/reconciliar todos os locks antes de tornar a versão ativa. Para um atendimento já iniciado, a reserva cobre somente `[greatest(starts_at, transaction_timestamp()), ends_at)`; não tenta reivindicar retroativamente o intervalo já transcorrido. O instante de corte é capturado uma vez na transação. Se algum appointment não couber, a versão anterior continua ativa e a transação não deixa locks parciais; o retorno identifica os appointments conflitantes para resolução operacional. Requisitos antigos permanecem para rastreabilidade dos locks históricos. Esta estratégia transacional precisa ser testada com volume realista; se exceder o tempo seguro, uma ativação em lotes requer estado explícito `pending`, sem expor o conjunto novo como ativo até o backfill completo.

Todos os escritores de appointment adquirem, antes de ler o conjunto ativo, o mesmo bloqueio transacional por `(organization_id, unit_id, service_id)` usado pela ativação. Mudança de serviço adquire os pares antigo e novo em ordem determinística. DML direto e a RPC atual podem já ter travado a linha de appointment antes de alcançar o trigger e seu bloqueio de configuração. Por isso, após tomar o bloqueio de configuração, a ativação tenta os row locks de appointments com `NOWAIT`, em ordem estável: se qualquer linha estiver ocupada, a transação inteira aborta com erro tipado de retry, sem publicar versão ou deixar locks parciais. Nunca espera por uma linha enquanto mantém o bloqueio de configuração. A ativação só publica a versão depois do backfill sob esse bloqueio; teste de duas sessões deve demonstrar tanto a ausência de deadlock quanto a impossibilidade de criação/edição escapar entre leitura da versão antiga e publicação da nova. A escolha de recursos exige bloqueio por `(organization_id, unit_id, resource_type)` em ordem estável; a constraint GiST continua proteção final para caminhos manuais que não participem dele.

`resources.resource_type` e `active` são hoje mutáveis. Um recurso já reservado automaticamente não pode ser desativado nem trocar de tipo sem reconciliação transacional dos appointments ocupantes com `ends_at > transaction_timestamp()` e seus locks; na primeira fatia, rejeitar essas mutações enquanto existirem locks automáticos vigentes ou futuros. `unit_id` já é imutável no fato referenciado pelo lock composto. Um vínculo por `requirement_id` sozinho não prova que o recurso ainda satisfaz o tipo exigido.

As RPCs `public.update_appointment(...)` e `public.create_appointment(...)` continuam como fronteiras de escrita via `service_role`; Express autentica JWT, deriva organização/membership e autoriza os papéis existentes. A implementação usa, sem duplicar precedência, `private.resolve_calendar_policy`, `private.resolve_professional_shift` e `private.resolve_calendar_overrides` (timezone de `units`) e a constraint GiST de `resource_locks`. Nova reserva de recurso deve ocorrer na mesma transação que cria ou altera appointment. Não basta consultar disponibilidade e gravar depois: a exclusion constraint do lock é a proteção contra corrida.

O algoritmo das RPCs deve travar o appointment e validar tenant, ator, version e idempotência; resolver política/turno/override na zona local da unidade; calcular proposta e término; retornar conflito tipado e janela máxima; e apenas depois de confirmação revalidar estado e gravar appointment/locks atomicamente. A alocação ordena tipos e recursos, seleciona `required_count` recursos ativos distintos de cada tipo, e serializa a seleção por org/unidade/tipo. A exclusion constraint protege a corrida com locks manuais ou outros escritores que não tomem o mesmo bloqueio. Ao editar, somente locks automáticos podem ser liberados/recriados; os manuais permanecem intocados. Uma falha em qualquer reserva reverte appointment e locks na mesma transação. A ação “Encaixar” envia uma nova duração como proposta, nunca confirmação implícita.

Para payload com duração e alteração de profissional/serviço simultânea, a duração explicitamente definida pelo resize prevalece sobre o default do serviço/capability e é salva como snapshot do appointment após confirmação única do diff completo. Troca de serviço/profissional sem `duration_minutes` continua recalculando o default atual. Decisão do Platform Owner em 2026-10-18.

### 4.1 Fronteira comum de integridade

`appointments_default_fill_unit_id` preenche a unidade padrão em `BEFORE INSERT` e a coluna é `NOT NULL`; a criação direta não precisa de backfill de `unit_id`. A regra de recurso, porém, não pode morar apenas em `create_appointment`/`update_appointment`: séries cancelam ocorrências futuras por `UPDATE` direto, a aceitação client-facing também atualiza appointment e o Express expõe `DELETE` direto. A fatia de reserva instala triggers universais em `appointments` para `INSERT`, mudanças de intervalo, serviço, unidade ou status em `UPDATE` e `DELETE`. O trigger `BEFORE` adquire os bloqueios de configuração em ordem determinística, valida os atributos e a agenda quando houver alteração de slot **ou transição de estado não ocupante para ocupante** (mesmo com horários iguais), e prepara a liberação dos locks automáticos na exclusão física; o trigger `AFTER` reconcilia os locks do fato persistido na mesma transação. A implementação deve respeitar a ordem de `appointments_default_fill_unit_id` e usar a unidade já preenchida; nenhuma RPC ou DML direto pode desabilitar esses triggers. Para estados não ocupantes, libera os locks automáticos restantes; para exclusão física, remove os automáticos antes da FK `resource_locks.appointment_id ON DELETE RESTRICT`. Locks manuais continuam sujeitos à política anterior de exclusão e não são apagados pela automação. O Express DELETE será substituído por uma RPC autorizada, embora o trigger também proteja exclusão direta. Testar cada escritor, não só as duas RPCs principais.

`resource_lock_release` atual aceita liberar um lock ativo por papel autorizado e versão, inclusive um lock de appointment. Ao introduzir o marcador de lock automático, a RPC deve rejeitar liberação manual de lock obrigatório enquanto o appointment permanecer ocupante. Um trigger em `resource_locks` proíbe `UPDATE`/`DELETE` de locks automáticos vigentes, inclusive a remoção do marcador, fora da rotina interna de reconciliação. A rotina interna de escopo restrito, chamada apenas pelos triggers de appointment/ativação, libera/recria o lock na mesma transação que mantém a quantidade exigida; ela não expõe uma flag ou `SECURITY DEFINER` pública para contornar o guard. Conferir grants DML reais em `resource_locks`, revogar acessos diretos desnecessários e testar DML autenticado e `service_role` sem acesso à rotina interna. Sem este guard, qualquer ator com permissão de recurso conseguiria burlar a reserva obrigatória após o agendamento.

As policies atuais de `appointments` autorizam `INSERT`/`UPDATE`/`DELETE` a `authenticated` conforme membership/unidade; não há `REVOKE` explícito de DML dessa tabela nas migrations lidas. Conferir os grants efetivos no banco e testar escrita direta com JWT de reception. A proteção dos triggers independe dos grants: se DML direto estiver concedido, ele continua sujeito à mesma integridade; como redução de superfície, revogar DML direto de `authenticated` após mapear os clientes e migrá-los para RPCs autorizadas, sem depender dessa revogação para a invariante. `service_role` também atravessa os triggers. O guard de `resource_lock_release` deve distinguir uso externo autorizado da rotina interna sem abrir `SECURITY DEFINER` genérica invocável por `authenticated`.

O fluxo `origin='direct'` de `create_appointment` não executa as verificações de calendário que hoje são condicionadas a `origin <> 'direct'`. A nova validação de slot deve usar `unit_id` efetiva, inclusive o default para criação direta, e validar o intervalo completo; a liberação da UI de resize não pode depender de um booleano diário de `resolve_calendar_overrides`. Exceções e folgas parciais devem ser comparadas por interseção real com `[starts_at, ends_at)`, respeitando precedência e timezone da unidade. Casos que cruzem meia-noite local ou uma transição de horário de verão exigem teste com instantes UTC e limites locais explícitos, sem aritmética de `HH:MM` que produza uma janela incorreta.

O endpoint de disponibilidade atual calcula ocupação apenas por appointments. Após associar requisitos ao serviço, ele deve buscar o conjunto ativo e, para cada slot candidato, contar recursos ativos distintos e sem lock sobreposto por tipo; oferecer o slot somente quando cada `required_count` couber. A consulta segue escopo de organização/unidade e não revela outro tenant. Esta prévia pode perder uma corrida para outro agendamento, portanto o commit revalida no banco e devolve conflito tipado sem reservar parcialmente. Testar dois recursos de mesmo tipo, um bloqueado por manutenção, outro por appointment, e alteração de configuração concorrente.

## 5. Compatibilidade e backfill

Chamadores antigos sem `duration_minutes` preservam seu contrato atual. Serviços sem conjunto ativo continuam sem lock extra. A ativação exige backfill de appointments ocupantes (`scheduled`, `confirmed`, `in_service`) cujo `ends_at` esteja no futuro; appointments já iniciados recebem lock pelo intervalo remanescente até `ends_at`. Se algum falhar, nenhum novo conjunto fica ativo e o operador recebe diagnóstico. Nova regra deve cobrir appointments criados por séries, grupos e waitlist, além do caminho manual, e edição por replan/status. Alterar serviço/profissional junto com resize mantém a duração informada pelo operador; sem duração explícita, usa-se o default vigente.

## 6. Plano de execução e rollback

Plano preliminar expandido; a sequência anterior de três fatias é insuficiente depois da decisão de associar recursos aos serviços. O adendo DEC-69 está no Migration Map; o fatiamento precisa de aceite técnico:

1. Fundação de resource requirement por serviço/unidade, RLS, índice, configuração e teste pgTAP.
2. Alocação/reserva transacional na criação de appointment, com backfill de appointments futuros e testes de série/grupo.
3. Extensão de `update_appointment` para resize, Change Plan, conflito tipado e realocação/ajuste de locks.
4. Camada Express para configuração e edição, validação/allowlist, feature flag em `organizations.settings` e testes Jest de autorização/tenant/idempotência.
5. PWA: editor de requisitos, duração e resize touch/pointer, explicação por tipo de conflito, encaixe com segunda confirmação e revert em erro; testes Vitest.
6. Red Team da implementação, reset limpo local, pgTAP/backend/frontend e lint SQL antes de qualquer promoção.

A migration deve ser aditiva (`CREATE OR REPLACE` na assinatura já existente) e reversível apenas por nova migration forward-only se já aplicada. Rollback de release é desativar o caminho UI/HTTP em feature branch/deploy, sem apagar mudanças de appointments; não executar DDL destrutivo. A ordem e os limites precisam ser aprovados junto com o Blueprint.

## 7. Matriz de acesso e contratos afetados

| Superfície | Leitura/escrita | Autorização/escopo |
|---|---|---|
| PWA | intenção, diff e confirmação via HTTP | JWT; não fala com Supabase para escrita. |
| Express `PATCH /appointments/:id` | lê membership/role; chama RPC | tenant derivado de membership; roles existentes; valida campos e version. |
| RPC pública `update_appointment` | escreve appointments, resource_locks e idempotency | EXECUTE revogado de `public`, `anon`, `authenticated`; grant a `service_role`; ator/tenant verificados no corpo. |
| RPC pública `create_appointment` | escreve appointment e locks de recursos, quando requeridos | Mantém checagens atuais, adiciona reserva atômica e fail-closed por tenant/unidade. |
| Requisitos serviço-recurso | owner/admin/manager configura; membros autorizados consultam | RLS restrita por organização/unidade; nenhuma escrita direta via PWA, mutations via endpoint/RPC autorizada. |
| RLS de `appointments` | defesa em profundidade | conferir grants efetivos; migrar escritores diretos e revogar DML de `authenticated` quando seguro. Triggers garantem a invariante mesmo antes da revogação e para `service_role`. |

Referências de implementação atuais: `backend/src/modules/appointments/appointments.validation.js`, `appointments.service.js`, `appointments.controller.js`; `supabase/migrations/20260805020000_onda5_fatia033_participants.sql`; `frontend/src/modules/agenda/AppointmentModal.jsx`, `AgendaPage.jsx`, `ChangeDiff.jsx`.

## Benchmark Gate

- **FATO — Booksy:** o Booksy Biz declara suporte a arrastar e soltar blocos para reagendar, editar bloco de agendamento, configurar duração por serviço e bloquear sobreposição em tempo real. Sua documentação brasileira descreve variantes com durações/preços diferentes e complementos que ajustam automaticamente duração do compromisso. Fontes: [Calendar & Scheduling](https://biz.booksy.com/features/calendar-scheduling), [Guia de serviços](https://support.booksy.com/hc/pt-br/articles/20706548191378-Guia-para-configurar-seus-servi%C3%A7os).
- **FATO — referência cross-industry:** FullCalendar oferece evento de resize, retorno explícito `revert()` para falha de gravação e controles para overlap/constraint; a API deixa a regra de autorização e persistência ao produto. Fontes: [eventResize](https://fullcalendar.io/docs/eventResize), [dragging/resizing](https://fullcalendar.io/docs/event-dragging-resizing).
- **FATO — Vagaro:** a documentação de agendamento permite ajustar a duração e escolher recurso (sala, cadeira ou equipamento) requerido pelo serviço para controlar disponibilidade e impedir dupla reserva. Fonte: [Book a Single Appointment](https://support.vagaro.com/hc/en-us/articles/360010188414-Book-a-Single-Appointment-for-a-Customer).
- **INFERÊNCIA:** a alça pode oferecer interação familiar, mas não deve confirmar persistência antes do servidor; a confirmação explícita do KortexOS conserva o Change Plan/concorrência otimista e evita ajuste silencioso.
- **DECISÃO já registrada no handoff DEC-64:** mudança pura de duração exige confirmação; nunca auto-clamp; integridade final na constraint GiST. O benchmark foi reexecutado nesta retomada; falta fechar ambiguidades listadas neste rascunho antes de solicitar aprovação.

## Revisão adversarial preliminar

**Veredito: BLOQUEADO para declarar Etapa 7 concluída e Etapa 8 validada.** O adendo de escopo já foi registrado em DEC-69. A revisão independente apontou caminhos de escrita direta, liberação de locks, backfill em andamento, inversão de bloqueios e reocupação por status; o contrato acima agora explicita as medidas propostas. Elas ainda não foram executadas nem provadas. A CLI está vinculada ao projeto de staging, mas não há Docker nem Supabase local e a consulta de migrations remotas não concluiu. Nenhuma alteração de schema foi aplicada.

1. Cobrir todos os escritores de `appointments` em séries, grupos, waitlist, replan, DML direto de `authenticated` (grants efetivos a verificar) e alterações diretas de status; a reserva obrigatória não pode depender só de duas RPCs públicas.
2. Validar folgas/exceções parciais, meia-noite local e DST contra intervalos reais. O Resolver atual retorna `is_open` por dia quando uma exceção apenas intersecta o dia; isso não basta como validação de intervalo.
3. Provar concorrência de múltiplos recursos e ativação/backfill sem lock parcial nem deadlock (inclusive activation NOWAIT contra writer que já travou appointment), com lock manual concorrente, release ou DML direto indevido em `resource_locks`, edição de `resource_type`/`active`, reocupação por status e alto volume.
4. Colisão concorrente sem mudança de `version`: somente as exclusion constraints garantem integridade; criar testes de concorrência e rollback completo.
5. Executar Red Team independente do desenho, fatiamento vertical e teste de implementação em Supabase descartável antes de qualquer promoção.

Comprovar os itens 1–4 em implementação e teste de duas sessões antes de declarar o gate completo. Nenhum `GO` foi emitido.

## Próximo gate

Revisar os riscos do Blueprint e o Red Team de desenho. A autorização explícita do Platform Owner já foi dada; após `GO` técnico, executar Etapa 8 em ambiente descartável e registrar evidência real, sem repetir a pergunta de permissão.
