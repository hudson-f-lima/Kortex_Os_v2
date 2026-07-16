# PLANEJAMENTO_EXECUCAO_UNIFICADO

Status: CANÔNICO — única fonte de numeração de fases a partir da Fase 8
Fase atual: 10 [CONCLUÍDA] | Última atualização: 2026-07-16 (Fase 10 concluída — capacidades N:N + hardening do agendamento) | Supersede sequenciamentos de:
PLANEJAMENTO_FINANCEIRO §4-5, PLANEJAMENTO_COMISSOES §8, PLANEJAMENTO_ROADMAP_POS_MVP §7, PLANEJAMENTO_CALENDARIO_OPERACIONAL §11, PLANEJAMENTO_AGENDA_TRANSACIONAL §13

## 1. Objetivo e Regra de Canonicidade

- Este documento **CONTINUA** a numeração de `KORTEX_MVP_TECNICO.md §10` (Fases 1–7, encerradas).
- **Regra de governança**: nenhum outro documento pode criar numeração própria de "Fase" ou "Camada" executável. Documentos de planejamento apenas propõem; a fase de execução é alocada e registrada exclusivamente aqui.
- **"Propõe, não decide sozinho"**: toda fase possui um bloco "Decisões em aberto" que o usuário resolve ANTES do início da fase (não durante o seu desenvolvimento).
- **Regra de ouro — pesquisar antes de decidir**: nenhuma "Decisão em aberto" pode ser fechada, e nenhum ADR pode passar de `Proposed` para `Accepted`, sem antes pesquisar como o mercado global (não só o nicho de salões/estética) resolve o mesmo problema. Pesquisa vem antes da recomendação, nunca depois. Precedente desta sessão: a migration da Fase 9 (`20260715103200_fase9_foundation.sql`) implementou `order_refund` sem reversão de comissão; só a pesquisa de legislação trabalhista brasileira revelou que isso é o comportamento correto por lei (CLT), não uma lacuna — ver ADR 0005.

## 2. Estado Verificado

Estado atual:
- **Migrations**: 6 (baseline, permissões, grupos/pacotes, comissões, fundação financeira, motivo do estorno).
- **RPCs**: `checkout_close`, `inventory_adjust`, `create_organization`, `membership_set`, `cash_entry_manual`, `order_refund`.
- **Módulos Backend**: 16.
- **Módulos PWA**: 8.
- **Testes**: 151 pgTAP + 208 backend + 75 frontend.
- **CI**: Fase 7 rodou e passou.
- **Render**: `REAL` (Fase 7 fechou; backend `kortex-api` validado online com `/health` OK).

**Tabela de Rastreabilidade**

| Origem da Demanda | Fase Alocada |
|---|---|
| `PLANEJAMENTO_FINANCEIRO` Camada 1 | Fase 9 |
| `PLANEJAMENTO_COMISSOES` §8.3 | Fase 10 |
| `PLANEJAMENTO_COMISSOES` §8.4 | Fase 11 |
| ADR 0007 — `cash_sessions` + Void vs. Refund (novo) | Fase 12 |
| `PLANEJAMENTO_COMISSOES` §8.1+8.2 | Fase 13 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` §5/§6 | Fase 14 |
| `PLANEJAMENTO_CALENDARIO_OPERACIONAL` (completo) | Fase 15 |
| `PLANEJAMENTO_AGENDA_TRANSACIONAL` (completo) | Fase 16 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 2 (restante — waitlist/anti-gap) | Fase 17 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` §5/portal do cliente | Fase 18 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 3 (memberships) | Fase 19 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 4 | Bloqueado (§6) |

## 3. Invariantes Transversais e Arquitetura-alvo do Checkout

Esta é a equação-alvo de reconciliação que será definida **UMA única vez** e implementada em fatias pelas próximas fases.
`sum(payments) == subtotal - discount_total + tip_total - deposit_credit`

(Hoje `discount` = `tip` = `deposit` = 0 forçados. A Fase 9 ativará discount/tip e a Fase 14 ativará deposit_credit; contudo, a equação e os checks nascerão completos já na Fase 9).

- **Contrato de payload extensível** na `checkout_close` com campos opcionais, valores default e **versionamento do hash de idempotência** (para evitar falhas no retry cruzando o deploy de novos campos).
- **Invariantes permanentes**: 
  - Todo o dinheiro usa centavos inteiros.
  - Toda RPC que escreve dinheiro requer `private.idempotency_keys`.
  - A comissão é sempre congelada no checkout (não retroage).
  - Toda tabela nova nasce com a matriz RLS completa e testes pgTAP por papel.

## 4. Fases de Execução (Fase 8 a 15)

