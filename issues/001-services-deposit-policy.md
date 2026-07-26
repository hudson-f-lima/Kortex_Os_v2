## Parent Blueprint

`docs/KORTEXOS_5_1_2_BLUEPRINT_ONDA_1_DRAFT.md` (DEC-34), §2.1 e §4 (`services` ALTER).

## What to build

Extensão aditiva de `services` com política de depósito e de comissão de no-show, ambas opcionais. Toda organização/serviço existente continua funcionando exatamente como hoje (colunas nascem `NULL` = sem política). O backend passa a aceitar esses campos opcionais ao criar/atualizar um serviço.

Colunas novas (todas nullable):
- `deposit_mechanic` (`hold` | `immediate_charge`)
- `deposit_type` (`percentage` | `fixed`)
- `deposit_value` (basis points ou centavos, conforme `deposit_type`)
- `no_show_commission_type` (`percentage` | `fixed`)
- `no_show_commission_value` (unidade conforme o tipo)

`no_show_commission_type`/`value` são independentes do `commission_type`/`value` normal do serviço — não herdam a comissão de venda.

## Acceptance criteria

- [ ] Migration aditiva cria as 5 colunas em `services`, todas nullable, sem alterar nenhuma constraint existente
- [ ] `services.validation.js` aceita os 5 campos como opcionais no create e no update, validando os enums (`deposit_mechanic`, `deposit_type`, `no_show_commission_type`) e que `deposit_value`/`no_show_commission_value` sejam inteiros não-negativos quando o par tipo/valor correspondente for informado
- [ ] Serviço criado sem os campos novos continua idêntico ao comportamento atual (nenhuma regressão nos testes existentes de `services`)
- [ ] pgTAP: RLS herdada de `services` continua igual (nenhuma política nova); só `owner`/`admin` conseguem gravar as colunas novas (mesma regra atual de edição de catálogo)
- [ ] Teste de integração backend: cria serviço com política de depósito completa, lê de volta, atualiza pra `NULL` (remove a política), confirma idempotência

## Blocked by

None - can start immediately

## Seções do Blueprint endereçadas

- §2.1 (campos novos em `services`)
- §4 (`services` ALTER)
- §5 (compatibilidade — nenhum comportamento muda até configuração explícita)
