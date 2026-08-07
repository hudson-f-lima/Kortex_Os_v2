# Matriz mínima de gates

| Gate | Evidência mínima |
|---|---|
| Escopo/cânone | sem V1.5 ou migration não autorizada |
| Backend | unitários, integração, contrato de erro e fail-closed |
| Tenant | body/query ignorado; cross-tenant negado em rota, repo e RPC |
| Dinheiro | centavos inteiros, totais reconciliados, replay seguro |
| Estoque | lock, saldo consistente, corrida e histórico |
| Agenda | conflito concorrente, status válido e reagendamento |
| Supabase | reset limpo, grants/RLS/RPC/advisors e testes cross-tenant |
| PWA | atualização, offline seguro, nenhum cache de API sensível |
| Segredos | scan limpo; `.env` e chaves ignorados |
| Histórico Git | nenhum segredo/PII em commits alcançáveis ou risco/rotação formalmente tratados |
| Supply chain | lockfile, audit conhecido e risco aceito |
| Render | Blueprint validado, health 200, logs sem erro, rollback definido |

Resultado possível: `PASS`, `PASS COM RISCO ACEITO`, `FAIL` ou `BLOQUEADO`.
