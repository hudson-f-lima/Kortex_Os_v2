# KORTEXOS™ — Migration Map 5.1.2

**Versão:** v1.2
**Data:** 2026-07-20 (v1.0 aprovada DEC-24; v1.1 adiciona Onda 0, DEC-27; v1.2 finaliza escopo de unidade, DEC-28)
**Produzido por:** Claude Code, executando a Etapa 6 da ordem de construção (Master Briefing §22.1), seguindo `$kortex-migration-mapper` (`.agents/skills/kortex-migration-mapper/`).
**Entrada:** `KORTEXOS_5_1_2_TRUTH_MAP.md` v1.0 (DEC-23) + `KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md` v1.0 (DEC-26, item 1 reconsiderado por DEC-27).
**Autoridade deste artefato (§0.1 do Master):** mapeia nomes, tabelas, domínios, prefixos e impacto de promoção. **Não executa.** Não escreve SQL, não define coluna/tipo/constraint, não é Blueprint (etapa 7, segue BLOQUEADA até este documento ser aprovado).
**Status:** **APROVADO pelo Platform Owner (v1.0 DEC-24; v1.1 DEC-27; v1.2 DEC-28, todas 2026-07-20).** Etapa 6 CONCLUÍDA — ver `KORTEXOS_5_1_2_DECISION_LOG.md` e `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` §22.1. Etapa 7 (Blueprint) desbloqueada, ainda não iniciada.
**Changelog v1.1 → v1.2 (DEC-28):** as 4 questões deixadas em aberto na Onda 0 foram decididas — vínculo profissional↔unidade é N:N (`professional_units`); `memberships` ganha escopo híbrido (`unit_id` nullable); todas as Ondas 1-3/5-6 e as 19 tabelas MVP existentes ganham classificação de escopo por unidade (org-wide / catálogo com override / transacional direto) — ver tabela de classificação após a Onda 0.

## 0. Regra de leitura e limites

```text
Este documento nomeia OBJETOS (tabelas/domínios), não colunas nem SQL.
"Novo" = objeto que não existe hoje em nenhuma migration.
"Estende" = objeto MVP existente ganha capability nova, sem trocar de identidade.
"Depende de" = ordem de existência, não ordem de execução de migration física (essa é a Etapa 8).
Nenhuma linha aqui autoriza CREATE TABLE. Aprovação deste mapa desbloqueia o Blueprint (etapa 7),
que aí sim define coluna, tipo, constraint, índice e migration real.
```

## 1. Achado de cobertura descoberto durante o mapeamento

O Truth Map v1.0 auditou os módulos 01–06 (DEC-20). Ao mapear dependências para o Availability Resolver (D07), este Migration Map verificou o schema real (`supabase/migrations/`) e confirmou que a **Calendar Policy & Availability Layer (D02, Parte III §2 do Master)** — horário padrão, turnos, feriados, aberturas/fechamentos excepcionais — **não tem nenhuma tabela correspondente hoje** (busca por `shift`/`turno`/`horario`/`feriado`/`holiday`/`business_hours`/`calendar_polic` em todas as migrations: zero resultado). Isso não estava no escopo original do Truth Map (D02 não é um dos módulos 01–06), mas é pré-requisito direto de D07, que está em escopo.

**Resolvido:** auditoria complementar produzida em `KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md` (v1.0, 2026-07-20) — `CRÍTICO`/`AUSENTE` confirmado em toda a extensão do domínio, com evidência de código linha a linha. Aguardando aprovação do Platform Owner e DEC-25.

## 2. Schema MVP existente (referência — checado em `supabase/migrations/`, 12 arquivos)

`organizations` · `profiles` · `memberships` · `clients` · `professionals` · `services` · `products` · `appointments` · `orders` · `order_items` · `payments` · `inventory_movements` · `cash_entries` · `service_groups` · `packages` · `package_items` · `professional_service_commissions` · `professional_service_capabilities` · `professional_service_group_eligibility` · `sync_events` · `private.idempotency_keys`.

