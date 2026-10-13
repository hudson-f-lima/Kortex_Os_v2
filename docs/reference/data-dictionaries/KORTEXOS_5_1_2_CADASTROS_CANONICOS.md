# PARTE II — CADASTROS CANÔNICOS

## 0. Por que esta parte existe

O Master Briefing 5.1 define motores, invariantes e gates, mas a camada de cadastros — a matéria-prima de todo cálculo — está subespecificada. Quatro buracos concretos:

| # | Buraco | Consequência econômica |
|---:|---|---|
| 1 | Forma de pagamento sem taxa/prazo/conta/absorção obrigatórios | Margem invisível; Gate 11/12 incalculáveis |
| 2 | Plano/pacote sem preço de referência de consumo | "Comissão no uso real" (Gate 14) é matematicamente indefinida |
| 3 | Combo sem regra de rateio de desconto | Comissão ambígua → conflito direto com staff |
| 4 | Pacote sem validade/breakage | Passivo eterno no ledger; receita antecipada sem regra de saída |

Esta parte fecha os quatro e especifica os nove cadastros: formas/tipos de pagamento, clientes, staff, serviços, produtos, complementos, combos, planos de assinatura e pacotes.

---

## 1. Camadas SaaS × cadastros — mapa refinado

### 1.1 Onde cada cadastro vive

| Cadastro | Domínio | Camada | Bloqueio de venda | Gates principais |
|---|---|---:|---|---|
| Formas e tipos de pagamento | D13/D14/D15 | 1 (Foundation) | Nenhum | 10, 11, 12, 18 |
| Clientes | D05 | 1 (Foundation) | Nenhum | 01, 04, 13, 21 |
| Staff | D05/D17 | 1 (Foundation) | Nenhum | 02, 03, 14 |
| Serviços | D06 | 1 (Foundation) | Nenhum | 03, 04, 08, 10 |
| Produtos | D06 | 1 (Foundation) | Nenhum | 10, 11 |
| Complementos (add-ons) | D06 | 1 (Foundation) | Nenhum | 05, 10 |
| Combos | D06/D12 | 1–3 | Rateio aprovado + comissão estável | 05, 10, 14 |
| Planos de assinatura | D18 | 4 (Revenue) | **BLOQUEADO até KortexFlow real** (regra 21.2) | 11, 12, 13, 14, 15 |
| Pacotes de serviços | D18 | 4 (Revenue) | **BLOQUEADO até KortexFlow real** (regra 21.2) | 11, 13, 14, 15 |

### 1.2 Regra de leitura da tabela

```text
Camada 1 pode ser cadastrada e usada assim que o Blueprint liberar Foundation.
Camada 4 pode ser CADASTRADA como rascunho, mas não pode ser VENDIDA
antes de ledger, wallet e benefit_obligations reais.
Cadastro sem os campos CRÍTICOS marcados nesta parte não entra em checkout nem em agenda.
```

---

## 2. Regras transversais — valem para TODOS os cadastros

| # | Regra | Definição | Status |
|---:|---|---|---|
| T1 | Tenant-scoped | Todo registro pertence a um tenant; RLS obrigatória | CRÍTICO |
| T2 | Chave natural declarada | Cada cadastro define sua unicidade (ex.: cliente = telefone E.164; produto = SKU) e o backend rejeita duplicata | CRÍTICO |
| T3 | Arquivar, nunca deletar | Registro com histórico financeiro ou de agenda não é deletado; muda para `arquivado`. Deleção real só sem histórico | CRÍTICO |
| T4 | Vigência de valores | Preço, custo, taxa e comissão mudam por vigência (data de início/fim). Histórico preserva o valor da época. Reescrever valor passado é proibido | CRÍTICO |
| T5 | Ciclo de status mínimo | `rascunho → ativo → inativo → arquivado`. Só `ativo` aparece em checkout/agenda/booking público | REAL |
| T6 | Auditoria de mutação | Toda alteração registra autor, data e valor anterior | CRÍTICO |
| T7 | Cadastro incompleto bloqueia uso | Entidade sem campos CRÍTICOS preenchidos não entra em fluxo financeiro | CRÍTICO |
| T8 | Campos calculados são read-only | Score, saldo, wallet, conta corrente aparecem no cadastro como projeção; nunca são campos editáveis | CRÍTICO |
| T9 | Frontend não deriva regra | Elegibilidade, preço, comissão e taxa vêm do backend; a tela só exibe | CRÍTICO |

