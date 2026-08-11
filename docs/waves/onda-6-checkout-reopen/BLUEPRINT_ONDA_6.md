---
title: "Blueprint Onda 6 — Checkout final: reabertura de comanda"
status: "APROVADO"
stage: "BLUEPRINT"
governance_ref: ["DEC-03", "DEC-11", "DEC-24", "DEC-28", "DEC-44", "DEC-53", "DEC-62", "ADR-0025"]
upstream_doc: "docs/waves/KORTEXOS_5_1_2_MIGRATION_MAP.md"
last_updated: "2026-08-10"
---

# KortexOS 5.1.2 — Blueprint Onda 6: Checkout final e reabertura de comanda

**Status:** APROVADO por DEC-62 em 2026-08-11. O Red Team de desenho concluiu `GO` após quatro rodadas; os achados reproduzíveis e suas correções estão na seção 8. A Etapa 8 permanece bloqueada até o fatiamento ser aprovado e uma autorização explícita própria.

**Escopo:** materializar a reabertura governada de uma comanda já fechada, com edição plena do pedido original, preservação integral de versões e efeitos financeiros/operacionais reversíveis. O núcleo é `order_revisions`, a trava financeira e os Commands server-owned de reabrir, refechar e descartar reabertura.

**Não é escopo:** PSP, emissão fiscal, sessão/fechamento de caixa, payout, wallet/crédito, nova política de comissão, UI executável ou SQL/migration. Estes domínios serão apenas consumidores/produtores futuros da trava financeira; não são simulados nesta Onda.

## 1. Autoridade, benchmark e limites

O Migration Map aprovado (DEC-24/DEC-28) mapeia a Onda 6 como o versionamento de venda que altera `checkout_close`/`order_refund` somente depois da fundação do KortexFlow. DEC-03 define que o fechamento anterior permanece rastreável e que a reabertura reverte em cascata seus efeitos; DEC-11 exige edição plena de itens, valores, profissionais e pagamentos até a trava financeira. DEC-44 exige dark launch, pre-flight e fatias TDD; DEC-53 exige o Benchmark Gate.

`organization_id` continua sendo a fronteira primária de tenant. `unit_id` é obrigatório em cada novo fato transacional e em toda FK que atravessar fatos por unidade. O backend/RPC deriva o ator da membership autenticada; body, query ou identificador de pedido nunca escolhem tenant nem ampliam papel.

### 1.1 Benchmark Gate

