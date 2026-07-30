---
title: "Issue 028 - Availability Resolver Express Endpoint"
status: "IMPLEMENTED_LOCAL"
stage: "ISSUE"
governance_ref: ["DEC-49"]
upstream_doc: "docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md"
last_updated: "2026-07-29"
---

## Parent Blueprint

`docs/waves/onda-4-calendar-availability/KORTEXOS_5_1_2_BLUEPRINT_ONDA_4.md` (APROVADO, DEC-49), §3.4, §3.6, §3.7, §7.

## What to build

Módulo Express novo (`backend/src/modules/availability/`) que orquestra as funções SQL das fatias 023/027 + `appointments` existente para gerar a grade de slots — o loop de datas, a interseção política×turno e a subtração de ocupação rodam aqui (Rota A, decisão fechada por interview), testados via `node --test` (o runner real deste backend — a formulação original do issue dizia "Jest", impreciso; corrigido aqui) com um teste de integração contra o Supabase local real, mesmo padrão já usado por todo o backend. Rota nova e isolada — não modifica `create_appointment`/`checkout_close` nem nenhuma rota existente (fundação sem ativação, §3.6).

`GET /units/:unitId/availability?service_id=&professional_id=&date_from=&date_to=` — `professional_id` opcional; janela limitada a 31 dias por chamada; resposta `[{date, professional_id, slots: [{starts_at, ends_at}]}]`. Protegida por `availability_resolver_enabled` (middleware consulta `organizations.settings->>'availability_resolver_enabled'`, `403` se ausente/`false` — primeira rota desta trilha efetivamente gated por feature flag).

**Achado corrigido durante a implementação, fora do escopo original desta fatia mas necessário para ela funcionar:** `backend/src/middleware/requireFeatureFlag.js` já existia (commit `2c477b1`, anterior a esta Onda) mas lia `req.organizationContext.organization.settings` — uma forma que a cadeia real de middleware nunca produz (`organizationContext` popula `req.auth.organizationId`, não `req.organizationContext`). Como nenhuma rota usava esse middleware ainda, o bug nunca foi exercitado — só o teste unitário próprio, que mockava a mesma forma errada. Corrigido para consultar `organizations.settings` via `req.auth.organizationId` (recebe `supabaseAdmin` como parâmetro), e o teste unitário reescrito para o contrato real.

**Achado adicional:** PostgREST só expõe RPCs do schema `public`, nunca `private` — `resolve_calendar_policy`/`resolve_professional_shift`/`resolve_calendar_overrides` (fatias 023/027) são `private.*` de propósito. Adicionados 3 wrappers finos em `public.*` (mesmo nome, `security definer`, grant só `service_role`) só para o Express conseguir chamá-los — a lógica continua inteiramente nas funções `private.*` já testadas por pgTAP. Adicionado também `public.local_time_to_utc(timezone, date, local_time)`, utilitário puro reaproveitado pelo Express para converter blocos `HH:MM` resolvidos em `starts_at`/`ends_at` de resposta sem reimplementar conversão de fuso horário em JS (não há biblioteca de timezone no backend).

## Acceptance criteria

