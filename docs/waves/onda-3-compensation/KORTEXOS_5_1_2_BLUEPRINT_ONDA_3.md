---
title: "Blueprint Onda 3 — Compensation: Staff Levels & Comissão de Venda"
status: "DRAFT"
stage: "BLUEPRINT"
governance_ref: ["DEC-24", "DEC-27", "DEC-28", "DEC-44"]
upstream_doc: "docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md"
last_updated: "2026-07-27"
---

# KortexOS 5.1.2 — Blueprint Onda 3: Compensation — Staff Levels & Comissão de Venda

**Status:** **RASCUNHO, red team de desenho concluído.** 1ª rodada `$kortex-qa-redteam`: `NO-GO` com 1 achado crítico (`staff_level_id` nullable vs. "Obrigatório" do Master §6.1, sem desvio registrado) e 6 achados menores (achado §0 com alegação de duração errada e citação de linha desatualizada; unicidade de `commission_sale_records` bloquearia venda repetida legítima do mesmo pacote; FKs sem `on delete`; `search_path` ausente em 2 funções `security definer`; índice secundário faltando em `staff_level_service_overrides`; precedente de `no_show_settlement_create` citado incorretamente). Todos os 7 corrigidos neste documento (ver §0, §3.1, §3.4, §4). Aguardando 2ª rodada de red team e aprovação explícita do Platform Owner antes de qualquer SQL/migration/Etapa 8.
**Etapa:** 7 (Blueprint), em redação — achados da 1ª rodada de red team incorporados.
**Escopo:** subconjunto de D17/D05, exatamente a tabela da Onda 3 em `KORTEXOS_5_1_2_MIGRATION_MAP.md` §3 — `staff_levels`, `staff_level_service_overrides`, `private.resolve_sale_commission()`, `commission_sale_records`. `private.resolve_commission()` (execução) permanece intocada, decisão já fechada (Migration Map, §4 decisão 2). **Exclui deliberadamente** Cash Sessions/Void (ADR 0007) e Comissão Escalonada (ADR 0003) — ambos mencionados pela DEC-29 como "re-hospedados" em Onda 3 por tema, mas nenhum dos dois está listado como objeto na tabela aprovada do Migration Map §3, e a ADR 0003 nunca saiu do status `Proposed`. Confirmado com o Platform Owner nesta sessão: escopo desta Onda é estritamente o Migration Map; os dois temas ficam para onda própria futura, com adendo ao Migration Map antes de qualquer Blueprint — mesmo padrão usado para fechar o gap do D02 (DEC-25).

## 0. Achado pré-existente relevante para esta Onda

**Corrigido após red team de desenho (evidência conferida pessoalmente contra o código vigente, não a versão originalmente citada):**

- **Preço:** `checkout_close` (definição vigente em `supabase/migrations/20260726190000_onda1_checkout_close_deposit_appointment_guard.sql`, que redefine a função por último — a migration `20260713060000` citada numa versão anterior deste achado já está superada) resolve preço de serviço lendo `services.price_cents` diretamente — **nunca** consulta `professional_service_capabilities.price_override_cents`, apesar dessa coluna existir desde a Fase 10. O override de preço por profissional×serviço não tem efeito real hoje. Confirmado também que nenhuma rota de `backend/src/` referencia esse campo fora do CRUD de cadastro.
- **Duração — achado revisado, a alegação original estava errada:** diferente do preço, `create_appointment` e `update_appointment` (`supabase/migrations/20260716150000_fase_opcao_c_elegibilidade_snapshot.sql:245-251` e `:376-382`) **já consultam** `professional_service_capabilities.duration_override_minutes` via `coalesce(psc.duration_override_minutes, s.duration_minutes)`, e o resultado já é gravado em `appointments.resolved_duration_minutes`, afetando `ends_at` e o exclusion constraint de conflito de agenda. O override de duração por profissional×serviço (nível 1) **já está ativo em produção** — só o nível 2 (por staff level) seria integração nova ali.

Isso muda a leitura de risco da Decisão 2 (§3.2): ativar a cascata de PREÇO em `checkout_close` seria uma integração nova numa RPC crítica (risco alto, mesma classe da fatia 004/Onda 1); ativar a cascata de DURAÇÃO em `create_appointment`/`update_appointment` seria estender um `coalesce` que já existe hoje, um degrau de risco abaixo. Mesmo assim, nenhuma das duas é ativada nesta Onda (§3.2) — a assimetria fica registrada como informação para a onda de ativação decidir sequenciamento, não como justificativa para ativar parcialmente aqui.

