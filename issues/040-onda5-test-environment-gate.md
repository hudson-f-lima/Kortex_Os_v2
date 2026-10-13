---
title: "Onda 5 — recupera o gate de ambiente de testes"
status: "IMPLEMENTADA"
stage: "ISSUE"
governance_ref: ["DEC-52", "DEC-54", "DEC-57", "ADR-0023"]
upstream_doc: "docs/waves/onda-5-recurring-group-waitlist/KORTEXOS_5_1_2_BLUEPRINT_ONDA_5.md"
last_updated: "2026-08-06"
---

# 040 — recupera o gate de ambiente de testes

Corretiva (DEC-54). O ambiente (CLI Supabase 2.109.0 + Docker, `supabase db reset` reproduzível) já estava funcional — não havia CLI incompatível para trocar. O gate degradado era um bug de ordem de execução: a suíte de backend (`node --test`) cria organizações/clientes reais via `setUpOrgWithRole` e nunca limpa (por desenho — são fixtures de integração real, não pgTAP). Isso persiste dados cross-tenant no mesmo banco local que o pgTAP reutiliza. Dois testes pgTAP legados liam tabelas de negócio sem filtrar por `organization_id`/`record_id`, então pegavam dado de OUTRA organização quando essa poluição já existia:

- `supabase/tests/rpc_fase9_foundation_test.sql` — 11 subconsultas em `public.orders` (`status = 'closed'`/`'refunded'`, `discount_cents = 2000`, `tip_cents = 1000`, sempre com `limit 1` sem `WHERE organization_id`) resolviam para o pedido mais antigo de qualquer organização, não necessariamente o desta execução — `order_refund` falhava com `order not found` ao tentar estornar um pedido de outro tenant.
- `supabase/tests/sync_events_test.sql` — as 6 contagens/leituras de `public.sync_events` filtravam só por `table_name`/`action`, sem `record_id`; com dado de outras execuções presente, `count(*) = 1` virava `count(*) = 47`.

Corrigido escopando cada consulta pelo `organization_id`/`record_id` que o próprio teste cria (`test_context`/`:client_id`), sem alterar nenhuma RPC. Reproduzido ao vivo antes e depois do fix: pgTAP limpo (908/908) → suíte de backend rodando → pgTAP quebrando nesses 2 arquivos exatamente como descrito → fix aplicado → pgTAP roda de novo na mesma ordem contaminada e permanece 908/908.

Achado à parte, na mesma auditoria (fora do escopo original desta issue, mas corrigido junto por ter aparecido na varredura): `onda5_unit_aware_write_guard_test.sql` (fatia 037) cobria só 1 das 14 operações despachadas por `private.onda5_guarded_write_dispatch` e nunca provava o caminho positivo (owner/admin/manager preservados). Expandido para as 14 operações (série, grupo, waitlist), com prova positiva para papel org-wide e para reception da unidade correta.

Aceite: `supabase db reset` limpo em ambiente local + 908/908 pgTAP (57 arquivos, inclui as fatias 036-039 e o guard de unidade expandido) + 325/325 backend (`node --test`) + `supabase db lint --local` sem achados — reconfirmado rodando o pgTAP antes e depois da suíte de backend, sem regressão em nenhuma das duas ordens.

**Fechamento (DEC-57, 2026-08-06):** com o ambiente determinístico desta fatia, o Red Team final de implementação rodou sobre 029-040 e classificou `GO` — ver Decision Log SEÇÃO 23 e ADR 0023 (seção "Red Team final"). A Onda 5 está fechada localmente; `staging`/`main`/produção seguem não autorizados sob DEC-52.