Nenhum objeto novo proposto abaixo pode reaproveitar esses nomes para finalidade diferente da atual — colisão de nome com tabela MVP existente é sempre risco `ALTO`, marcado explicitamente.

## 3. Objetos propostos, por onda de dependência

As ondas seguem a Ordem única de correção do Truth Map (§8): fundação de pagamento antes de ledger, ledger antes de wallet/payout, availability antes de recorrência/grupo/waitlist.

### Onda 0 — Identity & Tenant: Unidade (D01, adicionada por DEC-27, finalizada por DEC-28)

> **Natureza diferente das Ondas 1-6.** As demais ondas são capability NOVA para o produto final. Esta é retrofit da fundação de tenant (D01), que o Truth Map já classifica `REAL` (JWT/membership/RLS). Risco geral da onda: **Alto**, não pelo volume de objetos, mas porque toca RLS e o FK chain de toda tabela que hoje só tem `organization_id`.

| Domínio | Objeto proposto | Estende/novo | Depende de | Impacto em tabela MVP existente | Risco |
|---|---|---|---|---|---|
| D01 | `units` | Novo (extensão da fundação D01, já `REAL`) | `organizations` (existente) | Nenhuma alteração direta a `organizations` — mas dispara a classificação de escopo por unidade das 19 tabelas MVP existentes, ver tabela abaixo | **Alto** — retrofit da fundação de tenant; todo RLS e todo FK chain em produção ficam sob revisão conceitual |
| D01 | `professional_units` — **decidido: N:N (DEC-28)** | Novo — tabela de vínculo | `professionals` (existente), `units` | Nenhuma coluna nova em `professionals`; profissional pode atuar em mais de 1 unidade, cada vínculo é uma linha própria | Médio — cardinalidade N:N escolhida deliberadamente (mais flexível que N:1), consistente com o padrão Fresha/Zenoti "atribuir a 1+ locations" encontrado no benchmark |
| D01 | `memberships` — **escopo híbrido decidido (DEC-28)** | Estende `memberships` (nova coluna `unit_id`, nullable) | `memberships` (existente), `units` | Papéis estruturais (dono, gerente) continuam org-wide (`unit_id` nulo = acesso a todas as unidades); papéis operacionais (profissional, recepção) passam a ser por unidade (`unit_id` preenchido) | Médio — nulidade da coluna é o mecanismo de distinção, decisão de Blueprint confirmar se é suficiente ou se precisa de tabela própria de escopo |

### Classificação de escopo por unidade — 19 tabelas MVP existentes + objetos novos (decidido, DEC-28)

Padrão adotado: **Zenoti** (herança empresa→unidade com override autorizado por campo — já é a semântica que o Master §1.5/1.6 define) para catálogo/config; escopo **direto** ("onde aconteceu", não herança) para dados transacionais; **org-wide** para identidade compartilhada entre unidades.

| Classificação | Objetos | Regra |
|---|---|---|
| **Org-wide** (identidade/saldo da pessoa, sem `unit_id`) | `clients`, `professionals` (identidade), `client_wallets`, `staff_current_accounts`, `benefit_obligations`, `card_on_file_tokens`, `pix_automatico_mandates`, `staff_levels`/`staff_level_service_overrides`, `sync_events`, `private.idempotency_keys` | Cliente e profissional têm identidade única na organização, usável em qualquer unidade (padrão "Datashare" do benchmark). Carteira/conta corrente/benefício são saldo da PESSOA, não da unidade — senão um crédito ganho na Unidade A ficaria preso lá |
| **Catálogo/config — herança com override** (padrão Zenoti) | `services`, `products`, `service_groups`, `packages`, `package_items`, `professional_service_commissions`, `professional_service_capabilities`, `professional_service_group_eligibility` | Empresa define o padrão; unidade pode sobrepor campo a campo (preço, disponibilidade) — mesmo mecanismo que o Master §1.6 já exige ("Herdar ≠ copiar... override congela... autorizado por campo") |
| **Transacional — `unit_id` direto** (fato do registro, não herança) | `appointments`, `orders`, `order_items`, `payments`, `inventory_movements`, `cash_entries`, e os novos `payment_intents`, `psp_webhook_events`, `deposit_holds`, `kortex_ledger_transactions`, `kortex_ledger_entries`, `kortex_account_balances`, `payout_batches`, `resolve_sale_commission()`/`commission_sale_records`, `calendar_policies`, `professional_shifts`, `resources`, `resource_locks`, `appointment_series`, `appointment_participants`, `waitlist_entries`, `order_revisions` | Uma transação/evento aconteceu numa unidade específica — não é configuração herdável, é fato imutável do registro |

