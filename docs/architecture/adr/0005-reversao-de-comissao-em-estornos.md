# 5. Reversão de Comissão em Estornos

Date: 2026-07-15

## Status

Proposed

## Context

A migration da Fase 9 (`supabase/migrations/20260715103200_fase9_foundation.sql`) introduziu `order_refund`: transiciona `orders.status` para `refunded`, insere um `cash_entries kind='refund'` e reverte estoque de itens de produto — mas **não** altera `order_items.commission_cents`. A leitura inicial (sem pesquisa) tratou isso como uma lacuna a fechar automaticamente ("estorno deveria reverter a comissão").

Seguindo a regra de sempre pesquisar o mercado global antes de decidir (`PLANEJAMENTO_EXECUCAO_UNIFICADO.md §1`), a pesquisa revelou dois conjuntos de restrições que a leitura inicial ignorava:

**1. Legislação trabalhista brasileira (profissional CLT).** Jurisprudência consolidada, aplicando a Lei nº 3.207/1957 art. 7º por analogia a comissionistas: uma vez ultimada a venda, é indevido o estorno das comissões já pagas, ainda que o comprador seja inadimplente, sob pena de transferir ao empregado o risco da atividade econômica. **Somente a insolvência do comprador autoriza o estorno.** Um cancelamento por desistência do cliente, erro do estabelecimento, ou correção de registro não autoriza descontar a comissão de um profissional CLT.

**2. Lei do Salão Parceiro (Lei nº 13.352/2016).** Profissionais autônomos-parceiros não são regidos pela proteção acima — a remuneração e as regras de retenção/desconto devem estar previstas no contrato de parceria escrito e homologado. Sem esse contrato formal (ou se o profissional exerce função fora do escopo do contrato), a lei converte a relação em vínculo empregatício (CLT), reativando a proteção do item 1.

**3. Prática global de SaaS/afiliados (clawback timing).** O padrão mais seguro não é reversão retroativa instantânea: comissão fica pendente durante uma janela de estorno, e qualquer correção pós-pagamento é um **lançamento de ajuste negativo no próximo ciclo**, nunca um `UPDATE` do valor já congelado. Isso é consistente com o invariante já adotado no projeto (`PLANEJAMENTO_EXECUCAO_UNIFICADO.md §3`: "a comissão é sempre congelada no checkout, não retroage").

**4. Um cenário adicional e distinto surgiu durante a mesma investigação**: correção de comanda fechada por erro operacional da recepção (ex.: serviço ou profissional errado digitado) não é um estorno real ao cliente — nenhum dinheiro sai do caixa. Reusar `order_refund` para esse caso geraria um lançamento de caixa fantasma e misturaria duas questões legais diferentes: "estornar uma venda válida" (protegido pela legislação acima) vs. "corrigir um registro que nunca esteve certo" (o profissional nunca teve direito à comissão daquele registro específico — base legal mais simples, mas ainda não modelada). Esse primitivo (`order_correct`, candidato) é tratado como decisão em aberto da Fase 9, não resolvido por este ADR.

O schema atual não modela: (a) a classificação legal do profissional (CLT vs. autônomo-parceiro com contrato válido) nem (b) o motivo do estorno (inadimplência do cliente vs. desistência vs. erro operacional). Sem essas duas informações, qualquer automação de reversão de comissão é uma aposta jurídica, não uma decisão técnica neutra.

## Decision

`order_refund` **não deve reverter `order_items.commission_cents` automaticamente até que os dois campos abaixo existam no schema.** O comportamento atual da migration (não tocar em comissão) é adotado como o **padrão seguro por design**, não uma lacuna a corrigir às pressas — mas passa a ser uma decisão registrada, não um acidente de implementação.

Quando a reversão de comissão for implementada (fase futura, não escopada aqui):
- Deve ser um **lançamento de ajuste separado** (nova linha/evento), nunca um `UPDATE` de `order_items.commission_cents` — preserva o invariante de não-retroatividade já adotado.
- Só deve disparar automaticamente quando o motivo do estorno for **inadimplência do comprador** (a única causa que a lei permite para CLT) ou quando o profissional for **autônomo-parceiro com contrato válido que preveja a hipótese**.
- Correção de erro operacional (comanda digitada errada) é tratada por um primitivo diferente de `order_refund` (ver Fase 9 do `PLANEJAMENTO_EXECUCAO_UNIFICADO.md`), com base legal distinta (correção de registro incorreto, não estorno de venda válida).

## Consequences

- **Positivo**: elimina o risco de implementar um desconto de comissão juridicamente indevido para profissionais CLT: a lacuna atual (comissão não revertida) é a opção mais segura enquanto a classificação do profissional não existir no schema.
- **Positivo**: mantém consistência com o invariante "comissão congelada, não retroage" já adotado no projeto — a solução (lançamento de ajuste, não `UPDATE`) é a mesma tanto para este caso quanto para o `deposit_credit` da Fase 13.
- **Negativo/Trade-off**: relatórios de comissão por profissional ficam temporariamente incorretos para pedidos estornados (comissão de venda cancelada continua "no papel") até a automação existir — aceitável para o volume atual (auditoria manual), mas deve ser revisitado antes de qualquer módulo de folha/payout automático.
- **Negativo/Trade-off**: exige nova coluna/tabela para classificar o profissional (CLT vs. autônomo-parceiro) e capturar o motivo do estorno antes de qualquer automação — escopo não definido aqui, fica como decisão em aberto da Fase 9/12.
- Este ADR não substitui aconselhamento jurídico trabalhista específico; a leitura da legislação aqui é insumo para a decisão técnica, não uma opinião legal definitiva.