## 1. Autoridade e limites

Este Blueprint materializa `docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md` (Onda 3, D17/D05, DEC-24/27/28) e `docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` — Parte III §6 (Staff Levels & Pricing Resolution, DEC-04) e Parte I (D17 — Compensation & Payout Engine, Gate 14 Commission Accuracy, Gate 02 Staff Privacy). Nenhuma decisão de produto já fechada é reaberta aqui — DEC-04 (override triplo por nível), DEC-15 (comissão de venda independente da de execução, escopo pacotes) e DEC-18 (fórmula de reembolso/clawback) são consumidas como regra vigente, não redesenhadas.

**Exclusão deliberada de escopo — fundação sem ativação em `checkout_close`/`create_appointment`.** Igual ao princípio já estabelecido pela Onda 2 (ADR 0019, "fundação sem ativação"): esta Onda constrói schema e funções de resolução testáveis isoladamente via pgTAP, mas **não modifica `checkout_close` nem `create_appointment`**. A cascata de preço/tempo por nível (§3.2) e a comissão de venda (§3.4) nascem como capability nova, sem produtor automático ligado ao caminho de venda real. Ativar qualquer uma delas dentro de `checkout_close` é, por si, um Blueprint/fatiamento próprio de risco equivalente à fatia 004 da Onda 1 (HITL, achado crítico em produção pós-merge — DEC-36) — decisão consciente de sequenciamento, não omissão.

`organization_id` continua sendo a fronteira primária de tenant. `unit_id` (Onda 0/DEC-28) se aplica a `commission_sale_records` (transacional, herda de `orders.unit_id`) mas **não** a `staff_levels`/`staff_level_service_overrides` (org-wide — nível de carreira não varia por unidade física, classificação já fechada no Migration Map). Este Blueprint não cria UI nem RPC exposta em rota Express além da explicitamente descrita em §3.4.

## 2. Escopo de dados

| Objeto | Contrato técnico | Estado |
|---|---|---|
| `staff_levels` | Cadastro de níveis de carreira por organização (`Aprendiz`, `Sênior`, etc.), nome e ordem livres (Master Parte III §6.1). Org-wide, sem `unit_id`. | Novo |
| `professionals.staff_level_id` | Coluna nova, nullable (profissional sem nível atribuído continua funcionando — cascata cai direto pro nível 3). Ponteiro simples ao nível atual, sem tabela de vigência histórica (ver Decisão 1, §3.1). | Extensão aditiva |
| `staff_level_service_overrides` | Override de preço/duração/comissão por nível×serviço — mesma forma de `professional_service_capabilities` (nível 1 da cascata) mas para o nível 2. Carrega os 3 eixos (preço, tempo, comissão) para bater com a regra de negócio (Master §6.1: "nível pode definir preço/duração/comissão"), mas só os eixos preço/tempo têm função de resolução nesta Onda (ver Decisão 3, §3.3) | Novo |
| `private.resolve_service_pricing()` | Função nova, `stable security definer` — cascata de preço/duração: override profissional×serviço (`professional_service_capabilities`) → override nível×serviço (`staff_level_service_overrides`) → base do serviço (`services`). Equivalente de `resolve_commission()` para os eixos preço/tempo, hoje inexistente (Migration Map, linha Onda 3/staff_levels). **Sem call site nesta Onda** — testável isoladamente, não consumida por `checkout_close`/`create_appointment` (ver achado §0 e Decisão 2, §3.2) | Novo (schema + função, sem produtor) |
| `packages.sale_commission_type` / `packages.sale_commission_value` | Campo próprio no cadastro do pacote, % ou valor fixo (DEC-15, item a) — mesma forma de `professional_service_commissions.commission_type`/`commission_value`. Nullable: pacote pode não ter comissão de venda configurada. | Extensão aditiva |
| `private.resolve_sale_commission()` | Função nova, `stable security definer` — lê os 2 campos acima do pacote e retorna o valor resolvido (sem cascata — é um campo flat, não profissional×serviço). Independente de `resolve_commission()`, nunca reduz nem é reduzida por ela (mandato explícito DEC-15/DEC-24 decisão 2). | Novo |
| `commission_sale_records` | Uma linha por comissão de venda reconhecida — `order_id`, `package_id`, `professional_id` (o vendedor), valor resolvido, `status` (`accrued`\|`clawed_back`). `unit_id` direto (herda de `orders.unit_id`). Coluna `kortex_ledger_transaction_id` nullable, reservada para quando uma Onda futura ativar postagem real no ledger (Onda 2 segue sem produtor — ver Decisão 5, §3.5) | Novo |
| `commission_sale_record_create` (RPC) | Grava uma linha em `commission_sale_records` a partir de `order_id`/`package_id`/`p_seller_professional_id` explícito. Idempotente (mesmo padrão `private.idempotency_keys`). **Sem call site automático nesta Onda** — quem é "o vendedor" não existe como conceito no payload atual de `checkout_close` (achado, ver Decisão 4, §3.4); wiring de produção fica para follow-up com decisão de UI própria. | Novo (RPC, sem produtor automático) |
| `organizations.settings` | Coluna nova `jsonb not null default '{}'` — chave de Feature Flag para Dark Launching (DEC-44). Reaproveitável por todas as Ondas futuras, não exclusiva desta. | Extensão aditiva |

