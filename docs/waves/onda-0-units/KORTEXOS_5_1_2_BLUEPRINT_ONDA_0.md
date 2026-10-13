# KortexOS 5.1.2 — Blueprint Onda 0: Units

**Status:** **APROVADO E IMPLEMENTADO.** Revisado e aprovado pelo Platform Owner em 2026-07-22 (DEC-31); a Etapa 8 foi autorizada localmente por DEC-32. A implementação forward-only foi validada e promovida para `staging` conforme os registros de execução e verificação desta pasta.  
**Etapa:** 7 (Blueprint) concluída; Etapa 8 executada dentro da autorização de DEC-32.  
**Escopo:** D01 Identity & Tenant; somente fronteira de unidade e compatibilidade do MVP existente.

## 1. Autoridade e limites

Este Blueprint materializa `AGENTS.md`, Master Briefing, Truth Map e Migration Map v1.2. As decisões abaixo foram fechadas e o artefato foi aprovado pelo Platform Owner em 2026-07-22 (DEC-31); essa aprovação não dispensa o gate QA Red Team antes da Etapa 8.

Não cria override de catálogo, calendário, Payment Core, ledger, UI de seleção de unidade ou SQL executável. `organization_id` continua sendo a fronteira primária de tenant; `unit_id` é uma fronteira operacional subordinada e nunca é aceito isoladamente do cliente.

## 2. Escopo de dados

| Objeto | Contrato técnico | Estado |
|---|---|---|
| `units` | Unidade pertence a uma `organization`, tem UUID, nome único case-insensitive por organização, timezone IANA obrigatória, status ativo, marcador de default e metadados de autoria/tempo. Nesta onda, toda unidade nasce com timezone fixa `America/Sao_Paulo` (único tenant real hoje é o Salão Esperança); a coluna existe e é validada contra `pg_timezone_names`, mas não há UI nem parâmetro de RPC para escolhê-la — fica registrado como débito explícito para quando existir onboarding multi-região. | Novo |
| `professional_units` | Vínculo N:N mínimo entre profissional e unidade: `organization_id`, profissional, unidade, ativo e auditoria. Sem horário, capacidade, comissão ou regras comerciais. | Novo |
| `memberships.unit_id` | Escopo híbrido: `owner`/`admin`/`manager` exigem nulo (org-wide); `professional`/`reception` exigem unidade ativa. | Extensão |
| `membership_permissions` | Allowlist normalizada e tenant-safe para `schedule:view_all` e `clients:view_all`; só se aplica a `professional` unit-scoped. | Novo, aprovado nesta revisão |
| `unit_access_audit_events` | Evento append-only para mudanças de unidade, vínculo, escopo e permissões. Registra origem `user`/`system`, ator quando humano, alvo, ação e before/after mínimo sem PII. | Novo, aprovado nesta revisão |

`units` deve preservar exatamente uma unidade default ativa por organização. Não é permitido desativar a última unidade ativa. Trocar a default só afeta resolução futura, é auditado e não relota dados históricos. Unidades com histórico não são apagadas: são desativadas.

## 3. Integridade e escopo por unidade

As FKs novas usam sempre a dupla `(organization_id, id)` contra o objeto pai. `professional_units` é único por organização, profissional e unidade. A membership e o vínculo profissional devem apontar para unidades da mesma organização.

O status ativo de unidade é validado em command/RPC e por proteção de banco antes de novas operações; histórico em unidade inativa permanece legível. A mudança de papel aplica a matriz abaixo de modo atômico e auditado.

| Papel | `memberships.unit_id` | Regra |
|---|---|---|
| `owner`, `admin`, `manager` | obrigatório nulo | atuação org-wide |
| `reception` | obrigatório preenchido | operação somente na unidade indicada |
| `professional` | obrigatório preenchido | exige também `professional_units` ativo na mesma unidade para novos agendamentos |

Promover papel unit-scoped para org-wide limpa `unit_id` e revoga permissões específicas de profissional. Rebaixar para `professional` ou `reception` exige uma unidade ativa explícita; nunca usa fallback.

### 3.1 Contrato físico de schema

