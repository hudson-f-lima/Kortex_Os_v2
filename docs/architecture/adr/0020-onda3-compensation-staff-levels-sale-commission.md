# ADR 0020: Onda 3 — Compensation: Staff Levels & Comissão de Venda (Fundação sem Ativação)

## Status
Proposed (rascunho, 2026-07-27). 1ª rodada `$kortex-qa-redteam` (agente independente): `NO-GO`, 1 achado crítico (`staff_level_id` nullable contradizendo "Obrigatório" do Master §6.1 sem desvio registrado) + 6 achados menores (ver Blueprint Onda 3 §0/§3.1/§3.4/§4/§8 para a lista completa e a correção de cada um). Todos corrigidos nesta revisão da ADR. Aguarda 2ª rodada de red team e aprovação explícita do Platform Owner (DEC própria) antes de virar Accepted.

**Onda relacionada:** [Onda 3 — Compensation](../../waves/onda-3-compensation/KORTEXOS_5_1_2_BLUEPRINT_ONDA_3.md) · [Migration Map](../../waves/KORTEXOS_5_1_2_MIGRATION_MAP.md)

## Date
2026-07-27

## Context

A Onda 3 (Migration Map v1.2, §3, D17/D05) cobre dois objetos aprovados: `staff_levels`/`staff_level_service_overrides` (DEC-04, override de preço/tempo/comissão por nível de carreira) e `private.resolve_sale_commission()`/`commission_sale_records` (DEC-15, comissão de venda de pacote, independente da comissão de execução). `private.resolve_commission()` permanece intocada por decisão já fechada (Migration Map §4, decisão 2).

### Ambiguidade de escopo resolvida antes da redação

A DEC-29 (encerramento do MVP) descreve Sessões de Caixa/Void (ADR 0007, Accepted) e Comissão Escalonada (ADR 0003, ainda `Proposed`) como "re-hospedadas" em Onda 3 por tema. Nenhum dos dois objetos aparece na tabela §3 do Migration Map aprovado (DEC-24/27/28). Interview de alinhamento com o Platform Owner (nesta sessão) confirmou escopo estrito ao Migration Map — os dois temas ficam para onda própria futura, com adendo ao Migration Map antes de qualquer Blueprint, mesmo padrão usado para o gap do D02 (DEC-25).

### Motivações

1. **Sequenciamento já decidido (Migration Map §4):** `resolve_commission()` fica intocada; comissão de venda é função própria e independente (decisão 2). Nenhum objeto desta Onda tem dependência estrutural que force tocar `checkout_close`.
2. **Achado de código real (revisado após red team — a alegação original sobre duração estava errada):** `checkout_close` (definição vigente: `supabase/migrations/20260726190000_onda1_checkout_close_deposit_appointment_guard.sql`) resolve preço lendo `services.price_cents` direto — nunca consulta `professional_service_capabilities.price_override_cents`. Esse gap é real só para PREÇO. Para DURAÇÃO, `create_appointment`/`update_appointment` (`supabase/migrations/20260716150000_fase_opcao_c_elegibilidade_snapshot.sql:245-251,376-382`) já consultam `professional_service_capabilities.duration_override_minutes` via `coalesce`, ativo em produção — só o nível 2 (staff level) seria integração nova ali.
3. **Precedente de risco (DEC-36):** a fatia 004 da Onda 1 (tocar `checkout_close`) produziu o único bug crítico pós-merge do projeto até agora. Qualquer ativação de cascata de preço ou de comissão de venda dentro de `checkout_close` é, por construção, da mesma classe de risco.
4. **Ledger ainda não ativado (ADR 0019):** a Onda 2 é fundação sem produtor real, `NO-GO` para `staging`/`main`. Empilhar o primeiro produtor real do ledger em cima de uma fundação não promovida amplia o raio de explosão sem necessidade.

### Constraints

- **Não tocar `checkout_close` nem `create_appointment` nesta Onda.** Mesmo princípio da Onda 2 (ADR 0019) — ativação é Blueprint próprio.
- **`staff_levels`/`staff_level_service_overrides` são org-wide; `commission_sale_records` é transacional, `unit_id` direto** (Migration Map, DEC-28) — já decidido, só aplicado.
- **`_cents bigint`, nunca float** (§7.2 do Master), mesmo teto percentual de 10000 basis points já usado em `professional_service_commissions`.
- **DEC-44 (primeira Onda sob o protocolo):** Feature Flag em `organizations.settings`, Pre-flight Check por migration, TDD com pgTAP/Jest, rastreabilidade via `closes issues/NNN`.

## Decision

