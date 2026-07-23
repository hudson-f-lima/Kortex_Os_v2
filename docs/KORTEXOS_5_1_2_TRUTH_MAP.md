# KORTEXOS™ — Truth Map 5.1.2

**Versão:** v1.0
**Data:** 2026-07-20
**Produzido por:** Claude Code, executando a Etapa 5 da ordem de construção (Master Briefing §22.1), conforme `KORTEXOS_5_1_2_INSTRUCAO_CLAUDE_CODE_TRUTH_MAP.md`.
**Escopo:** transição do MVP técnico para o produto final 5.1.2, limitada aos módulos 01–06 priorizados por DEC-20, com prioridade máxima aos 4 itens **REFORÇAR CRÍTICO** de DEC-22 (agendamento recorrente, cancelamento recorrente, Pix Automático, resolução de hold de depósito).
**Autoridade deste artefato:** classifica REAL/PARCIAL/MOCKADO/HARDCODED/CRÍTICO (§0.1 do Master Briefing). Não aprova arquitetura, não escreve SQL/migration, não altera decisões DEC, não autoriza deploy ou Migration Map.
**Status:** **APROVADO pelo Platform Owner em 2026-07-20 (DEC-23).** Etapa 5 CONCLUÍDA — ver `KORTEXOS_5_1_2_DECISION_LOG.md` e `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` §22.1. Etapa 6 (Migration Map) desbloqueada, ainda não iniciada.

## 0. Nota de proveniência

Um rascunho não versionado deste Truth Map já existia em `docs/kortex 512/KORTEXOS_5_1_2_TRUTH_MAP.md` antes desta sessão, com a mesma data (2026-07-20). Ele não estava registrado no Decision Log (não existe DEC-23) nem refletido no status da Etapa 5 do Master Briefing (§22.1 segue listando "Truth Map 5.1.1 — PENDENTE" no arquivo fonte). Portanto foi tratado como **hipótese a verificar, não como fato**, conforme a hierarquia de evidência do `kortex-truth-mapper` (teste executado > código/schema > estado documentado > plano).

Verificação executada nesta sessão (buscas diretas no código, não apenas leitura do rascunho):

- Ausência confirmada por busca textual em todo o repositório (fora dos próprios documentos 5.1.2): recorrência/série/ocorrência, Pix Automático/mandate/débito automático, resource lock/deposit hold/card-on-file/SetupIntent, waitlist/smart gap/availability resolver, e qualquer tabela de ledger (`kortex_accounts`, `ledger_entries`, `journal`) nas migrations.
- Conferidos os módulos reais de `backend/src/modules/` e `frontend/src/modules/` contra os módulos citados como REAL/PARCIAL — nenhum módulo de ledger, wallet, payout, waitlist, resource ou deposit existe.
- Conferido `backend/src/modules/checkout/checkout.validation.js`: enum de forma de pagamento é literalmente `['cash', 'pix', 'debit_card', 'credit_card', 'other']` — confirma que "pix" é só um rótulo de registro manual, sem integração de PSP.
- Conferido `.github/workflows/deploy-pages.yml`: dispara em `push` para `main` sem depender do workflow de CI — confirma que o deploy do Pages não é gateado por teste/lint.
- Conferido `render.yaml`: `CORS_ORIGINS` só lista `https://hudson-f-lima.github.io`; o domínio do próprio `kortex-pwa` (Render) não está incluído.
- Conferido `frontend/vite.config.js`: `base: '/Kortex_Os_v2/'` fixo — incompatível com o domínio raiz do deploy Render (`kortex-pwa`), que não usa esse subcaminho.
- Conferidas as migrations presentes (`supabase/migrations/`, 12 arquivos até `20260718120000_fase11_professionals_self_view.sql`) e os testes de comissão (`rls_professional_service_commissions_test.sql`, `rpc_checkout_close_test.sql`) — confirmam a cascata de comissão citada.
- Conferido `frontend/src/modules/agenda/` — nenhuma ocorrência de drag/drop/resize.

Todas as afirmações verificadas do rascunho se confirmaram. Este documento incorpora e substitui o rascunho, que foi removido de `docs/kortex 512/` (pasta também reorganizada — ver seção de higiene de repositório e o resumo enviado ao usuário). Nenhuma classificação abaixo foi elevada por otimismo; onde a suíte de testes integral não foi reexecutada nesta sessão, isso está declarado explicitamente na evidência.

---

## PASSO 0 — Identidade do repositório