## 3. Integridade e invariantes

### 3.1 Decisão — `staff_levels`: ponteiro simples, não tabela temporal

`professionals.staff_level_id` é um ponteiro único ao nível atual (nullable, `on delete restrict`). Não existe tabela de vigência/histórico de nível.

**Por quê:** "promoção não retroage" (Master §6.2: "Preço/tempo resolvidos travam no appointment confirmado; promoção de nível posterior não reprecifica") já é garantido pelo padrão de snapshot no momento da confirmação (ADR 0011), não por uma consulta retroativa "qual era o nível em 15/06". Nenhum consumidor precisa de histórico de nível fora do momento da resolução, que já é congelado no evento (appointment/order_item), não na tabela de níveis.

**Alternativa rejeitada:** tabela `professional_level_history` com `valid_from`/`valid_to`. Rejeitada — complexidade temporal sem consumidor real; se aparecer necessidade real (ex.: relatório histórico de nível por profissional), é mudança aditiva futura, não custo pago agora.

**Desvio registrado, não silencioso — "Obrigatório" (Master §6.1) vs. `nullable` (achado do red team de desenho).** O Master Briefing Parte III §6.1 declara "Nível do profissional | Obrigatório; com vigência (promoção não retroage)". Este Blueprint materializa a parte "não retroage" (parágrafo acima) mas **não** torna `staff_level_id` `not null` — decisão consciente, não omissão: `staff_levels` nasce vazia por organização (§5) e é cadastro deliberado do owner/admin; se a coluna fosse `not null` desde a primeira migration, toda organização existente ficaria sem conseguir que `professionals` aceite `INSERT`/`UPDATE` até cadastrar níveis que ainda não decidiu nomear — nenhuma há hoje. **A obrigatoriedade real é uma regra de ATIVAÇÃO, não de fundação:** quando uma organização adota Staff Levels (Feature Flag `staff_levels_enabled`, §3.7) e a Onda de ativação ligar a cascata de preço/tempo a `create_appointment`/`checkout_close`, a exigência de "obrigatório" passa a ser aplicada pelo BACKEND no fluxo de criação/edição de profissional daquela organização (validação de aplicação, não `CHECK` de banco) — mesmo padrão já usado para tornar features novas opt-in sem quebrar tenants que não adotaram ainda. Nenhuma organização é forçada a preencher nível antes de decidir usar a feature. Este desvio fica registrado aqui e na ADR 0020 — não é uma reabertura silenciosa de DEC-04.

### 3.2 Decisão — cascata de preço/tempo por nível: função nova, sem ativação

`private.resolve_service_pricing(p_organization_id, p_professional_id, p_service_id)` implementa a cascata dos 3 níveis para preço e duração, mesmo formato de retorno de `private.resolve_commission()` (`stable`, `security definer`, `revoke all from public/anon/authenticated`). **Não é chamada por nenhuma RPC nesta Onda.**