### Fase 8 — Consolidação documental e fechamento real do MVP [CONCLUÍDA]
**Escopo**: merge (fast-forward) da branch de docs; criação deste documento; higiene documental de todos os arquivos; fechamento da pendência Render; parametrização de `deploy-pages.yml`.
**Dependências**: Nenhuma técnica — é o pré-requisito de TODAS as outras. (Uma divergência de documentação impede o sequenciamento correto no main).
**Entregáveis**: Higiene nos docs concluída (ADRs ajustados, INDEX renomeado, supersedes adicionados).
**Decisões em aberto**: (a) `/health` do Render: corrigir agora ou re-escopar formalmente o deploy do backend? (~~b) fast-forward vs cherry-pick~~ — resolvido: merge fast-forward aplicado; ~~c) nome do agrupamento no INDEX~~ — resolvido: "Trilhas A–D").
**Riscos**: Manter a pendência de devops silenciada.
**Gate de saída**: main = única verdade; CI verde; evidência real do /health 200 em produção OU decisão registrada de re-escopo documentado. INDEX sem colisão de numeração.

### Fase 9 — Fundação Financeira (Camada 1) [CONCLUÍDA]
**Escopo**: Desconto real em `checkout_close` (fim do `discount_cents=0`); regra de distribuição do desconto entre itens (pré/pós expansão de pacote); gorjeta; RPC de lançamento manual de caixa (`income`/`expense`/`refund`) com idempotência; estorno de venda (`order_refund`). Nasce aqui a equação-alvo do §3, prevendo já o `deposit_credit`.

**Estado real (fechado em 2026-07-15)**: a migration `20260715103200_fase9_foundation.sql` implementa desconto/gorjeta rateados por maior resto em `checkout_close`, `cash_entry_manual` e `order_refund`. Comissão é calculada sobre `total_cents - discount_cents` (equivalente ao modo "Revenue" do Zenoti — ver Fase 12) sem flag de organização ainda. Uma segunda migration (`20260715120000_fase9_order_refund_reason.sql`) fechou a decisão (3) abaixo, adicionando `orders.refund_reason` e exigindo `p_reason` em `order_refund`. Suíte pgTAP 100% `PASS` (151 testes no projeto), wiring backend completo (208 testes) e PWA operando os três fluxos (75 testes) — ver `PROJECT_STATE.md` para o relato completo, incluindo o achado de vários bugs pré-existentes na suíte pgTAP (nunca executada antes por bloqueio de porta do Docker no Windows).

**Achado — `order_refund` não reverte comissão (linhas 128–159 da migration): isto está correto por padrão, não é uma lacuna a fechar automaticamente.** Pesquisa de legislação trabalhista (ver ADR 0005) mostrou que estornar comissão já congelada de profissional CLT é ilegal exceto por inadimplência do comprador (Lei 3.207/1957 art. 7º); para profissional autônomo-parceiro (Lei 13.352/2016) a regra depende do contrato de parceria. O schema não distingue hoje a classificação do profissional nem o motivo do estorno — nenhuma automação de reversão de comissão deve ser implementada até essas duas informações existirem (ver ADR 0005).

**Novo deliverable identificado — correção de comanda fechada por erro operacional (ex.: recepção digitou o serviço/profissional errado) é um cenário DIFERENTE de estorno ao cliente, e não deve reusar `order_refund`.** A primeira pesquisa (Zenoti "Reopen a Closed Invoice", Vagaro "Reassign Sold By", Square "Return or Exchange") não achou um padrão único e sugeriu uma RPC isolada `order_correct`. **Pesquisa de seguimento em concorrentes diretos do nicho (AppBarber, Trinks, e confirmação lateral em Avec/Nex) achou um padrão local convergente e mais forte, que substitui essa hipótese**: nos quatro sistemas, reabrir uma comanda fechada não é uma ação isolada na própria comanda — **é travada pelo estado da sessão de caixa que a contém**.
- **AppBarber**: uma comanda só pode ser alterada enquanto o caixa em que ela está ainda está aberto. Se o caixa já fechou, o fluxo documentado é: `Financeiro > Histórico de Caixa` → localizar o caixa pelo usuário/data (a mensagem de erro já informa os dois) → reabrir o caixa (ação própria, auditável) → só então a comanda fica editável → corrigir → finalizar a comanda de volta no mesmo caixa → fechar o caixa de novo.
- **Trinks**: mesmo princípio em granularidade mensal — "Fechamento Mensal" trava os valores a pagar por profissional; existe um botão explícito "reabrir mês" para ajustes retroativos, depois fecha de novo.
- Isso substitui a hipótese de um `order_correct` isolado: **falta uma peça de fundação que hoje não existe em nenhum lugar do schema — sessão de caixa (abertura/fechamento por período/turno)**. `cash_entries` hoje é só uma lista *append-only* sem fronteira de sessão (confirmado por grep no baseline — nenhuma coluna de sessão/período); não há como replicar "só edita se o caixa ainda está aberto" sem essa tabela nova. Isso é maior que uma RPC — é um novo objeto de domínio (ver risco novo no §7 abaixo).

