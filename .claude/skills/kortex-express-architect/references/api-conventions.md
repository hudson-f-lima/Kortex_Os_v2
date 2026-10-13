# Convenções da API

- Prefixar APIs com `/api/v1` sem antecipar V1.5 de produto.
- Disponibilizar `/health` sem segredos e separar readiness de liveness quando necessário.
- Aceitar JSON com limite de tamanho explícito.
- Rejeitar campos desconhecidos em comandos financeiros e de estoque.
- Usar centavos inteiros (`bigint` no banco; string ou inteiro seguro no contrato JSON).
- Responder mutações idempotentes com o mesmo recurso e indicar replay quando útil.
- Não retornar stack trace, SQL, chave, token ou configuração interna.
- Registrar `request_id`, ator disponível, tenant server-owned, operação, duração e resultado; minimizar PII.
