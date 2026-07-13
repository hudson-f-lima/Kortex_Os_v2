# Planejamento — Comissões de Serviços e Pacotes

**Status:** `REAL` — implementado nas Fases 3.1 (`20260713050000_service_groups_and_packages.sql`) e 5.1 (`20260713060000_professional_commissions_checkout.sql`), ver `docs/PROJECT_STATE.md`. O conteúdo abaixo é o design original; mantido como documento de referência da decisão de modelo de dados, não como plano pendente. Este documento detalha e resolve em decisão de modelo de dados o que `docs/PLANEJAMENTO_FINANCEIRO.md §4` já havia identificado como "Camada 1" (atribuição de profissional) e parte da "Camada 2" (engine de comissão) — aqui as duas se fundem numa única proposta, porque, como o §5 deste documento mostra, não dá para resolver uma sem a outra.

**Ordem de leitura antes deste documento:** `AGENTS.md` → `docs/KORTEX_MVP_TECNICO.md` → `docs/PLANEJAMENTO_FINANCEIRO.md` (auditoria anterior desta mesma área).

## 1. Objetivo e escopo

Modelar serviços e pacotes com: comissão (percentual ou valor fixo), duração e preço; um percentual **padrão por grupo de serviços**; e a possibilidade de **override por profissional**. Escopo explicitamente fora deste documento: comissão sobre produtos (já tem `cost_cents`/margem própria, não pedido aqui) e integração com folha de pagamento.

## 2. Estado real hoje (recapitulando o que já foi auditado)

`services` é uma tabela plana (`name`, `price_cents`, `duration_minutes`, `active`) sem categoria e sem qualquer campo de comissão. Não existe tabela de grupos, de pacotes, nem de comissão por profissional — `professionals` também não tem nenhum campo financeiro. `order_items` (linha vendida no checkout) não tem `professional_id`. Isto é domínio novo, não uma extensão de algo parcialmente pronto.

## 3. Pesquisa global — como o mercado resolve "quanto cada profissional recebe"

**A regra universal é "o mais específico vence".** Zenoti: comissão configurada no nível do cargo (*job*) vale para todos que exercem aquele cargo; se também houver configuração no nível do funcionário, **só a do funcionário conta** — as duas nunca se somam. Vagaro: comissão definida por serviço/produto específico sobrepõe a comissão em camadas por faturamento (*tiered by revenue*); a documentação da própria Vagaro descreve isso como "o sistema usa o percentual mais específico disponível". A Trinks (referência local) confirma o mesmo padrão em português: comissão é cadastrada no cadastro do profissional, por categoria de serviço, individualmente (ex.: "Maria recebe 40% em corte e 30% em coloração").

**Percentual ou valor fixo coexistem, nunca um só.** O mercado trata isso como uma escolha por regra, não uma escolha única do sistema inteiro: tanto Vagaro quanto Zenoti permitem configurar comissão como percentual do valor do serviço **ou** como valor fixo por atendimento, e essa escolha pode variar serviço a serviço.

**"Percentual de quê?" é a pergunta que mais gera disputa.** A pesquisa é explícita: uma comissão de 45% calculada sobre o valor líquido (após custo/desconto) pode pagar mais que 55% sobre o bruto — a base de cálculo importa tanto quanto a taxa. Isso força uma decisão explícita no §4.5 em vez de deixar implícito.

**Pacotes multiplicam o problema porque frequentemente envolvem mais de um profissional.** Um pacote "dia da noiva" pode ter corte com um profissional e maquiagem com outro; a pesquisa de mercado (Mangomint) é direta: ao vender um pacote, "o sistema precisa calcular splits de comissão corretos para cada profissional envolvido" — comissão de pacote não é um valor único, é a soma da comissão de cada componente. Preço de pacote, por sua vez, é convencionalmente 10–20% mais barato que a soma dos itens avulsos — o que cria um problema de **alocação proporcional** (dividir o preço-pacote entre os componentes sem sobrar/faltar centavo), exatamente o problema que o algoritmo de "maior resto" em `docs/legacy/checkout_math_logic.md §2` (`allocateProportional`) resolve. Diferente do ledger/FSM descartados no planejamento financeiro anterior, **esse algoritmo específico é estado da arte genuíno para este problema específico** e vale reaproveitar o padrão (não o arquivo — reimplementar em SQL dentro da RPC, no mesmo lugar onde `checkout_close` já calcula preço).

