# Schema greenfield do MVP

## Identidade e tenant

- `profiles(user_id → auth.users)`
- `organizations`
- `memberships(organization_id, user_id, role, active)`

O frontend seleciona uma organização; o backend valida a membership do JWT. Seleção não equivale a autorização.

## Operação

- `clients`
- `professionals`
- `services`
- `products`
- `appointments`

Usar constraint de não sobreposição para profissional/intervalo em estados ativos.

## Venda e estoque

- `orders`
- `order_items` com snapshots de descrição/preço
- `payments`
- `inventory_movements`
- `cash_entries`
- `private.idempotency_keys` com hash do payload

O checkout deve obter preços no banco, bloquear produtos, impedir saldo negativo, reconciliar pagamentos, gravar caixa e retornar resposta dentro da mesma transação.

## Fronteiras

PWA usa Supabase apenas para Auth. Express valida o bearer token, resolve membership e usa `service_role` server-only. `anon`/`authenticated` não recebem grants de negócio. RPCs privilegiadas recebem o ator validado e rechecagem membership; FKs compostas impedem referências cross-tenant.

## Fora do MVP

Ledger contábil double-entry, fiscal, folha, comissões avançadas, múltiplas unidades, marketplace e integrações de pagamento.