- **Remote:** `git@github.com:hudson-f-lima/Kortex_Os_v2.git` (origin, único remote configurado).
- **`Kortex_Os_v2` é evolução/reescrita de `HopeOs-v1`, não um projeto paralelo.** Evidência: (a) o próprio Master Briefing 5.1.2, §0.3, declara textualmente "HOPE OS vira legado histórico interno... Nenhum documento futuro pode tratar HOPE OS, SMART Flow™ e KortexOS™ como produtos paralelos"; (b) busca por "hope" no repositório só retorna documentos em `docs/legacy/` (histórico) e um asset de design (`docs/legacy/Interface moderna do Hope OS para negócios.png`, movido nesta sessão — ver abaixo); (c) `git log --all` não tem nenhum commit mencionando Hope OS; (d) `package.json` do frontend/backend usa `kortex-pwa`/`kortex-api`, sem vestígio de nome antigo no código ativo.
- **`git remote -v` != tentativa de fetch nesta sessão:** o `git fetch --all` executado no Passo 1 não retornou dentro do tempo desta sessão (rede/SSH). A comparação abaixo usa as referências remotas já conhecidas localmente (`origin/main`, `origin/claude/...`), não um fetch ao vivo — reportado como limitação, não escondido.

## PASSO 1 — Auditoria local × GitHub

| Item | Estado |
|---|---|
| Branch atual | `main`, em `8e71ead`, idêntico à referência local `origin/main` conhecida |
| Mudanças não commitadas | `frontend/src/shared/OrganizationContext.jsx` e `OrganizationContext.test.jsx` (123 inserções/16 remoções) — trabalho em andamento pré-existente, **fora do escopo desta auditoria; não tocado** |
| Diretórios/arquivos não rastreados | `.agents/skills/frontend-design/`, `.agents/skills/supabase-postgres-best-practices/`, `.agents/skills/supabase/`, `.agents/skills/ui-ux-pro-max/`, `.claude/skills/`, `.mcp.json`, `.supabase-tmp/`, `skills-lock.json` — ferramentas/skills de terceiros, fora do escopo desta auditoria de código de produto |
| Worktree paralela | `.claude/worktrees/gracious-northcutt-61f4e4`, HEAD destacado em `d05f13b` — mesmo conteúdo de `233e941`/`78df84a` antes do squash-merge das PRs #9/#10; **não é divergência real**, é resíduo de uma sessão anterior já mesclada em `main`. Não removido nesta sessão (remoção de worktree é ação destrutiva fora do escopo pedido) |
| Divergência real local × remoto | **Nenhuma encontrada** nos artefatos de código/schema. A única "divergência" é documental: os 5 documentos canônicos 5.1.2 e este Truth Map, que eram não rastreados antes desta sessão |

Nenhuma correção silenciosa foi feita nesses achados de higiene — ficam registrados para decisão do Platform Owner (ex.: descartar a worktree, decidir o destino do diff de `OrganizationContext`).

---

## 1. Resumo executivo

O repositório contém uma fundação MVP **real**: isolamento de tenant via JWT + membership, RLS em 17 tabelas, agenda unitária transacional com conflito/idempotência/versão, checkout atômico e idempotente, estoque com baixa dupla, comissão em cascata (profissional > serviço > grupo), PWA modular com sincronização incremental (SSE + REST + IndexedDB), CI com lint/testes/scan de segredo, e deploy automatizado (Render + GitHub Pages).

O produto final definido pelo Master Briefing 5.1.2 **não existe como sistema integrado**. A lacuna concentra-se em cinco blocos: (1) Availability Resolver / Smart Gap / recursos físicos / waitlist (D07/D11) — inexistentes; (2) agendamento e cancelamento recorrente (D09) — inexistentes; (3) borda real de pagamento — PSP, Pix Automático, card-on-file, hold de depósito (D13) — inexistente, o enum de forma de pagamento é só rótulo local; (4) KortexFlow — ledger double-entry, wallet, conta corrente de staff, payout (D15/D16) — inexistente, o que existe é um log de caixa operacional (`cash_entries`), correto para o MVP mas insuficiente para o produto final; (5) release não gateado pela CI e configuração PWA/CORS incompatível com o segundo domínio de deploy (Render).

**Veredito: NO-GO para promoção direta ao produto final.** O MVP não deve ser descartado — seus invariantes (backend como SSOT, tenant por membership, centavos inteiros, idempotência, PWA sem escrita financeira direta) são exatamente os invariantes que o Master Briefing 5.1.2 exige e devem ser preservados, não redesenhados.

## 2. Gravidade econômica

