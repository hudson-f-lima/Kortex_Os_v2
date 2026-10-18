---
title: "Onda 7 — requisitos versionados de recursos"
status: "PROPOSED"
stage: "ISSUE"
governance_ref: ["DEC-69"]
upstream_doc: "docs/waves/onda-7-agenda-drag-resize/BLUEPRINT_ONDA_7_RESIZE.md"
last_updated: "2026-10-18"
---

# 062 — Configuração de recursos por serviço e unidade

Criar, por migrations forward-only, conjuntos versionados de requisitos e linhas por tipo/quantidade, FKs compostas tenant/unit-safe, índice único de versão ativa, RLS unit-aware e RPC de configuração owner/admin/manager. Adicionar identificador nullable de requisito em `resource_locks` para distinguir lock automático de lock manual; preservar locks legados. Incluir feature flag desligada por padrão, pre-flight e guard que impede desativar/trocar tipo de recurso com locks automáticos futuros. Documentar capacidade exclusiva vigente (`resources.capacity` não multiplexa a exclusion constraint).

**Aceite:** pgTAP prova cross-tenant/unidade, constraints, versionamento, grant/REVOKE, preservação de locks manuais e mutação incompatível de recurso rejeitada. A versão draft não modifica bookings. Rodar `supabase db reset`, `supabase test db` e `supabase db lint --local` em banco descartável. Nenhuma ativação em staging ou produção nesta fatia.

Blocked by: Red Team de desenho `GO` e runtime Supabase descartável.
Blocks: [063](063-onda7-resource-allocation.md).