**Risco a registrar para o Blueprint:** `client_wallets`/`staff_current_accounts`/`benefit_obligations` ficam org-wide, mas `kortex_ledger_entries` (que os alimenta) fica unit-scoped — o saldo agregado da pessoa precisa somar entradas de múltiplas unidades. A reconstrução exigida pelo Gate 13 (Wallet Drift) precisa considerar isso desde o desenho do Blueprint, não como ajuste posterior.

### Onda 1 — Payment Core (D13)

> **Escopo por unidade (DEC-28):** `payment_intents`, `psp_webhook_events`, `deposit_holds` são transacionais, ganham `unit_id` direto (ver classificação acima). `card_on_file_tokens` e `pix_automatico_mandates` seguem `clients` — org-wide, não por unidade.
>
> **Ordem Onda 1 × Onda 2, decidida (ver §4, decisão 4):** o *schema* desta onda pode ser criado em paralelo ao da Onda 2 (KortexFlow) — nenhum objeto abaixo tem FK obrigatória para `kortex_ledger_entries`. Mas nenhum fluxo de captura de pagamento real via `payment_intents` pode **ativar em produção** antes da Onda 2 existir e o Gate 11 (Ledger Balance) passar — captura sem ledger é dinheiro sem lugar auditável para pousar.

| Domínio | Objeto proposto | Estende/novo | Depende de | Impacto em tabela MVP existente | Risco |
|---|---|---|---|---|---|
| D13 | `payment_intents` | Novo | `orders` (existente) | **Coexistência permanente, decidida (ver §4, decisão 1).** `payments` continua sendo o registro canônico de dinheiro recebido, por qualquer método. `payment_intents` é satélite, exclusivo do fluxo mediado por PSP (cartão, Pix Automático, COF); ao capturar, gera uma linha em `payments` — nunca a substitui | Médio — decisão de convivência tomada; risco remanescente é só de implementação (não duplicar o mesmo recebimento em duas linhas) |
| D13 | `psp_webhook_events` | Novo | `payment_intents` | Nenhum | Baixo — puramente aditivo, mas exige infraestrutura de outbox/retry (D30) que hoje não existe no backend |
| D13 | `card_on_file_tokens` | Novo | `clients` (existente), `payment_intents` | Nenhum | **Alto** — dado sensível de instrumento de pagamento; exige consentimento LGPD (D26) registrado antes de qualquer linha, e política de acesso mais restrita que o padrão RLS atual |
| D13 | `deposit_holds` | Novo | `appointments` (existente), `payment_intents` | Nenhum | Médio — é a materialização de DEC-22 (06.3); depende de scheduler/outbox para retentativa, infraestrutura de job assíncrono inexistente hoje no backend Express |
| D13 | `pix_automatico_mandates` | Novo | `clients` (existente), `payment_intents` | Nenhum | **Alto** — depende de integração real com PSP/Banco Central, fora do controle do KortexOS; mapeia para Subscription Engine (D18), que ainda nem tem Migration Map próprio |

### Onda 2 — KortexFlow Ledger + Wallet & Current Accounts (D15/D16)

> **Escopo por unidade (DEC-28):** `kortex_accounts`/`kortex_ledger_transactions`/`kortex_ledger_entries`/`kortex_account_balances`/`payout_batches` são transacionais, ganham `unit_id` — consistente com D28 ("ledgers separados" por unidade). `client_wallets`/`staff_current_accounts`/`benefit_obligations` ficam org-wide (saldo da pessoa, não da unidade) — ver risco de reconstrução (Gate 13) registrado na classificação da Onda 0.