| Lacuna | Por que é grave em R$/risco, não só tecnicamente |
|---|---|
| **Ledger/Wallet/Payout ausentes (D15/D16)** | Bloqueia toda a monetização recorrente do produto final: planos de assinatura, pacotes com obrigação, benefício corporativo e parceria dependem de "crédito rastreável e reconstruível" (Gate 11/13) para existir sem risco de saldo fantasma ou dupla verdade financeira. Sem isso, vender qualquer plano/pacote hoje seria contabilidade paralela — o maior risco identificado no próprio Master Briefing (§25.3: "automatizar correlações ruins antes de provar dados, causalidade, margem e segurança") aplicado a dinheiro real |
| **Recorrência ausente (D09) — REFORÇAR CRÍTICO** | É a realidade central do negócio-alvo (cliente do corte toda quinta, benchmark Vagaro/Boulevard). Sem isso, todo cliente recorrente precisa ser reagendado manualmente todo ciclo — custo operacional direto e risco de perda de retenção, o oposto da tese "Intelligent Capacity" do produto |
| **Pix Automático ausente (D13/D18) — REFORÇAR CRÍTICO** | É o mecanismo brasileiro nativo de cobrança recorrente (obrigatório para instituições financeiras desde out/2025). Sem ele, o Subscription Engine inteiro (D18) não tem forma de cobrar renovação sem intervenção manual — trava a principal fonte de receita recorrente do produto final |
| **Hold de depósito ausente (D13) — REFORÇAR CRÍTICO** | Sem hold local + retentativa, o Negative Guard não tem instrumento para proteger contra no-show de alto risco em agendamentos distantes (janela de rede de cartão ~5 dias). Receita perdida por no-show não mitigado é custo direto, recorrente, mensurável |
| **Borda de pagamento real (PSP/COF) ausente (D13)** | Sem consentimento tokenizado e cobrança real, auto-checkout, depósito cobrado na hora e proteção contra no-show de alto valor não existem — dependência de dinheiro/pix manual no balcão para todo o volume, sem redução de fila nem de inadimplência |
| **Release não gateado pela CI + conflito Render/CORS** | Risco operacional imediato, não hipotético: um push em `main` com teste quebrado ainda publica no Pages; a segunda superfície de deploy (Render `kortex-pwa`) hoje muito provavelmente serve assets 404 (por causa do `base: '/Kortex_Os_v2/'`) e teria requisições de API bloqueadas por CORS se alguém a usasse como PWA principal |

## 3. Classificação da verdade atual

Taxonomia: `REAL` (implementado, funcional, testado, sem gambiarra) · `PARCIAL` (existe, mas incompleto ou com lacuna conhecida) · `MOCKADO` (interface/contrato existe, lógica real não) · `HARDCODED` (valor fixo onde deveria ser configurável/calculado) · `CRÍTICO` (ausência ou erro aqui quebra integridade financeira/dados) · `AUSENTE` (extensão deste Truth Map às 5 classificações da INSTRUÇÃO: nenhum código, schema ou tela encontrado — distinto de MOCKADO, que pressupõe pelo menos uma interface existente).

