# PLANEJAMENTO_EXECUCAO_UNIFICADO

Status: CANÔNICO — única fonte de numeração de fases a partir da Fase 8
Fase atual: 8 | Última atualização: 2026-07-13 | Supersede sequenciamentos de:
PLANEJAMENTO_FINANCEIRO §4-5, PLANEJAMENTO_COMISSOES §8, PLANEJAMENTO_ROADMAP_POS_MVP §7

## 1. Objetivo e Regra de Canonicidade

- Este documento **CONTINUA** a numeração de `KORTEX_MVP_TECNICO.md §10` (Fases 1–7, encerradas).
- **Regra de governança**: nenhum outro documento pode criar numeração própria de "Fase" ou "Camada" executável. Documentos de planejamento apenas propõem; a fase de execução é alocada e registrada exclusivamente aqui.
- **"Propõe, não decide sozinho"**: toda fase possui um bloco "Decisões em aberto" que o usuário resolve ANTES do início da fase (não durante o seu desenvolvimento).

## 2. Estado Verificado

Estado atual:
- **Migrations**: 4 (baseline, permissões, grupos/pacotes, comissões).
- **RPCs**: `checkout_close`, `inventory_adjust`, `create_organization`, `membership_set`.
- **Módulos Backend**: 16.
- **Módulos PWA**: 8.
- **Testes**: 123 pgTAP + ~195 backend + 69 frontend.
- **CI**: Fase 7 rodou e passou.
- **Render**: `BLOQUEADO` (Fase 7 fechou como "PASS COM RISCO ACEITO", backend `kortex-api` com erro de timeout/503).

**Tabela de Rastreabilidade**

