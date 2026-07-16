---
name: kortex-express-architect
description: Planeja e revisa o backend Node.js/Express do KortexOS.
---

# Arquitetar o backend Express

## 1. Quando ativar
- Em tarefas que envolvam a implementação de rotas HTTP, middlewares de validação, controllers, services ou integrações do backend.

## 2. Quando não ativar
- Ao trabalhar exclusivamente em layouts PWA frontend ou estruturação/migrations puras do Supabase local (sem alterar APIs).

## 3. Objetivo
- Projetar e codificar serviços de API robustos, performáticos e seguros que atuem como a única fonte de verdade de negócio do KortexOS.

## 4. Entradas necessárias
- Contrato da API desejado, especificação das regras de segurança e banco de dados.

## 5. Fluxo mínimo
1. Carregar as convenções da API de [references/api-conventions.md](references/api-conventions.md).
2. Escrever validadores de payload rígidos (ex: Joi/Zod) antes de processar dados.
3. Obter e validar a identidade e membership do ator a partir do JWT do Supabase Auth.
4. Chamar repositórios ou RPCs e tratar erros de banco mapeando-os para formatos de resposta estáveis.
5. Escrever suíte de testes de integração e contrato (supertest/node test runner).

## 6. Restrições críticas
- Proibir a aceitação de `X-Organization-Id` sem validar se o ator autenticado possui membership ativa na referida organização.
- Exigir `Idempotency-Key` em todos os endpoints que efetuem mutações críticas (checkout, ajustes de estoque, etc.).
- Nunca retornar stack traces ou detalhes confidenciais de banco/infraestrutura em respostas de erro.
- O backend deve atuar como SSOT: preços, comissões, estoque e caixa são validados/calculados somente no servidor.

## 7. Arquivos que podem ser carregados
- [references/api-conventions.md](file:///c:/Users/hudso/OneDrive/Documentos/Kortex%20Os%20v2/.agents/skills/kortex-express-architect/references/api-conventions.md)

## 8. Condition de parada
- Endpoints implementados, suite de testes de backend passando (100% PASS), sem vazamento de segredos e APIs expostas de forma segura.

## 9. Formato de saída
- Estrutura de rotas e testes executados:
```text
ROUTES_ADDED:
- <MÉTODO> <Rota> -> <Função>
TESTS_RESULTS:
- <resumo de testes executados e status PASS/FAIL>
```