| Módulo / capacidade | Estado | Evidência física | Lacuna ou risco para o produto final |
|---|---|---|---|
| Fundação: JWT, membership e tenant | `REAL` | `backend/src/middleware/auth.js`; `backend/src/middleware/organizationContext.js`; `supabase/migrations/20260712235319_mvp_baseline.sql` | Preservar: o header só seleciona organização; membership autenticada é quem autoriza |
| **M01** — Agenda unitária por appointment (CRUD, conflito, versão, idempotência) | `PARCIAL` | `backend/src/modules/appointments/*`; `supabase/migrations/20260716150000_fase_opcao_c_elegibilidade_snapshot.sql`; `supabase/tests/rpc_appointments_test.sql` | CRUD transacional com `create_appointment`/`update_appointment` (idempotência, concorrência otimista, elegibilidade fail-closed) existe e é sólido — mas cobre só profissional×intervalo, não é o Booking & Capacity Scheduling completo (D07) |
| M01 — duração/elegibilidade por profissional | `PARCIAL` | `professional_service_capabilities`; `professional_service_group_eligibility`; snapshot em `appointments.resolved_*` | Cascata resolve no backend (ADR 0010/0011), mas não há UI (PWA) para configurar o tri-state por grupo/default — só a API/RPC |
| M01 — visualização/edição de agenda (drag, resize, chain) | `PARCIAL` | `frontend/src/modules/agenda/AgendaPage.jsx`; `AppointmentModal.jsx` — busca confirma zero ocorrência de drag/resize | Sem reagendamento por arraste, redimensionamento por alça, ou "move visit" de bloco composto |
| **M01 — agendamento recorrente** (D09) | `CRÍTICO` / `AUSENTE` | Busca em `supabase/migrations/`, `backend/src/`, `frontend/src/` por recorrência/série/ocorrência: zero resultado fora dos próprios documentos 5.1.2 | DEC-22 (01.13) marca **REFORÇAR CRÍTICO**. Não há modelo de série, frequência, data-fim, Command nem tela |
| **M01 — cancelamento recorrente** (ocorrência vs. série) | `CRÍTICO` / `AUSENTE` | Mesma busca acima — depende inteiramente de M01 recorrente existir primeiro | DEC-22 (01.14) **REFORÇAR CRÍTICO**. Não pode ser resolvido isoladamente; é consequência direta do item anterior |
| M01 — booking em grupo/multi-cliente (D10) | `AUSENTE` | `appointments` tem `client_id` único; sem tabela de participantes/pagador≠beneficiário | Não atende Gate 07; corrigido para REFORÇAR por DEC-22 (01.10), ainda não desenhado |
| **M02** — Availability Resolver, Smart Gap, yield (D07) | `AUSENTE` | Nenhum módulo, migration, rota ou teste de disponibilidade, slot score ou gap prevention | O Master exige D07 como fonte canônica de horários reserváveis; hoje só existe checagem de conflito unitária dentro do CRUD de appointment |
| M02 — recursos físicos, lock e expiração (D11) | `CRÍTICO` / `AUSENTE` | Nenhuma entidade/rota/teste de `resource`/`hold` | Sem reserva transacional de sala/equipamento, sem timeout, sem revalidação |
| M02 — waitlist e recuperação econômica | `CRÍTICO` / `AUSENTE` | Nenhum estado ACTIVE→MATCHED→OFFERED→HOLDING→BOOKED, endpoint ou tela | Cancelamentos não recuperam capacidade; Gate 09 não pode passar |
| **M03** — checkout, catálogo, estoque, pagamento registrado | `PARCIAL` | `checkout_close` RPC em `supabase/migrations/20260715103200_fase9_foundation.sql`; `backend/src/modules/checkout/*`; testes `rpc_checkout_close_test.sql` | Núcleo transacional atômico e idempotente é sólido; suíte integral não foi reexecutada nesta sessão (ver nota de método) |
| M03 — desconto/gorjeta em R$ **ou** % | `PARCIAL` | Fase 9 resolve `discount_cents`/`tip_cents` com rateio por maior resto | DEC-16 exige entrada em R$ **ou** % com resolução no backend; contrato atual só aceita centavos já resolvidos, não as duas modalidades de entrada |
| **M03 — PSP, Pix Automático, pagamento recorrente** (D13/D18) | `CRÍTICO` / `AUSENTE` | `backend/src/modules/checkout/checkout.validation.js` linha 5: `PAYMENT_METHODS = ['cash', 'pix', 'debit_card', 'credit_card', 'other']` — enum local, sem webhook, mandate, job ou state machine de PSP | "pix" hoje é só um rótulo de registro manual de pagamento já recebido por fora, não uma cobrança. DEC-22 (02.9b) **REFORÇAR CRÍTICO** |
| M03 — estorno | `PARCIAL` | `order_refund` em `supabase/migrations/20260715120000_fase9_order_refund_reason.sql`; `backend/src/modules/orders/*` | Reverte estoque e caixa local corretamente; não há chargeback, evento de PSP ou transferência real (porque não há PSP) |
| **M04** — caixa operacional e idempotência | `PARCIAL` | `cash_entries`; `private.idempotency_keys` (hardening RLS em `20260717060000_rls_hardening_idempotency_sync_events.sql`); `cashEntries.test.js` | É log de caixa operacional (entradas/saídas manuais) — correto para MVP, mas não é ledger financeiro do produto final |
| **M04 — ledger double-entry append-only** (D15) | `CRÍTICO` / `AUSENTE` | Nenhuma tabela `kortex_accounts`/`ledger_entries`/`journal` em nenhuma das 12 migrations existentes | Master exige Gates 11–13; sem isso, qualquer reversão/reabertura hoje seria contabilidade não reconstruível |
| **M04 — client wallet / staff current account** (D16) | `CRÍTICO` / `AUSENTE` | Nenhuma tabela, RPC, projeção ou tela correspondente | Impede crédito, consumo ordenado (benefício→wallet→forma externa), payout auditável |
| M04 — reabertura de comanda (DEC-03/11) | `CRÍTICO` / `AUSENTE` | Só existe `order_refund`; `docs/adr/0007-cash-sessions-void-vs-refund.md` já registra o gap como decisão consciente para Fase 12 | DEC-03/11-13 exigem reversão em cascata (comissão, gorjeta, benefício, estoque, pagamento) + financial lock; estorno atual não é substituto |
| **M05** — comissão de execução | `PARCIAL` | `professional_service_commissions`; `private.resolve_commission()`; snapshot em `order_items`; confirmado em `rls_professional_service_commissions_test.sql`/`rpc_checkout_close_test.sql` | Cascata profissional > serviço > grupo existe e é testada; sem payout, sem níveis completos (DEC-04 preço/tempo/comissão por nível), sem comissão de venda |
| M05 — gorjeta | `PARCIAL` | Fase 9 rateia gorjeta proporcionalmente pelos itens de serviço | Não satisfaz DEC-01 (absorção por forma de pagamento) nem o split ponderado por valor **e** tempo (DEC-02) |
| M05 — reversão de comissão, comissão de venda, payout | `CRÍTICO` / `AUSENTE` | `docs/adr/0005-reversao-de-comissao-em-estornos.md` registra intenção futura; sem payout batch, staff current account, clawback ou comissão de venda | Sem base para Gates 14/18 e DEC-15/18 |
| **M06** — no-show | `PARCIAL` | Status `no_show` em `appointments.validation.js` | Sem régua progressiva (11.2), Client Reliability Score, sinal/pré-pagamento ou Healing |
| **M06 — depósito, card-on-file, auto-checkout** (D13) | `CRÍTICO` / `AUSENTE` | Nenhum token, consentimento COF, SetupIntent, webhook de PSP ou depósito por serviço | O enum de forma de pagamento não materializa integração real; DEC-22 (06.4/06.6) |
| **M06 — hold local + retentativa/lembrete** (resolução de 06.3) | `CRÍTICO` / `AUSENTE` | Nenhuma tabela de hold, scheduler, outbox ou endpoint correspondente | DEC-22 (06.3) **REFORÇAR CRÍTICO** — solução já definida pelo Platform Owner (hold local + retentativa), só falta existir |
| PWA, auth-only, cache incremental | `PARCIAL` | `frontend/src/app/routes.jsx`; `shared/supabaseClient.js`; `shared/apiClient.js`; `shared/syncEngine.js` | Cache é projeção de leitura (IndexedDB + SSE/REST), correto para o MVP; insuficiente para hold/waitlist offline do produto final |
| Entrega e release | `CRÍTICO` / `PARCIAL` | `.github/workflows/deploy-pages.yml` (dispara em `push: main` sem depender do job de CI); `render.yaml` (`CORS_ORIGINS` só GitHub Pages); `frontend/vite.config.js` (`base: '/Kortex_Os_v2/'` fixo) | Pages publica independente do resultado da CI. Config do Render (`kortex-pwa`) conflita com o `base` fixo do Vite e não tem CORS liberado no backend. Não existe ambiente de homologação |