---

## 3. Cadastro de Formas e Tipos de Pagamento

### 3.1 Modelo em três níveis

```text
NÍVEL 1 — TIPO: a natureza econômica da liquidação (enum fechado do sistema).
NÍVEL 2 — FORMA: o instrumento concreto configurado pelo tenant (tipo + adquirente + conta + bandeira).
NÍVEL 3 — CONDIÇÃO: à vista, parcelado N×, com/sem antecipação — cada condição com sua taxa e prazo.
```

### 3.2 Tipos canônicos (Nível 1 — não editável pelo tenant)

| Tipo | Natureza | Cria receita nova? | Observação |
|---|---|---:|---|
| Dinheiro | Liquidação imediata | Sim | Único que aceita troco |
| PIX | Liquidação D+0 | Sim | Taxa possível conforme conta |
| Débito | Cartão presente | Sim | Taxa MDR |
| Crédito à vista | Cartão | Sim | Taxa MDR |
| Crédito parcelado | Cartão | Sim | Taxa por faixa de parcela |
| Transferência/boleto | Liquidação D+n | Sim | Uso corporativo/B2B |
| Wallet do cliente | Consumo de crédito existente | Não | Debita `client_wallets`; receita já reconhecida ou reclassificada |
| Voucher / gift | Consumo de crédito pré-vendido | Não | Origem e validade obrigatórias |
| Benefício de assinatura | Consumo de obrigação | Não | Debita `benefit_obligations` |
| Benefício de pacote | Consumo de obrigação | Não | Debita sessão do pacote |
| Benefício corporativo | Consumo de contrato B2B | Não | Regras do contrato |
| Benefício de parceiro | Consumo com origem rastreável | Não | Anti-cupom (seção 15.4 do Master) |
| Fiado autorizado | Dívida governada | Sim (contra recebível) | Só aparece se Negative Guard aprovar para o cliente |
| Cortesia | Baixa sem receita | Não | Exige Action Request; comissão conforme política |

### 3.3 Campos canônicos da FORMA (Nível 2)

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome exibido | Sim | Ex.: "Crédito Visa — Stone" |
| Tipo (Nível 1) | Sim | Enum acima |
| Adquirente / maquininha | Se cartão | Rastreio de conciliação |
| Conta de destino | Sim | Onde o dinheiro cai |
| Taxa (% + fixa) por condição | Sim | MDR por parcela; vigência (T4) |
| Prazo de liquidação (D+n) por condição | Sim | Fluxo de caixa previsto |
| Modelo de absorção de taxa | Sim | Bruto Salão / Dividido / Bruto Staff (seção 8.4 do Master); default da forma, override por contrato de staff |
| Aceita gorjeta | Sim | E destino da gorjeta no ledger (tip isolation) |
| Permite estorno | Sim | E via de estorno (mesma forma / wallet) |
| Superfícies habilitadas | Sim | Presencial, link de pagamento, booking online |
| Ordem de exibição no checkout | Não | UX apenas |
| Status | Sim | T5 |

### 3.4 Invariantes

| Regra | Status |
|---|---|
| Forma sem taxa + prazo + conta + modelo de absorção = bloqueada no checkout | CRÍTICO |
| Benefício não é pagamento: é consumo de obrigação. No ledger, nunca gera receita nova em duplicidade | CRÍTICO |
| Recibo/checkout histórico preserva a taxa vigente na data (T4) | CRÍTICO |
| Fiado só é exibido no checkout se o Negative Guard autorizar aquele cliente naquele valor | CRÍTICO |
| Split multi-forma permitido; ordem default de consumo: benefício → wallet → forma externa | DECISÃO D-03 |
| Gorjeta em cartão: salão absorve a taxa da gorjeta para preservar "100% para o destinatário"; custo visível no ledger | DECISÃO D-02 |
| Estorno segue a via da forma original; ajuste por lançamento reverso, nunca edição | CRÍTICO |

### 3.5 Proibições