**Entregáveis**: RPC `checkout_close` alterada (concluído); RPCs de lançamento e estorno de caixa (concluído); motivo obrigatório (`customer_cancellation`/`customer_default`) no payload de `order_refund` (concluído, ADR 0006); wiring backend Express (concluído); suporte no PWA para Comanda e Caixa (descontos, gorjeta, lançamento manual, estorno com motivo — concluído). `cash_sessions` e a reabertura de comanda por correção operacional **saem do escopo desta fase** (ver decisão 4 abaixo).
**Decisões em aberto — resolvidas em 2026-07-15 (usuário, após pesquisa registrada em ADR 0006)**:
- ~~(1) Gorjeta entra na base da comissão ou vai 100% para o profissional?~~ — **resolvido: 100% ao profissional, fora da base.** Nenhuma mudança de código necessária (comportamento já implícito na migration). Ver ADR 0006.
- (2) Classificação do profissional (CLT vs. autônomo-parceiro) — **resolvido: adiado.** Não modelar nesta fase; `order_refund` continua sem reverter comissão de ninguém (comportamento já adotado no ADR 0005), sem automação até uma fase futura decidir o schema de classificação.
- ~~(3) Motivo do estorno (inadimplência/desistência do cliente vs. correção operacional)~~ — **resolvido: dois fluxos distintos (void vs. refund), nunca a mesma RPC.** Correção operacional nunca usa `order_refund` (depende de `cash_sessions`, fora de escopo — ver decisão 4). `order_refund` passa a exigir motivo obrigatório (`customer_cancellation`/`customer_default`), materializado em `20260715120000_fase9_order_refund_reason.sql` e na PWA (`RefundModal.jsx`, sem valor default). Ver ADR 0006.
- ~~(4) `cash_sessions` entra na Fase 9 ou vira decisão de escopo própria?~~ — **resolvido: vira fase própria, separada.** Removido do escopo/entregáveis/gate de saída da Fase 9. **Numeração ainda não alocada** — pendente de nova entrada neste documento antes de qualquer código.
- (5) Reabertura de sessão de caixa exige papel/permissão própria e log auditável? — **adiado junto com a decisão 4**; será resolvido quando `cash_sessions` for alocada como fase própria, não nesta fase.

**Riscos**: Regressão no cálculo de `checkout_close`.
**Gate de saída [FECHADO em 2026-07-15]**: pgTAP da equação nova com testes negativos e de desconto maior que o subtotal, e de `order_refund` rejeitando motivo ausente/inválido (151/151 `PASS`); testes de integração do backend (208/208 `PASS`); frontend operando descontos, gorjetas e estornos (com motivo) na Comanda e lançamento manual no Caixa (75/75 `PASS`), verificado end-to-end via API real contra Supabase + backend locais.