## 4. Falhas estruturais

1. **Ordem financeira invertida para o produto final.** O MVP registra caixa (`cash_entries`) antes de existir ledger/wallet. Para o alvo 5.1.2, planos, benefícios, crédito e payout ficam bloqueados até existir uma única fonte financeira append-only e reconstruível (D15/D16).
2. **Agenda não tem motor de capacidade.** Anti-overlap por profissional (o que existe hoje) não é Availability Resolver, recurso físico, Smart Gap ou hold (D07/D11). Não conectar automação/mensageria de waitlist antes disso existir.
3. **Não há borda de integração de pagamentos.** Métodos locais (`cash`/`pix`/`debit_card`/`credit_card`/`other`) não provam PSP, consentimento de cartão, Pix Automático, conciliação ou chargeback.
4. **Reabertura de comanda seria destrutiva hoje.** Sem ledger, reversal events, financial lock e reconstrução, uma edição pós-fechamento criaria duas verdades financeiras — exatamente o "Risco nº 1" que o próprio Decision Log (Seção 6) já identificou como o ponto de maior risco contábil do sistema.
5. **Release não é gateado.** Deploy do Pages não depende do sucesso da CI; a segunda superfície de deploy (Render) tem configuração incompatível (base path + CORS) nunca validada em uso real; a migration da Fase 11 segue sem confirmação de paridade em produção (`docs/PROJECT_STATE.md`, "Próxima Ação Imediata").
6. **Pontos jurídicos bloqueados externamente.** DEC-14 (breakage/aceite de pacote), DEC-18 (reembolso unificado) e DEC-19 (dado sensível/LGPD) exigem validação jurídica antes de qualquer ativação comercial — não é lacuna técnica, é bloqueio de processo que nenhum código resolve.