**Por quê:** o achado §0 mostra que mesmo o nível 1 (override profissional×serviço, já existente desde a Fase 10) nunca foi ligado a `checkout_close`. Ativar a cascata de preço — nível 1 já existente + nível 2 novo desta Onda — dentro de `checkout_close` ou `create_appointment` é, por si, uma mudança de comportamento no caminho mais crítico do sistema (mesma classe de risco da fatia 004 da Onda 1, que produziu o achado crítico da DEC-36 pós-merge). Fundação pronta, ativação é decisão própria de onda futura.

**Alternativa rejeitada:** ativar a cascata em `checkout_close` já nesta Onda, aproveitando para também corrigir o achado §0. Rejeitada — dobraria o raio de explosão (2 schemas novos + reescrita de lógica de preço numa RPC financeira crítica) na mesma sessão, exatamente o padrão que a Onda 2 (ADR 0019) já rejeitou pelo mesmo motivo.

### 3.3 Decisão — comissão por nível: coluna existe, função de resolução não usa ainda

`staff_level_service_overrides` grava `commission_type`/`commission_value` (as 3 colunas de override do Master §6.1 vivem juntas na mesma linha nível×serviço). Mas `private.resolve_commission()` (execução) **não muda** — continua sua cascata atual (profissional×serviço → serviço → grupo), sem consultar `staff_level_service_overrides`.

**Por quê:** o Migration Map fecha isso explicitamente — `resolve_commission()` está marcado "Intocado, decidido" (§4 decisão 2), e o mandato de ativação de cascata "hoje inexistente" no texto da Onda 3 se refere nomeadamente a preço/tempo, não a comissão. Gravar o dado agora e não consumi-lo ainda é o mesmo idioma já usado em `benefit_obligations` (Onda 2: "nasce vazia, sem produtor nesta Onda").

**Risco registrado, não escondido:** isso cria uma divergência temporária entre a regra completa do Master §6.2 (nível deveria afetar os 3 eixos) e o comportamento real (só preço/tempo têm função de resolução, e nem essa está ativada). Fica como achado explícito para a onda que decidir tocar `resolve_commission()`.

### 3.4 Decisão — comissão de venda: função + RPC prontas, sem call site automático

`private.resolve_sale_commission(p_organization_id, p_package_id)` lê `packages.sale_commission_type`/`sale_commission_value` e retorna o valor resolvido (`null` se o pacote não configura comissão de venda — RPC de gravação vira no-op nesse caso). RPC `public.commission_sale_record_create(p_organization_id, p_actor_user_id, p_idempotency_key, p_order_id, p_package_id, p_seller_professional_id)` grava em `commission_sale_records`, autorização `owner`/`admin`/`manager`/`reception` (mesma lista de `checkout_close`, já que é chamada pelo mesmo fluxo operacional). **Nenhuma rota Express chama essa RPC automaticamente nesta Onda.**

**Achado que motiva a decisão:** o payload de `checkout_close` (branch `kind = 'package'`) mapeia `service_id → professional_id` (quem *executa* cada componente), mas não carrega em nenhum lugar quem *vendeu* o pacote — DEC-15 é explícito que o vendedor "pode ou não ser quem executa as sessões". Não existe hoje nenhum campo no payload, na tela de checkout ou em `order_items` que capture essa identidade. Assumir "o vendedor é o profissional do primeiro componente" seria um default plausível mas **factualmente errado** frente à própria definição da DEC-15 — decisão consciente de não inventar essa regra aqui.

**Por quê ainda assim construir a RPC pronta:** o valor de entregar `resolve_sale_commission()` + `commission_sale_records` + a RPC de gravação como unidade testável e chamável isoladamente (via pgTAP, com `p_seller_professional_id` explícito) é real e não depende de resolver a captura de "quem vendeu" — mesmo padrão de `deposit_hold_create` (Onda 1, fatia 003): RPC nova, chamada pelo backend Express logo após uma RPC existente (`create_appointment`) sem alterar seu corpo, e que segue ativa em produção hoje (`backend/src/modules/appointments/appointments.service.js`) — precedente real e vivo de "RPC isolada, ativada por chamada do backend, sem tocar a RPC principal", não um padrão hipotético.

**Follow-up explícito, fora desta Onda:** decidir onde a tela de checkout captura "quem vendeu este pacote" (novo campo na UI + no payload que o backend envia) é uma decisão de produto pequena, mas real, que este Blueprint não assume por conta própria.