```text
Tipo novo criado pelo tenant é proibido (enum é do sistema).
Forma ativa sem mapeamento contábil completo é proibida.
Taxa "média estimada" no lugar da taxa real por condição é proibida.
Cortesia sem Action Request é proibida.
```

---

## 4. Cadastro de Clientes

### 4.1 Blocos canônicos

| Bloco | Campos | Regra |
|---|---|---|
| Identidade | Nome, telefone (chave natural, E.164), e-mail, data de nascimento, CPF (opcional) | Dedupe por telefone; merge governado por Command, nunca deleção manual do duplicado |
| Consentimento (LGPD) | Por canal: WhatsApp, SMS, e-mail, push — com data, origem e prova | Pré-requisito para KortexLink; campanha sem consentimento é bloqueada |
| Origem de aquisição | Orgânico, indicação (quem), parceiro (qual), corporativo (qual contrato), campanha (qual) | Obrigatório na criação; alimenta CAC e analytics de parceiro |
| Relacionamento | Preferências, tags, staff preferido, observações operacionais NÃO sensíveis | Observação sensível (saúde/estética) NÃO entra aqui — ver 4.3 |
| Família / grupo | Vínculo a household para plano família e group booking | Pagador ≠ beneficiário sempre explícito (Gate 07) |
| Confiança | Reliability Score, Trust Pass, fricções ativas (depósito compulsório, pré-pagamento, bloqueio) | Todos calculados/aplicados por política; read-only no cadastro (T8) |
| Financeiro | Wallet (saldo, créditos com origem/validade), obrigações ativas (planos, pacotes, corporativo), fiado autorizado e limite | 100% projeção do ledger; nenhum campo editável |

### 4.2 Estados

```text
ativo → inativo (sem movimento por N meses, automático, reversível)
→ bloqueado (política/Action Request) → arquivado → anonimizado (LGPD)
```

### 4.3 Regras e invariantes

| Regra | Status |
|---|---|
| Telefone único por tenant; segundo cadastro com mesmo telefone força fluxo de merge | CRÍTICO |
| Score e wallet jamais editáveis em tela de cadastro | CRÍTICO |
| Remoção de fricção (depósito, bloqueio) exige política ou Action Request | CRÍTICO |
| Dados sensíveis (anamnese, alergia, saúde, estética íntima) ficam FORA do cadastro base; módulo próprio especificado em Parte II §13 | DEC-19 — RESOLVIDO |
| Cliente com histórico financeiro é anonimizado, nunca deletado | CRÍTICO |
| Origem de aquisição não é editável após primeiro checkout (protege CAC/parceiro) | CRÍTICO |

---

## 5. Cadastro de Staff

### 5.1 Blocos canônicos

| Bloco | Campos | Regra |
|---|---|---|
| Identidade | Nome, apelido de exibição, telefone, e-mail, foto, documentos | Documento de contrato anexável |
| Vínculo legal | Tipo: **Parceiro (Lei do Salão Parceiro)** / CLT / autônomo / assistente. Se Parceiro: contrato, cota-parte %, data de homologação | Vínculo legal ≠ role do sistema. Cota-parte com vigência (T4) |
| Role do sistema | dono / gerente / profissional / recepção (persona matrix, seção 17 do Master) | Um humano pode ter vínculo Parceiro e role gerente |
| Habilitação técnica | Matriz staff × serviço: habilitado?, duração própria (override), comissão específica | Fonte do Booking Candidate; serviço não habilitado não aparece na agenda do staff |
| Agenda de trabalho | Grade semanal, pausas, bloqueios, exceções, férias | Fonte de disponibilidade; mudança não altera appointments já confirmados sem fluxo de conflito |
| Comissão | Regra default por vínculo + override por serviço, produto, plano e forma de pagamento (absorção de taxa) | Sempre com vigência; mudança nunca retroage |
| Financeiro | Conta corrente (produção, comissão, gorjeta, adiantamentos, saldo projetado) | Projeção read-only; ajuste manual só via Action Request |

### 5.2 Regras e invariantes

