# KortexOS 5.1.2 — Blueprint Onda 1: Payment Core

**Status:** **Aprovado pelo Platform Owner em 2026-07-25 (DEC-34).** `$kortex-qa-redteam`: 1ª rodada NO-GO (5 achados: 2 críticos/altos de dinheiro e concorrência, 2 médios de autorização/overflow), 2ª rodada GO com 1 achado baixo residual, fechado nesta versão (§3.3, transição para `expired`). Decisões de desenho fechadas via `$grill-me` em 2026-07-25 (9 rodadas). Ver [ADR 0017](adr/0017-onda1-payment-core-arquitetura.md) para o detalhamento arquitetural. Próximo passo: Fatiamento (`$prd-to-issues`) — Etapa 8 (SQL) continua exigindo autorização própria, ainda não concedida.
**Etapa:** 7 (Blueprint), iniciada após Migration Map v1.2 aprovado (DEC-24), item Onda 1 (D13 — Payment Core).
**Escopo:** subconjunto de D13 — `payment_intents`, `psp_webhook_events`, `deposit_holds`, extensão de `services`. Exclui explicitamente `card_on_file_tokens` e `pix_automatico_mandates` (ver §1).

## 1. Autoridade e limites

Este Blueprint materializa `docs/KORTEXOS_5_1_2_MIGRATION_MAP.md` (Onda 1, D13) e `docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` (D13 Payment Core, DEC-22 06.1–06.6). Nenhuma decisão de produto já fechada é reaberta aqui — só as lacunas que o Migration Map deixou em aberto para o Blueprint fechar.

**Exclusão deliberada de escopo:** `card_on_file_tokens` (exige consentimento LGPD/D26 registrado antes de qualquer linha; D26 não tem Migration Map nem código) e `pix_automatico_mandates` (depende de integração com Banco Central e do Subscription Engine/D18, sem Migration Map próprio) ficam **fora desta onda**, tratados como "adiado, reavaliar depois" — mesmo padrão que a Onda 4 já aplicou a `availability_slot_cache`. Não são abandonados: quando D26 e D18 existirem, entram como extensão aditiva deste Blueprint, não como redesenho.

**Modelo de PSP:** KortexOS integra com **um único PSP como plataforma/marketplace** (padrão "Separate Charges and Transfers", já citado como referência no Global Benchmark Map), onde cada organização-cliente é uma subconta/connected account. Não há suporte a múltiplos PSPs simultâneos nesta onda — schema fica agnóstico via coluna `provider`, mas sem camada de abstração/adapter. **Qual PSP real (Mercado Pago, Pagar.me ou outro) é decisão de implementação (Etapa 9), não deste Blueprint** — nenhum contrato aqui depende do formato exato de webhook de um fornecedor específico.

`organization_id` continua sendo a fronteira primária de tenant; `unit_id` é fronteira operacional subordinada (Onda 0), aplicada a todos os objetos transacionais desta onda. Este Blueprint não cria UI de configuração de depósito/PSP, não integra de fato com nenhum PSP (isso é Etapa 9), e não altera `checkout_close` além da reconciliação de depósito descrita em §3.

## 2. Escopo de dados

| Objeto | Contrato técnico | Estado |
|---|---|---|
| `payment_intents` | Satélite do fluxo mediado por PSP. Coexiste permanentemente com `payments` — nunca o substitui; ao capturar, gera uma linha em `payments` (checkout) ou em pedido sintético (no-show, §3). `order_id` **nullable**: um intent de depósito pré-reserva nasce sem pedido (não existe checkout ainda); um intent de checkout nasce com pedido. `purpose` distingue as duas origens (`checkout` / `deposit`). | Novo |
| `psp_webhook_events` | Outbox mínimo, específico deste domínio (não generalizado para outros casos de uso futuros) — resolve DEC-22 (06.3), que já definiu a solução como "hold local + retentativa". Armazena o payload bruto do provedor para reprocessamento; nunca descarta um evento não correspondido (dead-letter com `payment_intent_id` nulo em vez de perda silenciosa). | Novo |
| `deposit_holds` | Materialização de DEC-22 (06.3) e (06.4). Distingue formalmente as duas mecânicas que DEC-22 (06.4) exige: `hold` (só guarda cartão, sem cobrança) e `immediate_charge` (cobra na hora) — configurável por serviço (§2.1). Snapshot dos valores de política no momento da criação (mesmo padrão de congelamento da ADR 0011), não referência viva à configuração do serviço. | Novo |
| `services` (extensão) | Ganha política de depósito e de comissão de no-show, ambas opcionais (nulas = sem política, comportamento idêntico ao atual). Reaproveita o mesmo par `tipo/valor` (`percentage`/`fixed` + basis points ou centavos) já usado em `service_groups.default_commission_type`/`professional_service_commissions` — nenhuma forma nova de representar taxa/percentual. | Extensão |