| Domínio | Objeto proposto | Estende/novo | Depende de | Impacto em tabela MVP existente | Risco |
|---|---|---|---|---|---|
| D15 | `kortex_accounts` | Novo (prefixo canônico, Master §7.4) | Nenhum | Nenhum | Baixo isoladamente, mas é a raiz de todo o resto desta onda |
| D15 | `kortex_ledger_transactions` | Novo | `kortex_accounts` | Nenhum | Médio — cabeçalho de transação, precisa nascer com `idempotency_key` desde o primeiro desenho (invariante §7.2) |
| D15 | `kortex_ledger_entries` | Novo | `kortex_ledger_transactions` | Nenhum | **Crítico** — append-only, RLS deve bloquear UPDATE/DELETE por contrato, não só por convenção de aplicação |
| D15 | `kortex_account_balances` | Novo (projeção) | `kortex_ledger_entries` | Nenhum | Médio — decisão de Blueprint: tabela recalculável vs. view materializada; Migration Map não decide, só nomeia |
| D16 | `client_wallets` | Novo | `clients` (existente), `kortex_ledger_entries` | Nenhum | **Crítico** — Gate 13 (Wallet Drift) exige reconstrução total a partir do ledger; qualquer campo de saldo direto na tabela é proibido por §9.3 do Master |
| D16 | `staff_current_accounts` | Novo | `professionals` (existente), `kortex_ledger_entries` | Nenhum | **Crítico** — mesma regra de reconstrução; Gate 02 (Staff Privacy) exige isolamento entre profissionais |
| D16 | `benefit_obligations` | Novo | `kortex_accounts`, `client_wallets` | Nenhum | Alto — representa saldo de pacote/plano/corporativo/parceiro a consumir; nasce vazio até D18 existir, mas a fundação (D15/D16) não deve esperar D18 para ser construída |
| D16 | `payout_batches` | Novo | `staff_current_accounts` | Nenhum | Médio — lote de repasse; depende de definição de calendário de payout (semanal, Master §8.3), que é regra de negócio já decidida, não pendente |

### Onda 3 — Compensation & Payout, extensão (D17)

> **Escopo por unidade (DEC-28):** `resolve_sale_commission()`/`commission_sale_records` são transacionais (inherdam `unit_id` da venda). `staff_levels`/`staff_level_service_overrides` ficam org-wide — nível de carreira não varia por local físico.

| Domínio | Objeto proposto | Estende/novo | Depende de | Impacto em tabela MVP existente | Risco |
|---|---|---|---|---|---|
| D17 | `private.resolve_commission()` (execução) | **Intocado, decidido (ver §4, decisão 2)** | — | Nenhum | Baixo — permanece exatamente como está, chamado 2× dentro de `checkout_close()` (`supabase/migrations/20260713060000_professional_commissions_checkout.sql:218,324`); zero risco de regressão nos testes pgTAP existentes |
| D17 | `private.resolve_sale_commission()` (venda, DEC-15) + `commission_sale_records` | Novo — função própria e tabela própria | `kortex_ledger_entries` (nasce no pagamento da venda, não no consumo) | Nenhum | Médio — caminho novo e independente, nunca reduz nem é reduzido pela comissão de execução (mandato explícito de DEC-15) |
| D05/D17 | `staff_levels` + `staff_level_service_overrides` (DEC-04) | Novo | `professionals` (existente), `services` (existente) | Nenhum | Médio — aditivo puro; cascata de resolução (Master §6.2 Parte III) precisa ser implementada em `resolve_commission()`-equivalente para preço/tempo, hoje inexistente |

### Onda 4 — Calendar Policy (D02) + Availability & Resource Orchestration (D07/D11)