### Fase 10 — Capacidades N:N profissional×serviço + Hardening do Agendamento [CONCLUÍDA]
**Escopo**: Tabela N:N (`professional_service_capabilities`) com `duration_override_minutes` (alimentando a janela GiST da agenda), `buffer_before_min`/`buffer_after_min` (achado de `PLANEJAMENTO_AGENDA_TRANSACIONAL.md §6`) e `price_override_cents`; PWA listando e filtrando agenda e catálogo por capacidades. **Escopo estendido (auditoria de agenda, 2026-07-15)**: três correções de hardening no módulo `appointments` — (a) `ends_at` calculado no servidor a partir da duração resolvida (hoje aceito livre do cliente — risco de segurança real, não feature); (b) guard de transição de status (hoje um `completed` pode ser movido de volta para `scheduled` — nenhuma FSM existe); (c) coluna `appointments.version` para lock otimista (hoje updates concorrentes não-sobrepostos em horário não são detectados).
**Dependências**: Ocorre depois da Fase 9 porque `price_override` altera a base sobre a qual o desconto/comissão incidem. Precisa ocorrer antes da Fase 12 (receita do profissional) e antes da Fase 14 (a Availability Engine consome `duration_override`/buffers desta tabela). Ordem trocável com a Fase 11. O hardening (a)-(c) foi absorvido aqui — domínio errado para a Fase 9 (financeira), pequeno demais para justificar mini-fase própria — em vez de uma Fase 10.5.
**Entregáveis**: Migration de capabilities (incl. colunas de buffer) — concluído; migration de hardening (`ends_at` server-side, guard de status, `version`) — concluído; backend CRUD — concluído; frontend com abas e filtros na Equipe — concluído (seção "Capacidades por Profissional" em `EquipePage.jsx`).
**Estado real (fechado em 2026-07-16)**: migration `20260715140000_fase10_capabilities.sql` cria a tabela com RLS completo (select aberto a qualquer membro ativo incl. `professional`, insert/update `owner/admin/manager`, delete `owner/admin`); `20260715140100_fase10_appointments_hardening.sql` adiciona `version` (lock otimista, coluna + trigger de incremento — o enforcement de `expected_version` no contrato de escrita fica para a Fase 16) e a FSM guard (`completed` imutável, nenhuma transição de saída permitida). Backend: módulo `professionalServiceCapabilities` novo (5 rotas, mesmo padrão de `professionalCommissions`); `appointments.service.js` ganhou `resolveDurationMinutes`/`computeEndsAt` — `ends_at` nunca mais é aceito do cliente (`400 unknown_fields` se enviado), sempre resolvido via cascata capability→serviço, recomputado em create/update quando `professional_id`/`service_id`/`starts_at` mudam. Frontend: `CapabilitiesTab.jsx`/`CapabilityModal.jsx` seguem o padrão real do projeto (`modal-overlay`/`form-error`, confirmação inline sem `window.confirm`, Modal chama a API diretamente). Testes: pgTAP 173/173 (151→173, novo `rls_professional_service_capabilities_test.sql` com 22 testes cobrindo RLS + FSM + lock otimista), backend 215/215 (208→215, 7 testes novos + testes de `appointments` pré-existentes atualizados para o novo contrato de `ends_at`), frontend 84/84 (75→84, 9 testes novos de `CapabilitiesTab`), `supabase db advisors` limpo, `npm run build` do frontend OK.
**Achados reais da sessão**: (1) bloqueio de porta 54322 por exclusão dinâmica do Windows/Hyper-V (mesmo already-known da Fase 9), contornado sem commit; (2) query pré-existente em `rpc_fase9_foundation_test.sql` sem filtro de `organization_id` (`select ... from orders where status='closed' order by created_at limit 1`) causou falso positivo de regressão ao rodar backend antes de pgTAP — não é bug da Fase 10, é ordem de execução errada localmente (CI já roda pgTAP primeiro); (3) `<form>` sem `noValidate` faz os atributos HTML5 `min`/`max` bloquearem `onSubmit` antes da validação JS rodar — corrigido no `CapabilityModal`, consistente com o padrão de validação 100% em JS do resto da PWA. Ver `docs/FASE_10_STATUS.md` para o relato completo.
**Decisões em aberto — resolvidas em 2026-07-16 após pesquisa própria (ver ADR 0008)**: as duas primeiras haviam sido fechadas na sessão de implementação sem pesquisa (violação da regra de ouro), corrigido retroativamente. Nome final da tabela: `professional_service_capabilities` (mantido, sem controvérsia). `price_override` em pacotes: **pesquisa em Zenoti confirma que o preço do pacote sempre vence o override individual do profissional** ("guests booking via the package will pay the standard price... even if the employee performs the service"); `checkout_close` (Fase 5.1) já não consulta capabilities para nenhum propósito — decisão fixa o contrato para quando o wiring de preço acontecer numa fase futura. Profissional sem vínculo: a citação original a `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md §10.3` era uma **conflação incorreta** — aquela seção é sobre `professional_working_hours_template` (jornada, Fase 15), não sobre capacidade de serviço (Fase 10). Pesquisa própria (Fresha, Cal.com, Calendly — nicho + fora do nicho) confirma o padrão oposto: **default-allow/opt-out**, não default-deny — sem capability, o profissional usa os valores padrão do serviço e pode ser agendado normalmente. Implementação já feita coincidia, por acidente, com o padrão correto; nenhum código mudou, só a justificativa documentada.
**Riscos**: Bloquear erroneamente um agendamento válido; mudar `ends_at` para ser sempre server-side quebra silenciosamente qualquer cliente de API que hoje envie duração própria — deve ser comunicado, não silencioso (ver `PLANEJAMENTO_AGENDA_TRANSACIONAL.md §15`) — **mitigado**: rejeição explícita com `400 unknown_fields`, não descarte silencioso.
**Gate de saída [FECHADO em 2026-07-16]**: pgTAP validando o booking (173/173); teste de override de capability mudando a duração/`ends_at` resolvido; red team de override negativo/zero (CHECK constraints + validação JS); teste de regressão confirmando que `ends_at` do cliente é ignorado; teste de guard de status (completed imutável). Verificação visual no browser não realizada (mesma restrição de política já documentada na Fase 9 — credencial de teste via automação); cobertura de testes automatizados (pgTAP contra RLS real, integração de backend contra Supabase Auth/DB local real, componentes de frontend com Testing Library) cobre o mesmo caminho.

