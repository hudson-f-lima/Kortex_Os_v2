# Política de cache

| Classe | Estratégia | Regra |
|---|---|---|
| HTML/app shell | network-first | fallback apenas para shell seguro |
| JS/CSS com hash | cache-first | cache versionado e limpeza no activate |
| ícones/fontes próprias | stale-while-revalidate | sem dados pessoais |
| GET público imutável | stale-while-revalidate | somente se contrato permitir |
| API autenticada | network-only por padrão | não armazenar resposta sensível |
| mutações | network-only | nunca enfileirar checkout/estoque/caixa sem protocolo idempotente explícito |

O modo offline pode permitir navegação e rascunhos locais não críticos. Nunca exibir disponibilidade, saldo ou fechamento antigos como atuais.