| Regra | Status |
|---|---|
| Staff não vê cadastro financeiro alheio (Gate 02) | CRÍTICO |
| Comissão sem vigência é proibida; edição retroativa é proibida | CRÍTICO |
| Duração própria por serviço: SIM no MVP (afeta agenda real) | DECISÃO D-01a — RECOMENDADO |
| Preço próprio por nível de profissional: NÃO no MVP (sofisticação prematura) | DECISÃO D-01b — ADIADO |
| Desligamento arquiva o staff, preserva histórico e trava agenda futura; conta corrente liquida por payout final | CRÍTICO |
| Cota-parte do Parceiro é a base do modelo de absorção de taxa (seção 3.3) | REAL como tese |

---

## 6. Cadastro de Serviços

### 6.1 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome + categoria | Sim | Navegação e analytics |
| Descrição pública vs interna | Não | Booking online vs operação |
| Duração de execução | Sim | Minutos reais na cadeira |
| Buffer pré/pós | Sim (pode ser 0) | Preparo/higienização; ocupa agenda mas não é "atendimento" |
| Preço base | Sim | Com vigência (T4); `_cents` |
| Comissão default | Sim | Override por staff na matriz 5.1 |
| Recursos exigidos | Se aplicável | TIPO de recurso (cadeira de barbeiro, sala de estética), não instância — D11 resolve a instância |
| Consumo técnico de produtos | Se aplicável | Receita de baixa de estoque por execução (ex.: 30 ml de produto X) |
| Elegibilidade a benefício | Sim | Flags: assinável / empacotável / corporativo / parceiro / off-peak only |
| Yield | Não | Participa de premium window? Aceita desconto off-peak? Multiplicadores com vigência |
| Políticas próprias | Não | Depósito, antecedência mínima, janela de cancelamento (default herda D02) |
| Visibilidade | Sim | Público (booking online) / interno |

### 6.2 Regras e invariantes

| Regra | Status |
|---|---|
| Serviço sem duração + preço + comissão default = não entra em agenda nem checkout (T7) | CRÍTICO |
| Buffer conta na ocupação e no Slot Score | REAL como tese |
| Mudança de preço não altera appointments já agendados com preço travado | CRÍTICO |
| Serviço off-peak only não é agendável em premium window sem regra superior (Gate 08) | CRÍTICO |
| Consumo técnico dispara baixa de estoque no checkout concluído | CRÍTICO |

---

## 7. Cadastro de Produtos

### 7.1 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome, SKU (chave natural), código de barras | SKU sim | Dedupe e conciliação |
| Finalidade | Sim | **Revenda / uso interno / ambos** |
| Categoria + fornecedor | Não | Compras e analytics |
| Unidade de venda vs unidade de consumo + fator de conversão | Se uso interno | Ex.: frasco 1000 ml vendido inteiro, consumido em ml |
| Custo | Sim | Com vigência; base da margem |
| Preço de venda | Se revenda | Com vigência |
| Comissão de revenda | Se revenda | Default + override por staff |
| Estoque mínimo / alerta | Não | Reposição |
| Status | Sim | T5 |

### 7.2 Regras e invariantes

| Regra | Status |
|---|---|
| Duas vias de baixa: venda (checkout) e consumo técnico (execução de serviço) — ambas idempotentes | CRÍTICO |
| Produto sem custo cadastrado gera ALERTA de margem cega (não bloqueia venda) | REAL como tese |
| Estoque negativo é proibido silenciosamente: exige registro de divergência | CRÍTICO |
| Ajuste de estoque manual registra motivo + autor (T6) | CRÍTICO |

---

## 8. Cadastro de Complementos (Add-ons)

### 8.1 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome | Sim | Ex.: "Sobrancelha", "Hidratação express" |
| Serviços compatíveis | Sim | Add-on só existe acoplado a serviço pai |
| Delta de duração | Sim (pode ser 0) | Soma na agenda |
| Delta de preço | Sim | Com vigência |
| Comissão própria | Sim | Não herda cegamente do serviço pai |
| Elegibilidade a benefício | Sim | Inclui uso como "upgrade" de parceria (seção 15.3 do Master) |
| Limite por atendimento | Não | Anti-abuso |

### 8.2 Regras e invariantes

| Regra | Status |
|---|---|
| Add-on sem serviço pai no mesmo appointment/checkout é proibido | CRÍTICO |
| Comissão do add-on é própria e explícita | DECISÃO D-09 — RECOMENDADO |
| Add-on gratuito via benefício de parceiro exige origem rastreável (anti-cupom) | CRÍTICO |