| Origem da Demanda | Fase Alocada |
|---|---|
| `PLANEJAMENTO_FINANCEIRO` Camada 1 | Fase 9 |
| `PLANEJAMENTO_COMISSOES` §8.3 | Fase 10 |
| `PLANEJAMENTO_COMISSOES` §8.4 | Fase 11 |
| `PLANEJAMENTO_COMISSOES` §8.1+8.2 | Fase 12 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` §5/§6 | Fase 13 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 2 (restante) | Fase 14–15 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 3 | Fase 16 |
| `PLANEJAMENTO_ROADMAP_POS_MVP` Camada 4 | Bloqueado (§6) |

## 3. Invariantes Transversais e Arquitetura-alvo do Checkout

Esta é a equação-alvo de reconciliação que será definida **UMA única vez** e implementada em fatias pelas próximas fases.
`sum(payments) == subtotal - discount_total + tip_total - deposit_credit`

(Hoje `discount` = `tip` = `deposit` = 0 forçados. A Fase 9 ativará discount/tip e a Fase 13 ativará deposit_credit; contudo, a equação e os checks nascerão completos já na Fase 9).

- **Contrato de payload extensível** na `checkout_close` com campos opcionais, valores default e **versionamento do hash de idempotência** (para evitar falhas no retry cruzando o deploy de novos campos).
- **Invariantes permanentes**: 
  - Todo o dinheiro usa centavos inteiros.
  - Toda RPC que escreve dinheiro requer `private.idempotency_keys`.
  - A comissão é sempre congelada no checkout (não retroage).
  - Toda tabela nova nasce com a matriz RLS completa e testes pgTAP por papel.

## 4. Fases de Execução (Fase 8 a 13)

### Fase 8 — Consolidação documental e fechamento real do MVP
**Escopo**: merge (fast-forward) da branch de docs; criação deste documento; higiene documental de todos os arquivos; fechamento da pendência Render; parametrização de `deploy-pages.yml`.
**Dependências**: Nenhuma técnica — é o pré-requisito de TODAS as outras. (Uma divergência de documentação impede o sequenciamento correto no main).
**Entregáveis**: Higiene nos docs concluída (ADRs ajustados, INDEX renomeado, supersedes adicionados).
**Decisões em aberto**: (a) `/health` do Render: corrigir agora ou re-escopar formalmente o deploy do backend? (~~b) fast-forward vs cherry-pick~~ — resolvido: merge fast-forward aplicado; ~~c) nome do agrupamento no INDEX~~ — resolvido: "Trilhas A–D").
**Riscos**: Manter a pendência de devops silenciada.
**Gate de saída**: main = única verdade; CI verde; evidência real do /health 200 em produção OU decisão registrada de re-escopo documentado. INDEX sem colisão de numeração.

### Fase 9 — Fundação Financeira (Camada 1)
**Escopo**: Desconto real em `checkout_close` (fim do `discount_cents=0`); regra de distribuição do desconto entre itens (pré/pós expansão de pacote); gorjeta; RPC de lançamento manual de caixa (`income`/`expense`/`refund`) com idempotência; estorno com reversão de comissão. Nasce aqui a equação-alvo do §3, prevendo já o `deposit_credit`.
**Dependências**: É a inversão de dependência central. A política de absorção de desconto da Fase 12 é inútil antes do desconto existir. O sinal de no-show da Fase 13 precisa de lançamento manual no caixa e os tiers da Fase 12 precisam da base definida.
**Entregáveis**: RPC `checkout_close` alterada; RPCs de lançamento e estorno de caixa; Suporte no PWA para Comanda e Caixa.
**Decisões em aberto**: A gorjeta entra na base da comissão ou vai 100% para o profissional (recomendado: 100% profissional)? Estorno devolve o estoque? Desconto é no item ou só no pedido?
**Riscos**: Regressão no cálculo de `checkout_close`.
**Gate de saída**: pgTAP da equação nova com testes negativos e de desconto maior que o subtotal; testes de integração do backend; frontend operando descontos, gorjetas e estornos no Caixa.

### Fase 10 — Capacidades N:N profissional×serviço
**Escopo**: Tabela N:N (`professional_service_capabilities`) com `duration_override_minutes` (alimentando a janela GiST da agenda) e `price_override_cents`; PWA listando e filtrando agenda e catálogo por capacidades.
**Dependências**: Ocorre depois da Fase 9 porque `price_override` altera a base sobre a qual o desconto/comissão incidem. Precisa ocorrer antes da Fase 12, pois a receita do profissional dependerá desses preços. Ordem trocável com a Fase 11 (sem dependência dura, mas recomendada por nascer RLS completo para as capacidades do profissional).
**Entregáveis**: Migration de capabilities; backend CRUD para gerenciar a tabela; frontend com abas e filtros na Equipe.
**Decisões em aberto**: Nome final da tabela? `price_override` aplica em pacotes ou só avulso? Profissional sem vínculo pode tudo ou nada?
**Riscos**: Bloquear erroneamente um agendamento válido.
**Gate de saída**: pgTAP validando o booking; teste de peso de pacote com override; red team de override negativo/zero.

### Fase 11 — Acesso da Equipe (Convite + RLS self-view)
**Escopo**: SMTP de produção (mailer default Supabase é rate-limited); Fluxo de convite (auth admin → membership → link `professionals.user_id` com UNIQUE garantido); Policies RLS na tabela `professional` focadas em self-view.
**Dependências**: Após a Fase 10 (policies nascem mais robustas). O redirect de callback exige teste real sob o base path do GitHub Pages para não perder o fragment `#access_token` via 404.html (Blind Spot).
**Entregáveis**: Endpoint de invite; SMTP; ajustes RLS; PWA com tela de convite.
**Decisões em aberto**: Qual provedor SMTP usar? Profissional pode enxergar comanda inteira ou apenas seus serviços (allowlist ou não)? Expiração do link de convite?
**Riscos**: Vazamento intra-org.
**Gate de saída**: Teste E2E de convite com e-mail REAL. Red team testando um vazamento de dados de profissionais diferentes na mesma organização.

### Fase 12 — Comissões Escalonadas + Política de Absorção de Desconto
**Escopo**: Tabela `commission_tiers` + flag na organização de política de desconto (`net_price_split`, `gross_price_salon_absorbs`, `deduct_after_commission`).
**Dependências**: Fase 9 (Desconto) e Fase 10 (Preços Finais) devem estar estabilizadas. Por ser complexa, fica por último e maximiza o tempo de definição.
**Entregáveis**: Alterações finais em `checkout_close`; módulo CRUD de Tiers; flag na Org e no PWA.
**Decisões em aberto (Obrigatório resolver antes)**: Marginal vs Cliff (recomendado marginal para não re-calcular comissões antigas). Como dividir split de vendas cruzando o limiar? Timezone de fronteira de mês para Org. Concorrência: leitura com lock (`FOR UPDATE`) no faturamento. O override anula o tier ou o tier escala o override? Estorno altera a comissão acumulada de vendas futuras do mês (recomenda-se não retroagir)?
**Riscos**: Deadlocks em transações ou recálculo retroativo inválido de pagamentos efetuados.
**Gate de saída**: Testes de concorrência com dois checkouts batendo o limiar do tier ao mesmo tempo; pgTAP de fronteira mensal/timezone; red team em acumulo manipulado via estornos.