### 3.5 Decisão — sem postagem no ledger nesta Onda

`commission_sale_record_create` grava em `commission_sale_records` mas **não chama `kortex_ledger_post`**. `kortex_ledger_transaction_id` nasce nullable, preenchida só quando uma Onda futura ligar a postagem real.

**Por quê:** a Onda 2 (o ledger) segue `NO-GO` para `staging`/`main`, sem nenhum produtor real ativado (ADR 0019, "fundação sem ativação"). Empilhar o primeiro produtor real do ledger em cima de uma fundação ainda não promovida amplia o raio de explosão desta Onda sem necessidade — e não é regressão: comissão de execução (`order_items.commission_cents`) já opera hoje inteiramente fora do ledger (que não existe como sistema ativo), então comissão de venda seguir o mesmo estado por enquanto é consistente, não uma nova dívida.

**Alternativa rejeitada:** ativar `kortex_ledger_post` já nesta Onda só para comissão de venda. Rejeitada — ativação parcial do ledger (só um produtor, isolado) cria uma superfície onde parte do dinheiro está no ledger e parte não, mais confuso que nenhuma parte estar. Ativação deve ser decisão íntegra de uma onda de ativação própria (mesmo racional do "Onda 2b" já registrado em ADR 0019).

### 3.6 Reversão (clawback, DEC-18) — não automatizada nesta Onda

`commission_sale_records.status` (`accrued`\|`clawed_back`) permite reversão manual registrada, mas nenhuma RPC de reversão automática nasce aqui. Mesmo racional já usado por `order_void` (ADR 0007: "não reverterá comissão automaticamente — aguarda decisão de classificação do profissional, ADR 0005"). A regra de negócio (DEC-18: clawback total se e somente se uso=0) já está definida; a automação fica no mesmo backlog que ADR 0005 abriu para comissão de execução.

### 3.7 Feature Flag e Dark Launching (DEC-44)

`organizations.settings jsonb not null default '{}'` — coluna nova em `organizations`, reaproveitável por qualquer Onda futura (não exclusiva desta). Duas chaves independentes nesta Onda: `settings->>'staff_levels_enabled'` e `settings->>'sale_commission_enabled'` — schema e RPCs existem sempre (não há "meio SQL"), a flag governa só se uma rota Express futura expõe o comportamento. Default ausente/`false` = comportamento idêntico ao pré-Onda-3 (nenhuma rota nova nesta Onda para governar de qualquer forma — a flag nasce pronta para quando a Onda de ativação existir). Escrita da chave restrita a `owner`/`admin` (mesma allowlist de configuração organizacional sensível, `membership_set`).

### 3.8 Matriz de autorização — RLS

| Objeto | SELECT | INSERT/UPDATE | DELETE |
|---|---|---|---|
| `staff_levels` | Todos os membros (`is_member`) — cadastro operacional, mesmo padrão de `services`/`service_groups` | `owner`/`admin`/`manager` | `owner`/`admin` |
| `staff_level_service_overrides` | `owner`/`admin`/`manager` — carrega comissão (dado financeiro), tratamento mais estrito que `professional_service_capabilities` isolado (ver nota abaixo) | `owner`/`admin`/`manager` | `owner`/`admin` |
| `commission_sale_records` | `owner`/`admin`/`manager` (org-wide) + profissional vendedor, self-view (`professionals.user_id = auth.uid()`, mesmo padrão `staff_current_accounts` §7 da Onda 2, Gate 02) | Nenhum grant direto — só `commission_sale_record_create` (`security definer`) | Nenhum grant — reversão é `UPDATE status`, não `DELETE` |

**Nota sobre `staff_level_service_overrides`:** diferente de `professional_service_capabilities` (que reception enxerga hoje, `is_member`), esta tabela mistura comissão no mesmo registro de preço/duração por nível — optado por aplicar a regra mais estrita (financeira) à tabela inteira em vez de fatiar em 2 tabelas, para não contradizer o nome do objeto já aprovado no Migration Map ("staff_level_service_overrides", singular). Custo aceito: reception perde visibilidade de preço/duração por nível que tinha por profissional individual — sem consumidor real hoje (§3.2), revisitável se virar necessidade concreta.

## 4. Contrato físico de schema