---

## 9. Cadastro de Combos

### 9.1 Definição

Combo é venda conjunta de itens (serviços + add-ons + produtos) com preço fechado ou desconto estruturado, executada em sequência (chain booking) e paga em um checkout.

### 9.2 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome + descrição | Sim | Ex.: "Corte + Barba + Sobrancelha" |
| Itens (tipo, referência, quantidade) | Sim | Serviços, add-ons, produtos |
| Modo de preço | Sim | Preço fechado OU desconto sobre a soma — desconto em **R$ (valor fixo) ou % (percentual)**, modalidade escolhida no cadastro (DEC-16) |
| **Regra de rateio do desconto** | Sim | Proporcional ao preço base de cada item (regra canônica única) |
| Modelo de absorção do desconto | Sim | Salão absorve / compartilhado — liga com o modelo de comissão 8.4 do Master |
| Sequência de execução | Sim | Ordem + staff único ou múltiplo (Gate 05 — chain booking) |
| Janela de validade / restrição de horário | Não | Combos off-peak; premium window exige regra superior |
| Elegibilidade a benefício | Sim | Combo dentro de plano/pacote/parceria? |
| Status | Sim | T5 |

### 9.3 Regras e invariantes

| Regra | Status |
|---|---|
| Rateio proporcional ao preço base é a ÚNICA regra de rateio; comissão de cada item calcula sobre o valor rateado | DECISÃO D-04 — RECOMENDADO CANÔNICO |
| Combo sem rateio definido não pode ser vendido | CRÍTICO |
| Na criação/edição, o backend simula margem do combo (preço − custo técnico − comissão rateada − taxa média); margem negativa exige aprovação explícita | CRÍTICO (Negative Guard) |
| Desconto de combo em horário nobre exige regra superior (herda 10.3 do Master) | CRÍTICO |
| Item removido no atendimento recalcula o combo no backend (perde preço de combo conforme política) | CRÍTICO |

---

## 10. Cadastro de Planos de Assinatura

### 10.1 Arquétipos canônicos de benefício

```text
QUOTA    → N usos de serviço/add-on por ciclo (ex.: 4 cortes/mês).
CRÉDITO  → R$ X em wallet por ciclo, com regras de uso.
DESCONTO → % em categoria/serviço durante a vigência.
Um plano pode combinar arquétipos, mas cada item declara o seu.
```

### 10.2 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome + ciclo (mensal) + preço | Sim | `_cents`, vigência |
| Itens de benefício (arquétipo + referência + quantidade) | Sim | Conforme 10.1 |
| **Preço de referência de consumo por item** | Sim | Base de comissão e de reconhecimento de receita no uso. SEM ISSO O GATE 14 É INCALCULÁVEL |
| Janela de uso | Sim | Dias/horários (ex.: terça–quinta); premium window excluída por default |
| Rollover | Sim | Default: expira no ciclo. Alternativa: acumula até N ciclos |
| Overuse | Sim | Excedente paga avulso (default) ou preço de membro |
| Beneficiários | Sim | Individual ou família (N dependentes do household) |
| Carência / fidelidade / pausa (freeze) | Sim | Limites explícitos; pausa máxima por ano |
| Cancelamento e desistência | Sim | **Fórmula unificada com pacotes (DEC-18):** `valor pago − (valor da parte utilizada, pelo preço de referência de consumo do item — mesmo campo usado para comissão)`, nunca negativo. Sem multa percentual autônoma (DEC-17 superada). Se uso=0, reembolso é integral E a comissão de venda (quando existir) é revertida (DEC-18); havendo qualquer uso, comissão de venda fica definitiva |
| Dunning | Sim | Tentativas, degraus, suspensão do benefício em inadimplência |
| Staff elegível | Sim | Qualquer habilitado (default) ou lista restrita |
| Comissão no uso | Sim | Calcula sobre o preço de referência do item consumido |
| Status | Sim | rascunho → ativo → **suspenso para novas vendas** → arquivado |

### 10.3 Regras e invariantes

