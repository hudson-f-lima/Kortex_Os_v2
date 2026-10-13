# 10. Elegibilidade Profissional×Serviço: Modelo Tri-State e Gate Fail-Closed Configurável por Organização (Accepted)

Date: 2026-07-16

## Status

**Accepted (2026-07-16).** Este ADR é o item 3 do plano de 7 ADRs autorizado pela Fase 1 (Auditoria Executável, `docs/audit_global/SERVICE_PROFESSIONAL_OPTION_C_AUDIT.md §11`) e resolve a Decisão 2 que o [ADR 0008](0008-capacidade-profissional-default-allow-e-preco-de-pacote.md) deixou **Reaberta**. As 4 perguntas de aprovação da seção "Nomenclatura e escopo" foram respondidas pelo usuário e estão registradas na seção Decision. Nenhuma migration foi criada ainda nesta sessão — a implementação segue como próximo passo de engenharia (Phase 3 da auditoria), não bloqueada por decisão pendente.

## Context

O ADR 0008 pesquisou se um profissional sem `professional_service_capabilities` cadastrada deveria poder ser agendado (default-allow, comportamento atual) ou ficar bloqueado (default-deny). A pesquisa de mercado ficou dividida (Zenoti/Fresha em default-allow; Square/Mindbody em default-deny) e o testemunho de operação real do usuário (5 anos em Booksy) pesou para o lado de default-deny na prática vivida — mas o ADR 0008 explicitamente **não escolheu**, citando o custo de implementação (inversão de semântica de ausência de linha, UX de atribuição em massa, migração de dados) como grande demais para decidir sem aprovação.

A auditoria executável (Phase 1) confirmou o estado físico:
- `active` é um boolean simples (`professional_service_capabilities.active`), sem tri-state.
- Nenhum gate de elegibilidade existe em `appointments.service.js` — `create()`/`update()` nunca consultam `active` para bloquear, só para resolver duração (`resolveDurationMinutes`, linhas 39-62).
- **10 de 10 componentes da "Opção C"** (elegibilidade tri-state, competency tracking, grupo→profissional, approval workflow, source tracking, snapshot imutável, fail-closed gate, MOVE_TIME_ONLY, diff+confirmação, idempotência) estão ausentes.

Este ADR endereça especificamente o **primeiro** desses componentes — o modelo de dados e o gate de elegibilidade — porque os demais (snapshot, idempotência, change plan, booking×settlement) dependem dele existir primeiro.

## Pesquisa

### O problema técnico não é "allow vs. deny" — é como inverter o default sem quebrar dados existentes

Zenoti resolve elegibilidade com presença/ausência de linha (2 estados: linha existe = override se aplica; linha ausente = comportamento padrão). Esse modelo **não suporta trocar o padrão** sem reescrever o significado de "ausência" para todas as organizações já em produção — exatamente o risco que o ADR 0008 apontou (profissionais existentes ficariam subitamente bloqueados no dia do deploy).

Sistemas de permissão que precisam desse terceiro estado — "aplicar override aqui, mas cair no padrão em todo o resto" — convergem em um padrão de **três estados explícitos** em vez de dois:

> "Tri-state permissions... include three states: Allow, Deny, and Inherit... Without tri-state, if you assign Team X to a book with just View, users with both roles can no longer edit, because the presence of Team X alone overrides [the broader role]." — [BookStack Issue #5672 — Add tri-state content permissions](https://github.com/BookStackApp/BookStack/issues/5672)

O paralelo é direto: hoje, **qualquer linha em `professional_service_capabilities` já é tratada como override total** mesmo quando só `duration_override_minutes` foi preenchido (os outros campos ficam nos defaults da coluna, não "herdando" nada de fato — é coincidência de valores-padrão, não herança real). Introduzir um terceiro estado (`INHERIT`) separa "este campo tem um valor específico" de "este professional×serviço está habilitado", permitindo:
1. Inverter o default global sem tocar em linhas existentes (elas viram `ENABLED` explicitamente na migração de dados).
2. Modelar o relato do usuário sobre o Booksy real — atribuição em dois níveis (grupo inteiro **ou** serviço individual) — como duas camadas de cascata, cada uma podendo ser `INHERIT`.

O princípio fail-closed (linha ausente em **todas** as camadas = não elegível) segue o mesmo racional já citado no ADR 0008 (OWASP, "deny by default"), agora aplicado apenas onde a evidência de operação real (Booksy) apontou, não como regra universal do produto.

### A tensão real não é técnica, é de produto — e a solução é não fixar globalmente

O ADR 0008 encontrou mercado dividido (Zenoti/Fresha allow, Square/Mindbody deny) e testemunho pessoal apontando para deny-na-prática. Isso não é ruído — **é evidência de que salões diferentes esperam comportamentos diferentes**, e forçar um valor fixo no código não serviria nenhum dos dois grupos de evidência corretamente. A proposta deste ADR é tornar o default **uma configuração por organização**, não uma escolha global do time do Kortex — o que também elimina a necessidade de "vencer" o debate allow-vs-deny em abstrato.

## Decision (proposta)

### 1. Substituir `active` (boolean) por `eligibility` (tri-state) em `professional_service_capabilities`

```sql
alter table public.professional_service_capabilities
  add column eligibility text not null default 'ENABLED'
    check (eligibility in ('INHERIT', 'ENABLED', 'DISABLED'));

-- migração de dados: preserva 100% do comportamento hoje vigente
update public.professional_service_capabilities set eligibility = case
  when active then 'ENABLED'
  else 'DISABLED'
end;

-- active é removido só depois que todo código consumidor migrar para eligibility
alter table public.professional_service_capabilities drop column active;
```

`INHERIT` só faz sentido para uma linha que existe por causa de outro campo (ex.: só quer sobrepor `duration_override_minutes`, sem opinar sobre elegibilidade) — cai para a camada de grupo.

### 2. Nova tabela para atribuição em massa por grupo (paridade com o relato do Booksy: "posso escolher grupos de serviços inteiros")

```sql
create table public.professional_service_group_eligibility (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  professional_id uuid not null,
  service_group_id uuid not null,
  eligibility text not null default 'ENABLED' check (eligibility in ('INHERIT', 'ENABLED', 'DISABLED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, professional_id, service_group_id),
  foreign key (organization_id, professional_id) references public.professionals(organization_id, id) on delete restrict,
  foreign key (organization_id, service_group_id) references public.service_groups(organization_id, id) on delete restrict
);
-- RLS espelhando professional_service_capabilities (select: is_member; insert/update: owner/admin/manager; delete: owner/admin)
```

### 3. Configuração por organização (resolve a tensão de produto sem escolher um lado)

```sql
alter table public.organizations
  add column default_service_eligibility text not null default 'ENABLED'
    check (default_service_eligibility in ('ENABLED', 'DISABLED'));
```

**Toda organização existente migra com `'ENABLED'`** (= comportamento atual, zero risco de bloqueio surpresa no deploy). `'DISABLED'` só pode ser ativado deliberadamente por um `owner` via UI futura (Fase 11+), e o ADR 0008 já documentou o pré-requisito antes disso ser seguro: UX de atribuição em massa por grupo (item 2 acima resolve a parte de dados; a UI ainda não existe).

### 4. Cascata de resolução (mais específico vence, mesmo princípio de `private.resolve_commission`)

```
resolveEligibility(org, professional, service):
  1. professional_service_capabilities.eligibility (se existir linha e for ENABLED/DISABLED, não INHERIT) → retorna, fonte = "capability"
  2. professional_service_group_eligibility.eligibility (para o group_id do serviço; se existir e não for INHERIT) → retorna, fonte = "group"
  3. organizations.default_service_eligibility → retorna, fonte = "org_default"
```

A função retorna `{ eligible: boolean, source: 'capability'|'group'|'org_default' }` — o `source` é o que viabiliza a auditoria que o item 8.4 da auditoria (`Sem Rastreamento de Origem`) apontou como bloqueada; um resolver de origem única e nomeada é pré-requisito para o ADR de snapshot (próximo da lista).

### 5. Enforcement em `appointments.service.js`

`create()` e `update()` (quando `professional_id`, `service_id` ou ambos mudam) chamam `resolveEligibility` antes de `computeEndsAt`. Se `eligible === false` → `HttpError.badRequest('professional_not_eligible_for_service', ...)` com o `source` no corpo do erro para a PWA explicar a causa (ex.: "bloqueado pela configuração padrão da organização" vs. "bloqueado explicitamente para este profissional").

### 6. Nomenclatura e escopo — decisões do usuário (2026-07-16)

- **Nomes dos estados** (`INHERIT`/`ENABLED`/`DISABLED`) e das duas tabelas/coluna novas (`eligibility`, `professional_service_group_eligibility`) — **aprovado como está**, sem ajuste.
- **Gate como bloqueio rígido** (400 `professional_not_eligible_for_service` na criação/edição, não um aviso não-bloqueante na PWA) — **aprovado**.
- **Default por organização nasce `ENABLED`** para todo tenant existente, exigindo ação explícita do `owner` para trocar — **aprovado**, sem estratégia alternativa (ex.: `DISABLED` para organizações novas criadas após o deploy fica fora de escopo por ora).
- **A UI de troca de `default_service_eligibility` e de atribuição em massa por grupo** permanece fora do escopo deste ADR (só modelo de dados e gate de API) — fica como trabalho futuro, não atribuído a uma fase específica ainda.

## Consequences

### Positivo
- Resolve a Decisão 2 do ADR 0008 sem forçar uma escolha global de produto — cada organização decide, com um default seguro (`ENABLED`) que não quebra ninguém em produção hoje.
- Modelo tri-state suporta o padrão de atribuição em dois níveis (grupo + individual) relatado pelo usuário como prática real do Booksy, sem exigir que toda organização configure par a par.
- `source` no resultado do resolver destrava rastreabilidade ("de onde veio essa decisão de elegibilidade?"), pré-requisito para o próximo ADR (snapshot imutável).
- Migração de dados é não-destrutiva e reversível até o `drop column active` (que só acontece depois de todo o código consumidor migrar).

### Trade-off
- Adiciona uma tabela nova, uma coluna em `organizations`, e uma função de resolução com 3 camadas em vez da checagem única atual — mais superfície para manter e testar (RLS + pgTAP para a tabela nova, testes de cascata nos 3 níveis).
- **Não torna `DISABLED` seguro de usar sozinho** — sem a UX de atribuição em massa por grupo (Fase 11+, fora do escopo deste ADR), um `owner` que troque o default manualmente hoje bloquearia todo profissional sem linha explícita, reproduzindo o próprio risco que este modelo foi desenhado para evitar. Isso deve ser documentado como aviso na UI quando essa tela existir.
- Ainda não resolve `price_override_cents` (permanece dead code, fora de escopo — ver ADR 0008 Decisão 1, já `Accepted`) nem os buffers (`buffer_before_min`/`buffer_after_min`, aguardando a Availability Engine da Fase 14).

## Próximos ADRs (Phase 2, itens 4-7 do plano da auditoria)

Este ADR cobre só o item 3 (Elegibilidade Fail-Closed). Os itens restantes dependem deste ser aprovado primeiro, porque todos consomem o resolver/`source` que ele introduz:

4. **Snapshot Operacional** — congelar `eligibility.source` + duração/buffers resolvidos no momento da criação do agendamento (append-only), corrigindo o CRITICAL GAP de `ends_at` recalculando em updates (`appointments.service.js:116-134`).
5. **Idempotência de Commands** — `Idempotency-Key` para `POST/PATCH /appointments`, mesmo padrão já usado em `checkout`/`inventory` (`shared/validation.js:84`, `idempotency_keys` table).
6. **Change Plan e Confirmação** — diff explícito na PWA quando trocar profissional/serviço afeta um agendamento já confirmado (depende do snapshot existir para ter o que comparar).
7. **Separação Booking × Settlement** — formalizar que elegibilidade/duração resolvem no *booking* (agendamento) e comissão resolve no *settlement* (checkout), já são pipelines distintos hoje (`private.resolve_commission` roda só em `checkout_close`) — este ADR só documenta o princípio já implícito no código.

Itens 1 (Tenancy) e 2 (Actor Identity) do plano original da auditoria não geram ADR próprio — já estão comprovados como fato físico consolidado (`organization_id` e `auth.users(id)` via `memberships`, sem alternativa em nenhuma tabela) e serão apenas citados como precedente nos ADRs 4-7, evitando um documento que só ratifica o óbvio sem decisão nova.

## References
- [ADR 0008 — Capacidade profissional: preço de pacote e gate de agendamento](0008-capacidade-profissional-default-allow-e-preco-de-pacote.md) — Decisão 2, reaberta, resolvida por este documento
- `docs/audit_global/SERVICE_PROFESSIONAL_OPTION_C_AUDIT.md` §9, §11 — matriz de completude e plano de 7 ADRs autorizado
- [BookStack Issue #5672 — Add tri-state content permissions (Allow / Deny / Inherit)](https://github.com/BookStackApp/BookStack/issues/5672) — padrão de três estados citado na Pesquisa
- [Zenoti Help — Update the services an employee can perform](https://help.zenoti.com/en/employee-and-payroll/employee-related-manager-tasks/update-the-services-an-employee-can-perform.html) — modelo de 2 estados (linha existe/ausente), citado no ADR 0008, insuficiente para trocar o default sem quebrar dados
- `backend/src/modules/appointments/appointments.service.js:39-62` — `resolveDurationMinutes`, cascata "mais específico vence" que o resolver de elegibilidade espelha
- `supabase/migrations/20260713060000_professional_commissions_checkout.sql` — `private.resolve_commission`, mesmo princípio de cascata já em produção
- Memória do agente `feedback-research-before-deciding` e `user-booksy-experience` — base de evidência herdada do ADR 0008
