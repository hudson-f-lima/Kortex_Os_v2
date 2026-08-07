# 12. Idempotência de Commands e Ativação da Concorrência Otimista em Appointments (Accepted)

Date: 2026-07-16

## Status

**Accepted (2026-07-16).** Item 5 do plano de 7 ADRs. O fork arquitetural da seção 1 foi resolvido pelo usuário: **Rota B** (RPC transacional).

## Context

### Idempotência: `appointments` é a única rota de escrita relevante sem proteção

Toda rota de escrita com efeito colateral relevante já exige `Idempotency-Key` — checkout (`checkout.service.js`), ajuste de estoque (`inventory.service.js`), lançamento de caixa. `POST/PATCH /appointments` é a exceção: um duplo-clique ou retry de rede no cliente cria dois agendamentos idênticos (a exclusion constraint só bloqueia profissionais **sobrepostos**, não duplicados idênticos se o cliente reenviar exatamente o mesmo payload após um timeout).

### Concorrência otimista: a coluna `version` existe e não faz nada

`supabase/migrations/20260715140100_fase10_appointments_hardening.sql:6,29-43` já adicionou `appointments.version bigint` com um trigger que **incrementa automaticamente a cada UPDATE**. Mas nenhum código consumidor lê ou envia `version`:

```
$ grep -rn "version" backend/src/modules/appointments/*.js
(nenhum resultado)
```

Ou seja: a infraestrutura de "lock otimista" existe fisicamente, mas o contrato que a torna um lock de fato — cliente envia a versão que tinha em mãos, servidor rejeita com 409 se divergir — nunca foi implementado. Hoje, dois `PATCH` concorrentes no mesmo agendamento aplicam last-write-wins silenciosamente.

Isso importa especialmente para o próximo ADR (Change Plan): não dá para mostrar um diff "seguro" (compare o que você está vendo com o que vai aplicar) sem garantir que o registro não mudou por baixo entre a leitura e a escrita.

## Pesquisa

O padrão hoje em produção neste repositório (`checkout_close`, `inventory_adjust`, `create_package`/`update_package`) segue uma regra implícita e consistente: **toda mutação com mais de uma invariante ou mais de uma tabela envolvida vira uma RPC `security definer`, não um `insert`/`update` direto do Express via PostgREST.** `appointments` já tem hoje 3 invariantes ativas (exclusion constraint anti-sobreposição, guard de FSM `completed` imutável, incremento de `version`) e, com o [ADR 0010](0010-elegibilidade-tri-state-fail-closed.md)/[0011](0011-snapshot-operacional-agendamento.md), ganhará mais duas (gate de elegibilidade tri-state, snapshot de duração) — é o módulo com mais invariantes de escrita do sistema depois de `checkout`, mas é o único desse porte que ainda escreve direto via `supabaseAdmin.from('appointments').insert/update(...)` no Express (`appointments.service.js`), sem RPC.

O padrão de idempotência já estabelecido (`private.idempotency_keys`, PK composta `(organization_id, key)`, `insert ... on conflict do nothing` seguido de `select ... for update`, resposta em cache reaproveitada se a chave já foi resolvida) só é atômico **dentro** de uma função `plpgsql` — a checagem de chave e a escrita de negócio acontecem na mesma transação. Implementar idempotência no Express (duas chamadas HTTP separadas ao Postgres: uma para checar/gravar a chave, outra para escrever o agendamento) não tem essa garantia — uma falha entre as duas chamadas deixa a chave gravada sem o agendamento correspondente, ou vice-versa.

## Decision (proposta)

### 1. Fork arquitetural — decidido: Rota B

**Rota B — introduzir `create_appointment`/`update_appointment` como RPCs `security definer`**, absorvendo para dentro do Postgres tudo que hoje vive em `appointments.service.js` (resolução de elegibilidade do ADR 0010, snapshot do ADR 0011, checagem de idempotência, checagem de `version`) — mesma arquitetura de `checkout_close`. Consistente com o padrão já estabelecido no resto do sistema para mutações com múltiplas invariantes, com atomicidade real entre a checagem de idempotência e a escrita de negócio.