### `staff_levels`
`id` uuid PK, `organization_id` uuid (FK `organizations`, `on delete restrict`), `name` text (`check length(trim(name)) between 1 and 80`), `rank` integer not null (`check rank >= 0`, ordem de exibição/hierarquia — não usado por nenhuma lógica de cascata, só apresentação), `active` boolean default true, `created_at`/`updated_at`. **Unicidade:** `(organization_id, id)` (padrão FK composta), `(organization_id, name)`, `(organization_id, rank)`.

### `professionals` (extensão)
`+ staff_level_id` uuid nullable, FK composta `(organization_id, staff_level_id) references staff_levels(organization_id, id) on delete restrict`.

### `staff_level_service_overrides`
`id` uuid PK, `organization_id` uuid (FK `organizations`), `staff_level_id` uuid not null, `service_id` uuid not null, `duration_override_minutes` integer nullable (`check between 5 and 1440`, mesmo range de `professional_service_capabilities`), `price_override_cents` bigint nullable (`check >= 0`), `commission_type` text nullable (`check in ('percentage','fixed')`), `commission_value` bigint nullable (`check >= 0`, `check commission_type is distinct from 'percentage' or commission_value <= 10000` — mesmo teto de 100% em basis points de `professional_service_commissions`), `check` par: `commission_type`/`commission_value` ambos nulos ou ambos preenchidos (mesmo padrão `order_items_commission_pair`). `created_at`/`updated_at`. **Unicidade:** `(organization_id, staff_level_id, service_id)`. **FKs compostas:** `(organization_id, staff_level_id) references staff_levels(organization_id, id) on delete restrict`, `(organization_id, service_id) references services(organization_id, id) on delete restrict`. **Índice adicional (achado do red team — faltava na primeira redação):** `staff_level_service_overrides_service_idx on (organization_id, service_id)`, mesmo padrão de `professional_service_capabilities_service_idx` (`supabase/migrations/20260715140000_fase10_capabilities.sql:25-27`), para consultas "quais níveis sobrepõem este serviço".

### `private.resolve_service_pricing(p_organization_id uuid, p_professional_id uuid, p_service_id uuid)`
`returns table (price_cents bigint, duration_minutes integer)`, `language sql stable security definer set search_path = pg_catalog, public, private`. Corpo: `coalesce(psc.price_override_cents, slso.price_override_cents, s.price_cents)` e equivalente para duração, com `left join professional_service_capabilities psc` e `left join staff_level_service_overrides slso on slso.staff_level_id = professionals.staff_level_id` — mesma forma de `resolve_commission()`, `coalesce` do mais específico pro mais genérico, nunca soma. `revoke all on function ... from public, anon, authenticated`.

### `packages` (extensão)
`+ sale_commission_type` text nullable (`check in ('percentage','fixed')`), `+ sale_commission_value` bigint nullable (`check >= 0`, mesmo teto percentual de 10000). Par nulo/preenchido em conjunto, mesmo padrão.

### `private.resolve_sale_commission(p_organization_id uuid, p_package_id uuid)`
`returns table (commission_type text, commission_value bigint)`, `language sql stable security definer set search_path = pg_catalog, public, private` (achado do red team — a primeira redação omitia `search_path`, inconsistente com toda outra função `security definer` do projeto). Lê `packages.sale_commission_type`/`sale_commission_value` direto (sem cascata — campo flat). `revoke all from public, anon, authenticated`.

### `commission_sale_records`
`id` uuid PK, `organization_id` uuid (FK `organizations`), `unit_id` uuid (denormalizado de `orders.unit_id` no momento da gravação), `order_id` uuid, `package_id` uuid (FK composta `(organization_id, package_id) references packages(organization_id, id) on delete restrict`), `professional_id` uuid (FK composta `(organization_id, professional_id) references professionals(organization_id, id) on delete restrict` — o vendedor), `commission_type` text (`check in ('percentage','fixed')`), `commission_value` bigint (`check >= 0`), `commission_cents` bigint not null (`check >= 0`, valor resolvido em centavos, mesma convenção `order_items.commission_cents`), `status` text not null default `'accrued'` (`check in ('accrued','clawed_back')`), `kortex_ledger_transaction_id` uuid nullable (FK composta `(organization_id, kortex_ledger_transaction_id) references kortex_ledger_transactions(organization_id, id) on delete restrict`, preenchida só por onda futura de ativação), `created_at`/`updated_at`.