### Fase 11 — Acesso da Equipe (Convite + RLS self-view)
**Escopo**: SMTP de produção (mailer default Supabase é rate-limited); Fluxo de convite (auth admin → membership → link `professionals.user_id` com UNIQUE garantido); Policies RLS na tabela `professional` focadas em self-view.
**Dependências**: Após a Fase 10 (policies nascem mais robustas). O redirect de callback exige teste real sob o base path do GitHub Pages para não perder o fragment `#access_token` via 404.html (Blind Spot).
**Entregáveis**: Endpoint de invite; SMTP; ajustes RLS; PWA com tela de convite.
**Decisões em aberto**: Qual provedor SMTP usar? Profissional pode enxergar comanda inteira ou apenas seus serviços (allowlist ou não)? Expiração do link de convite?
**Riscos**: Vazamento intra-org.
**Gate de saída**: Teste E2E de convite com e-mail REAL. Red team testando um vazamento de dados de profissionais diferentes na mesma organização.

### Fase 12 — Sessões de Caixa + Reabertura de Comanda (Void)
**Escopo**: Tabela nova `cash_sessions` (abertura/fechamento por período/turno com auditoria); coluna `session_id` em `cash_entries` para referenciar sessão; RPC nova `order_void` (distinta de `order_refund`, para correção operacional de erro de recepção); RPCs `cash_session_open`/`cash_session_close` (restritas a `owner`/`manager`); RLS que travam edição de comanda se sessão já fechou; PWA novo fluxo de reabertura dentro de Histórico de Caixa.
**Dependências**: Após Fase 9 (fundação de caixa já existe). Antes de Fase 13 (Comissões) — `cash_sessions` é o contêiner sobre o qual fronteiras de acumulado (ex.: mês) serão definidas na Fase 13. Pesquisa realizada em AppBarber, Trinks, Avec, Nex (padrão local convergente de bloqueio por sessão aberta) — ver ADR 0007.
**Entregáveis**: Migration de `cash_sessions` + RLS; alteração em `cash_entries` com FK; RPC `order_void` (distinta de `order_refund`); RPCs de gerenciamento de sessão; backend CRUD de sessão + integrações; PWA com reabertura controlada de comanda por sessão aberta.
**Decisões em aberto**: Qual o escopo mínimo de `closing_balance_cents` (calculado automaticamente ou preenchido manualmente)? `order_void` reverter comissão (recomendação: não, aguardar ADR 0005 e classificação do profissional)? Granularidade: por dia/turno/customizável (recomendação: por turno/dia, flexível por organização)?
**Riscos**: Bloquear erroneamente uma correção legítima se sessão foi fechada muito cedo. Calcular `closing_balance` incorretamente (reconhecimento: é um problema de auditoria, exige validação com dados reais).
**Gate de saída**: pgTAP validando restrição de `order_void` com sessão fechada; teste de transição de estado (abrir → editar → fechar); red team de abertura múltipla da mesma sessão (impossível); teste de E2E reabrindo comanda de sessão aberta vs. rejeitando de sessão fechada; auditoria de quem abriu/fechou com timestamps. Ver ADR 0007 para contexto de pesquisa.

### Fase 13 — Comissões Escalonadas + Política de Absorção de Desconto
**Escopo**: Tabela `commission_tiers` + flag na organização de política de desconto (`net_price_split`, `gross_price_salon_absorbs`, `deduct_after_commission`).
**Dependências**: Fase 9 (Desconto), Fase 10 (Preços Finais) e **Fase 12 (`cash_sessions` — fronteira de período)** devem estar estabilizadas. Por ser complexa, fica por último e maximiza o tempo de definição.
**Achado de pesquisa (ADR 0004)**: o Zenoti — benchmark citado no próprio ADR — não usa uma única flag por organização; tem granularidade por tipo de item (serviço: "Sale price before discount" vs. "Revenue"; produto/membership: opção separada "Sale price after discount" vs. "Revenue", com dedução adicional). A Fase 9 já hardcodou o equivalente a "Revenue" só para serviços, sem flag. Avaliar se a Fase 13 deve granularizar por tipo de item em vez de uma flag única por organização, alinhando com o padrão de mercado em vez de simplificar demais.
**Entregáveis**: Alterações finais em `checkout_close`; módulo CRUD de Tiers; flag na Org e no PWA.
**Decisões em aberto (Obrigatório resolver antes)**: Marginal vs Cliff (recomendado marginal para não re-calcular comissões antigas). Como dividir split de vendas cruzando o limiar? Timezone de fronteira de mês para Org. Concorrência: leitura com lock (`FOR UPDATE`) no faturamento. O override anula o tier ou o tier escala o override? Estorno altera a comissão acumulada de vendas futuras do mês (recomenda-se não retroagir, ver ADR 0005)? Flag única por organização ou granular por tipo de item (serviço vs. produto), seguindo o padrão Zenoti?
**Riscos**: Deadlocks em transações ou recálculo retroativo inválido de pagamentos efetuados.
**Gate de saída**: Testes de concorrência com dois checkouts batendo o limiar do tier ao mesmo tempo; pgTAP de fronteira mensal/timezone; red team em acumulo manipulado via estornos.