| Objeto | Colunas novas/finais | Chaves, checks e índices |
|---|---|---|
| `units` | `id uuid`, `organization_id uuid`, `name text`, `timezone text`, `active boolean`, `is_default boolean`, `created_by uuid nullable`, `created_at timestamptz`, `updated_by uuid nullable`, `updated_at timestamptz` | PK `id`; `unique (organization_id, id)`; FK de `organization_id`; nome aparado de 2–120 caracteres; índice único parcial em `(organization_id)` para `is_default and active`; índice único funcional em `(organization_id, lower(trim(name)))`; índice de leitura `(organization_id, active)`. Timezone é validada contra `pg_timezone_names` no command/RPC, não por suposição de offset. |
| `professional_units` | `organization_id uuid`, `professional_id uuid`, `unit_id uuid`, `active boolean`, `created_by uuid nullable`, `created_at timestamptz`, `updated_by uuid nullable`, `updated_at timestamptz` | PK composta `(organization_id, professional_id, unit_id)`; FKs compostas para `professionals` e `units`; índices `(organization_id, unit_id, active)` e `(organization_id, professional_id, active)`. |
| `memberships` | `unit_id uuid nullable` | FK composta `(organization_id, unit_id)` para `units`; check: roles `owner`/`admin`/`manager` implicam `unit_id is null`, e `professional`/`reception` implicam `unit_id is not null`; índice parcial `(organization_id, unit_id, user_id) where active and unit_id is not null`. |
| `membership_permissions` | `id uuid`, `organization_id uuid`, `user_id uuid`, `permission_code text`, `granted_by uuid`, `granted_at timestamptz`, `revoked_by uuid nullable`, `revoked_at timestamptz nullable` | PK `id`; FK `(organization_id, user_id)` para `memberships`; check de allowlist `schedule:view_all`/`clients:view_all`; único parcial `(organization_id, user_id, permission_code) where revoked_at is null`; índice `(organization_id, user_id, permission_code) where revoked_at is null`. Uma concessão ativa só é válida para membership `professional` ativa e unit-scoped. |
| `unit_access_audit_events` | `id uuid`, `organization_id uuid`, `unit_id uuid nullable`, `event_type text`, `actor_kind text`, `actor_user_id uuid nullable`, `target_user_id uuid nullable`, `professional_id uuid nullable`, `before_state jsonb nullable`, `after_state jsonb nullable`, `created_at timestamptz` | PK `id`; FK de organização/unidade; checks: `actor_kind in ('user','system')`, ator humano obrigatório somente para `user`, e allowlist de evento (`unit_created`, `unit_updated`, `unit_deactivated`, `default_changed`, `professional_unit_changed`, `membership_scope_changed`, `permission_granted`, `permission_revoked`); índices `(organization_id, created_at desc)` e `(organization_id, unit_id, created_at desc)`. |

`created_by`/`updated_by` podem ser nulos somente para ações `system` de backfill. O evento de auditoria correspondente é obrigatório para toda mudança de topologia, escopo ou permissão; seus JSONs só incluem identificadores, status e códigos de permissão.

### 3.2 Invariantes concorrentes e enforcement

- `create_organization` (assinatura pública inalterada: `p_actor_user_id, p_name, p_slug`) cria organização, unidade default (timezone fixa `America/Sao_Paulo`) e membership owner na mesma transação — nenhum chamador (backend, PWA, pgTAP) precisa mudar.
- As 6 tabelas de fatos ganham `unit_id` preenchido automaticamente por trigger `BEFORE INSERT` (default da organização, quando nulo) — nenhuma das RPCs existentes (`checkout_close`, `create_appointment`, `update_appointment`, `inventory_adjust`) é reescrita nesta onda; elas continuam inserindo sem `unit_id` e o trigger resolve.
- `set_default_unit`, desativação de unidade, mudança de papel, vínculo profissional e permissão executam por RPC/command server-side com lock da organização e da unidade afetada. Eles rejeitam unidade inativa, cross-tenant e tentativa de remover a última unidade ativa.
- A proteção de banco consiste em triggers de validação para insert/update e triggers de imutabilidade para fatos; não depende de checks que exigiriam consultar outra tabela. Toda alteração produz `unit_access_audit_events` na mesma transação.
- `units.is_default` admite no máximo uma default ativa pelo índice parcial; o command e o trigger garantem ao menos uma ativa/default por organização. Troca de default bloqueia a organização, promove a nova antes de remover a anterior e não altera fatos existentes.
- A função de permissão consulta a linha não revogada a cada command/RPC. Revogação não usa cache JWT e vale imediatamente.

## 4. Fatos MVP que recebem `unit_id`

| Classe | Objetos | Regra |
|---|---|---|
| Transacional direto | `appointments`, `orders`, `order_items`, `payments`, `inventory_movements`, `cash_entries` | `unit_id` é o local imutável onde o fato ocorreu. |
| Org-wide | `clients`, `professionals`, `sync_events`, `private.idempotency_keys` | Não recebem `unit_id` nesta onda. |
| Catálogo/configuração | serviços, produtos, grupos, pacotes, capacidades e comissões | Sem coluna/tabela de override nesta onda; apenas classificação para evolução posterior. |