## 5. Pontos cegos

- **Rodízio/fila de walk-in** (Decision Log, Seção 8.3): lacuna identificada no próprio benchmark nacional (Trinks), registrada como "entra na pauta da promoção 5.1.2" — não apareceu em nenhum dos 6 módulos priorizados porque não tem módulo dono ainda; risco de ficar permanentemente fora do escopo priorizado se ninguém a resgatar explicitamente no Migration Map.
- **UI de elegibilidade tri-state (Opção C)** já é gap conhecido do MVP (`docs/PROJECT_STATE.md`, Gap #3) e continuará sendo gap também no produto final — nenhum dos 4 documentos 5.1.2 o menciona porque ele é invisível no nível de "módulo priorizado", mas bloqueia a mesma cascata de preço/tempo/comissão que DEC-04 exige para níveis.
- ~~**Ambiente de homologação inexistente** (Gap #4 do MVP)~~ — **fechado por DEC-29 (2026-07-22)**: segundo projeto Supabase + 2 serviços Render de staging criados, validados de ponta a ponta (deploy live, isolamento de ambiente confirmado por inspeção direta do bundle publicado) e branch `main` protegida via `gh api`. Continua valendo o ponto de fundo — a importância de homologação só cresce à medida que o produto final adiciona ledger/pagamento real — mas agora há QA intermediário real antes de qualquer merge em produção, não mais um risco em aberto.
- **Nomenclatura 5.1.1 dentro de arquivos 5.1.2**: o Master Briefing e o Decision Log usam a numeração "5.1.1" em vários trechos (títulos de seção, RAGOV, ordem de construção) dentro de arquivos nomeados "5.1.2". É inconsistência editorial herdada da promoção incremental dos documentos, não evidência de estado técnico — mas pode confundir quem ler só um trecho fora de contexto.

## 6. Invariantes obrigatórios

- Backend Express continua sendo o único dono de Commands e cálculo financeiro; frontend nunca calcula total, saldo, taxa, comissão, split ou herança (§7.2/§9.3/Parte III 4.5 do Master).
- Tenant deriva de JWT + membership ativa; `X-Organization-Id` isolado nunca concede acesso.
- Todo domínio de negócio novo tem `organization_id`, RLS e FKs tenant-safe, com teste de isolamento cross-tenant antes de ser considerado REAL.
- Dinheiro em `_cents` inteiros sempre; entrada em R$/% (DEC-16) é UX, nunca ambiguidade armazenada.
- Toda mutação financeira, de estoque, de booking/hold e de integração externa exige `idempotency_key`, motivo quando alterar valor/comissão, e trilha de auditoria.
- PWA nunca recebe `service_role`, nunca mantém verdade financeira ou de agenda concorrente sem passar por Command backend.
- Nenhuma IA, automação, webhook ou parceiro escreve agenda, saldo, benefício ou dinheiro fora de um Command validado (§6.4/§12.16 do Master — soberania do backend).

## 7. O que congelar

Não modificar, sem decisão explícita do Platform Owner, as seguintes superfícies já REAIS/PARCIAIS que o produto final vai herdar, não redesenhar do zero:

- Contrato de `create_appointment`/`update_appointment` (idempotência, concorrência otimista `version`, elegibilidade fail-closed) — é a base sobre a qual D07/D09 vão se apoiar, não um protótipo a jogar fora.
- Estrutura de `cash_entries` como registro de caixa operacional — continua válida como está até o ledger existir; não "esticar" seus campos para simular contabilidade double-entry por atalho.
- Cascata de comissão `professional_service_commissions`/`resolve_commission()` — base correta para a extensão de níveis (DEC-04) e comissão de venda (DEC-15), não precisa ser reescrita.
- `organizationContext.js`/`auth.js` — mecanismo de tenant/JWT correto e testado; qualquer novo domínio se conecta a ele, não recria autenticação própria.

## 8. Ordem única de correção

1. **Gate de fundação e entrega:** confirmar paridade da migration Fase 11 em produção; fazer o deploy do Pages depender do sucesso da CI; resolver o conflito `base` do Vite / CORS para o domínio Render; definir ambiente de homologação.
2. **M06/M03 — borda de pagamento:** desenhar (no Migration Map, não aqui) payment intent, estados de PSP, webhooks idempotentes, consentimento COF e depósitos. Não implementar Pix Automático isoladamente antes dessa borda existir.
3. **M04/M05 — KortexFlow mínimo:** ledger append-only double-entry, contas, wallet reconstruível, staff current account, reversões e payout — antes de qualquer plano, benefício, reabertura de comanda ou comissão de venda.
4. **M01/M02 — Availability Engine:** calendário/políticas → candidate resolver → recursos com lock e expiração/revalidação → só então waitlist state machine e recorrência (D09).
5. **Checkout final:** integrar consumo `benefício → wallet → forma externa`, desconto/gorjeta em R$/%, comissão de uso/venda, reabertura por eventos reversos com reason codes.
6. **Só depois:** Subscription, Corporate/Partner Benefits, mensageria (KortexLink), Action Requests, analytics e automação — sempre em modo OBSERVE com kill switch antes de qualquer execução autônoma.

## 9. Patch list executável

Itens de higiene/configuração que não dependem do Migration Map e podem ser corrigidos como manutenção, sem violar o bloqueio de SQL/migration/feature nova desta etapa:

- [x] **Confirmado (2026-07-20, DEC-28):** `supabase/migrations/20260718120000_fase11_professionals_self_view.sql` **NÃO rodou em produção** — verificado via `mcp__supabase__list_migrations` contra o projeto de produção (`kpedsuklnedlhjvadiyc`, confirmado por `get_project_url`); a última migration lá é `20260717060000`. O vazamento de RLS (profissional vendo toda a lista da organização) segue ativo em produção. **Aplicar a migration não foi executado — aguarda confirmação explícita do Platform Owner**, por ser mudança de schema em produção.
- [x] Dependência do job de CI adicionada (DEC-28): `deploy-pages.yml` passa a disparar via `workflow_run` da "CI/CD Pipeline", com `if: conclusion == 'success'`, e faz checkout do commit exato validado pela CI (`head_sha`).
- [x] `CORS_ORIGINS` em `render.yaml` corrigido (DEC-28) — adicionado `https://kortex-pwa.onrender.com` (URL assumida pelo padrão default do Render; **confirmar no dashboard** se um domínio customizado estiver configurado).
- [x] Conflito `base` do Vite resolvido (DEC-28) — `base: process.env.VITE_BASE_PATH || '/'` em `vite.config.js`; `deploy-pages.yml` seta `VITE_BASE_PATH=/Kortex_Os_v2/` só no build do GitHub Pages. Verificado por build local (com e sem a variável) — **build falhou por um motivo não relacionado**: `CaixaPage.jsx` importa um `CaixaPage.css` inexistente, parte de uma quantidade grande de mudanças de frontend não commitadas encontradas na árvore de trabalho (provável redesign de shell em andamento em paralelo a esta sessão) — não investigado nem corrigido, fora do escopo desta auditoria.
- [ ] Reexecutar as três suítes de teste (pgTAP, backend, frontend) integralmente — adiado para o início do Blueprint (DEC-28), não executado agora.
- [x] Worktree `claude/gracious-northcutt-61f4e4` removida do controle do git (2026-07-20) — `git worktree list` não a lista mais. Diretório em disco e metadados `.git/worktrees/` não foram totalmente apagados (erro de permissão do Windows, provavelmente arquivo em uso por outro processo) — resíduo inofensivo, não bloqueia nada. Uma segunda worktree não documentada, `compare-hudson-lima-logic`, também apareceu no mesmo erro — não investigada, ver aviso na resposta desta sessão.

Nenhum item acima cria domínio, tabela, endpoint ou tela do produto final 5.1.2 — são correntes de manutenção do MVP já existente.

## 10. Gates antes de expansão

| Gate | Estado atual | Condição mínima para avançar |
|---|---|---|
| 00–02 Fundação, tenant e privacidade | `PARCIAL` | Reexecutar evidência de teste, confirmar Fase 11 em produção, preservar isolamento em todo domínio novo |
| 03–09 Disponibilidade, conflito, recorrência, grupo, waitlist | `NO-GO` | Availability Resolver + recursos + holds + expiração + idempotência + testes multi-tenant, todos ausentes hoje |
| 10–15/18 Checkout, ledger, wallet, comissão, caixa | `NO-GO` | Ledger/wallet/payout e state machine de PSP; reversões auditáveis; reconstrução verde |
| 16–17 Action Request, IA e mensageria | `NO-GO` | Policy layer, outbox, consentimento, aprovação humana e kill switch |
| 19–21 Analytics, integrações, LGPD | `NO-GO` | Projeções reconstruíveis, webhooks seguros, validações jurídicas de DEC-14/18/19 |
| 25 Release | `NO-GO` | CI bloqueando deploy, homologação, paridade de schema confirmada, rollback testado |

## 11. O que não construir agora

- Telas de plano, wallet, Pix Automático, reabertura de comanda ou qualquer superfície de IA operacional antes do Migration Map e do Blueprint aprovados (§22.2 do Master: "criar planos antes de ledger/wallet" é bloqueio explícito).
- Expansão de `cash_entries` com campos ad hoc para imitar ledger — vira dívida técnica disfarçada de progresso.
- Tratar os `packages` atuais como equivalentes aos pacotes com obrigação, aceite digital, validade, extensão e breakage de DEC-14/18 — são conceitos diferentes hoje.
- Ativação de recorrência, waitlist ou qualquer booking automático via inserção direta em `appointments` como atalho — quebra a garantia de Command único.
- Qualquer integração de PSP real, Pix Automático ou card-on-file antes do desenho de payment intent/webhook do Migration Map — não "plugar Stripe/PSP rápido" para destravar M06 isoladamente.
- Qualquer venda comercial de pacote/plano/dado sensível antes do parecer jurídico de DEC-14/18/19.

## 12. Próximo passo executável ideal

1. ~~Platform Owner revisa e aprova este Truth Map v1.0~~ — **feito**: aprovado em 2026-07-20.
2. ~~Registrar DEC-23 e atualizar a tabela §22.1 do Master Briefing~~ — **feito**: `KORTEXOS_5_1_2_DECISION_LOG.md` (DEC-23) e `KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md` §22.1 atualizados em 2026-07-20.
3. **Próximo:** iniciar a **Etapa 6 — Migration Map** (`$kortex-migration-mapper`), começando pelos blocos 1–3 da Ordem única de correção (§8 acima): fundação/release, borda de pagamento, KortexFlow mínimo.
4. Não iniciar SQL, migration ou UI de regra crítica antes disso — guardrail que se mantém idêntico ao da sessão que produziu este documento.

---

FILES_CHANGED:
- `docs/KORTEXOS_5_1_2_TRUTH_MAP.md`: novo (este documento — v1.0, versionado, substitui o rascunho).
- `docs/KORTEXOS_5_1_2_MASTER_BRIEFING_CANONICO.md`, `KORTEXOS_5_1_2_DECISION_LOG.md`, `KORTEXOS_5_1_2_GLOBAL_BENCHMARK_MAP.md`, `KORTEXOS_5_1_2_COMPARATIVE_PROPOSAL.md`, `KORTEXOS_5_1_2_INSTRUCAO_CLAUDE_CODE_TRUTH_MAP.md`: movidos de `docs/kortex 512/` para `docs/` (promovidos a documentos canônicos vivos, mesmo nível dos ADRs).
- `docs/kortex-5.1.2-design/`: nova pasta, contém os 2 assets de design (`Dashboard moderno de gestão Kortex OS.png`, `Kortex_Design_System_v1_0(1).docx`) movidos de `docs/kortex 512/`.
- `docs/legacy/Interface moderna do Hope OS para negócios.png`: movido da raiz de `docs/` — branding Hope OS é legado por regra explícita do Master §0.3.
- `docs/legacy/kortex_5_1_2_raw_upload_bundle.zip`: movido de `docs/files.zip` — bundle redundante (3 dos 5 docs canônicos já extraídos).
- `docs/kortex 512/` (pasta): removida, vazia após as promoções acima.
- Nenhum arquivo de código, schema, migration ou teste foi alterado.

BLOCKERS_REMAINING:
- Aprovação do Platform Owner para encerrar a Etapa 5 e registrar DEC-23.
- Paridade da migration Fase 11 em produção (independente deste Truth Map, já pendente em `PROJECT_STATE.md`).
- Reexecução integral das 3 suítes de teste (não rodadas nesta sessão).
- Validação jurídica de DEC-14, DEC-18 e DEC-19.
- Decisão do Platform Owner sobre a worktree `claude/gracious-northcutt-61f4e4` e o diff não commitado de `OrganizationContext.jsx` (ambos fora do escopo desta auditoria).

VEREDITO:
- `NO-GO` para promoção direta ao produto final; `GO` apenas para iniciar a Etapa 6 (Migration Map) após aprovação explícita deste Truth Map v1.0.
