---
name: kortex-qa-redteam
description: Define gates e executa revisão adversarial de segurança e integridade do KortexOS.
---

# Validar e atacar o incremento

## 1. Quando ativar
- Antes de declarar um incremento como concluído, pronto para homologação, ou pronto para deploy em produção.

## 2. Quando não ativar
- Durante as fases iniciais de desenvolvimento ou prototipagem rápida (fases sem código ou testes estáveis).

## 3. Objetivo
- Validar de forma adversarial e sistemática a segurança (tenant, RLS), concorrência e corretude de lógicas de negócio do incremento.

## 4. Entradas necessárias
- Plano de implementação, pull request/diff, e código dos testes automatizados existentes.
- Se o incremento foi fatiado (`$prd-to-issues`), a(s) issue(s) da fatia em validação — não é preciso esperar a Onda inteira para rodar este gate.

## 5. Fluxo mínimo
1. Carregar a matriz de gates de [references/gate-matrix.md](references/gate-matrix.md).
2. Em gate de desenho, ou quando a fatia introduzir/refinar comportamento de produto, conferir o **Benchmark Gate**: Booksy primeiro, principais players do mercado em seguida e referências cross-industry quando aplicável. Exigir links e a separação entre `FATO`, `INFERÊNCIA` e `DECISÃO`; ausência de precedente no Booksy também deve ser registrada.
3. Executar a suíte completa de testes automatizados (backend, frontend e pgTAP) **pessoalmente, com o comando real** — nunca aceitar "os testes passam" como fato sem rodar e ver a saída.
4. Atacar caminhos negativos: simular bypass de tenant, manipulação de payloads, replay de idempotência e concorrência (double booking/estoque).
5. Classificar e registrar cada falha ou vulnerabilidade encontrada de forma isolada e reproduzível, com o comando/consulta que a reproduz.

## 6. Restrições críticas
- Emitir veto absoluto (`NO-GO`) para qualquer vazamento de segredos, bypass de RLS/tenant, corrupção de valores financeiros ou falha crítica de integridade de concorrência.
- Proibir a correção silenciosa de bugs pelo Red Team; as vulnerabilidades devem ser reportadas e revalidadas formalmente.
- **Nunca declarar um gate `PASS` com base em relato de outro agente/subagente sobre ambiente, migration ou deploy** — se a verificação foi delegada, quem assina o veredito reproduz o comando pessoalmente antes de registrar o resultado. Um relato sem evidência bruta anexada não conta como verificação (incidente registrado: alegação de "ambiente testado e saudável" fabricada em 2026-07-21/22, nunca confirmada).
- Não emitir `PASS` ou `GO` para decisão de produto nova/refinada sem Benchmark Gate documentado; classificar como `BLOQUEADO` e apontar a evidência ausente. Correção estritamente mecânica, sem mudança de comportamento, é isenta.

## 7. Arquivos que podem ser carregados
- [references/gate-matrix.md](references/gate-matrix.md)

## 8. Condição de parada
- Matriz de gates revisada com todas as avaliações marcadas como `PASS` (ou `PASS COM RISCO ACEITO` justificado).

## 9. Formato de saída
- Relatório de validação adversarial:
```text
GATES_EVALUATION:
- <Nome do Gate> -> <PASS/FAIL/BLOQUEADO>
- Benchmark Gate (quando aplicável) -> <PASS/BLOQUEADO + fontes e FATO/INFERÊNCIA/DECISÃO>
EVIDENCE:
- <Nome do Gate> -> <comando executado + resultado bruto (contagem de teste, saída de log), nunca resumo de terceiro>
VULNERABILITIES_FOUND:
- <caminho/componente: descrição da vulnerabilidade e impacto>
VEREDITO:
- <GO/NO-GO>
```