**FK de `order_id` corrigida após red team de desenho:** `(organization_id, order_id, unit_id) references orders(organization_id, id, unit_id)` — mesmo padrão de 3 colunas já usado por `order_items`/`payments`/`inventory_movements` (`supabase/migrations/20260723025006_onda0_units_schema_backfill.sql:318-324`, via `orders_org_id_unit_unique`), não a FK simples de 2 colunas da primeira redação. Garante em nível de banco que o `unit_id` desnormalizado bate com o `unit_id` real do pedido — não só "confiar que a RPC copiou certo".

**Unicidade removida após red team de desenho.** A primeira redação propunha `unique (organization_id, order_id, package_id, professional_id)` para evitar duplicar comissão — **errado**: `checkout_close` não deduplica entradas repetidas de `kind='package'` no array `items` (confirmado por leitura do loop), então vender o MESMO pacote 2 vezes no MESMO pedido pelo MESMO vendedor é um cenário legítimo hoje, e essa constraint bloquearia a 2ª comissão legítima com um erro bruto de unicidade. **Sem unicidade de chave de negócio nesta tabela** — mesmo padrão já usado por `order_items` (só `id` como PK, várias linhas podem descrever "o mesmo" serviço/pacote dentro do mesmo pedido). Exclusividade de gravação (nunca gravar a mesma comissão 2x por erro/retry) é responsabilidade exclusiva de `p_idempotency_key` na RPC (§ abaixo), não de constraint de banco sobre as colunas de negócio.

### `commission_sale_record_create` (RPC)
`public.commission_sale_record_create(p_organization_id uuid, p_actor_user_id uuid, p_idempotency_key text, p_order_id uuid, p_package_id uuid, p_seller_professional_id uuid) returns jsonb`, `language plpgsql security definer set search_path = pg_catalog, public, private` (mesmo achado de `search_path` ausente, corrigido). Valida `actor_has_role(owner/admin/manager/reception)`, valida `order` existe/pertence à org/está `closed`, valida `package`/`professional` existem e pertencem à org, resolve via `resolve_sale_commission`; se `commission_type is null`, retorna no-op (`{"skipped": true, "reason": "package has no sale commission configured"}`) sem inserir linha; senão calcula `commission_cents` (mesma fórmula percentage/fixed de `checkout_close`) e insere, reaproveitando `private.idempotency_keys` como único mecanismo de exatamente-uma-vez. **Contrato do chamador (por causa da unicidade removida acima):** o backend deve chamar esta RPC uma vez por unidade de pacote vendida no pedido (se o mesmo `package_id` aparece 2× no payload original de `checkout_close`, são 2 chamadas), cada uma com `p_idempotency_key` distinto (ex.: `{order_id}:{package_id}:{índice na lista de items}`) — mesma responsabilidade de composição de chave que o backend já tem hoje em qualquer chamada de RPC idempotente.

### `organizations` (extensão)
`+ settings` jsonb not null default `'{}'::jsonb`.

## 5. Compatibilidade e backfill

Toda mudança é aditiva. `professionals.staff_level_id` nasce nullable — nenhum profissional existente quebra (cascata cai direto no nível 3, igual hoje). `packages.sale_commission_type`/`sale_commission_value` nascem nullable — pacotes existentes seguem sem comissão de venda até serem configurados explicitamente. `organizations.settings` nasce com default `'{}'` — nenhuma organização existente precisa de backfill de linha, só o default da coluna. Nenhuma tabela existente (`services`, `professionals`, `packages`, `orders`) tem coluna removida ou constraint alterada. Confirmado por leitura direta: nenhuma rota Express, RPC ou teste atual referencia `staff_levels`/`staff_level_service_overrides`/`commission_sale_records`/`resolve_service_pricing`/`resolve_sale_commission` — são objetos inteiramente novos, sem consumidor hoje.

**Sem backfill de dado obrigatório:** diferente da Onda 0 (toda unidade existente precisava das 7 contas fixas) e da Onda 2 (toda unidade existente precisava do seed de `kortex_accounts`), esta Onda não tem nenhuma entidade pré-existente que precise de linha retroativa — `staff_levels` nasce vazia por organização (cadastro é ato deliberado do owner/admin), `commission_sale_records` nasce vazia (sem produtor).