| Regra | Status |
|---|---|
| Alterar plano ativo NÃO altera contratos vigentes: gera nova versão; assinantes migram por ação explícita | CRÍTICO |
| Cobrança gera obrigação (`benefit_obligations`); consumo passa pelo checkout; receita reconhece/reclassifica no consumo | CRÍTICO |
| Benefício suspenso por inadimplência não é consumível | CRÍTICO |
| Uso fora da janela exige regra superior ou paga avulso | CRÍTICO |
| Plano com margem de referência negativa (preço do ciclo < custo do consumo máximo × referência) exige aprovação explícita | CRÍTICO (Negative Guard) |
| Reembolso calcula sobre a parte NÃO utilizada (mesma fórmula de pacotes, DEC-18); nunca sobre valor já consumido; nunca resulta em reembolso negativo (piso zero) | CRÍTICO |
| Comissão de execução já paga por sessão/benefício realizado nunca entra na conta de devolução — protegida por construção (DEC-18) | CRÍTICO |
| Canal da venda (presencial vs. distância) é registrado no plano; determina se o direito de arrependimento do art. 49 CDC se aplica (7 dias, sem uso, reembolso integral sem dedução) — ver ressalva jurídica, seção 11.6 | CRÍTICO |
| **VENDA BLOQUEADA até ledger + wallet + obrigações reais** (regra 21.2 do Master) | BLOQUEADO |

---

## 11. Cadastro de Pacotes de Serviços

### 11.1 Definição

Pacote é compra pontual pré-paga de N sessões de serviço(s), com validade. Difere de assinatura: não recorre, não tem ciclo, não tem dunning.

### 11.2 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Nome + itens (serviço, nº de sessões) | Sim | Ex.: 10 sessões de limpeza de pele |
| Preço do pacote | Sim | Desconto embutido vs soma avulsa |
| **Rateio por sessão** | Sim | Preço do pacote ÷ sessões, proporcional por item — base de comissão e reconhecimento de USO |
| **Validade** | Sim | Dias após a compra. Pacote sem validade é proibido |
| **Motivos elegíveis para extensão** | Sim (DEC-14) | Subconjunto de: saúde / férias / outro |
| **Prazo máximo de extensão** | Sim (DEC-14) | Enum: 7, 14, 21 ou 28 dias. Concessão real seleciona motivo + prazo ≤ máximo, com autor e data registrados |
| **Texto e mecanismo de aceite digital** | Sim (DEC-14) | Texto canônico (seção 11.4); aceito por clique simples + assinatura desenhada na tela; registra hash/timestamp |
| Transferibilidade | Sim | Default: intransferível; família permitida se marcado |
| **Política de reembolso por desistência antecipada** | Sim (DEC-14) | `valor pago − (sessões consumidas × preço avulso da época)`, nunca negativo; percentual e forma de devolução (dinheiro/wallet) configuráveis por pacote |
| Regra de breakage | Sim | Aplica-se somente ao fim da janela de extensão sem uso (DEC-14) — nunca no vencimento direto da validade |
| **Comissão de venda** | Não (DEC-15) | % ou valor fixo, com vigência; default desligada. Distinta e independente da comissão de uso/execução |
| Staff elegível | Sim | Igual a planos |
| Status | Sim | T5 |

### 11.3 Regras e invariantes

| Regra | Status |
|---|---|
| Compra gera obrigação (passivo); sessão consumida no checkout debita a obrigação e reconhece receita rateada | CRÍTICO |
| **Comissão de USO** por sessão calcula sobre o valor rateado, no momento do consumo — nunca na venda do pacote (DEC-10/Gate 14) | CRÍTICO |
| **Comissão de VENDA** (DEC-15, se configurada) reconhece no momento do pagamento da venda, remunera quem processou a venda (independente de quem executa). Revertida por lançamento reverso (T6) SE E SOMENTE SE nenhuma sessão foi utilizada (uso=0); havendo qualquer uso, a comissão de venda é definitiva, nunca revertida (DEC-18) | CRÍTICO |
| Comissão de venda e comissão de uso são independentes: não se substituem, não se reduzem mutuamente; mesma pessoa pode receber ambas | CRÍTICO |
| Pacote sem validade, sem rateio ou sem aceite digital configurado = BLOQUEADO na criação | CRÍTICO |
| Sequência de breakage é sempre: validade vencida → janela de extensão (motivo + prazo ≤ máximo, crédito de wallet + aviso) → só então reconhecimento de receita. Pular a extensão é proibido (DEC-14) | CRÍTICO |
| Reembolso por desistência antecipada é regra distinta do breakage; aplica-se enquanto o pacote está dentro da validade original | CRÍTICO |
| **VENDA BLOQUEADA até KortexFlow real E validação jurídica do mecanismo de aceite digital** (regra 21.2 do Master + DEC-14) | BLOQUEADO |