## 4. Modelo proposto

### 4.1 Cascata de resolução (a decisão central)

```
profissional × serviço  (override mais específico)
        ↓ se não configurado
serviço  (padrão próprio do serviço, opcional)
        ↓ se não configurado
grupo de serviços  (padrão do grupo — sempre obrigatório)
```

"Mais específico vence" — nunca soma, nunca média. Cada nível é uma regra completa e independente (tipo + valor), não um ajuste sobre o nível anterior. Todo serviço pertence a exatamente um grupo (`service_group_id not null`) e todo grupo é obrigado a ter um padrão configurado (`default_commission_type`/`default_commission_value not null`) — isso garante que a cascata **sempre termina em um valor**, nunca precisa de um caso de erro em tempo de checkout por "comissão não configurada". A validação acontece no cadastro (criar serviço sem grupo é rejeitado), não na venda.

### 4.2 Como representar "percentual ou fixo" sem float

Duas colunas em todo nível da cascata, nunca uma sozinha:

| Coluna | Tipo | Significado |
|---|---|---|
| `commission_type` | `text check in ('percentage','fixed')` | qual das duas regras vale |
| `commission_value` | `bigint` | se `percentage`: **pontos-base** (10000 = 100,00%, permite 2 casas decimais de percentual sem float); se `fixed`: **centavos** |

Mesma disciplina de `money.js`/`checkout_close` já em produção: nunca `numeric`/`float` para algo que vira dinheiro.

### 4.3 Entidades novas

| Tabela | Campos-chave | Papel |
|---|---|---|
| `service_groups` | `name`, `default_commission_type`, `default_commission_value` (ambos `not null`) | nível 3 da cascata (§4.1) |
| `services` *(estender)* | `+ service_group_id not null fk`, `+ commission_type null`, `+ commission_value null` | nível 2, opcional |
| `packages` | `name`, `price_cents`, `active` | preço de venda do pacote (não é soma dos componentes) |
| `package_items` | `package_id fk`, `service_id fk`, `quantity` | composição do pacote |
| `professional_service_commissions` | `professional_id fk`, `service_id fk`, `commission_type`, `commission_value`, único por `(organization_id, professional_id, service_id)` | nível 1 da cascata, o "override por profissional" pedido |

### 4.4 Pacotes: preço por alocação proporcional, comissão por componente

Um pacote **não** tem seu próprio campo de comissão — ele se decompõe em itens de serviço normais no checkout, cada um mantendo seu `service_id` (logo, sua própria cascata de comissão) e seu próprio `professional_id` (quem de fato executou aquele componente). O preço do pacote é distribuído entre os componentes com o algoritmo de maior resto, usando o preço avulso de cada serviço como peso — a mesma função que já existe como referência em `docs/legacy/checkout_math_logic.md`, portada para dentro da RPC de checkout (não para o backend Express, para não abrir uma segunda fonte de verdade de preço). Duração do pacote = soma da duração dos componentes (assume execução sequencial; ver §7 se a operação real for paralela).

### 4.5 Base de cálculo da comissão (resolve o "percentual de quê?")

Comissão percentual incide sobre o **valor líquido do item após alocação do pacote** (o que o profissional efetivamente gerou de receita naquela venda), nunca sobre o preço de tabela do serviço avulso. Comissão fixa ignora preço/alocação — é sempre `commission_value × quantity`. Se/quando `discount_cents` (gap `CONTRADITÓRIO` do planejamento financeiro anterior) for implementado, o desconto também deve ser alocado proporcionalmente antes do cálculo de comissão, com o mesmo algoritmo — **é a mesma migration, não uma terceira**.

### 4.6 Congelar no checkout, nunca recalcular depois

`order_items` ganha `professional_id`, `commission_type`, `commission_value` e `commission_cents` **resolvidos e gravados no momento do checkout** — a cascata roda uma vez, dentro de `checkout_close`, e o resultado fica congelado na linha vendida. Se o profissional trocar de percentual mês que vem, vendas antigas não mudam retroativamente; isso é o mesmo princípio que já protege `unit_price_cents` (preço muda no cadastro, pedidos fechados não). A resolução roda **só na RPC**, nunca no Express nem na PWA — seguindo o invariante já existente de que preço/comissão nunca são confiança do cliente.