### Fundação sem ativação — dois objetos, dois pontos de ativação futuros, nenhum ligado hoje

Como a Onda 2, esta Onda constrói schema e funções de resolução (`resolve_service_pricing`, `resolve_sale_commission`) testáveis isoladamente via pgTAP. Nenhuma delas é chamada por `checkout_close`/`create_appointment`. A RPC `commission_sale_record_create` existe e é funcional, mas sem call site automático.

**Alternativa rejeitada:** ativar a cascata de preço e/ou a comissão de venda dentro de `checkout_close` já nesta Onda. Rejeitada — dobraria o raio de explosão (2 schemas novos + reescrita de RPC financeira crítica), replicando o padrão de risco que a Onda 2 já rejeitou pelo mesmo motivo (ADR 0019, Alternativa A).

### `staff_levels`: ponteiro simples em `professionals`, sem tabela de vigência temporal

`professionals.staff_level_id` nullable, FK composta `on delete restrict`. "Promoção não retroage" (Master §6.2) é garantido pelo snapshot já existente no momento da confirmação (ADR 0011), não por histórico de nível.

**Alternativa rejeitada:** tabela `professional_level_history` com `valid_from`/`valid_to`. Rejeitada — nenhum consumidor real precisa de "qual era o nível numa data passada"; complexidade temporal paga sem necessidade comprovada.

**Achado crítico do red team, corrigido com desvio registrado:** o Master §6.1 declara nível "Obrigatório", mas `staff_level_id` nasce `nullable`. Resolução: a obrigatoriedade é regra de **ativação** (aplicada pelo backend quando a organização liga `staff_levels_enabled` e tenta usar a feature), não de **fundação** (banco). Forçar `not null` nesta Onda travaria `INSERT`/`UPDATE` de `professionals` em toda organização existente, já que `staff_levels` nasce vazia por org — não há nível nenhum para apontar até o owner cadastrar um. Ver Blueprint Onda 3 §3.1 para o texto completo do desvio.

### `staff_level_service_overrides`: uma tabela, 3 eixos, só 2 com função de resolução

A tabela carrega preço/duração/comissão por nível×serviço (bate com a regra de negócio do Master §6.1). Mas só preço/duração ganham função de resolução (`resolve_service_pricing`) nesta Onda — comissão fica gravada, não consumida, porque `resolve_commission()` está marcada "Intocada, decidido" no Migration Map.

**Alternativa rejeitada:** estender `resolve_commission()` para consultar `staff_level_service_overrides` como 3º nível de cascata. Rejeitada — contradiz decisão já fechada do Migration Map (§4, decisão 2); tocar uma função `security definer` chamada 2× dentro da transação atômica de `checkout_close`, hoje coberta por testes pgTAP estáveis, é exatamente o tipo de mudança que essa decisão evitou deliberadamente.

**Alternativa rejeitada:** duas tabelas separadas (`staff_level_service_pricing` + `staff_level_service_commissions`), espelhando a separação já existente em `professional_service_capabilities`/`professional_service_commissions` no nível 1. Rejeitada por nome — o Migration Map já aprovou o objeto no singular ("staff_level_service_overrides"); dividir em dois contradiz o objeto nomeado sem necessidade técnica que justifique reabrir esse ponto.

### Comissão de venda: RPC completa, sem call site — "quem vendeu" não existe no payload atual

`commission_sale_record_create(p_order_id, p_package_id, p_seller_professional_id)` é construída e testável isoladamente, mas nenhuma rota Express a chama automaticamente após `checkout_close`.

**Achado que motiva a decisão:** o payload de `checkout_close` (branch `package`) mapeia `service_id → professional_id` (quem executa cada componente) — não existe campo para "quem vendeu o pacote", e DEC-15 é explícito que o vendedor "pode ou não ser quem executa as sessões". Nenhum default incorreto (ex.: "vendedor = profissional do primeiro componente") foi assumido para evitar atribuir comissão à pessoa errada.

**Alternativa rejeitada:** assumir vendedor = profissional do primeiro item do pacote. Rejeitada — contradiz o texto literal da DEC-15; um default plausível que resolve a pergunta errada é pior que deixar a pergunta em aberto e registrada.

**Alternativa rejeitada:** adicionar `seller_professional_id` ao payload de `checkout_close` nesta Onda. Rejeitada — exigiria alterar a RPC financeira mais crítica do sistema para um campo que hoje não tem nenhuma superfície de UI que o colete; a mudança de UI (perguntar "quem vendeu" no checkout) é uma decisão de produto pequena mas real, fora do escopo que este Blueprint assume por conta própria.