> **Decisão de escopo revisada (DEC-27, supera a confirmação original de DEC-26):** `calendar_policies`/`professional_shifts` passam a depender de **`units`** (Onda 0), não mais de `organizations` diretamente — timezone e horário são propriedade da unidade (Master §2.4), agora modelado no nível certo desde o início, seguindo o padrão Zenoti/Mindbody em vez do Vagaro/Trinks originalmente confirmado. `professional_shifts` também depende do vínculo profissional↔unidade da Onda 0. Continua confirmado: suporta múltiplos blocos por profissional/dia (horário partido/pausa) desde o desenho inicial.

| Domínio | Objeto proposto | Estende/novo | Depende de | Impacto em tabela MVP existente | Risco |
|---|---|---|---|---|---|
| D02 | `calendar_policies` (horário padrão, feriados, exceções) | Novo | `units` (Onda 0) — **revisado de `organizations`, DEC-27** | Nenhum | Médio — achado suplementar (§1 acima), fora do escopo original do Truth Map |
| D02 | `professional_shifts` | Novo | `professionals` (existente), `calendar_policies`, vínculo profissional↔unidade (Onda 0) | Nenhum | Médio — mesma ressalva de escopo; múltiplos blocos/dia confirmado (DEC-26 item 3) |
| D11 | `resources` | Novo | `organizations` (existente) | Nenhum | Baixo isoladamente |
| D11 | `resource_locks` | Novo | `resources`, `appointments` (existente) | Nenhum | **Crítico** — precisa da mesma disciplina de concorrência otimista que `appointments` já tem (ADR 0012); um lock mais fraco que o appointment que ele protege é uma regressão de integridade |
| D07 | Availability Resolver (motor, sem tabela própria na v1 — ver §4, decisão 3) | Novo (lógica, não schema) | `calendar_policies`, `appointments`, `resource_locks`, `deposit_holds` (D13) | Nenhum | **Crítico** — é o domínio mais citado como `AUSENTE` no Truth Map; qualquer atalho aqui (ex.: calcular disponibilidade sem consultar locks reais) reintroduz a "dupla fonte de verdade para agenda" proibida em §20.6 do Master |
| D07 | `availability_slot_cache` | **Adiado (decisão 3) — não faz parte do escopo deste Migration Map** | — | Nenhum | N/A — reavaliar só depois que o Gate 03 (Smart Availability) passar com cálculo on-demand e dado real de carga mostrar necessidade |

### Onda 5 — Recurring, Group Booking, Waitlist (D09/D10/D07-D08)

> **Escopo por unidade (DEC-28):** os 3 objetos são transacionais, ganham `unit_id` direto — uma série recorrente, um grupo ou uma entrada de waitlist são sempre para uma unidade específica (o cliente escolhe onde quer o slot).

| Domínio | Objeto proposto | Estende/novo | Depende de | Impacto em tabela MVP existente | Risco |
|---|---|---|---|---|---|
| D09 | `appointment_series` | Novo | `appointments` (existente) | **Estende** `appointments` com referência nullable à série (ex.: coluna de vínculo) | **Alto** — DEC-22 (01.13/01.14) marca REFORÇAR CRÍTICO; qualquer alteração em `appointments` precisa preservar idempotência/`version`/elegibilidade fail-closed já implementados (ADR 0010-0012) sem regressão |
| D10 | `appointment_participants` | Novo | `appointments` (existente), `clients` (existente) | Nenhum (aditivo) | Médio — separa pagador de beneficiários (Gate 07); só faz sentido depois que M01 recorrente estiver estável, para não empilhar duas mudanças estruturais em `appointments` ao mesmo tempo |
| D07/D08 | `waitlist_entries` | Novo | `clients`, `services` (existentes), Availability Resolver (Onda 4) | Nenhum | **Crítico** — máquina de estado ACTIVE→MATCHED→OFFERED→HOLDING→BOOKED (Gate 09) depende de disponibilidade real (Onda 4) e de hold (padrão de `deposit_holds`, Onda 1) para não prometer vaga que não existe |

### Onda 6 — Checkout final: reabertura de comanda (D12/D14/D15, DEC-03/11)