`order_items` e `payments` devem coincidir com a unidade do `order` pai. Movimentos de estoque e caixa associados a pedido herdam sua unidade; ajustes manuais exigem unidade ativa autorizada. `appointments` exigem profissional com vínculo ativo na unidade. Alterar unidade de agendamento é reagendamento explícito; unidade financeira nunca é alterada, sendo corrigida por fluxo reversível.

### 4.1 FK, imutabilidade e transição dos fatos

Cada uma das seis tabelas recebe `unit_id uuid` inicialmente nullable e FK composta `(organization_id, unit_id)` para `units`, preenchido automaticamente por trigger `BEFORE INSERT` (default da organização) — não por reescrita das RPCs. Depois do backfill, `unit_id` torna-se obrigatório (Migration 2). `orders` também recebe chave candidata `unique (organization_id, id, unit_id)`; `order_items`, `payments`, `inventory_movements.order_id` e `cash_entries.order_id` usam FK composta para esse trio quando referenciam pedido. Assim o filho não pode divergir da unidade da venda.

Trigger de imutabilidade (Migration 2) bloqueia atualização de `unit_id` em `appointments`, `orders`, `order_items`, `payments`, `inventory_movements` e `cash_entries` depois de preenchido. Para `appointments`, mover para outra unidade exige command de reagendamento futuro, fora desta Onda. Para ajuste manual de caixa/estoque, o command recebe a unidade resolvida no servidor e valida membership/atividade antes da inserção.

## 5. Compatibilidade e backfill

Como hoje existe apenas uma organização real em produção (Salão Esperança — DEC-26 item 7 registra o KortexOS como single-tenant real), o backfill é 100% determinístico e roda **inline na Migration 1** (mesmo arquivo do schema aditivo, no estilo já usado no ADR 0011 — `alter table` + `update ... set` + comentário explicando a derivação), sem pré-flight nem coleta de input por organização:

1. Criar uma unidade default ativa por organização existente, com o nome da organização e timezone fixa `America/Sao_Paulo`.
2. Vincular todos os profissionais existentes, ativos ou inativos, à unidade default via `professional_units`.
3. Backfill dos seis fatos transacionais para a unidade default da organização (`update ... set unit_id = <default> where unit_id is null`).
4. Medir registros sem unidade (contagem, não gate manual); Migration 2 só é aplicada depois que essa contagem é zero.

O backfill é idempotente, observável por contagens antes/depois e não apaga dados. Nova organização nasce atomicamente com a primeira unidade default via `create_organization`. Durante a transição (entre Migration 1 e Migration 2), fatos novos sem `unit_id` explícito são preenchidos pelo trigger de default — não pelo backend; pedidos públicos que enviem `unit_id` são rejeitados até existir contrato promovido. O fallback é temporário e só pode ser removido após Migration 2 aplicada e testes de tenant/unidade aprovados.

### 5.1 Plano de execução e rollback

1. **Migration 1** (schema aditivo + backfill inline + triggers de default-fill): cria tabelas novas, `unit_id` nullable nas 6 tabelas de fatos, `create_organization` atualizada, backfill da organização existente para sua unidade default, triggers `BEFORE INSERT` de default-fill. Não muda nenhum contrato público nem remove grants/policies existentes.
2. Validar métricas: organizações sem default ativa, profissionais sem vínculo, memberships unit-scoped inválidas e cada fato sem unidade devem ser zero.
3. **Migration 2** (hardening): só então `NOT NULL`, `VALIDATE CONSTRAINT`, triggers de imutabilidade e FKs compostas finais.
4. Executar pgTAP, backend e frontend; manter rollback limitado a reverter a Migration 2 (constraints/triggers, reversível) ou, antes disso, também a Migration 1 (nenhum dado novo unit-aware terá sido gravado por clientes reais nesse intervalo curto). Não apagar unidades, eventos ou fatos já gravados uma vez que existam.

Falha antes da Migration 2 é recuperável por reexecução/reversão da Migration 1. Falha após a Migration 2 exige migration corretiva forward-only, pois fatos unit-scoped e auditoria não podem ser relocados ou apagados.

## 6. Autorização, privacidade e auditoria

Backend valida JWT, membership e escopo de unidade; RLS/RPC espelham a mesma fronteira. `owner`/`admin` gerem unidades, escopos e permissões; `manager` é org-wide operacional, sem gerir topologia ou acesso.