**Rota A (Express, duas etapas) foi avaliada e descartada** — introduziria a primeira rota de escrita do sistema com idempotência não-atômica, inconsistente com `checkout_close`/`inventory_adjust`/`create_package`.

**Custo aceito, registrado para dimensionamento da Phase 3:** reescrever a lógica de `appointments.service.js` em `plpgsql` (resolução de elegibilidade, snapshot, cálculo de `ends_at`, guard de FSM que já existe como trigger), migrar os testes de integração que hoje batem no Express para testes pgTAP + testes de contrato HTTP mais finos, e reduzir o módulo Express a um wrapper fino (mesmo formato que `checkout.service.js` já é hoje). É provavelmente o maior item de esforço entre os 4 ADRs desta leva — a implementação deve orçar isso como uma sub-fase própria, não um ajuste incremental.

### 2. Idempotência (aplicável às duas rotas)

`Idempotency-Key` (8-200 chars) passa a ser obrigatório em `POST /appointments`, mesma validação já existente (`shared/validation.js:84`, reaproveitada sem mudança). `PATCH /appointments/:id` também exige — reagendamentos por retry de rede têm o mesmo risco de duplicação de efeito (recomputar `ends_at`/consumir a resolução do ADR 0011 duas vezes não é destrutivo por si, mas o princípio de proteção deve ser uniforme entre todas as rotas de escrita, não seletivo).

### 3. Ativar a concorrência otimista existente

`PATCH /appointments/:id` passa a exigir `version` no payload (campo obrigatório, não opcional — evita PATCHes "cegos" que nunca souberam qual versão estavam editando). Servidor compara contra o `version` atual da linha:
- Se bater → aplica o update normalmente (o trigger já existente incrementa `version` automaticamente, nenhuma mudança na coluna em si).
- Se divergir → `409 version_conflict`, corpo inclui o estado atual da linha para o cliente decidir (recarregar e tentar de novo, ou — no ADR 0013 — mostrar um diff).

`GET /appointments/:id` já retorna a linha inteira (`COLUMNS` inclui todas as colunas relevantes); basta incluir `version` explicitamente na lista se ainda não estiver (hoje `COLUMNS` não lista `version` — precisa ser adicionado para o cliente conseguir enviá-lo de volta).

## Consequences

### Positivo
- Fecha a única rota de escrita relevante sem `Idempotency-Key`, uniformizando o contrato de todas as APIs de escrita do sistema.
- Ativa uma coluna que já existe e já está sendo mantida pelo trigger (`STORED_UNUSED` → `REAL`), sem nova migration de schema para a concorrência em si (só o contrato de API muda).
- Pré-requisito necessário para o ADR 0013 (Change Plan) — não dá para propor um diff com segurança sem saber que a leitura que gerou o diff ainda é válida no momento da escrita.

### Trade-off
- A Rota B é uma reescrita estrutural real do módulo `appointments`, não incremental — o maior item de esforço de engenharia entre os 4 ADRs desta leva; deve ser dimensionada como sub-fase própria na Phase 3.
- Tornar `version` obrigatório no PATCH é uma mudança de contrato "breaking" para qualquer cliente existente da API que hoje faz PATCH sem esse campo (hoje só a PWA consome essa rota, então o impacto prático é apenas atualizar o `apiClient`/`AgendaPage`/`ComandaPage` — sem consumidor externo documentado).

## Referências
- `backend/src/modules/checkout/checkout.service.js`, `supabase/migrations/20260712235319_mvp_baseline.sql:261-434` (`checkout_close`) — padrão de idempotência atômica a espelhar (Rota B) ou adaptar (Rota A)
- `backend/src/shared/validation.js:82-90` — `validateIdempotencyKey`, reaproveitável sem mudança
- `supabase/migrations/20260715140100_fase10_appointments_hardening.sql` — coluna `version` e trigger de incremento, hoje sem consumidor
- `backend/src/modules/appointments/appointments.service.js` — módulo a modificar (Rota A) ou substituir por RPC (Rota B)
- [ADR 0010](0010-elegibilidade-tri-state-fail-closed.md), [ADR 0011](0011-snapshot-operacional-agendamento.md) — lógica que migraria para dentro da RPC se a Rota B for aprovada