### Fase 14 — No-show FSM + Sinal + Mensageria nativa
**Escopo**: Tabelas de log de estado por cliente×org (`no_show_count`, limiares); Sinal como `deposit_credit` habilitado na RPC `checkout_close` e lançado manualmente no caixa via Pix. PWA envia template manual via Web Share API / `wa.me` sem uso de bot.
**Dependências**: Fase 9 obrigatória (Lançamentos manuais de caixa para sinal). Não depende das F10 a F13.
**Entregáveis**: Módulo Backend/Banco de máquina de estados para no-show; botão de Mensageria PWA nativo; check de impedimento em agendamento (cobrando depósito).
**Decisões em aberto**: Histórico antigo de faltas conta (backfill)? Cancelar status de no-show é idempotente? Políticas de retenção LGPD. Qual o valor do sinal (Fixo vs Percentual)?
**Riscos**: Bloqueio equivocado de clientes ou LGPD.
**Gate de saída**: pgTAP em todas arestas do State Machine; reentrada idempotente; Red team de crédito duplo de depósito; Nota LGPD no repositório.

### Fase 15 — Calendário Operacional & Availability Engine
**Escopo**: Timezone da organização (decisão ÚNICA compartilhada com a fronteira de mês da Fase 13 — não decidir duas vezes); `business_hours_template`/`professional_working_hours_template` (jornada semanal); `business_hours_exception`/`professional_working_hours_exception` (feriados, folgas, jornadas especiais); `query_resolve_effective_availability` (a Availability Engine — cálculo de horários livres sob demanda, sem materializar slots). Especificação completa em `docs/PLANEJAMENTO_CALENDARIO_OPERACIONAL.md`.
**Dependências**: Depois da Fase 10 (consome `duration_override_minutes`/buffers das capacidades). Antes da Fase 16 (motor transacional consome a disponibilidade calculada aqui) e da Fase 17 (waitlist precisa saber o que está livre).
**Entregáveis**: 4 tabelas novas + RLS + pgTAP; endpoint de resolução de disponibilidade (leitura); UI de configuração de horários (só depois dos contratos fechados).
**Decisões em aberto (ver documento completo §5)**: "Unidade" vira entidade própria ou `organization_id` continua sendo o nível único (recomendado: manter único, sem entidade nova, até haver evidência de multiunidade)? Profissional sem jornada cadastrada = indisponível por padrão ou herda o expediente da organização (recomendado: indisponível por padrão)? Change Sets (preview/apply/revert em lote) do briefing 5.1.1 — não recomendado para este porte; edição direta + auditoria cobre o mesmo resultado com menos complexidade.
**Riscos**: Fechar um dia (exceção de organização) sem antes consultar quais appointments existentes são afetados — a query de impacto deve existir antes de qualquer exceção ir para produção.
**Gate de saída**: pgTAP de todos os cenários do documento (§12: abrir domingo fechado, abrir feriado, fechar dia aberto, múltiplos intervalos, interseção vazia unidade-fechada×profissional-com-jornada, exceção duplicada rejeitada); teste de timezone.

### Fase 16 — Agenda Dinâmica Transacional
**Escopo**: Contrato de mutação `move-plan`/`move` (troca de horário, profissional, serviço), matriz de conflitos com códigos estruturados, auditoria append-only de mutações (`appointment_change_log`), UI de drag-and-drop consumindo a disponibilidade real da Fase 15 (fim da grade hardcoded de `dateUtils.js`). Especificação completa em `docs/PLANEJAMENTO_AGENDA_TRANSACIONAL.md`.
**Dependências**: Depois da Fase 15 (consome `query_resolve_effective_availability`) e do hardening da Fase 10 (`version`, guard de status, `ends_at` server-side já devem existir).
**Entregáveis**: Endpoints `move-plan`(preview, sem estado persistido)/`move`(aplicação, idempotente); tabela de auditoria; matriz de conflitos versionada; PWA com drag-and-drop.
**Decisões em aberto (ver documento completo §5)**: Contrato two-step com `planToken` persistido (proposta do briefing 5.1.1) ou variante sem estado, recalculada a cada preview (recomendado — escala de salão único não justifica o token com TTL/GC)? Adotar os 8 estados de agendamento do briefing (`HOLD`/`PENDING_PAYMENT`/`EXPIRED`) ou mapear sem adotar (recomendado: mapear — esses três dependem de portal público e pagamento online, Fase 17+, bloqueados hoje)?
**Riscos**: Mudança de contrato de `ends_at` (Fase 10) tem efeito observável em qualquer cliente de API existente — deve ser comunicada, não silenciosa.
**Gate de saída**: pgTAP/integração de todos os cenários do documento (§14: grade 10min×serviço 45min, `expected_version` divergente, `completed` imutável, troca de profissional recalcula tudo, duas requisições concorrentes só uma aplica).