### 2.1 Campos novos em `services`

| Campo | Nullable | Função |
|---|---|---|
| `deposit_mechanic` | Sim | `hold` \| `immediate_charge` (DEC-22 06.4). Nulo = serviço sem política de depósito |
| `deposit_type` | Sim | `percentage` \| `fixed`, mesmo enum de comissão |
| `deposit_value` | Sim | basis points (se `percentage`) ou centavos (se `fixed`) |
| `no_show_commission_type` | Sim | `percentage` \| `fixed`. Independente do `commission_type` normal do serviço — a operação real (colaborador desconfia se não vê) exige que seja configurável separadamente, não herdado da comissão de venda |
| `no_show_commission_value` | Sim | idem, unidade conforme o tipo |

## 3. Integridade e invariantes

### 3.1 Depósito pré-reserva não é checkout

Um `payment_intent` de depósito (`purpose = 'deposit'`) nasce vinculado a um `appointment` via `deposit_holds`, nunca a um `order`. `checkout_close` (RPC existente, intocada em sua lógica financeira central) ganha uma responsabilidade nova e isolada: ao fechar o pedido de um agendamento que tem um `deposit_hold` ativo, reconcilia — abate o valor retido do total cobrado (mecânica `hold`) ou registra o valor já cobrado como adiantamento (mecânica `immediate_charge`) — e marca o hold como `captured_checkout`. Essa reconciliação é a única mudança em `checkout_close`; nenhuma outra lógica da função é tocada.