- [x] `backend/src/modules/availability/availabilitySlotMath.js` — funções puras (`intersectBlocks`, `subtractIntervalsMs`, `generateSlotStartsMs`), sem I/O, testadas isoladamente
- [x] `backend/src/modules/availability/availability.service.js` — orquestra `resolve_calendar_policy`/`resolve_professional_shift`/`resolve_calendar_overrides` (via wrappers públicos) por dia no intervalo pedido, subtrai `appointments` (`status in ('scheduled','confirmed','in_service')`) por janela UTC derivada do timezone local da unidade, não por data UTC ingênua
- [x] Duração calculada a partir de `services.duration_minutes` com override de `professional_service_capabilities.duration_override_minutes` — buffer/consumo técnico fora de escopo (limitação registrada no Blueprint §3.4, não bloqueio)
- [x] `professional_id` opcional: quando omitido, considera todo profissional com vínculo ativo à unidade **e elegível para o serviço** (ADR 0010 — ver correção pós-implementação abaixo)
- [x] Janela `date_from`/`date_to` limitada a 31 dias — requisição maior retorna `400 date_range_too_large`; datas civis impossíveis (`2027-02-31`) retornam `400 invalid_date_from`/`invalid_date_to`
- [x] Middleware de feature flag: rota retorna `403 feature_disabled` quando `organizations.settings->>'availability_resolver_enabled'` ausente ou `false`
- [x] **Unit scope enforcement** (ver correção pós-implementação): papel unit-scoped (reception/professional) só consulta a própria unidade; papel org-wide (owner/admin/manager) consulta qualquer unidade
- [x] Nenhuma alteração em `backend/src/modules/appointments/`, `backend/src/modules/checkout/`, nem em nenhuma rota existente — só arquivos novos + 2 linhas aditivas em `app.js` (import + `apiRouter.use(...)`) + a correção do middleware pré-existente não utilizado
- [x] `node --test`: funções puras de slot math — `backend/tests/unit/availabilitySlotMath.test.js`, 9/9; `requireFeatureFlag` corrigido — `backend/tests/unit/requireFeatureFlag.test.js`, 3/3; integração contra Supabase local real — `backend/tests/integration/availability.test.js`, 10/10 (403 com flag desligada; slots respeitando interseção unidade×turno e subtraindo appointment agendado, com conversão de timezone verificada contra instantes UTC esperados; nenhum slot quando o profissional não tem turno no dia; janela > 31 dias rejeitada; data civil impossível rejeitada; `professional_id` sem vínculo ativo rejeitado; appointment noturno em unidade `America/New_York` cujo UTC cai no dia seguinte subtraído corretamente; unit-scope mismatch rejeitado com 403, papel próprio e org-wide continuam funcionando; `professional_id` explícito com `eligibility='DISABLED'` rejeitado com 400; listagem sem `professional_id` omite profissional desabilitado). Suíte completa do backend: **321/321**, sem regressão

## Blocked by

026 (resource_locks — limitação registrada, ver correção pós-implementação), 027 (funções do Resolver) — concluídas

## Seções do Blueprint endereçadas

- §3.4 (contrato da rota, Rota A, limitação de buffer)
- §3.6 (fundação sem ativação — confirmação de que nenhuma rota existente muda)
- §3.7 (Feature Flag governando rota real pela primeira vez nesta trilha)
- §7 (matriz RLS e contratos afetados)

## Correção pós-implementação (2026-07-29, Red Team de implementação)

Relatório colado pelo usuário, cada achado reverificado pessoalmente contra o código antes de aceitar — todos confirmados reais:

- `CRÍTICO` — a rota nunca comparava `req.params.unitId` a `req.auth.unitId`; como `supabaseAdmin` usa `service_role` e ignora RLS, nada mais protegia isso. Reception de uma unidade lia dados de outra unidade da mesma organização. **Corrigido**: `403 unit_scope_mismatch` para papel unit-scoped consultando unidade diferente da própria.
- `CRÍTICO` — `resource_locks`/`deposit_holds` nunca eram subtraídos. **Reverificado**: `deposit_holds` não tem `starts_at`/`ends_at` próprios (sempre amarrado a um `appointment_id`, sem colunas de intervalo) — já coberto estruturalmente pela consulta a `appointments`, sem necessidade de código novo. `resource_locks` é gap real sem correção possível sem inventar um mapeamento serviço→recurso inexistente no schema — decisão do Platform Owner: documentar como limitação (ver `availability.service.js`, comentário acima de `fetchOccupiedIntervalsMs`), não simular uma regra.
- `ALTO` — elegibilidade tri-state (ADR 0010) nunca era checada, nem com `professional_id` explícito. **Corrigido**: nova função pública `resolve_eligibility` (wrapper de `private.resolve_eligibility`, já existente desde a Fase Opção C) consultada nos dois caminhos — explícito rejeita `400 professional_not_eligible`; listagem sem filtro omite profissionais desabilitados.

Evidência pós-Red-Team desta fatia foi substituída pela auditoria final abaixo.

## Auditoria final de fix (2026-07-29)

Dois bugs adicionais foram confirmados e corrigidos: `validateAvailabilityQuery` aceitava datas impossíveis porque `new Date()` normalizava `2027-02-31`, e `fetchOccupiedIntervalsMs` filtrava appointments por dia UTC, deixando disponível um horário local noturno quando a unidade estava a oeste de UTC e o `starts_at` caía no dia UTC seguinte. Corrigido com parser estrito de data civil e fronteira UTC calculada por `public.local_time_to_utc(units.timezone, date, '00:00')`.

Evidência final desta fatia: 10/10 testes de integração, suíte completa do backend 321/321.