## 5. Horizonte Reservado (Fases 17 a 19)
Estas fases estão explicitamente marcadas como "reservadas, sem spec" (anti-mock). Elas só receberão detalhamento quando a fase que as antecede cruzar seus gates de saída com sucesso.
- **Fase 17**: Lista de espera e anti-gap básico. (Depende da Fase 15 — precisa saber o que está livre para gerenciar espera).
- **Fase 18**: Portal do cliente e booking online. (Requer Red Team próprio na superfície anônima/pública).
- **Fase 19**: Memberships Mínimas de retenção. (Exigirá a revogação formal em ADR do não-objetivo do MVP antes de ser executada).

## 6. Explicitamente Bloqueado

Itens bloqueados exigem a criação de um **novo ADR** + alocação de Fase neste documento. O desbloqueio nunca ocorre de forma implícita.

| Item | Origem | Critério de Desbloqueio Baseado em Evidência |
|---|---|---|
| Kortex.ai / IA (D22) | ROADMAP | Decisão explícita do usuário; nunca por fase ou evolução. |
| Ledger Partidas Dobradas | FINANCEIRO §3.1 | Apenas se o Lançamento Manual (F9) falhar operacionalmente em volume. |
| Gateways Pagamento / Escrow | MVP TECNICO §11 | Apenas se o controle de recebimento via Pix/Manual mostrar atritos. |
| Carteiras de Cliente (Wallets) | ROADMAP | Depende integralmente da quebra de bloqueio do Ledger Partidas Dobradas. |
| Yield e Preço Dinâmico | ROADMAP | Depende da captação prévia de ocupação robusta (Pós-F17). |
| Fiscal, NF-e, Marketplace | MVP TECNICO §11 | Fora de escopo até revisão formal da arquitetura geral em ADR. |
| Kortex Autonomous Operations Engine / Automações (Master Briefing 5.1.1 §11-§12) | `docs/legacy/KORTEXOS_5_1_1_MASTER_BRIEFING_CANONICO.md` | O próprio briefing (§1.3) declara que não é autoridade de implementação. Nenhum item do Opportunity Engine, heatmaps, matching, Reliability Score ou automação progressiva é desbloqueado por este documento ter chegado — segue exigindo ADR + alocação de fase como qualquer outro item desta tabela. |

## 7. Riscos Transversais e Operação
- **Escala de pgTAP**: Cada tabela adicionada + novo Papel intra-org (`professional`) trará um aumento combinatorial na suíte. O orçamento da CI deve ser avaliado e splits da suite previstos para acelerar testes localmente.
- **Backup / Restore**: Dados vitais financeiros como sessões de caixa, sinal pago, comissões em tier e lançamentos manuais elevam os danos em caso de corrupção. As políticas de backup do tier local do Supabase e scripts de dump devem estar definidos antes das Fases 12, 13 e 14.
- **LGPD**:
  - Punições da máquina de estado do no-show representam perfis de consumo e penalidades comportamentais (PII); necessitam de fluxos de "exclusão de cliente".
  - O uso do Web Share e WhatsApp (`wa.me`) revela o número da recepcionista/clínica e o telefone do usuário; requer política limpa de opt-in.
  - Links de convites e emails gerados também tratam e geram registros auditáveis.
- **Timezone**: Sem as configurações de Fuso Horário fixadas em Org (America/Sao_Paulo vs UTC), a fronteira do "Final de Mês" do comissionamento (Fase 13) falhará em horários noturnos nos dias 31. **Decisão única**: a coluna `organizations.timezone` é compartilhada entre a Fase 13 (fronteira de mês) e a Fase 15 (jornada/expediente) — não decidir duas vezes em dois documentos.
- **Sessão de caixa (confirmado por concorrentes diretos — ADR 0007)**: `cash_entries` não tem fronteira de sessão/período — sem isso, não é possível replicar o padrão local (AppBarber/Trinks/Avec/Nex) de travar edição de comanda por caixa fechado. **Decisão alocada em 2026-07-15**: `cash_sessions` é Fase 12 (tabela nova + RPC `order_void` + RLS que trava edição por sessão aberta), formalizado em ADR 0007. Antes da Fase 12, correção de comanda por erro operacional não tem caminho no sistema.
- **Agenda — ausência total de fundação de disponibilidade (auditoria 2026-07-15)**: hoje a agenda só impede colisão de horário (exclusion constraint); não existe jornada, exceção, timezone, lock otimista, guard de status ou auditoria de mutação. `ends_at` é calculado no frontend e o backend aceita qualquer valor — risco de integridade real, não só lacuna de feature (ver Fase 10 estendida). Ver `PLANEJAMENTO_CALENDARIO_OPERACIONAL.md` e `PLANEJAMENTO_AGENDA_TRANSACIONAL.md`.