`reception` pode consultar clientes e catálogo org-wide, mas acessa fatos transacionais apenas da própria unidade. `professional` vê o próprio perfil e os próprios agendamentos; `schedule:view_all` permite agenda completa apenas da sua unidade. Sem permissão, dados de clientes são projeção mínima dos próprios agendamentos; `clients:view_all` permite consulta org-wide via DTO do backend, não leitura direta irrestrita da tabela. Concessão e revogação entram em vigor na próxima requisição.

`unit_access_audit_events` é append-only, consultável apenas por `owner`/`admin`. Eventos de migração registram origem `system`, sem fingir um ator humano. O payload não inclui PII de clientes, segredos ou valores financeiros detalhados. `sync_events` não substitui essa auditoria.

### 6.1 Matriz RLS e contratos afetados

| Superfície | Alteração exigida | Falha segura |
|---|---|---|
| `create_organization` | Assinatura pública inalterada; cria a unidade default (timezone fixa) atomicamente, sem parâmetro novo. | Falha de criação da unidade aborta a organização inteira (mesma transação). |
| `membership_set` e convite | Recebem escopo de unidade apenas para `professional`/`reception`; owner/admin executam mudanças de topologia. | papel × unidade inválido, unidade inativa ou cross-tenant retornam erro de autorização/validação. |
| `create_appointment`/`update_appointment` | Não aceitam `unit_id` público nesta onda; corpo da função inalterado — trigger `BEFORE INSERT` resolve a default. | profissional sem vínculo ativo ou payload com `unit_id` são negados (validação server-side, fora da RPC). |
| `checkout_close`, `order_refund`, `inventory_adjust` e ajustes de caixa | Corpo das funções inalterado nesta onda; trigger `BEFORE INSERT` propaga a unidade default a todos os filhos/lançamentos. | divergência pai-filho e unidade inativa são pegas pelo trigger/constraint, não pela RPC. |
| Leitura de agenda/clientes | Backend aplica escopo; professional recebe próprios agendamentos por default e permissões são consultadas a cada request. | não expor tabela `clients` diretamente; DTO mínimo sem permissão. |

RLS de `units`, `professional_units`, `memberships.unit_id`, permissões e auditoria deriva de membership autenticada; `owner`/`admin` administram, `manager` opera org-wide sem administrar, e papéis unit-scoped só acessam o próprio escopo. `unit_access_audit_events` não recebe grants a `anon`/`authenticated` para escrita; leitura é permitida apenas ao backend para `owner`/`admin` autorizados. As policies de fatos transacionais devem negar cross-unit mesmo quando `organization_id` coincide.

## 7. Contratos preservados e fora de escopo

- PWA permanece sem seletor/tela de unidades nesta onda e nunca recebe `service_role`.
- Backend segue como dono de preço, agenda, estoque, caixa e autorização.
- `checkout_close`, `order_refund`, `create_appointment` e `update_appointment` preservam idempotência, concorrência, elegibilidade e semântica financeira; qualquer evolução é compatível e testada.
- Instantes permanecem em `timestamptz`/UTC. Timezone de unidade orienta cálculo e exibição local, sem reinterpretar dados históricos.

## 8. Gates de Blueprint e definição de pronto

| Gate | Evidência exigida |
|---|---|
| Schema | Colunas, tipos, PK/FK tenant-safe, constraints de papel/unidade, índices e estratégia de rollback revisados. |
| Backfill | Inline na Migration 1, idempotente, timezone fixa `America/Sao_Paulo`, métricas de cobertura e caminho para zero registros sem unidade antes da Migration 2. |
| Tenant/RLS | Testes cross-tenant e cross-unit; proibição de `unit_id` isolado; permissão reavaliada por requisição. |
| Agenda | Profissional sem vínculo ativo negado; unidade de appointment imutável; reagendamento explícito. |
| Financeiro/estoque | Unidade do filho coincide com o pedido; ajustes autorizados; fatos imutáveis. |
| Auditoria | Eventos append-only, sem PII, acesso exclusivo de owner/admin e origem system/user correta. |
| Compatibilidade | Fluxos legados resolvem default no backend; PWA atual não quebra; remoção de fallback tem gate explícito. |

## 9. Veredito

**APROVADO, QA `GO`.** Onda 0 está pronta para solicitar aprovação explícita do Platform Owner para SQL (Etapa 8). Até essa nova aprovação, nenhuma implementação é autorizada.