**Precedente citado corrigido após red team:** a redação original citava `no_show_settlement_create` (Onda 1, fatia 005) como modelo de "RPC pronta esperando ativação limpa" — achado do red team mostrou que essa RPC foi ativada, depois substituída por um trigger, e hoje não tem nenhum chamador (abandonada, não "aguardando"). O precedente correto é `deposit_hold_create` (Onda 1, fatia 003): RPC nova chamada pelo backend Express logo após `create_appointment`, sem alterar seu corpo, e **ativa em produção hoje** (`backend/src/modules/appointments/appointments.service.js`) — precedente real de "RPC isolada, ativada por chamada externa, sem tocar a RPC principal".

**Achado menor do red team, corrigido — unicidade de negócio removida.** A redação original propunha `unique (organization_id, order_id, package_id, professional_id)` em `commission_sale_records`. Errado: `checkout_close` não deduplica entradas repetidas de `kind='package'` no payload — vender o mesmo pacote 2× no mesmo pedido pelo mesmo vendedor é cenário legítimo, e essa constraint bloquearia a 2ª comissão. Corrigido: sem unicidade de chave de negócio (mesmo padrão de `order_items`, só `id` como PK); exclusividade fica 100% a cargo de `p_idempotency_key`, com o chamador compondo uma chave distinta por unidade de pacote vendida.

**Achados menores adicionais do red team, corrigidos sem alternativa a documentar (consistência, não trade-off):** FK de `order_id` em `commission_sale_records` ampliada para o padrão de 3 colunas `(organization_id, order_id, unit_id) references orders(organization_id, id, unit_id)` já usado por `order_items`/`payments`/`inventory_movements`; `on delete restrict` explícito em todas as FKs de `commission_sale_records`; `set search_path = pg_catalog, public, private` adicionado a `resolve_sale_commission()`/`commission_sale_record_create()` (presente em toda outra função `security definer` do projeto, ausente na primeira redação); índice `staff_level_service_overrides_service_idx on (organization_id, service_id)` adicionado, espelhando `professional_service_capabilities_service_idx`.

### Sem postagem no ledger — `commission_sale_records` sozinha, `kortex_ledger_transaction_id` nullable reservado

Mesmo raciocínio de `benefit_obligations`/`payout_batches` na Onda 2: schema pronto para produtor futuro, sem ativação agora.

**Alternativa rejeitada:** ativar `kortex_ledger_post` só para comissão de venda nesta Onda. Rejeitada — ativação parcial do ledger (1 produtor isolado, o resto do dinheiro fora) é mais confuso que nenhuma parte estar ativada; ativação deveria ser decisão íntegra de uma onda própria.

### RLS de `staff_level_service_overrides`: regra financeira mais estrita aplicada à tabela inteira

`SELECT` restrito a `owner`/`admin`/`manager` (sem `reception`), diferente de `professional_service_capabilities` (que reception enxerga hoje).

**Alternativa rejeitada:** manter `is_member` (mesma política de `professional_service_capabilities`), já que preço/duração por si não é dado sensível. Rejeitada — a tabela mistura comissão (dado financeiro) na mesma linha; aplicar a política mais permissiva vazaria comissão para `reception`, violando o mesmo princípio de Gate 02 (Staff Privacy) que já rege `professional_service_commissions`. Custo aceito: reception perde visibilidade de override de preço por nível — sem consumidor real hoje (`resolve_service_pricing` não está ativada em nenhuma rota).

## Alternatives Considered

### A: Ativar a cascata de preço/tempo em `checkout_close`/`create_appointment` já nesta Onda
- **Pros:** feature realmente útil desde o primeiro dia; corrige de quebra o achado §0 (override de Fase 10 nunca ativado)
- **Cons:** dobra o raio de explosão numa RPC já responsável pelo único bug crítico pós-merge do projeto (DEC-36); mistura 2 mudanças estruturais na mesma sessão
- **Rejected:** fundação primeiro, ativação depois — mesmo princípio da Onda 2

### B: Assumir vendedor = profissional executor (primeiro componente do pacote)
- **Pros:** elimina a necessidade de nova UI; `commission_sale_record_create` ganha call site automático já nesta Onda
- **Cons:** contradiz o texto literal da DEC-15 ("pode ou não ser quem executa"); atribuiria comissão de venda à pessoa errada em qualquer caso onde vendedor ≠ executor
- **Rejected:** nenhum atalho que resolve a pergunta errada é aceitável para dado financeiro

