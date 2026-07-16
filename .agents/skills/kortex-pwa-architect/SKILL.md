---
name: kortex-pwa-architect
description: Planeja e revisa a PWA modular, segura e offline-ready do KortexOS.
---

# Arquitetar a PWA modular

## 1. Quando ativar
- Em tarefas que envolvam o desenvolvimento do frontend React, criação de telas, componentes, lógica do client API, service worker ou controle de cache.

## 2. Quando não ativar
- Durante modificações puras no backend Node.js, ou na modelagem do banco de dados/migrations que não requeiram suporte na UI.

## 3. Objetivo
- Projetar e construir uma PWA responsiva, rápida e segura com App Shell integrado, consumo de APIs REST/SSE e suporte a cache local via IndexedDB.

## 4. Entradas necessárias
- Protótipos de tela, fluxos de rotas do usuário, e contratos HTTP das APIs do backend.

## 5. Fluxo mínimo
1. Carregar a política de cache canônica de [references/cache-policy.md](references/cache-policy.md).
2. Definir rotas com gates baseados no papel (`RoleGatedRoute`) da membership ativa.
3. Consumir a API do backend usando o `apiClient` unificado (injetando JWT e ID de organização).
4. Implementar estados de carregamento, vazio, erro, offline e conflito para garantir resiliência visual.
5. Configurar e testar o registro e banner de atualização do service worker (`virtual:pwa-register`).

## 6. Restrições críticas
- Nunca incluir a chave priviliegiada `service_role` ou qualquer segredo do backend no bundle público da PWA.
- Tratar o backend como única fonte de verdade operacional (preço, caixa, estoque e comissões não devem ser calculados na UI).
- Não persistir informações pessoais sensíveis (PII) ou dados financeiros locais sem criptografia ou expirar adequadamente.

## 7. Arquivos que podem ser carregados
- [references/cache-policy.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-pwa-architect/references/cache-policy.md)

## 8. Condição de parada
- Módulo frontend implementado e build de produção concluído com sucesso, com o service worker registrando normalmente e testes passando (100% PASS).

## 9. Formato de saída
- Relatório de rotas e tamanho de bundle:
```text
COMPONENTS_ADDED:
- <caminho do arquivo de componente ou tela>
TESTS_RESULTS:
- <resumo de testes Vitest executados e status PASS/FAIL>
```
