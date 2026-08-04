# Classificação operacional

- `REAL`: existe e possui evidência proporcional ao risco.
- `PARCIAL`: existe, mas não satisfaz integralmente o contrato.
- `MOCKADO`: simula comportamento sem fonte real.
- `HARDCODED`: depende de valor fixo ou configuração tratada como regra.
- `CRÍTICO`: pode comprometer dinheiro, tenant, estoque, agenda, segredo ou release.
- `BLOQUEADO`: não pode avançar sem decisão, autorização ou dependência.
- `DESCONHECIDO`: evidência insuficiente.
- `OBSOLETO`: não representa a fundação vigente.
- `CONTRADITÓRIO`: duas fontes autorizadas não podem ser verdadeiras ao mesmo tempo.

Não usar “pronto”, “seguro” ou “produção” sem definir e provar o gate correspondente.