### C: Duas tabelas para `staff_level_service_overrides` (pricing vs. commission), espelhando o nível 1
- **Pros:** RLS naturalmente diferenciada por eixo, sem precisar aplicar regra financeira à tabela inteira
- **Cons:** contradiz o nome do objeto já aprovado no Migration Map (singular); duplica um padrão que no nível 1 existe por acidente histórico (tabelas nasceram em fases diferentes), não por necessidade de desenho
- **Rejected:** uma tabela, RLS mais estrita aplicada ao todo, custo documentado

### D: Postar comissão de venda no ledger já nesta Onda
- **Pros:** exercitaria o Gate 11 (Ledger Balance) com dado real de comissão
- **Cons:** ativação parcial do ledger antes de qualquer promoção da Onda 2; mistura "schema novo" com "primeira ativação real do ledger" na mesma sessão
- **Rejected:** mesmo padrão de sequenciamento — fundação, depois ativação íntegra

## Consequences

### Aplicação
- **Fatiamento (DEC-33):** 4 fatias verticais candidatas (`organizations.settings` → `staff_levels`+`professionals.staff_level_id` → `staff_level_service_overrides`+`resolve_service_pricing` → `packages.sale_commission_*`+`resolve_sale_commission`+`commission_sale_records`+`commission_sale_record_create`), cada uma testável isoladamente via `$tdd`
- **Rollback:** toda a Onda é aditiva pura — nenhuma tabela/RPC existente é alterada, reverter qualquer migration não toca dado existente
- **DEC-44 (primeira Onda sob o protocolo):** Feature Flag (`organizations.settings`), Pre-flight Check por migration (`to_regclass` antes de FK composta nova), TDD pgTAP/Jest, `closes issues/NNN` em cada commit de implementação

### Código
- **`checkout_close`/`create_appointment`/`resolve_commission()`:** não são tocados nesta Onda — zero risco novo nas RPCs mais críticas do sistema
- **`resolve_service_pricing`/`resolve_sale_commission`/`commission_sale_record_create`:** funções/RPC novas, sem rota Express nesta Onda — só pgTAP chama diretamente
- **Frontend:** nenhuma UI nesta onda, mesma decisão já aplicada nas Ondas 0/1/2

### Futuro
- **Onda de ativação de preço/tempo:** liga `resolve_service_pricing` a `checkout_close`/`create_appointment` — Blueprint próprio, mesmo escrutínio da fatia 004 da Onda 1; também corrige o achado §0 (override de Fase 10 nunca ativado)
- **Onda de ativação de comissão por nível:** estende `resolve_commission()` (ou substitui) para considerar `staff_level_service_overrides` — Blueprint próprio, reabre deliberadamente a decisão "intocada" do Migration Map §4
- **Decisão de UI "quem vendeu":** pequena mudança de produto, fora desta Onda, necessária antes de `commission_sale_record_create` ganhar call site real
- **Onda de ativação do ledger:** quando a Onda 2 for promovida e ganhar produtores reais, `commission_sale_records.kortex_ledger_transaction_id` deixa de ser sempre nulo

## Related Decisions

- **DEC-04:** override triplo (preço/tempo/comissão) por profissional×serviço no produto final — fundamenta `staff_level_service_overrides` como extensão análoga por nível
- **DEC-15/DEC-18:** comissão de venda independente da de execução, escopo pacotes, fórmula de clawback — fundamenta `resolve_sale_commission`/`commission_sale_records`
- **DEC-24 (Migration Map §4, decisão 2):** `resolve_commission()` fica intocada; comissão de venda é função própria — decisão já fechada, não reaberta aqui
- **DEC-28:** escopo por unidade — `staff_levels`/`staff_level_service_overrides` org-wide; `commission_sale_records` transacional
- **DEC-29:** rehospedagem temática de Cash Sessions/Void e Comissão Escalonada para "Onda 3" — resolvida nesta sessão como fora do escopo do Migration Map §3, ficam para onda própria
- **DEC-33:** reforma de processo (fatiamento, TDD, evidência) sob a qual este Blueprint foi desenhado
- **DEC-36:** achado crítico pós-merge da Onda 1 (tocar `checkout_close`) — precedente direto para a decisão de não ativar nada nesta Onda
- **DEC-44:** Feature Flag, Pre-flight Check, TDD pgTAP/Jest, rastreabilidade — primeira Onda sob este protocolo
- **ADR 0005:** comissão não reverte automaticamente em estornos — mesmo racional aplicado ao `status = 'clawed_back'` manual desta Onda
- **ADR 0007:** `order_void` não reverte comissão automaticamente — precedente direto para não automatizar clawback aqui
- **ADR 0011:** padrão de snapshot na confirmação — por que `staff_levels` não precisa de tabela de vigência própria
- **ADR 0019:** "fundação sem ativação" da Onda 2 — padrão replicado integralmente nesta Onda