**Overflow (depósito maior que o total final, achado #5 do Red Team):** o valor aplicado do depósito é limitado a `min(deposit_amount, order_total)` — nunca deixa o pedido negativo. Se sobrar valor (ex.: cliente reduziu o serviço no checkout), o excedente segue o **estorno já existente** (ADR 0006/0007, void/refund) sobre o `payment` gerado pela captura original do depósito — não é um sistema de crédito novo (isso é escopo de `client_wallets`, Onda 2, que não existe ainda). `checkout_close` nunca inventa saldo: ou o valor cabe no pedido, ou o excedente vira estorno pelo caminho que já existe.

### 3.2 No-show não passa por `checkout_close`

Um no-show não tem serviço prestado, não tem `order` — e não deve ganhar um. A cobrança de no-show gera um **pedido mínimo e real**, através de uma RPC nova e pequena (não `checkout_close`): um `order`, um `order_item` (`service_id` = o serviço original do agendamento, comissão calculada a partir de `no_show_commission_type`/`no_show_commission_value` — nunca de `resolve_commission()` normal), e um `payment`. O `deposit_hold` correspondente vira `captured_no_show`.

**Por que este caminho, e não uma tabela de comissão paralela:** o colaborador verifica comissão hoje olhando `order_items.commission_cents` — não existe tela nem relatório separado. Uma cobrança de no-show que não aparecesse ali seria invisível para quem mais precisa vê-la, gerando desconfiança confirmada como risco real de operação (não hipotético). Reaproveitar o caminho existente custa uma RPC nova pequena; inventar visibilidade paralela custaria retrabalho e uma segunda fonte de verdade para o mesmo dado.

**Autorização (achado #4 do Red Team):** a RPC de liquidação de no-show exige o **mesmo papel/escopo de unidade que hoje já governa mudança de status de `appointment`** — owner/admin/manager (org-wide) ou reception/professional restritos à unidade do agendamento. Não é uma superfície nova de autorização; herda a regra existente em vez de inventar uma. Isso materializa a classificação `Política/Command` (não soberana) que o Master Briefing já atribui a "Cobrar depósito".

### 3.3 Exatamente um hold ativo por agendamento, capturado no máximo uma vez

Um `appointment` tem no máximo um `deposit_hold` com `status = 'active'` por vez (índice único parcial, mesmo padrão do `units_one_default_active_idx` da Onda 0). Cancelamento dentro da política libera o hold (`released`); a janela de expiração de autorização é definida pela rede do cartão (~4-5 dias, restrição técnica documentada no Global Benchmark Map) — quando aplicável, a mecânica `hold` fica sujeita a essa janela; `immediate_charge` não expira (o dinheiro já mudou de mãos).

**Trava de concorrência (achado #3 do Red Team):** a reconciliação de checkout (§3.1) e a liquidação de no-show (§3.2) são os dois únicos caminhos que capturam um `deposit_hold`, e são mutuamente exclusivos por construção — cada um só executa via `UPDATE deposit_holds SET status = '<destino>' WHERE id = ... AND status = 'active'` (compare-and-swap atômico, mesma disciplina de concorrência otimista já aplicada a `appointments` pela ADR 0012). Se zero linhas forem afetadas, o caminho aborta sem criar `order`/`payment` — o hold já foi capturado por outro caminho primeiro. Nenhum dos dois assume que o hold ainda está `active` sem essa checagem atômica.

**Transição para `expired` (achado #1 da 2ª rodada de Red Team):** dois gatilhos, nenhuma infraestrutura nova.
1. **Reativo:** se o provedor notificar expiração/cancelamento da autorização (evento comum na maioria dos PSPs), o mesmo outbox de webhook (§3.5) processa esse evento com o mesmo CAS já descrito acima.
2. **Fallback preguiçoso:** se checkout ou no-show tentar capturar um hold cuja autorização já morreu no lado do provedor, a chamada à API falha — essa falha, dentro da própria RPC que tentava capturar, marca o hold como `expired` em vez de propagar erro genérico. Não é um mecanismo separado; é tratamento de erro das duas RPCs que já existem.

Nenhum scheduler/job proativo é construído nesta onda — mesma decisão já tomada para o outbox (§3.5): sem evidência de caso de uso que justifique infraestrutura de polling. O pior cenário sem os dois gatilhos acima é uma linha `active` sem nenhum dos dois eventos acontecer (agendamento nunca chega a checkout, no-show ou cancelamento) — custo de higiene de dado, nunca de dinheiro, já que nada é capturado sem sucesso real na chamada ao provedor.

### 3.4 Grants e RLS seguem o padrão fail-closed da Onda 0

`payment_intents` e `deposit_holds`: SELECT para owner/admin/manager (org-wide) e reception/professional escopados à unidade — mesmo padrão de `private.can_access_fact_unit` já em produção. Nenhum INSERT/UPDATE direto de `authenticated`/`anon`; toda escrita passa por RPC `SECURITY DEFINER`. `psp_webhook_events`: sem nenhum grant a `anon`/`authenticated` — é dado de sistema, escrito exclusivamente pelo backend (`service_role`), mesmo padrão de `unit_access_audit_events`.

### 3.5 Idempotência contra replay de webhook (achados #1 e #2 do Red Team)

PSPs entregam webhook com garantia *at-least-once* — o mesmo evento pode chegar mais de uma vez, e isso não é hipotético, é comportamento documentado de qualquer provedor real. Duas travas, uma em cada tabela:

- `psp_webhook_events` grava o **ID do evento do próprio provedor** (`provider_event_id`), com unicidade em `(provider, provider_event_id)`. Reentrega do mesmo evento vira `INSERT` rejeitado por conflito, não reprocessamento — o outbox trata isso como sucesso idempotente, nunca como erro.
- `payment_intents` tem unicidade em `(organization_id, provider, provider_reference)` — impede duas linhas para a mesma transação externa, defesa em profundidade independente da unicidade do evento.

Nenhuma captura financeira (§3.1/§3.2) executa a partir de um `psp_webhook_events` que já tinha `processed_at` preenchido — reprocessar um evento já processado é no-op, não repetição de efeito.

## 4. Contrato físico de schema

### `payment_intents`
`id`, `organization_id`, `unit_id`, `order_id` (nullable, FK composta para `orders`), `purpose` (`checkout` \| `deposit`), `provider` (texto livre, agnóstico de fornecedor), `provider_reference` (id externo), `amount_cents`, `status` (ciclo de vida: `requires_capture` → `captured` \| `canceled` \| `failed`), `created_by` (nullable — fluxo de webhook não tem ator humano), timestamps. **Unicidade:** `(organization_id, provider, provider_reference)` (§3.5).

### `psp_webhook_events`
`id`, `organization_id` (nullable até correspondência), `unit_id` (nullable até correspondência), `payment_intent_id` (nullable — dead-letter quando não há correspondência, nunca descartado), `provider`, `provider_event_id` (ID do evento no provedor, não o `provider_reference` do intent), `event_type` (bruto do provedor), `payload` (jsonb, corpo completo para reprocessamento/auditoria), `processed_at` (nullable), `retry_count` (default 0), `last_error` (nullable), `received_at`. **Unicidade:** `(provider, provider_event_id)` (§3.5).

### `deposit_holds`
`id`, `organization_id`, `unit_id`, `appointment_id` (FK composta), `payment_intent_id` (FK composta), `mechanic` (`hold` \| `immediate_charge`), `amount_cents` (snapshot no momento da criação, nunca recalculado ao vivo), `no_show_commission_type`/`no_show_commission_value` (snapshot, nullable), `status` (`active` \| `captured_checkout` \| `captured_no_show` \| `released` \| `expired`), `expires_at` (nullable — só se aplica a `mechanic = 'hold'`), `created_by` (nullable), timestamps. Índice único parcial: um `active` por `appointment_id`.

### `services` (ALTER)
Ver §2.1 — cinco colunas nullable, todas aditivas, nenhuma alteração de constraint existente.

## 5. Compatibilidade e backfill

Toda mudança é aditiva. Nenhuma tabela existente (`payments`, `order_items`, `orders`) tem constraint alterada — a descoberta de que `payments.order_id` e `order_items.order_id` são `NOT NULL` (verificado diretamente no schema, não suposto) foi o que descartou o caminho inicial de "afrouxar constraint financeira" em favor do pedido sintético de no-show (§3.2). `services` existentes recebem `NULL` nas cinco colunas novas — nenhum comportamento muda até uma organização configurar depósito/no-show explicitamente para um serviço. Nenhum backfill de dado histórico é necessário: não existe hoje nenhum `payment_intent`/`deposit_hold` para migrar.

## 6. Plano de execução e rollback

Esta onda **passa pelo Fatiamento** (DEC-33) antes de qualquer SQL — nenhuma migration monolítica. Fatias verticais candidatas, cada uma testável isoladamente:

1. Extensão de `services` (§2.1) — schema + RLS + pgTAP, sem tocar RPC nenhuma
2. `payment_intents` + `psp_webhook_events` — schema + outbox mínimo, testável com evento sintético, sem PSP real ainda
3. `deposit_holds` + caminho de criação de hold no agendamento — depende de (1) e (2)
4. Reconciliação em `checkout_close` (§3.1) — depende de (3), maior risco (toca RPC financeira existente), fatia isolada e revisada com atenção redobrada
5. RPC de liquidação de no-show (§3.2) — depende de (1) e (3)

Cada fatia segue `$tdd` (teste antes do código) e passa por `$kortex-qa-redteam` antes de integrar. Rollback: fatias 1-3 e 5 são aditivas puras, reversíveis sem risco de dado. Fatia 4 (reconciliação em `checkout_close`) é a única que toca lógica financeira existente — reverter significa remover a chamada de reconciliação, deixando `checkout_close` exatamente como está hoje.

## 7. Matriz RLS e contratos afetados

| Objeto | SELECT | INSERT/UPDATE |
|---|---|---|
| `payment_intents` | owner/admin/manager (org-wide); reception/professional (unidade) | Nenhum grant direto — só via RPC `SECURITY DEFINER` |
| `psp_webhook_events` | Nenhum (nem owner/admin) — dado de sistema, sem tela nesta onda | Nenhum grant — só `service_role` (backend) |
| `deposit_holds` | owner/admin/manager (org-wide); reception/professional (unidade) | Nenhum grant direto — só via RPC, sempre CAS `WHERE status = 'active'` (§3.3) |
| `services` (colunas novas) | Herda RLS existente de `services` — nenhuma mudança de política | `owner`/`admin` (mesma regra atual de edição de catálogo) |

### 7.1 Autorização das RPCs novas (achado #4 do Red Team)

| RPC | Papel exigido | Escopo |
|---|---|---|
| `checkout_close` (reconciliação, §3.1) | Herda a autorização já existente da RPC — nenhuma mudança | — |
| Liquidação de no-show (§3.2) | owner/admin/manager, ou reception/professional | Org-wide (owner/admin/manager) ou restrito à unidade do `appointment` (reception/professional) — mesma regra que já governa mudança de status de `appointment` hoje |
| Criação de hold (agendamento) | Mesma regra de quem já pode criar/confirmar `appointment` | Unidade do agendamento |

**Confirmado por leitura direta do código:** `checkout_close` (`supabase/migrations/20260713060000_professional_commissions_checkout.sql:200-230`) resolve comissão via `private.resolve_commission()` e persiste em `order_items` — a reconciliação de depósito (§3.1) é uma adição a essa função, não uma reescrita; a liquidação de no-show (§3.2) deliberadamente não chama `checkout_close` nem `resolve_commission()`, evitando qualquer risco de regressão na função financeira mais crítica do sistema.

---

# Adendo corretivo — integridade do vínculo depósito↔agendamento↔comanda

**Data:** 2026-07-26

**Status:** aprovado pelo Platform Owner em DEC-38 para execução forward-only em local/`staging`; implementação, evidência e promoção permanecem pendentes.
**Relação com o texto anterior:** este adendo não reescreve o registro do Blueprint nem DEC-34–DEC-37. Ele substitui, para o trabalho corretivo futuro, o desenho permissivo de reconciliação descrito nas seções 3.1, 3.3, 3.5, 4 e 6 onde houver conflito. Ver ADR 0018.

## A. Contrato de identidade financeira

Um `deposit_hold` ativo deve congelar a identidade que autoriza sua captura:

| Dimensão | Fonte de verdade no momento da criação | Regra posterior |
|---|---|---|
| Tenant e unidade | `organization_id` e `unit_id` do agendamento bloqueado | Nunca alteráveis no hold; FKs tenant-safe em todo vínculo |
| Ocorrência | `appointment_id` | Um hold ativo por ocorrência; a comanda registra a ocorrência consumida |
| Cliente, serviço e profissional | snapshot do agendamento bloqueado | Nunca inferidos do estado atual; troca no agendamento é bloqueada enquanto o hold está ativo |
| Dinheiro e política | mecânica, valor, comissão de no-show e expiração aplicáveis | Mantidos como snapshot, sem recálculo por catálogo mutável |

O comando de criação do hold lê o agendamento com lock. Trigger ou proteção equivalente impede alteração direta dos snapshots. Preflight de migration deve abortar perante dados existentes ambíguos; é proibido inventar backfill por inferência.

## B. Checkout de agendamento separado de walk-in

O novo contrato externo é `POST /appointments/:id/checkout`. O backend, depois de validar JWT e membership, carrega sob lock o agendamento e o hold. Ele deriva cliente, unidade, profissional e relação financeira; nenhum destes limites é aceito como verdade de um payload.

O checkout walk-in continua como fluxo separado e não pode passar `appointment_id` para acionar reconciliação. A comanda de agendamento persiste `appointment_id` e `deposit_hold_id` com vínculos tenant-safe e unicidade que impedem duas comandas financeiras para a mesma ocorrência. A transação deve falhar fechada se qualquer dimensão do snapshot, do agendamento ou dos itens não corresponder.

Estados elegíveis: somente `in_service` e `completed`. A tentativa sobre `scheduled`, `cancelled`, ocorrência futura ou qualquer outro estado não cria pedido, pagamento nem transição de hold.

Ordem mínima de locks:

```text
idempotency_key → appointment FOR UPDATE → active deposit_hold FOR UPDATE/CAS → payment_intent
```

## C. Lifecycle do hold

Os estados terminais são exclusivos e só podem ser alcançados por comandos transacionais:

| Comando | Transição autorizada | Regra fail-closed |
|---|---|---|
| checkout de agendamento | `active → captured_checkout` | somente após validar o vínculo imutável e a elegibilidade |
| liquidação de no-show | `active → captured_no_show` | usa os snapshots, não campos atuais mutáveis |
| cancelamento/reagendamento elegível | `active → released` | `immediate_charge` que exija devolução é bloqueado sem estorno real |
| webhook de expiração ou captura inviável | `active → expired` | não cria efeito financeiro; tentativa posterior é rejeitada |

Todos usam CAS sobre `status = 'active'`. Corridas cancelamento×checkout, no-show×checkout e expiração×captura devem ter exatamente um vencedor e rollback integral para o perdedor.

## D. Webhook e dead-letter

O identificador do evento mantém deduplicação, mas não pode encerrar prematuramente uma tentativa de reprocessar dead-letter. Evento com `processed_at` nulo deve tentar resolver novamente um intent por identidade externa não ambígua na fronteira organização+provedor. Falha conserva o evento disponível, incrementa tentativas e registra erro; evento já processado é o único no-op. O reprocessamento manual explícito faz parte do contrato; nenhum scheduler é introduzido.

## E. Fatias e gates

O trabalho corretivo está fatiado em `issues/006` a `issues/011`. Cada fatia exige RED→GREEN, testes de comportamento e Red Team antes de integrar. O gate final exige reset limpo, testes de banco/backend/frontend, lint/build, testes concorrentes reais, reexecução dos exploits e homologação em `staging`.

Este adendo não autoriza PSP real, captura financeira real, Onda 2/ledger, `main` ou produção.