## 6. Plano de execução e rollback

Toda a Onda é aditiva por construção — nenhuma tabela/RPC/função existente é alterada (`checkout_close`, `create_appointment`, `resolve_commission()` permanecem intocados). Rollback de qualquer migration desta Onda é reverter a migration inteira — zero dado existente é tocado.

**Pre-flight Check obrigatório por migration (DEC-44).** Cada migration desta Onda abre com um bloco `do $$ begin ... end $$` que confere pré-condição via `to_regclass`/`information_schema` antes de qualquer DDL — ex.: a migration de `staff_level_service_overrides` assert que `to_regclass('public.staff_levels') is not null` antes de criar a FK composta; a migration de `commission_sale_records` assert que `to_regclass('public.packages') is not null` e que a coluna `packages.sale_commission_type` já existe. Aborta com mensagem explícita (`raise exception`) se a pré-condição falhar, em vez de deixar o `CREATE TABLE ... REFERENCES` falhar com erro genérico do Postgres.

Esta Onda **passa pelo Fatiamento** (`$prd-to-issues`, DEC-33) antes de qualquer SQL. Fatias verticais candidatas (a decidir/ajustar na etapa de Fatiamento, ver §7 do processo):

1. `organizations.settings` (Feature Flag, DEC-44) — fundação reaproveitável, sem dependência de nada nesta Onda
2. `staff_levels` + `professionals.staff_level_id` — cadastro de nível, sem dependência de override ainda
3. `staff_level_service_overrides` + `private.resolve_service_pricing()` — cascata de preço/tempo, depende da fatia 2
4. `packages.sale_commission_type/value` + `private.resolve_sale_commission()` + `commission_sale_records` + `commission_sale_record_create` — comissão de venda completa, independente das fatias 2-3

Cada fatia segue `$tdd` com pgTAP (SQL) e, onde houver rota Express futura, Jest com mocks de API (DEC-44, otimização 3) — nenhuma rota Express nasce nesta Onda (§3.4), então o componente Jest fica reservado para quando o call site existir. Cada fatia passa por `$kortex-qa-redteam` antes de integrar — mesmo processo das Ondas 1/2. Commits de implementação referenciam a issue correspondente (`closes issues/NNN`, DEC-44 otimização 4).

## 7. Matriz RLS e contratos afetados (consolidado)

| Objeto | SELECT | INSERT/UPDATE | DELETE |
|---|---|---|---|
| `staff_levels` | `is_member` | `owner`/`admin`/`manager` | `owner`/`admin` |
| `staff_level_service_overrides` | `owner`/`admin`/`manager` | `owner`/`admin`/`manager` | `owner`/`admin` |
| `commission_sale_records` | `owner`/`admin`/`manager` + self-view do profissional vendedor | Nenhum grant direto — só `commission_sale_record_create` | Nenhum grant |
| `organizations.settings` (coluna) | Igual à política já existente de `organizations` (membros) | Escrita restrita a `owner`/`admin` | — |

Nenhum caller existente quebra: confirmado por leitura de `backend/src/` e das migrations anteriores que nenhuma rota, RPC ou teste referencia qualquer objeto novo desta Onda.

## 8. Riscos registrados para follow-up (não resolvidos por este Blueprint)

1. **Achado §0 (pré-existente):** `professional_service_capabilities` (Fase 10) nunca foi ligada a `checkout_close` — preço/duração override não tem efeito real hoje. Esta Onda não corrige; só evita empilhar mais uma camada não-ativada sem registrar o fato.
2. **"Quem vendeu" não existe no payload de checkout (§3.4):** `commission_sale_record_create` está pronta, mas sem call site até uma decisão de UI capturar o vendedor do pacote, distinto de quem executa.
3. **Divergência temporária Master §6.2 vs. implementação (§3.3):** nível pode, por regra de negócio, afetar comissão — `resolve_commission()` não considera isso ainda.
4. **Ativação do ledger para comissão de venda (§3.5):** `commission_sale_records` não posta em `kortex_ledger_entries` — depende de uma Onda de ativação do ledger que ainda não existe (nem para Onda 2, que segue `NO-GO`).

---

Depois de redigido, este documento segue para `$kortex-qa-redteam` (gate de desenho) antes de qualquer pedido de aprovação ao Platform Owner.
