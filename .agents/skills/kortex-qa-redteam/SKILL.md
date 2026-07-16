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

## 5. Fluxo mínimo
1. Carregar a matriz de gates de [references/gate-matrix.md](references/gate-matrix.md).
2. Executar a suíte completa de testes automatizados (backend, frontend e pgTAP).
3. Atacar caminhos negativos: simular bypass de tenant, manipulação de payloads, replay de idempotência e concorrência (double booking/estoque).
4. Classificar e registrar cada falha ou vulnerabilidade encontrada de forma isolada e reproduzível.

## 6. Restrições críticas
- Emitir veto absoluto (`NO-GO`) para qualquer vazamento de segredos, bypass de RLS/tenant, corrupção de valores financeiros ou falha crítica de integridade de concorrência.
- Proibir a correção silenciosa de bugs pelo Red Team; as vulnerabilidades devem ser reportadas e revalidadas formalmente.

## 7. Arquivos que podem ser carregados
- [references/gate-matrix.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-qa-redteam/references/gate-matrix.md)

## 8. Condição de parada
- Matriz de gates revisada com todas as avaliações marcadas como `PASS` (ou `PASS COM RISCO ACEITO` justificado).

## 9. Formato de saída
- Relatório de validação adversarial:
```text
GATES_EVALUATION:
- <Nome do Gate> -> <PASS/FAIL/BLOQUEADO>
VULNERABILITIES_FOUND:
- <caminho/componente: descrição da vulnerabilidade e impacto>
VEREDITO:
- <GO/NO-GO>
```