## 8. Fontes de Planejamento e ADRs

**Documentos Internos**
- `docs/PLANEJAMENTO_FINANCEIRO.md`
- `docs/PLANEJAMENTO_COMISSOES.md`
- `docs/PWA_PLANEJAMENTO.md`
- `docs/PLANEJAMENTO_ROADMAP_POS_MVP.md`
- `docs/PLANEJAMENTO_CALENDARIO_OPERACIONAL.md`
- `docs/PLANEJAMENTO_AGENDA_TRANSACIONAL.md`
- `docs/adr/0001-record-architecture-decisions.md`
- `docs/adr/0002-checkout-atomico-idempotente-server-side.md`
- `docs/adr/0003-comissoes-escalonadas.md`
- `docs/adr/0004-politica-absorcao-descontos.md`
- `docs/adr/0005-reversao-de-comissao-em-estornos.md`
- `docs/adr/0006-gorjeta-fora-da-comissao-e-motivo-do-estorno.md`
- `docs/adr/0007-cash-sessions-void-vs-refund.md`
- `docs/adr/0008-capacidade-profissional-default-allow-e-preco-de-pacote.md`

**Benchmarks Externos (Padrões da Indústria)**
- **Comissões e Absorção de Descontos:** Zenoti (Employee Commissions; [Configure Service Commissions based on a Percentage of Revenue](https://help.zenoti.com/en/articles/700184-configure-service-commissions-based-on-a-percentage-of-revenue); [Configure Product Commissions based on a Percentage of Sales Price](https://help.zenoti.com/en/articles/700228-configure-product-commissions-based-on-a-percentage-of-sales-price)), Vagaro (Payroll & Commission Setting), Phorest.
- **No-Show e Retenção:** SICUS, DaySmart, GlossGenius, Vagaro, Boulevard.
- **Acesso Nativo Mobile (Web API):** MDN Web Docs (Web Share API), Documentação Meta/WhatsApp (Click-to-chat `wa.me`).
- **Clawback de Comissão em Estornos (mercado global SaaS/afiliados):** [Everstage — Sales Commission Clawback Best Practices](https://www.everstage.com/sales-commission/sales-commission-clawback), [SalesCookie — Complete Guide to Sales Commission Clawbacks](https://blog.salescookie.com/2026/05/05/complete-guide-sales-commission-clawbacks/), [TinyAffiliate — Refunds and affiliate commissions clawback workflow](https://www.tinyaffiliate.com/blog/refunds-and-affiliate-commissions-clawback-workflow).
- **Legislação Trabalhista Brasileira (estorno de comissão):** [Planalto — Lei nº 13.352/2016 (Lei do Salão Parceiro)](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2016/lei/l13352.htm), [BNZ Advogados — A Lei do Salão Parceiro e Seus Elementos](https://www.bnz.com.br/bnz-em-foco/artigos/trabalhista/a-lei-do-salao-parceiro-e-seus-elementos), [Jusbrasil — Descontos de Comissão (jurisprudência)](https://www.jusbrasil.com.br/jurisprudencia/busca?q=descontos+de+comiss%C3%A3o), [ConJur — Contrato de parceria em salões de beleza é constitucional, diz STF](https://www.conjur.com.br/2021-out-28/contrato-parceria-saloes-beleza-constitucional-stf/).
- **Correção de Comanda Fechada / Void vs. Edit (POS geral):** Zenoti (Reopen a Closed Invoice, Manage Invoices), Vagaro (Reassign "Sold By" Employee after Checkout, Undo a Checked-Out Appointment), Square (Process a return, exchange, or unlinked refund), [Modern Treasury — Enforcing Immutability in your Double-Entry Ledger](https://www.moderntreasury.com/journal/enforcing-immutability-in-your-double-entry-ledger), [AMS Retail — How to Void a Return Transaction in a POS System](https://amsretail.com/feeds/blog/void-return-transaction-pos-system).
- **Reabertura de Comanda por Sessão de Caixa (concorrentes diretos do nicho, Brasil):** [AppBarber/AppBeleza — Estou tentando reabrir uma comanda de um caixa fechado, como proceder?](https://appbarber-appbeleza.zendesk.com/hc/pt-br/articles/360001571051-Estou-tentando-reabrir-uma-comanda-de-um-caixa-fechado-como-proceder), [AppBarber/AppBeleza — Como funciona o Caixa?](https://appbarber-appbeleza.zendesk.com/hc/pt-br/articles/360002607332-Como-funciona-o-Caixa), [Trinks — Fechamento Mensal](https://ajuda.trinks.com/fechamento-mensal), [Avec — Como reabrir um caixa?](http://ajuda.avecbrasil.com.br/support/solutions/articles/17000092938-como-reabrir-um-caixa-).