## 5. Por que isto é uma única migration, não três

`professional_id` em `order_items` (Camada 1 do planejamento financeiro anterior), o modelo de comissão deste documento, e a alocação proporcional de pacotes compartilham o mesmo ponto de entrada (o payload de `checkout_close`) e a mesma tabela de destino (`order_items`). Implementar comissão sem `professional_id` é impossível; implementar `professional_id` sem decidir comissão junto significa migrar `order_items` duas vezes. Recomendação: tratar como uma entrega só.

## 6. Exemplo numérico

Pacote "Dia da Noiva" vendido por **R$ 220,00** (22000 centavos), composto por Corte (R$ 80 avulso), Escova (R$ 60 avulso) e Maquiagem (R$ 110 avulso) — soma avulsa R$ 250,00, desconto de pacote de R$ 30,00:

| Componente | Peso (preço avulso) | Alocado no pacote | Profissional | Comissão resolvida | Valor |
|---|---|---|---|---|---|
| Corte | R$ 80,00 | R$ 70,40 | Ana | override Ana×Corte: 60% | R$ 42,24 |
| Escova | R$ 60,00 | R$ 52,80 | Ana | sem override → grupo "Cabelo": 45% | R$ 23,76 |
| Maquiagem | R$ 110,00 | R$ 96,80 | Beatriz | sem override → serviço "Maquiagem": 50% fixo do grupo "Estética" | R$ 48,40 |

Soma alocada = R$ 70,40 + R$ 52,80 + R$ 96,80 = **R$ 220,00**, exata (sem sobra/falta de centavo). Cada linha carrega seu próprio profissional e sua própria comissão, resolvida independentemente — é isso que vira três `order_items` dentro de uma única `order`.

## 7. Decisões em aberto

- **Override por profissional × grupo** (não só × serviço específico): Zenoti/Vagaro suportam; não incluído no modelo mínimo do §4.3 porque o pedido original foi "override por profissional" no singular — adicionar depois é uma tabela nova, não uma migration destrutiva, então adiar é seguro.
- **Duração de pacote com execução paralela** (dois profissionais atendendo o mesmo cliente ao mesmo tempo): o modelo do §4.4 assume soma sequencial; se isso for comum no negócio real, duração do pacote precisa de um campo próprio em vez de ser sempre derivada.
- **Timing de reconhecimento da comissão** (Trinks oferece "na data de fechamento" vs. "na data de recebimento"): como o checkout do KortexOS é sempre à vista e imediato (sem parcelamento modelado), esta distinção não se aplica ainda — vira relevante só se/quando pagamento parcelado for suportado.
- **Grupo padrão automático por organização**: para não obrigar o dono a criar um grupo antes do primeiro serviço, o onboarding poderia criar um grupo "Geral" automaticamente — decisão de produto, não técnica.

## Fontes

- [Zenoti — Employee Commissions: Levels of Configuration and Impacts](http://help.zenoti.com/en/articles/757318-employee-commissions-levels-of-configuration-and-impacts)
- [Zenoti — Configure commissions](https://help.zenoti.com/en/employee-and-payroll/onboard-and-set-up/configure-commissions.html)
- [Vagaro — Set Up Commission for Services](https://support.vagaro.com/hc/en-us/articles/21475957047323-Set-Up-Commission-for-Services)
- [Vagaro — Configure Your Payroll](https://support.vagaro.com/hc/en-us/articles/204347910-Configure-Your-Payroll)
- [Trinks — Comissão (Central de Ajuda)](https://ajuda.trinks.com/comissao)
- [Zenoti — Salon Commission Structures: The Complete Guide](https://www.zenoti.com/thecheckin/salon-commission-structure)
- [Mangomint — Successful salon and spa packages](https://www.mangomint.com/blog/salon-package-examples/)
- [Square — Salon Pay Structures](https://squareup.com/us/en/the-bottom-line/managing-your-finances/salon-pay-structures)