### Fase 13 — No-show FSM + Sinal + Mensageria nativa
**Escopo**: Tabelas de log de estado por cliente×org (`no_show_count`, limiares); Sinal como `deposit_credit` habilitado na RPC `checkout_close` e lançado manualmente no caixa via Pix. PWA envia template manual via Web Share API / `wa.me` sem uso de bot.
**Dependências**: Fase 9 obrigatória (Lançamentos manuais de caixa para sinal). Não depende das F10 a F12.
**Entregáveis**: Módulo Backend/Banco de máquina de estados para no-show; botão de Mensageria PWA nativo; check de impedimento em agendamento (cobrando depósito).
**Decisões em aberto**: Histórico antigo de faltas conta (backfill)? Cancelar status de no-show é idempotente? Políticas de retenção LGPD. Qual o valor do sinal (Fixo vs Percentual)?
**Riscos**: Bloqueio equivocado de clientes ou LGPD.
**Gate de saída**: pgTAP em todas arestas do State Machine; reentrada idempotente; Red team de crédito duplo de depósito; Nota LGPD no repositório.

## 5. Horizonte Reservado (Fases 14 a 16)
Estas fases estão explicitamente marcadas como "reservadas, sem spec" (anti-mock). Elas só receberão detalhamento quando a fase que as antecede cruzar seus gates de saída com sucesso.
- **Fase 14**: Lista de espera e anti-gap básico.
- **Fase 15**: Portal do cliente e booking online. (Requer Red Team próprio na superfície anônima/pública).
- **Fase 16**: Memberships Mínimas de retenção. (Exigirá a revogação formal em ADR do não-objetivo do MVP antes de ser executada).

## 6. Explicitamente Bloqueado

Itens bloqueados exigem a criação de um **novo ADR** + alocação de Fase neste documento. O desbloqueio nunca ocorre de forma implícita.

| Item | Origem | Critério de Desbloqueio Baseado em Evidência |
|---|---|---|
| Kortex.ai / IA (D22) | ROADMAP | Decisão explícita do usuário; nunca por fase ou evolução. |
| Ledger Partidas Dobradas | FINANCEIRO §3.1 | Apenas se o Lançamento Manual (F9) falhar operacionalmente em volume. |
| Gateways Pagamento / Escrow | MVP TECNICO §11 | Apenas se o controle de recebimento via Pix/Manual mostrar atritos. |
| Carteiras de Cliente (Wallets) | ROADMAP | Depende integralmente da quebra de bloqueio do Ledger Partidas Dobradas. |
| Yield e Preço Dinâmico | ROADMAP | Depende da captação prévia de ocupação robusta (Pós-F14). |
| Fiscal, NF-e, Marketplace | MVP TECNICO §11 | Fora de escopo até revisão formal da arquitetura geral em ADR. |

## 7. Riscos Transversais e Operação
- **Escala de pgTAP**: Cada tabela adicionada + novo Papel intra-org (`professional`) trará um aumento combinatorial na suíte. O orçamento da CI deve ser avaliado e splits da suite previstos para acelerar testes localmente.
- **Backup / Restore**: Dados vitais financeiros como sinal pago, comissões em tier e caixa manual elevam os danos em caso de corrupção. As políticas de backup do tier local do Supabase e scripts de dump devem estar definidos antes das Fases 12 e 13.
- **LGPD**:
  - Punições da máquina de estado do no-show representam perfis de consumo e penalidades comportamentais (PII); necessitam de fluxos de "exclusão de cliente".
  - O uso do Web Share e WhatsApp (`wa.me`) revela o número da recepcionista/clínica e o telefone do usuário; requer política limpa de opt-in.
  - Links de convites e emails gerados também tratam e geram registros auditáveis.
- **Timezone**: Sem as configurações de Fuso Horário fixadas em Org (America/Sao_Paulo vs UTC), a fronteira do "Final de Mês" do comissionamento (Fase 12) falhará em horários noturnos nos dias 31.

## 8. Fontes de Planejamento e ADRs

**Documentos Internos**
- `docs/PLANEJAMENTO_FINANCEIRO.md`
- `docs/PLANEJAMENTO_COMISSOES.md`
- `docs/PWA_PLANEJAMENTO.md`
- `docs/PLANEJAMENTO_ROADMAP_POS_MVP.md`
- `docs/adr/0001-record-architecture-decisions.md`
- `docs/adr/0002-checkout-atomico-idempotente-server-side.md`
- `docs/adr/0003-comissoes-escalonadas.md`
- `docs/adr/0004-politica-absorcao-descontos.md`

**Benchmarks Externos (Padrões da Indústria)**
- **Comissões e Absorção de Descontos:** Zenoti (Employee Commissions), Vagaro (Payroll & Commission Setting), Phorest.
- **No-Show e Retenção:** SICUS, DaySmart, GlossGenius, Vagaro, Boulevard.
- **Acesso Nativo Mobile (Web API):** MDN Web Docs (Web Share API), Documentação Meta/WhatsApp (Click-to-chat `wa.me`).
