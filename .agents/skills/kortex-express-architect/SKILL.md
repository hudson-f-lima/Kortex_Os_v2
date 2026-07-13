---
name: kortex-express-architect
description: Planejar e revisar o backend Node.js/Express do KortexOS, com rotas, middleware, validação, serviços, engines, repositórios Supabase, contratos de erro, idempotência e tenant server-owned. Usar para módulos de clientes, equipe, catálogo, agenda, estoque, checkout, caixa, comissão e integrações do ERP vertical.
---

# Arquitetar o backend Express

1. Mapear a jornada de negócio e suas invariantes antes de definir endpoints.
2. Organizar cada módulo como rota fina, validação de entrada, serviço de caso de uso, regra pura quando possível e repositório de persistência.
3. Validar o bearer token com Supabase Auth, resolver memberships e centralizar `user_id`, `organization_id` e role em `req.auth`.
4. Manter preço, custo, comissão, disponibilidade, estoque, caixa e financeiro como verdade do servidor.
5. Usar RPC transacional para mutações que atravessam múltiplas tabelas; nunca compensar no frontend.
6. Exigir idempotency key em comandos críticos e vincular a chave ao hash do payload no desenho futuro.
7. Validar ambiente no boot, falhar fechado e nunca registrar tokens, service keys ou PII.
8. Definir erro estável com código, status, mensagem segura, detalhes permitidos e correlation id.
9. Comparar CORS por origem/hostname exatos após parse de URL; nunca usar `includes()` para confiar em domínio ou localhost.
10. Nunca aceitar token em query string; usar `Authorization: Bearer`. Após validar JWT e membership, usar o cliente privilegiado somente no servidor e passar o ator validado às RPCs.
11. Produzir contratos HTTP, dependências, sequência transacional, observabilidade e testes antes de implementação.

Ler [references/api-conventions.md](references/api-conventions.md) para o contrato mínimo.

Não confiar em `X-Organization-Id` sem membership. Como `service_role` ignora RLS, toda rota deve validar usuário, organização e role antes de qualquer acesso privilegiado.
