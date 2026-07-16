---
name: kortex-truth-mapper
description: Audita a verdade operacional e maturidade de implementações no KortexOS.
---

# Mapear a verdade do KortexOS

## 1. Quando ativar
- Antes de planejar novos módulos, para resolver contradições documentais, validar prontidão de entregas ou auditar conformidade de código.

## 2. Quando não ativar
- Durante a execução de codificação ou escrita de testes propriamente ditos (fase de implementação ativa).

## 3. Objetivo
- Fornecer um mapa de maturidade real baseado em evidências físicas e executáveis do workspace, separando fatos de planos.

## 4. Entradas necessárias
- Especificação solicitada e código/migrations/testes existentes no repositório.

## 5. Fluxo mínimo
1. Mapear e inspecionar código físico, schemas de banco e testes reais.
2. Ordenar autoridade: evidência executada (testes aprovados) > código e schema > estado canônico > planejamento > legado.
3. Separar rigorosamente alegações de provas físicas (ex: documentos de design não tornam a feature REAL).
4. Classificar e documentar achados usando a matriz de classificação.

## 6. Restrições críticas
- Nunca editar arquivos de código ou realizar modificações no repositório durante a auditoria de verdade.
- Proibir elevação de classificações com base em otimismo ou inferência sem teste executável.

## 7. Arquivos que podem ser carregados
- [references/classification.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-truth-mapper/references/classification.md)

## 8. Condição de parada
- Matriz de maturidade preenchida com caminhos, símbolos e testes que sustentam cada classificação.

## 9. Formato de saída
- Relatório de maturidade contendo:
```text
Matriz de Maturidade:
- Capacidade | Estado (REAL/PARCIAL...) | Evidência (link arquivo) | Lacunas/Riscos
```