> **Escopo por unidade (DEC-28):** `order_revisions` herda `unit_id` de `orders` — transacional, mesma unidade da venda original.

| Domínio | Objeto proposto | Estende/novo | Depende de | Impacto em tabela MVP existente | Risco |
|---|---|---|---|---|---|
| D12/D15 | Versionamento de venda (`order_revisions` ou equivalente) | Novo, mas **altera fluxo** de `checkout_close`/`order_refund` | `orders` (existente), `kortex_ledger_entries` (Onda 2) | **Altera** contrato de fechamento existente — precisa nascer só depois que o ledger existir, porque reabertura sem ledger reversível cria dupla verdade financeira | **Crítico** — é o "Risco nº 1" já identificado no Decision Log (Seção 6); não implementar antes da Onda 2 estar completa e testada |

## 4. Decisões sobre os riscos de alto impacto (Platform Owner, 2026-07-20)

As quatro questões abaixo foram decididas nesta revisão, antes do início do Blueprint. Nenhuma decisão aqui vira SQL — continuam sendo mapeamento (nome, domínio, dependência), não desenho de coluna/tipo/constraint.

### Decisão 1 — `payments` vs. `payment_intents`: coexistência permanente
`payments` (MVP) continua sendo o registro canônico de dinheiro efetivamente recebido, por qualquer método — não é substituído. `payment_intents` (novo) é satélite, existe só para o subconjunto de fluxos mediados por PSP (cartão via gateway, Pix Automático, cobrança por card-on-file). Quando um `payment_intent` é capturado com sucesso, ele **gera** uma linha em `payments` — nunca a troca. Justificativa: preserva o contrato de `checkout_close` inalterado para os métodos locais (`cash`, `pix` manual) que já funcionam hoje; isola o risco novo (integração de PSP) num objeto novo, sem reescrever o caminho que já está `REAL`.

### Decisão 2 — `resolve_commission()` fica intocada; comissão de venda é função nova
Verificado o código real (`supabase/migrations/20260713060000_professional_commissions_checkout.sql:68-79`): `private.resolve_commission()` é `security definer`, chamada 2× dentro da mesma transação atômica de `checkout_close()` (linhas 218 e 324, uma para item direto e uma para item de pacote explodido), coberta por `rls_professional_service_commissions_test.sql` e `rpc_checkout_close_test.sql`. Alterar essa função in-place arrisca regressão silenciosa em produção se algum caminho não estiver coberto pelos testes atuais. **Decisão:** `resolve_commission()` (comissão de execução) permanece exatamente como está. A comissão de venda (DEC-15) ganha função própria, `private.resolve_sale_commission()`, e tabela própria, `commission_sale_records` — caminho novo, independente, chamado num momento diferente do checkout (no pagamento da venda do pacote/plano, não no consumo da sessão). Isso também é o que DEC-15 já exige textualmente: "as duas coexistem sem se reduzirem mutuamente."

### Decisão 3 — Sem cache de disponibilidade na v1; Availability Resolver calcula on-demand
`availability_slot_cache` sai do escopo deste Migration Map. Construir uma tabela de projeção antes de o motor de resolução (D07) sequer existir e ser validado é otimização prematura — o mesmo padrão de risco que o Master já nomeia em §25.3 ("automatizar... antes de provar dados"). **Decisão:** a primeira versão do Availability Resolver calcula sob demanda, sem tabela própria. Cache só volta à mesa depois que o Gate 03 (Smart Availability) passar com dado real de carga mostrando necessidade — decisão de performance, revisitável, não uma dívida técnica assumida às cegas.

### Decisão 4 — Onda 1 (Payment Core) e Onda 2 (KortexFlow): schema em paralelo, ativação gateada
As duas ondas podem ter o *schema* criado em paralelo no Blueprint — nenhum objeto da Onda 1 tem dependência estrutural obrigatória da Onda 2 para existir. Mas nenhum fluxo de captura real de pagamento via `payment_intents` pode **ativar em produção** antes de a Onda 2 (ledger) existir e o Gate 11 (Ledger Balance) passar — capturar dinheiro sem ledger para lançá-lo recria o "saldo paralelo" proibido em §20.6 do Master. Isso preserva a prioridade de negócio da Truth Map (§8: borda de pagamento antes de KortexFlow) sem violar a dependência técnica real.

