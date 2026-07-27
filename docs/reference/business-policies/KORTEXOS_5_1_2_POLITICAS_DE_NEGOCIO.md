# PARTE III — CONFIGURAÇÃO, ONBOARDING, COMANDA, GORJETA E NÍVEIS

## 0. Registro de decisões do Platform Owner

As decisões DEC-01 a DEC-18, com texto completo, rationale e histórico de supersessão, vivem no [Decision Log](../../architecture/governance/KORTEXOS_5_1_2_DECISION_LOG.md#seção-1--registro-dec-01-a-dec-18-platform-owner-2026-07-19) — arquivo companion, nunca editado.

As regras VIGENTES resultantes dessas decisões estão especificadas nas seções 1 a 6 abaixo; cada uma cita o(s) DEC(s) que a fundamenta(m).

## 1. Business Configuration & Policy Layer (evolução de D02)

### 1.1 Nome canônico

**Business Configuration & Policy Layer — Camada de Configuração e Políticas do Negócio.**
Interface administrativa: **Business Settings / Configurações do Negócio.**

D02 deixa de se chamar "Business Setup & Policy Hub" e passa a este nome. RENOMEAR, não recriar.

### 1.2 Definição

Centraliza os dados cadastrais, configurações globais, políticas operacionais e padrões herdáveis da empresa e de suas unidades, servindo como fonte canônica para os demais domínios do sistema.

### 1.3 O que pertence à camada

| Grupo | Conteúdo |
|---|---|
| Identidade | Dados cadastrais, CNPJ, identidade comercial, identidade visual |
| Estrutura | Unidades, endereços, fusos horários |
| Regional | Moeda, idioma, configurações regionais |
| Calendário | Horários operacionais padrão (ver seção 2 — Calendar Policy) |
| Políticas | Cancelamento, atraso, no-show, depósito, fiado, régua progressiva |
| Agendamento | Regras gerais: antecedência, janela de booking, buffers default |
| Padrões financeiros | Padrões de preço, comissão, duração, absorção de taxa |
| Atendimento | Canais habilitados, configurações de atendimento |
| Plataforma | Preferências globais, feature flags governadas |
| Herança | Valores padrão herdados pelas unidades |

### 1.4 O que NÃO pertence à camada

```text
Não calcula disponibilidade (Availability Resolver, D07).
Não cria appointments (D08).
Não calcula comissão ou pagamento (D17/D13).
Não controla ledger (D15).
Não executa campanhas (D21/Automation Control Plane).
Não armazena regra específica de um cliente (D05/D24).
Não substitui os domínios especializados: fornece políticas; cada domínio valida e executa.
```

### 1.5 Hierarquia canônica de herança

```text
Sistema (defaults do KortexOS™)
→ Empresa (tenant): padrão global
→ Unidade: herda a empresa; aplica overrides autorizados
→ Profissional: apenas para domínios delegados (calendário próprio, nível, overrides de serviço)
```

### 1.6 Semântica de herança — regra central

| Regra | Definição | Status |
|---|---|---|
| Herdar ≠ copiar | Campo não configurado na unidade é um PONTEIRO para o nível acima. Mudança na empresa propaga automaticamente a todas as unidades que herdam | CRÍTICO |
| Override congela | Override na unidade congela o campo até ação explícita "restaurar herança" | CRÍTICO |
| Override autorizado por campo | Cada política declara `override_permitido`: sim / não / com aprovação (Action Request). Padrão validado por mercado: plataformas enterprise listam explicitamente quais configurações de unidade podem sobrepor a organização | CRÍTICO |
| Resolução backend-only | O domínio consumidor consulta a política EFETIVA resolvida pelo backend. Frontend nunca resolve herança | CRÍTICO |
| Vigência | Políticas mudam por vigência; mudança não retroage sobre fatos consumados | CRÍTICO |
| Auditoria | Toda mudança registra autor, data, escopo, valor anterior | CRÍTICO |

Exemplo canônico: Empresa define cancelamento até 24 h. Unidade A não configura → herda 24 h e acompanha mudanças futuras da empresa. Unidade B faz override para 12 h → congela em 12 h até restaurar herança.

### 1.7 Proibições

```text
Segunda fonte de configuração é proibida (inclusive onboarding — seção 3).
Configuração duplicada por cópia é proibida.
Override sem autorização declarada no campo é proibido.
Feature flag alterando verdade financeira sem gate é proibido.
```

---

## 2. Calendar Policy & Availability Layer (evolução de D02 + D05)

### 2.1 Nome canônico

**Calendar Policy & Availability Layer — Camada de Políticas de Calendário e Disponibilidade.**

```text
Esta camada mantém POLÍTICAS de calendário.
Quem calcula horários reserváveis é o Availability Resolver, dentro do D07.
Chamar esta camada de "Calendar Engine" é proibido — ela não calcula nada.
```

### 2.2 Objetos de política

| Objeto | Escopo | Conteúdo |
|---|---|---|
| Horário padrão | Unidade | Grade semanal (abertura/fechamento por dia) |
| Turnos | Profissional | Grade semanal de trabalho, pausas, intervalos |
| Feriados | Empresa/Unidade | Nacional, estadual, municipal, custom; com flag "unidade abre?" |
| Aberturas excepcionais | Unidade | Dia/horário fora do padrão (ex.: véspera de festa) |
| Fechamentos excepcionais | Unidade | Reforma, evento, força maior |
| Folgas e férias | Profissional | Períodos de indisponibilidade |
| Bloqueios pontuais | Profissional/Recurso | Trecho do dia indisponível |
| Exceções pontuais | Qualquer | Sobrepõem tudo, com autor e motivo |

### 2.3 Precedência canônica de resolução

```text
1. Exceção pontual autorizada
2. Fechamento excepcional / feriado sem abertura
3. Abertura excepcional
4. Folga / férias do profissional
5. Turno do profissional
6. Horário padrão da unidade
7. Padrão herdado da empresa
```

### 2.4 Regras e invariantes

| Regra | Status |
|---|---|
| Turno de staff ⊆ horário da unidade. Trabalho fora do horário exige abertura excepcional autorizada e ativa o acréscimo de conveniência (seção 13.3 do Master) | CRÍTICO |
| Feriado com abertura opcional: a unidade decide; acréscimo configurável conforme yield | REAL |
| Mudança de política NÃO altera appointments confirmados: gera fila de conflitos para resolução humana via Command; remarcação em massa exige Action Request | CRÍTICO |
| Timezone é propriedade da unidade; todo cálculo de calendário resolve no timezone da unidade | CRÍTICO |
| Availability Resolver (D07) consome: política de calendário resolvida + appointments + locks + holds + yield → produz slots. A camada de política nunca produz slot | CRÍTICO |
| Política de calendário versionada com vigência; histórico reconstruível | CRÍTICO |

---

## 3. Business Onboarding Workflow (evolução de D03)

### 3.1 Nome e princípio canônico

**Business Onboarding Workflow — Fluxo de Onboarding do Negócio.**

```text
Onboarding coleta e valida.
A Business Configuration & Policy Layer governa e persiste.
Onboarding → Commands → Configuration Layer → domínios consomem.
Onboarding NÃO é uma segunda fonte de configuração
nem uma camada independente de regras.
```

### 3.2 Etapas canônicas, dependências e critérios de conclusão

| # | Etapa | Depende de | Critério de conclusão |
|---:|---|---|---|
| 1 | Dados cadastrais da empresa | — | CNPJ/razão social/contato validados |
| 2 | Primeira unidade | 1 | Endereço + timezone definidos |
| 3 | Regional: moeda, idioma | 2 | Persistido na Configuration Layer |
| 4 | Horários padrão | 2 | Grade semanal completa (Calendar Policy) |
| 5 | Profissionais iniciais | 2 | ≥1 staff com vínculo, role e nível |
| 6 | Serviços e grupos | 5 | ≥1 serviço com duração, preço e comissão default |
| 7 | Políticas básicas | 2 | Cancelamento, no-show e depósito definidos (defaults sugeridos, aceitos ou editados) |
| 8 | Meios de pagamento | 2 | ≥1 forma completa: tipo, taxa, prazo, conta, absorção |
| 9 | Identidade visual | 1 | Logo/cores (não bloqueia ativação) |
| 10 | Usuários e permissões | 5 | Dono + roles iniciais confirmados |

### 3.3 Readiness e gates de ativação

| Ativação | Exige |
|---|---|
| Agenda interna | Etapas 4, 5, 6 |
| Checkout | Etapa 8 completa (forma sem taxa/prazo/conta/absorção não ativa checkout) |
| Booking público | Agenda interna + política de cancelamento/no-show + visibilidade de serviços |
| Campanhas (KortexLink) | Consentimento configurado; nunca no onboarding |

Readiness score = % de etapas concluídas + estado dos gates de ativação. Exibido no cockpit até 100%.

### 3.4 Regras e invariantes

| Regra | Status |
|---|---|
| Onboarding é retomável e idempotente; reexecutar uma etapa não duplica registro | CRÍTICO |
| Templates por segmento (barbearia, salão, estética) aceleram catálogo; nada é criado sem confirmação explícita | REAL |
| Estados: `not_started → in_progress → completed → closed`. Após `closed`, o fluxo se encerra definitivamente | CRÍTICO |
| Alterações posteriores acontecem nas telas administrativas (Business Settings), usando OS MESMOS contratos backend do onboarding — write-path único | CRÍTICO |
| Onboarding não grava em storage próprio, não mantém rascunho paralelo de configuração | CRÍTICO |

### 3.5 Texto canônico para o Blueprint

> Business Configuration & Policy Layer — fonte canônica dos dados cadastrais, configurações globais, políticas operacionais e padrões herdáveis da empresa e de suas unidades. O Business Onboarding Workflow coleta e valida a configuração inicial, mas toda persistência e alteração posterior ocorre pelos contratos canônicos dessa camada.

---

## 4. Comanda Lifecycle & Reopen (evolução de D12 + D14 + D15) — DEC-03

### 4.1 Estados canônicos da comanda

```text
aberta → em_atendimento → fechada
fechada → reaberta → refechada
qualquer estado antes de fechada → cancelada
Nenhum estado é destrutivo. Nada é apagado.
```

### 4.2 Princípio: reabrir não é editar o passado

| Regra | Definição | Status |
|---|---|---|
| Versões, não edição | Fechamento v1 permanece imutável. Reabertura cria v2 vinculada à v1. O ledger recebe reversão da v1 + lançamentos da v2 | CRÍTICO |
| Cascata completa de reversão | Reabrir reverte automaticamente: comissão, split de gorjeta, consumo de benefício (devolve sessão/quota/crédito), baixa de estoque e alocação de pagamento | CRÍTICO |
| Delta de pagamento | Novo total > pago → cobra diferença. Novo total < pago → devolve pela mesma forma ou credita wallet, conforme política | CRÍTICO |
| Motivo obrigatório | Reabertura registra motivo, autor e diff v1→v2 | CRÍTICO |
| Idempotência | Reabrir e refechar exigem `idempotency_key` como toda mutação financeira | CRÍTICO |

### 4.3 Janela de reabertura e travas financeiras

Padrão validado por mercado: plataformas enterprise permitem editar fatura pós-fechamento apenas com permissão explícita e bloqueiam quando a fatura está sob trava financeira.

| Momento | Quem pode | Mecanismo |
|---|---|---|
| Antes do fechamento de caixa do dia | Gerente ou dono | Reabertura direta com motivo |
| Após fechamento de caixa, antes do payout/fiscal | Dono | Action Request obrigatório |
| Após payout do staff, liquidação do PSP ou emissão fiscal | Ninguém reabre | **Financial lock.** Correção só por estorno/lançamento corretivo (fluxo de estorno do Master 7.3) |

### 4.4 Estorno vs. reabertura — fronteira canônica

```text
Estorno: desfaz o efeito financeiro de item ou venda. A comanda permanece fechada.
Reabertura: corrige a COMPOSIÇÃO da comanda (itens, profissionais, formas, gorjeta)
preservando vínculo, histórico e ledger por versão.
Reabertura após financial lock é proibida — vira estorno + nova venda.
```

### 4.5 Edição plena de comanda e modal de item — DEC-11 e DEC-12

Realidade operacional obrigatória: a comanda é um documento vivo até as travas da seção 4.3. Clicar em qualquer item abre o modal canônico de edição com todas as alterações possíveis.

| Alteração no modal do item | Governança |
|---|---|
| Valor unitário | Editável por permissão; delta contra preço resolvido registra como desconto/acréscimo de item com motivo; Negative Guard simula margem |
| Quantidade | Editável; recalcula estoque/consumo técnico |
| Profissional executor (e assistente) | Editável; recalcula comissão e split de gorjeta |
| Comissão (% ou valor) do item | Editável conforme alçada da persona (padrão: dono/gerente); motivo + trilha obrigatórios; fora da alçada → Action Request; comissão negativa mascarada segue proibida |
| Desconto do item | Editável em **R$ ou %** (DEC-16), dentro da política; fora dela → Action Request |
| Cortesia | Liga/desliga conforme política; comissão da cortesia definida em política, nunca implícita |
| Associar/desassociar benefício (pacote, plano, corporativo, parceiro) | Sempre disponível; consumo/devolução de obrigação via backend |
| Identificador externo (token/fidelidade) | Editável; sem efeito financeiro direto |
| Excluir item | Permitido até fechamento; após fechamento, só via reabertura (v2) |

| Regra estrutural | Status |
|---|---|
| Toda edição de item é evento auditado (autor, antes/depois, motivo quando exigido) | CRÍTICO |
| Duas semânticas de valor editável (DEC-13), nunca misturadas: | — |
| (a) VALOR DO ITEM (modal): reprecificação — muda o valor devido, recalcula comissão, desconto/acréscimo com motivo, Negative Guard simula margem | CRÍTICO |
| (b) VALOR COBRADO na comanda ≠ valor devido: a diferença NÃO reprecifica itens — cobrado a menor vira débito autorizado do cliente (fiado governado: Negative Guard + staff liquidado pelo devido, Master 7.3) e cobrado a maior vira crédito de wallet com origem "pagamento a maior/troco" | CRÍTICO |
| Comissão calcula sempre sobre o valor DEVIDO dos itens; divergência de cobrança jamais altera base de comissão | CRÍTICO |
| Comanda aberta/reaberta edita livre dentro das permissões; comanda sob trava financeira (4.3) não edita | CRÍTICO |
| Frontend exibe o modal; todo recálculo (comissão, split, benefício, estoque, totais) é backend | CRÍTICO |

### 4.6 Gates impactados

Gate 10 (Checkout Integrity), 11 (Ledger Balance), 12 (Payment Allocation), 14 (Commission Accuracy) e 18 (Cash Register Integrity) ganham cenários de reabertura: reabrir → editar → refechar deve fechar soma zero no ledger, recompor estoque, recompor benefício e recalcular comissão/gorjeta sem resíduo.

---

## 5. Tip Engine — gorjeta canônica (evolução de D12 + D17) — DEC-01 e DEC-02

### 5.1 Absorção de taxa (DEC-01)

```text
A gorjeta segue o MESMO modelo de absorção de taxa da forma de pagamento usada:
Bruto Salão, Dividido ou Bruto Staff — conforme cadastro da forma (Parte II, seção 3.3)
e contrato do profissional.
```

Tip isolation reinterpretado sem mentira contábil:

| Regra | Status |
|---|---|
| Gorjeta nunca vira receita do salão nem base de comissão | CRÍTICO (inalterado) |
| "100% para o destinatário" = 100% do valor líquido conforme o modelo de absorção da forma | CRÍTICO |
| Extrato do staff mostra: gorjeta bruta, taxa aplicada, modelo de absorção, líquido | CRÍTICO |
| Gorjeta em dinheiro não sofre taxa | REAL |
| Lançamento de gorjeta aceita **R$ ou %** (DEC-16); percentual calcula sobre o valor dos serviços da comanda (base igual à do split, seção 5.2); backend resolve e persiste o valor absoluto antes de rodar o split | CRÍTICO |

### 5.2 Split multi-profissional (DEC-02)

Comanda fechada com múltiplos serviços, produtos e profissionais:

```text
peso(profissional_i) = Σ valor_serviços_i  ×  fator_tempo_i (opcional)
gorjeta_i = gorjeta_total × peso_i / Σ pesos
```

| Regra | Definição | Status |
|---|---|---|
| Default canônico | Rateio proporcional ao VALOR dos serviços de cada profissional. Prática dominante de mercado (split automático por preço do serviço) | CRÍTICO |
| Fator tempo | Política do tenant pode ponderar por tempo de execução (puro ou híbrido valor×tempo) — cobre serviços de valor próximo e duração muito diferente | REAL, configurável |
| Split manual | Recepção/cliente pode direcionar valores específicos por profissional no checkout (custom split) | REAL |
| Produtos fora da base | Produtos não entram na base de rateio de gorjeta; gorjeta é sobre serviço | CRÍTICO |
| Assistente | Percentual do assistente, quando existir, sai declarado na política, nunca implícito | REAL |
| Arredondamento | Centavos residuais vão ao profissional de maior peso; soma dos splits = gorjeta total, sempre | CRÍTICO |
| Reabertura | Reabrir a comanda recalcula o split integralmente na v2 | CRÍTICO |

---

## 6. Staff Levels & Pricing Resolution (evolução de D05 + D06 + D17) — DEC-04

### 6.1 Cadastro de níveis

| Campo | Regra |
|---|---|
| Níveis por tenant | Nome e ordem livres (ex.: Aprendiz → Barbeiro → Sênior → Master) |
| Nível do profissional | Obrigatório; com vigência (promoção não retroage) |
| Multiplicador ou tabela por nível | Nível pode definir preço/duração/comissão por serviço |

### 6.2 Cascata canônica de resolução (preço, tempo e comissão)

```text
1. Override profissional × serviço   (preço, tempo, valor de comissão)
2. Tabela nível × serviço
3. Serviço base
Yield (off-peak, premium window, conveniência) multiplica SOBRE o valor resolvido.
```

| Regra | Status |
|---|---|
| Os três eixos do override são independentes: pode haver override só de tempo, só de preço ou só de comissão | CRÍTICO |
| Booking com profissional escolhido mostra o preço resolvido daquele profissional; sem profissional, exibe "a partir de" (menor preço resolvido entre habilitados) | CRÍTICO |
| Preço/tempo resolvidos travam no appointment confirmado; promoção de nível posterior não reprecifica | CRÍTICO |
| Comissão calcula sobre o preço efetivamente cobrado (resolvido + yield + rateios) | CRÍTICO |
| Prática validada por mercado: plataformas líderes ajustam tempo e preço por profissional individual automaticamente | REFORÇAR |
| Frontend nunca resolve a cascata; consome o valor resolvido do backend | CRÍTICO |

---