### 11.4 Texto canônico de aceite digital (DEC-14)

```text
TERMOS DO PACOTE

Você está adquirindo [N] sessões de [serviço], válidas por [X] dias a partir da compra.

- Sessões não usadas na validade entram automaticamente em janela de extensão
  (7 a 28 dias, conforme motivo aprovado). Você será avisado antes do vencimento.
- Encerrada a extensão sem uso, o saldo não é mais reembolsável.
- Desistindo dentro da validade, você recebe reembolso do valor pago menos as
  sessões já usadas (pelo preço avulso vigente).
- Pacote [intransferível / válido para o grupo familiar].

Ao assinar abaixo, você confirma que leu e concorda com estes termos.
[campo de assinatura]  —  Data/hora registradas automaticamente.
```

```text
Texto sujeito a validação jurídica antes de uso comercial (DEC-14).
Placeholders [N], [X], [intransferível/família] resolvidos pelo backend
a partir do cadastro do pacote — nunca hardcoded no frontend.
```

### 11.5 Comissão de venda — escopo futuro (DEC-15) e regra de reembolso unificada (DEC-18)

```text
Extensão da comissão de venda para PLANOS DE ASSINATURA está registrada como
intenção, NÃO implementada nesta versão.
Motivo do adiamento: plano tem múltiplos momentos de cobrança (adesão + cada
renovação), o que exige decidir separadamente se a comissão de venda se aplica
só na adesão, em toda renovação, ou em degrau decrescente — esse ponto
permanece aberto.
A condição de CLAWBACK, porém, já está pré-decidida (DEC-18) e vale desde já
quando essa extensão for implementada: reversão total apenas se uso=0;
qualquer uso torna a comissão de venda definitiva.
Nenhuma implementação de comissão de venda em planos antes de decisão explícita
do Platform Owner sobre o ponto ainda aberto (momento de aplicação).
```

### 11.6 Ressalva jurídica — direito de arrependimento e canal de venda (DEC-18)

```text
O art. 49 do CDC garante devolução integral e imediata, sem custos adicionais,
em compras fechadas FORA do estabelecimento comercial (online, app, telefone,
WhatsApp/KortexLink), dentro de 7 dias da assinatura/aceite ou do recebimento.

Pela leitura corrente da lei, venda PRESENCIAL na comanda do salão não se
enquadra nesse dispositivo especificamente — mas o sistema deve registrar o
CANAL da venda (presencial vs. distância) em todo pacote e plano vendido,
porque é esse dado que determina qual regra de reembolso se aplica.

Pontos que exigem validação jurídica antes de produção comercial (somam-se
aos já registrados em DEC-14):
- Se o uso de 1 sessão dentro dos 7 dias de um pacote/plano vendido a
  distância extingue ou não o direito de arrependimento do art. 49.
- Se a retenção de custos (taxa de cartão, nota fiscal) em reembolso de
  venda presencial com uso=0, fora do prazo de reflexão, é defensável.
```

---

## 12. Matriz de dependências e ordem de implementação dos cadastros

| Ordem | Cadastro | Depende de | Libera |
|---:|---|---|---|
| 1 | Formas de pagamento | — | Checkout real |
| 2 | Staff | — | Agenda, comissão |
| 3 | Serviços | Staff (matriz de habilitação) | Agenda, checkout |
| 4 | Clientes | — (contínuo) | Agenda, score, LGPD |
| 5 | Produtos | — | Revenda + consumo técnico |
| 6 | Complementos | Serviços | Up-sell no booking |
| 7 | Combos | 1–3 + rateio aprovado (D-04) | Chain booking com preço fechado |
| 8 | Pacotes | KortexFlow (ledger + obrigações) | Receita antecipada governada |
| 9 | Planos | KortexFlow + dunning + wallet | MRR e ocupação terça–quinta |