## 5. O que este Migration Map NÃO autoriza

```text
Não autoriza CREATE TABLE, ALTER TABLE ou qualquer DDL.
Não autoriza a Etapa 7 (Blueprint) a começar sem aprovação explícita deste documento.
Não decide coluna, tipo, índice, policy de RLS ou nome final — isso é do Blueprint.
Não resolve os "Riscos de alto impacto" da seção 4 — ficam para decisão do Platform Owner
  no início do Blueprint, não implícitos por omissão aqui.
Não estende o escopo do Truth Map v1.0 além do que ele already cobre — o achado de D02
  (seção 1) é reportado, não resolvido; um adendo ou v1.1 do Truth Map deveria avaliar
  D02 com o mesmo rigor de evidência usado para os módulos 01–06 antes do Blueprint tratar
  Availability como pronta para desenho técnico.
```

## 6. Próximo passo executável ideal

1. ~~Decidir os 4 riscos de alto impacto da seção 4~~ — **feito**: decisões 1–4 registradas em 2026-07-20 (seção 4 acima).
2. ~~Platform Owner revisa e aprova este Migration Map v1.0~~ — **feito**: aprovado em 2026-07-20 (DEC-24).
3. ~~Auditoria suplementar de D02 (Calendar Policy)~~ — **feito**: `KORTEXOS_5_1_2_TRUTH_MAP_ADENDO_D02.md` aprovado (DEC-25).
4. ~~Pontos cegos de profundidade (Unidade, Calendar, Action Request, Reliability Score, D00)~~ — **feito**: `KORTEXOS_5_1_2_PONTOS_CEGOS_PRE_BLUEPRINT.md` aprovado (DEC-26).
5. ~~Reconsiderar hierarquia Empresa→Unidade: `units` como entidade própria~~ — **feito**: Onda 0 adicionada, Onda 4 revisada (DEC-27, v1.1).
6. ~~Decidir cardinalidade profissional↔unidade, escopo de `memberships`, e escopo por unidade das demais ondas/19 tabelas MVP~~ — **feito**: N:N, híbrido, e classificação completa por objeto (DEC-28, v1.2 deste documento).
7. **Próximo:** iniciar a **Etapa 7 — Blueprint Unificado 5.1.2**, que aí sim define arquitetura técnica, coluna, tipo, constraint e ordem real de migration, usando a classificação de escopo por unidade já decidida como insumo direto.
8. SQL Master (etapa 8) continua bloqueado até o Blueprint ser aprovado.

---

FILES_CHANGED:
- `docs/KORTEXOS_5_1_2_MIGRATION_MAP.md`: v1.1 → v1.2. `professional_units` (N:N) e `memberships.unit_id` (híbrido) finalizados na Onda 0; nova tabela de classificação de escopo por unidade cobrindo as 19 tabelas MVP existentes e todos os objetos novos das Ondas 1-3/5-6.
- Nenhum arquivo de código, schema, migration ou teste foi alterado.

BLOCKERS_REMAINING:
- Risco registrado para o Blueprint: `client_wallets`/`staff_current_accounts`/`benefit_obligations` org-wide alimentados por `kortex_ledger_entries` unit-scoped — a reconstrução do Gate 13 precisa somar múltiplas unidades desde o desenho.
- Todos os blockers já registrados no Truth Map v1.0 (DEC-23) continuam abertos e não são resolvidos por este documento.

VEREDITO:
- Etapa 6 CONCLUÍDA (DEC-24 → DEC-27 → DEC-28, v1.2). Etapa 7 (Blueprint) DESBLOQUEADA, ainda não iniciada — todas as decisões de escopo de unidade resolvidas antes de qualquer linha de schema.