| Classificação | Evidência | Consequência para o KortexOS |
|---|---|---|
| FATO — Booksy | A documentação pública do Booksy encontrada descreve pagamento e devolução executados pelo prestador, mas não expõe um fluxo público de reabertura de comanda. [Booksy: refund](https://help.booksy.com/hc/en-us/articles/21636477672082-Can-I-get-a-refund-if-I-cancel-an-appointment) | A ausência de precedente público de Booksy é registrada; não autoriza pular os comparativos seguintes. |
| FATO — AppBarber (Beauty Tech) | O AppBarber permite reabrir e alterar uma comanda, mas exige desfazer a baixa financeira, o fechamento de caixa ou o pagamento de comissão antes da reabertura. [Baixa financeira](https://appbarber-appbeleza.zendesk.com/hc/pt-br/articles/5153484318861-N%C3%A3o-%C3%A9-poss%C3%ADvel-reabrir-esta-Comanda-pois-ela-est%C3%A1-em-uma-movimenta%C3%A7%C3%A3o-baixada-do-Financeiro), [comissão](https://appbarber-appbeleza.zendesk.com/hc/pt-br/articles/10501472124941-N%C3%A3o-%C3%A9-poss%C3%ADvel-reabrir-essa-comanda-pois-ela-est%C3%A1-em-um-pagamento-de-comiss%C3%A3o) | Edição direta do original é compatível com integridade somente antes de financial lock. |
| FATO — Vagaro | O reembolso é uma transação com motivo, não reversível e rastreada separadamente. [Vagaro: refunds](https://support.vagaro.com/hc/en-us/articles/18699473497115-Refund-Your-Customers) | `order_refund` continua distinto e terminal; não vira um atalho para reabrir. |
| FATO — Shopify / Square / Stripe | Shopify calcula saldo a cobrar ou reembolsar após editar o pedido; Square e Stripe criam reembolsos ligados ao pagamento concluído, com limites e concorrência. [Shopify](https://help.shopify.com/en/manual/fulfillment/managing-orders/editing-orders), [Square](https://developer.squareup.com/docs/payments-api/refund-payments), [Stripe](https://docs.stripe.com/refunds?dashboard-or-api=api) | O refechamento liquida apenas o delta; um total menor devolve proporcionalmente pelas formas originais. |
| INFERÊNCIA | Nenhuma referência é modelo integral: o padrão seguro combina edição operacional direta com versões imutáveis, reversão dos efeitos e bloqueio quando um efeito já se tornou externo/definitivo. | Snapshots de revisão e financial lock são necessários; uma flag editável ou uma mutação silenciosa não atende ao contrato. |
| DECISÃO | O pedido original é a versão viva; revisões preservam snapshots imutáveis. Reabrir é permitido apenas sem financial lock; edição não apaga v1 nem altera seus registros de auditoria. | Materializado nas seções 2–7 deste Blueprint. |

## 2. Escopo de dados

| Objeto | Contrato | Estado |
|---|---|---|
| `orders.status` e `orders.current_revision` | Acrescenta estado `reopened` e número da versão corrente. Pedidos existentes iniciam em `1`; o status `refunded` continua terminal. | Extensão |
| `order_revisions` | Snapshot imutável de cada versão fechada. Um snapshot contém totais, itens, pagamentos, comissão, gorjeta, efeitos de benefício/estoque e referências do ledger daquela versão. | Novo |
| `order_reopen_attempts` e eventos | Tentativa de reabertura distinta da versão fechada: motivo, solicitante, aprovação quando exigida, abertura, descarte ou refechamento. Eventos são append-only, permitindo várias tentativas sobre a mesma versão. | Novo |
| `order_ledger_links` | Ligação imutável e versionada entre uma versão de pedido e suas transações KortexFlow de fechamento, reversão ou restauração. | Novo |
| `order_financial_locks` | Registro append-only, vinculado à revisão, de controle financeiro. `cash_close` exige Action Request owner-only; `staff_payout`, `psp_settlement`, `fiscal_emission` e `captured_payment_intent` são terminais. | Novo |
| `order_payment_adjustments` | Alocações imutáveis de cada reembolso, ligadas ao pagamento original, à tentativa e ao lançamento de caixa; provam a distribuição proporcional exata. | Novo |
| `cash_entries` | A venda original não é alterada. No refechamento, recebe apenas o delta líquido: `sale` para diferença positiva, `refund` para diferença negativa, nenhum lançamento se o delta for zero. | Extensão de comportamento |
| `order_items` e `payments` | Itens permanecem no pedido vivo, protegidos por snapshot. Pagamentos ganham `revision_number`, permanecem append-only e são lidos pela revisão corrente; a alocação de um estorno nunca é inferida somente de `cash_entries`. | Extensão de write-path |

### 2.1 Simplificações deliberadas

- A Onda não ativa wallet/crédito. Quando o novo total for menor, o backend calcula e devolve proporcionalmente pelas formas de pagamento originais; nenhuma diferença vira saldo paralelo.
- A Onda não cria PSP, fiscal, payout ou sessão de caixa. Ela prepara `order_financial_locks`; tais produtores futuros têm de bloquear a mesma linha de `orders`, conferir a revisão ainda fechada e gravar a trava na mesma transação.
- Pedido legado sem `order_ledger_links` não reabre. Sua correção é exclusivamente `order_refund` + nova venda; a Onda não reconstrói retroativamente um lançamento financeiro sem origem auditável.
- UI pode editar a comanda reaberta em memória, mas nenhuma tabela financeira recebe DML direto do cliente. A persistência integral ocorre em `order_reclose`.

## 3. Integridade e invariantes

1. **Ciclo de vida:** `closed → reopened → closed`. `refunded` não reabre; permanece correção terminal e exige nova venda quando aplicável.
2. **Versão, não apagamento:** cada fechamento novo cria no mesmo commit um snapshot imutável e ao menos uma ligação `order_ledger_links`. Pedido legado sem essa ligação é inelegível. Nenhum snapshot recebe `UPDATE` ou `DELETE` operacional.
3. **Alçada:** só `owner`, `admin` e `manager` reabrem, refecham ou descartam reabertura. `reception` mantém o direito legado de fechar pedido novo, mas nunca o de reabrir um pedido financeiro.
4. **Motivo:** reabrir exige `reason_code` dentre `pricing_error`, `item_correction`, `professional_correction`, `payment_correction`, `inventory_correction` ou `other`, e `reason_detail` não vazio. O autor, instante e diff são auditáveis.
5. **Trava financeira:** `staff_payout`, `psp_settlement`, `fiscal_emission` e todo `payment_intent.status='captured'` associado ao pedido são terminais: bloqueiam com erro de domínio, sem bypass, update ou remoção manual. `cash_close` não é terminal: abre Action Request e somente `owner` pode aprovar a tentativa específica. Após lock terminal, a correção é estorno + nova venda.
6. **Reversão em cascata:** a abertura reverte os efeitos de v1 de comissão, split de gorjeta, consumo de benefício, baixa de estoque, alocação de pagamento e lançamento de ledger identificado por `order_ledger_links`. O refechamento recalcula-os por completo para v2; nunca ajusta somente campos isolados.
7. **Caixa e delta:** a venda original fica preservada. Refinalizar registra só `new_total_cents − v1_total_cents`: entrada positiva, estorno negativo, ou zero. Cada parcela negativa tem `order_payment_adjustments` vinculada ao pagamento de v1, à tentativa e ao lançamento de caixa; as parcelas usam arredondamento determinístico e soma exata em centavos.
8. **Descartar reabertura:** `order_reopen_discard` é um Command explícito, idempotente e atômico: restaura todos os efeitos de v1, inclusive a posição no KortexFlow, volta o pedido para `closed` e acrescenta evento `discarded` à tentativa. Não cria nova venda, cancelamento ou estorno.
9. **Concorrência e idempotência:** todos os Commands e todos os produtores de lock/commission bloqueiam a mesma linha de `orders` com `FOR UPDATE` e verificam status/revisão após o lock. Replay com mesmo payload retorna resposta; mesma chave e payload divergente falha. Só uma tentativa de reabertura pode estar ativa por pedido.
10. **Dinheiro:** valores são `_cents` inteiros e nunca negativos. A soma das formas da versão fechada deve igualar o total devido; backend, não frontend, resolve comissão, gorjeta, estoque, benefícios e rateios.
11. **Journal fechado e reproduzível:** toda versão criada com a flag ligada deriva o mesmo journal antes de postar: débito `cash` pela soma dos pagamentos; crédito `revenue_service` pela soma de itens de serviço líquidos do desconto rateado; crédito `revenue_product` pelos produtos líquidos do desconto rateado; crédito `tip_liability` pela gorjeta; e, por profissional, débito `commission_expense`/crédito `staff_current_account` pela comissão calculada. O desconto segue exatamente o rateio de maior resto já aplicado em `checkout_close`; gorjeta não reduz receita nem comissão. O checkout atual não consome benefício: se um futuro payload o introduzir sem o contrato de obrigação/liquidação correspondente, o Command falha fechado em vez de inventar entrada de ledger.
12. **Idempotência composta:** cada Command reserva sua chave de requisição no namespace já existente. Toda suboperação de ledger usa chave filha determinística `sha256(parent_key + order_id + revision + operation)`, prefixada e com menos de 200 caracteres; nunca reutiliza a chave/hash do Command pai.

## 4. Contrato físico e Commands

### 4.1 `orders`

`status` aceita `reopened` além dos estados atuais. `current_revision integer not null default 1 check (current_revision > 0)` recebe backfill para os pedidos existentes. A relação `(organization_id, id, unit_id)` deve permanecer chave de referência para os novos fatos; não se flexibiliza nenhuma FK tenant-safe existente.

### 4.2 `order_revisions` e `order_reopen_attempts`

`order_revisions` possui `id`, `organization_id`, `unit_id`, `order_id`, `revision_number`, `snapshot jsonb`, `closed_by`, `closed_at` e timestamps. Há `unique (organization_id, order_id, revision_number)` e FKs compostas para pedido e unidade. O `snapshot` é um documento canônico completo, inclusive ids das transações de ledger vinculadas; é histórico, não fonte paralela de cálculo. Trigger de imutabilidade rejeita `UPDATE`/`DELETE`.

`order_reopen_attempts` contém `id`, tenant/unidade/pedido, `base_revision_number`, motivo controlado+descrição, solicitante e timestamps. `order_reopen_attempt_events` é append-only, com `requested|approved|rejected|opened|discarded|reclosed`, ator, instante e payload mínimo. Índice parcial único permite no máximo uma tentativa `requested|approved|opened` por pedido, mas não impede uma nova tentativa depois de descarte. `cash_close` cria a tentativa `requested`; só um evento `approved` de `owner` permite abri-la. Policies permitem leitura gerencial e escrita somente por Commands.

### 4.3 `order_ledger_links`, `order_financial_locks` e ajustes de pagamento

`order_ledger_links` possui `id`, tenant/unidade/pedido, `revision_number`, `ledger_transaction_id`, `kind` (`closure|reversal|restore`) e timestamps. O único caminho que grava uma versão fechada cria, na mesma transação, a transação balanceada pelo `kortex_ledger_post`, seu link de `closure` e o snapshot. Reabrir lê os links de closure de v1, posta os lançamentos inversos por conta e cria links `reversal`; descartar posta a restauração e cria link `restore`. Esse vínculo é a única forma autorizada de reversão por versão.

`order_financial_locks` possui `id`, tenant/unidade/pedido, `revision_number`, `source_type` (`cash_close|staff_payout|psp_settlement|fiscal_emission|captured_payment_intent`), `source_id`, `enforcement` (`action_request_required|terminal`), `locked_at`, `created_by` e timestamps. FKs são tenant-safe e `unique (organization_id, order_id, revision_number, source_type, source_id)` evita duplicação. Todo produtor bloqueia `orders` com `FOR UPDATE`, exige status `closed` e a revisão exata, grava o lock e torna seu efeito definitivo no mesmo commit. Não há grant de escrita para `authenticated` nem endpoint manual. O fechamento novo cria lock terminal para todo `payment_intent` capturado associado; pedido que já tenha esse estado não reabre.

`payments` recebe `revision_number not null default 1 check (revision_number > 0)` e é append-only por versão; o read-model seleciona a revisão viva de `orders.current_revision`. `order_payment_adjustments` possui tenant/unidade/pedido, `reopen_attempt_id`, `source_payment_id`, `cash_entry_id`, `kind='refund'`, `amount_cents`, `created_by`, timestamps e FKs compostas. Cada refund tem uma linha por pagamento original; a soma das linhas deve ser exatamente o delta negativo e cada uma não pode superar o saldo daquele pagamento após ajustes anteriores.

### 4.4 `order_reopen`

Recebe `order_id`, `reopen_attempt_id` e `idempotency_key`. Deriva tenant/ator, valida alçada, flag, unidade e `status='closed'`; bloqueia o pedido, exige `order_ledger_links.closure` da revisão corrente e recusa pedido legado, lock terminal ou depósito/intenção capturado. Quando existir `cash_close`, exige evento aprovado de `owner` para a tentativa. Em uma única transação, posta a reversão identificada do ledger, reverte efeitos de v1, acrescenta evento `opened`, muda o status para `reopened` e retorna o estado vivo para edição. Não escreve `cash_entries` nesta etapa: dinheiro só se movimenta no delta do refechamento.

### 4.5 `order_reclose`

Recebe o payload completo e validado da versão editada, `order_id`, `reopen_attempt_id` e `idempotency_key`. Só aceita pedido `reopened` do mesmo tenant/unidade e tentativa ativa. Revalida catálogo, profissional, quantidade, preço autorizado, pagamento e todas as somas; restaura/aplica estoque, consumo de benefício, comissão e gorjeta; cria pagamentos append-only para a nova revisão; posta novo lançamento balanceado no KortexFlow; grava `order_ledger_links.closure`, snapshot de v2 e evento `reclosed`, muda para `closed` e incrementa `current_revision`.

O Command calcula o delta contra v1 e insere no caixa somente esse delta. A diferença negativa cria `cash_entries.kind='refund'` mais alocações `order_payment_adjustments` distribuídas pelas formas de v1; a positiva cria `kind='sale'`. `order_reclose` é o único caminho que seleciona pedido existente.

### 4.6 `order_reopen_discard`

Recebe `order_id`, `reopen_attempt_id` e `idempotency_key`. Só aceita `reopened`; restaura de maneira determinística os efeitos da v1 a partir de seu snapshot e da transação de reversão vinculada, posta a restauração no ledger, muda o pedido para `closed` e acrescenta evento `discarded`. Não cria pagamento, venda, estorno ou cancelamento adicional.

### 4.7 Compatibilidade de `order_refund`

`order_refund` permanece o fluxo de estorno por `customer_cancellation|customer_default`. Ele só aceita `closed`; nunca reabre `refunded` nem substitui `order_reopen`. A escolha do caminho depende exclusivamente da existência de `order_ledger_links.kind='closure'` para a revisão corrente, nunca do valor atual da flag: pedido sem esse link conserva exatamente o comportamento legado; pedido com link bloqueia pedido e revisão, posta a reversão identificada pelo helper interno, persiste `order_ledger_links.reversal` e só então muda o status/restaura estoque/cria o `cash_entries.refund` vigente. Logo, desligar a flag impede novos links em `checkout_close`, mas não elimina a reversão de um pedido versionado já existente. A assinatura pública, os motivos e os erros existentes não mudam.

### 4.8 Primitive interna de ledger e dark launch de `checkout_close`

`public.kortex_ledger_post` permanece uma RPC administrativa de `owner`/`admin`/`manager`; ela não ganha grant para `reception`. A Etapa 8 extrai a lógica compartilhada de validação, contas, idempotência e escrita para `private.kortex_ledger_post_entries(...)`. As duas primitives privadas — ela e `private.checkout_ledger_post(...)` — recebem `REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon, authenticated, service_role`; não existe RPC pública equivalente. Como `private` concede `USAGE` a `authenticated` e funções PostgreSQL nascem com `EXECUTE` para `PUBLIC`, essa revogação explícita é obrigatória e deve ser provada por pgTAP para `authenticated` e `service_role`. Dois invólucros chamam a primitive: a RPC pública preserva sua alçada atual, e `private.checkout_ledger_post(...)` aceita somente o contexto interno de `checkout_close`/`order_reclose`/`order_refund`, revalida o ator segundo a alçada do Command de origem e usa a chave filha determinística. Os três Commands autorizados continuam conseguindo chamar a primitive como owner definer; acesso direto externo falha. Assim, `reception` pode fechar a comanda apenas pelo caminho já autorizado, mas nunca postar lançamentos arbitrários.

O `checkout_close` mantém assinatura e validações atuais. A mudança de ledger/snapshot/link é protegida por `organizations.settings.checkout_reopen_enabled`: com `false` ou ausente, executa bit a bit o comportamento anterior e marca o pedido implicitamente como legado (sem `order_ledger_links`, portanto inelegível a reabertura). Com `true`, depois de validar pagamentos, rateios de desconto/gorjeta e comissões já existentes, ele deriva o journal da regra 11, chama `private.checkout_ledger_post`, grava `order_ledger_links.closure` e o snapshot v1 no mesmo commit. Falha do journal reverte integralmente o checkout, inclusive itens/pagamentos/caixa/estoque. O pre-flight e os testes devem provar os dois ramos e checkout de `reception`.

## 5. RLS, backend e feature flag

| Objeto/Command | Leitura | Escrita |
|---|---|---|
| `order_revisions` | `owner`/`admin`/`manager`, tenant e unidade validados | Apenas Commands server-owned; snapshots imutáveis |
| `order_financial_locks` | `owner`/`admin`/`manager`, tenant e unidade validados | Apenas produtor interno futuro, sem DML/grant direto |
| `order_reopen`, `order_reclose`, `order_reopen_discard` | N/A | `owner`/`admin`/`manager`, membership autenticada e escopo de unidade |
| pedido vivo | Mantém o contrato de leitura existente | Somente o Command correspondente enquanto `reopened` |

`organizations.settings.checkout_reopen_enabled` nasce ausente/`false`. Express aplica o feature flag antes de chamar o RPC; a PWA só exibe a ação com `useFeatureFlag('checkout_reopen_enabled')`. A RPC também a revalida, para que não haja bypass pela camada HTTP. Todos os endpoints novos confirmam que `unitId` do caminho e membership do ator pertencem ao pedido; nunca aceitam tenant/unidade isolados do payload. `commission_sale_record_create` é endurecida para travar `orders`, revalidar `status='closed'` e `current_revision` antes de inserir; assim, ela ou termina antes e é revertida, ou falha após a reabertura.

## 6. Etapa 8: fatiamento e rollback previstos

O Blueprint não autoriza implementação. Depois de aprovado, o fatiamento deve produzir issues independentes na ordem abaixo:

1. Flag, pre-flight e schema imutável (`orders`, revisões, tentativas/eventos, links ledger, locks e ajustes de pagamento), com RLS/grants e pgTAP de tenant/imutabilidade.
2. Primitive de ledger privada e journal: extrair o write-path comum sem ampliar grants, aplicar `REVOKE ALL` explícito contra `PUBLIC`, `anon`, `authenticated` e `service_role`, definir entradas para serviço/produto/desconto/gorjeta/comissão/pagamentos e testar chaves filhas/idempotência, negação de chamada direta e os três Commands chamadores.
3. Fechamento novo dark-launched: adaptar `checkout_close` sob flag para criar lançamento balanceado, link e snapshot; provar checkout legado idêntico com flag desligada, checkout de `reception`, bloquear pedido legado e todo intent capturado.
4. `order_reopen` e descarte atômico, incluindo reversão/restauração de ledger, estoque/benefício/comissão/gorjeta, Action Request de caixa e locks serializados.
5. `order_reclose`, snapshot v2, pagamentos versionados, alocações de refund e delta de caixa, com contratos Express/Jest e UI na casca de Design System.
6. `order_refund` compatível com ledger: reversão/link condicional para pedidos versionados, contrato legado preservado.
7. Hardening adversarial: locks, produtor de comissão, payloads concorrentes, refunds proporcionais, regressão de `checkout_close`/`order_refund`, flag desligada e Gates 10/11/12/14/18.

Toda migration é forward-only e traz pre-flight SQL. Se uma fatia falhar, a flag segue desligada e nenhum caminho legado muda. Correções são migrations novas; não se edita migration aplicada, não se apaga snapshot e não se desfaz registro financeiro por DML.

## 7. Critérios de aceitação do desenho

- Gate de benchmark distingue fatos, inferência e decisão, incluindo a ausência pública de precedente Booksy.
- Reabertura de outro tenant/unidade, por `reception`, por payload manipulado, pedido legado, intent capturado, lock terminal ou replay divergente falha; a chamada direta de cada primitive privada por `authenticated` ou `service_role` também falha.
- Reabrir → editar → refechar mantém histórico v1/v2, links ledger reversíveis, recompõe estoque/benefícios/comissão/gorjeta e deixa o delta do caixa/alocações de refund exatos.
- Descartar reabertura restaura v1 e a posição de ledger sem nova entrada de caixa, estorno ou venda.
- Produtor de lock e `commission_sale_record_create` não conseguem criar fato financeiro depois de `order_reopen` vencer o lock de pedido.
- Com a flag desligada, `checkout_close` continua com seu contrato e testes atuais e não cria novos links; `order_refund` sem closure link continua no contrato legado, enquanto `order_refund` de pedido já versionado sempre reverte seu ledger. Com a flag ligada, as novas transações/link/snapshots são atômicos, balanceados e reversíveis.
- Nenhuma feature flag, migration, endpoint ou UI é ativado por este documento.

## 8. Red Team de desenho e pendências de gate

O Red Team de desenho inicial foi `NO-GO`. A revisão direta confirmou os sete achados e esta versão os corrige: (1) link ordem/revisão↔ledger e bloqueio de legado; (2) lock terminal para intent capturado; (3) protocolo de `FOR UPDATE` compartilhado por produtor de lock; (4) alocações imutáveis de refund; (5) tentativas/eventos separados das versões; (6) serialização de comissão de venda; e (7) `cash_close` como Action Request owner-only, distinto dos locks terminais.

A segunda rodada continuou `NO-GO` por três falhas agora corrigidas no contrato: o checkout de `reception` não pode chamar a RPC pública de ledger, a chave de idempotência pai não pode ser reutilizada pela suboperação, e o journal deve ser explícito. A correção define primitive privada, namespace de chave filha e journal por conta. A mesma rodada também exigiu que `order_refund` reverta os pedidos versionados e que `checkout_close` tenha guard inline de feature flag; ambos estão definidos na seção 4.7–4.8. A terceira rodada identificou dois gaps, também corrigidos: rollback da flag não pode decidir o caminho de `order_refund`, que usa somente o closure link; e primitive privada precisa de `REVOKE ALL` explícito, pois `EXECUTE` nasce em `PUBLIC`.

A quarta rodada reatacou os doze achados contra as migrations/RPCs reais e deu `GO` de desenho: a flag desligada preserva somente o checkout novo como legado, enquanto `order_refund` de pedido já versionado continua revertendo o ledger; as primitives privadas não recebem execução externa e os Commands autorizados continuam funcionando como owner definer. O veredito não aprova SQL, UI, endpoint, flag ou Etapa 8.

- [x] Red Team de desenho revisou este contrato contra schema/RPCs reais e Benchmark Gate (`GO` de desenho, 2026-08-10).
- [x] Platform Owner aprovou explicitamente o Blueprint (DEC-62, 2026-08-11).
- [x] DEC-62, ADR 0025, matriz DEC↔ADR e navegação foram atualizados; o fatiamento vertical aguarda validação do Platform Owner.

## 9. DOCUMENTATION_CHECK

- [x] Artefato novo classificado em `docs/waves/` e com frontmatter válido.
- [x] `docs/INDEX.md` atualizado para expor estado e navegação da Onda 6.
- [x] Governança e benchmark citados; nenhum DEC/ADR foi inventado antes de aprovação formal.
- [x] Links locais afetados e o Blueprint revalidados após a revisão adversarial.