---

## 13. Dados Sensíveis do Cliente — Módulo Isolado (D26/DEC-19)

**Resolve D-07.** Anamnese, alergia, contraindicação, saúde e estética íntima ficam **fora** do cadastro base de cliente (Parte II §4), em módulo próprio, isolado por regime jurídico mais restrito.

### 13.1 Base legal

```text
Dado de saúde é dado sensível (LGPD art. 5º, II). O art. 11 permite apenas dois
caminhos: consentimento específico e destacado (inciso I), ou uma das 7 exceções
do inciso II — nenhuma das quais se aplica a salão de beleza/barbearia:
- Não há "legítimo interesse" para dado sensível (essa base só existe no art. 7º,
  para dado comum) — a rota mais simples do resto do sistema NÃO está disponível aqui.
- A exceção de "tutela da saúde" (alínea f) vale só para profissional de saúde,
  serviço de saúde ou autoridade sanitária — não cobre salão/barbearia.

BASE LEGAL ÚNICA: consentimento específico e destacado (art. 11, I).
```

### 13.2 Campos canônicos

| Campo | Obrigatório | Função |
|---|---:|---|
| Consentimento específico | Sim | Separado de qualquer outro consentimento (LGPD, marketing, aceite de pacote); finalidade própria: "prestar o serviço com segurança, evitando reação alérgica ou contraindicação" |
| Data, hora e canal do consentimento | Sim | T6 (auditoria de mutação) |
| Dado sensível estruturado | Não | Alergias e contraindicações relevantes ao serviço contratado — não ficha médica completa (minimização) |
| Serviço/procedimento vinculado | Sim | Todo registro sensível associa-se a um serviço ou categoria de serviço específico — nunca genérico |
| Prazo de retenção | Sim | Vigência definida; NÃO usa T3 (arquivar para sempre) — ver 13.3 |
| Status do consentimento | Sim | ativo → revogado. Revogação apaga o dado sensível especificamente, não o cadastro de cliente inteiro |

### 13.3 Regras e invariantes

| Regra | Status |
|---|---|
| Nenhum dado sensível é coletado, exibido ou processado sem o consentimento específico e destacado (13.1) ativo | CRÍTICO |
| Consentimento sensível NUNCA é pré-marcado, agrupado ou implícito em outro aceite (LGPD exige "específico e destacado") | CRÍTICO |
| Visibilidade restrita: apenas staff que executa o atendimento vinculado + dono/gerente. Não é visível a toda a equipe (diferente do cadastro geral de cliente) | CRÍTICO |
| **Exceção à regra T3 (arquivar, nunca deletar):** dado sensível tem prazo de retenção definido; ao expirar ou mediante revogação, é deletado ou anonimizado de fato — não apenas arquivado | CRÍTICO |
| Cliente pode consultar e solicitar exclusão do próprio dado sensível a qualquer momento (LGPD art. 18) | CRÍTICO |
| Minimização: coleta-se apenas o necessário para o serviço específico, nunca histórico médico amplo | CRÍTICO |
| Compartilhamento com terceiros (ex.: fornecedor de produto, plataforma de IA) exige novo consentimento específico — nunca herda do consentimento original | CRÍTICO |
| **VALIDAÇÃO JURÍDICA PENDENTE:** texto exato do consentimento e prazo de retenção — mesma ressalva já aplicada a DEC-14/DEC-18. Base legal (art. 11, I) está fundamentada; redação final não | BLOQUEADO até validação |

---

## 14. Decisões conceituais originais (D-01 a D-09)

Todas as 9 decisões foram endereçadas — nenhuma pendência restante. Registro completo, com reconciliação D → DEC, no Decision Log, Seção 2. D-07 resolvida em 13 acima (DEC-19).

## 15. O que NÃO construir agora

```text
Preço dinâmico por profissional/nível.
Tipos de pagamento customizados pelo tenant.
Ficha de anamnese dentro do cadastro de cliente.
Venda de planos ou pacotes antes do KortexFlow real.
Combos com rateio "manual caso a caso".
Importação em massa de cadastros sem regra de dedupe.
Campos livres de desconto no cadastro (desconto é política, não cadastro).
```

---

---
---

